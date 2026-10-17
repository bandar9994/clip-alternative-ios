import Foundation
import UIKit
import ImageIO
import CryptoKit

enum AppGroup {
    static let identifier = "group.com.bandar9994.clipalt"
}

/// File based storage shared by the app and the keyboard through the App Group container.
/// Falls back to the process' own Application Support folder when the App Group is unavailable
/// (for example if the re-signing service did not keep the App Group entitlement).
final class ClipStorage {
    static let shared = ClipStorage()

    static let maxUnpinned = 300
    static let maxTextLength = 100_000

    let baseURL: URL
    let isSharedContainer: Bool
    private let indexURL: URL
    private let imagesURL: URL

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let fm = FileManager.default
        if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            baseURL = group.appendingPathComponent("ClipAlt", isDirectory: true)
            isSharedContainer = true
        } else {
            let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            baseURL = support.appendingPathComponent("ClipAlt", isDirectory: true)
            isSharedContainer = false
        }
        indexURL = baseURL.appendingPathComponent("clips.json")
        imagesURL = baseURL.appendingPathComponent("Images", isDirectory: true)
        try? fm.createDirectory(at: imagesURL, withIntermediateDirectories: true)
    }

    /// True when the storage folder can actually be written (keyboard without Full Access cannot).
    var isWritable: Bool {
        FileManager.default.isWritableFile(atPath: baseURL.path)
    }

    // MARK: - Reading

    func load() -> [ClipItem] {
        var result: [ClipItem] = []
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: indexURL, options: [], error: &error) { url in
            result = Self.read(url)
        }
        return result
    }

    func imageURL(for item: ClipItem) -> URL? {
        guard let name = item.imageFileName else { return nil }
        return imagesURL.appendingPathComponent(name)
    }

    func image(for item: ClipItem) -> UIImage? {
        guard let url = imageURL(for: item) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Memory friendly thumbnail (important inside the keyboard extension, which has a small memory limit).
    func thumbnail(for item: ClipItem, maxPixelSize: Int = 240) -> UIImage? {
        guard let url = imageURL(for: item),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Writing

    enum AddOutcome {
        case new
        case movedToTop   // same content was already stored; bumped to the top
        case rejected     // empty / could not encode
    }

    @discardableResult
    func addText(_ raw: String) -> Bool { insertText(raw) != .rejected }

    @discardableResult
    func addImage(_ image: UIImage) -> Bool { insertImage(image) != .rejected }

    /// Re-copying something that already exists moves it to the top (never silently ignored).
    func insertText(_ raw: String) -> AddOutcome {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .rejected }
        let value = String(raw.prefix(Self.maxTextLength))
        let kind: ClipKind = Self.looksLikeURL(trimmed) ? .url : .text
        let stored = kind == .url ? trimmed : value
        var outcome = AddOutcome.new
        update { items in
            if let idx = items.firstIndex(where: { $0.kind != .image && $0.text == stored }) {
                var item = items.remove(at: idx)
                item.createdAt = Date()
                items.insert(item, at: 0)
                outcome = .movedToTop
            } else {
                items.insert(ClipItem(kind: kind, text: stored), at: 0)
            }
        }
        return outcome
    }

    func insertImage(_ image: UIImage) -> AddOutcome {
        let scaled = Self.downscaled(image, maxDimension: 2048)
        guard let data = scaled.jpegData(compressionQuality: 0.88) else { return .rejected }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let name = String(digest.prefix(32)) + ".jpg"
        let fileURL = imagesURL.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            do { try data.write(to: fileURL, options: .atomic) } catch { return .rejected }
        }
        var outcome = AddOutcome.new
        update { items in
            if let idx = items.firstIndex(where: { $0.imageFileName == name }) {
                var item = items.remove(at: idx)
                item.createdAt = Date()
                items.insert(item, at: 0)
                outcome = .movedToTop
            } else {
                items.insert(ClipItem(kind: .image, imageFileName: name), at: 0)
            }
        }
        return outcome
    }

    func togglePin(_ id: UUID) {
        update { items in
            if let idx = items.firstIndex(where: { $0.id == id }) { items[idx].pinned.toggle() }
        }
    }

    func delete(_ ids: Set<UUID>) {
        update { items in items.removeAll { ids.contains($0.id) } }
    }

    func deleteAllUnpinned() {
        update { items in items.removeAll { !$0.pinned } }
    }

    /// Read-modify-write under a file coordinator so the app and keyboard don't overwrite each other.
    @discardableResult
    func update(_ body: (inout [ClipItem]) -> Void) -> [ClipItem] {
        var output: [ClipItem] = []
        var error: NSError?
        let images = imagesURL
        NSFileCoordinator().coordinate(writingItemAt: indexURL, options: .forMerging, error: &error) { url in
            var items = Self.read(url)
            body(&items)
            Self.prune(&items)
            if let data = try? Self.encoder.encode(items) {
                try? data.write(to: url, options: .atomic)
            }
            Self.removeOrphanImages(keeping: items, in: images)
            output = items
        }
        return output
    }

    // MARK: - Helpers

    private static func read(_ url: URL) -> [ClipItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }

    private static func prune(_ items: inout [ClipItem]) {
        let unpinned = items.filter { !$0.pinned }.sorted { $0.createdAt > $1.createdAt }
        guard unpinned.count > maxUnpinned else { return }
        let drop = Set(unpinned.dropFirst(maxUnpinned).map { $0.id })
        items.removeAll { drop.contains($0.id) }
    }

    private static func removeOrphanImages(keeping items: [ClipItem], in folder: URL) {
        let keep = Set(items.compactMap { $0.imageFileName })
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: folder.path) else { return }
        for file in files where !keep.contains(file) {
            try? fm.removeItem(at: folder.appendingPathComponent(file))
        }
    }

    static func looksLikeURL(_ s: String) -> Bool {
        guard !s.contains(where: { $0.isWhitespace }),
              let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return false }
        return true
    }

    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        let longest = max(pixelW, pixelH)
        guard longest > maxDimension, longest > 0 else { return image }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: (pixelW * ratio).rounded(), height: (pixelH * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
