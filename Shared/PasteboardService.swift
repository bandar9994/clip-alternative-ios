import Foundation
import UIKit
import UniformTypeIdentifiers

enum CaptureResult {
    case saved
    case unchanged
    case empty
    case failed
}

/// Detailed result of one pasteboard read, used for the capture log.
struct CaptureOutcome {
    var result: CaptureResult
    var category: CaptureLog.Category
    var detail: String
}

/// Reads and writes the system pasteboard.
///
/// Prompt behaviour (iOS 16+): reading *contents* (string/url/image/items) can show the
/// "Allow Paste" prompt unless Settings › ClipAlt › Paste from Other Apps = Allow.
/// `changeCount`, `hasStrings`/`hasURLs`/`hasImages`, `types` and `detectPatterns` do NOT
/// prompt, so we use those to decide whether a read is worth it.
/// Limitation: if several copies happen between two checks, only the latest is visible —
/// iOS keeps a single pasteboard, there is no history to read back.
enum PasteboardService {
    private static let lastChangeKey = "ClipAlt.lastPasteboardChangeCount"

    static var lastSeenChangeCount: Int? {
        let d = UserDefaults.standard
        return d.object(forKey: lastChangeKey) == nil ? nil : d.integer(forKey: lastChangeKey)
    }

    static func captureIfChanged(storage: ClipStorage = .shared) -> CaptureResult {
        captureIfChangedDetailed(storage: storage)?.result ?? .unchanged
    }

    /// Returns nil when changeCount did not move.
    static func captureIfChangedDetailed(storage: ClipStorage = .shared) -> CaptureOutcome? {
        let count = UIPasteboard.general.changeCount
        if let last = lastSeenChangeCount, last == count { return nil }
        let outcome = captureDetailed(storage: storage)
        UserDefaults.standard.set(count, forKey: lastChangeKey)
        return outcome
    }

    static func capture(storage: ClipStorage = .shared) -> CaptureResult {
        captureDetailed(storage: storage).result
    }

    /// Human readable list of what's on the pasteboard (does not trigger the paste prompt).
    static func typeSummary(_ pb: UIPasteboard = .general) -> String {
        var flags: [String] = []
        if pb.hasStrings { flags.append("strings") }
        if pb.hasURLs { flags.append("urls") }
        if pb.hasImages { flags.append("images") }
        let types = pb.types.prefix(8).joined(separator: ",")
        return "has=[\(flags.joined(separator: ","))] types=[\(types)] items=\(pb.numberOfItems)"
    }

    static func captureDetailed(storage: ClipStorage = .shared) -> CaptureOutcome {
        let pb = UIPasteboard.general
        markSeen()
        let types = pb.types
        let summary = typeSummary(pb)

        // 1) Images (Photos, Safari "Copy" on an image, screenshots…)
        if pb.hasImages || types.contains(where: { UTType($0)?.conforms(to: .image) == true }) {
            if let image = pb.image ?? firstImageFromItems(pb) {
                return outcome(storage.insertImage(image), what: "image", summary: summary)
            }
            if !pb.hasStrings && !pb.hasURLs {
                return CaptureOutcome(result: .failed, category: .readFailed,
                                      detail: "image present but unreadable (paste denied?) \(summary)")
            }
        }

        // 2) URLs (Safari share sheet "Copy", long-press "Copy Link")
        if pb.hasURLs {
            if let url = pb.url ?? pb.urls?.first {
                return outcome(storage.insertText(url.absoluteString), what: "url", summary: summary)
            }
        }

        // 3) Plain text
        if pb.hasStrings {
            if let string = pb.string ?? pb.strings?.first, !string.isEmpty {
                return outcome(storage.insertText(string), what: "text(\(string.count) chars)", summary: summary)
            }
        }

        // 4) Fallbacks: raw typed values (rich text, html, plain text under other UTIs)
        if let text = textFromItems(pb), !text.isEmpty {
            return outcome(storage.insertText(text), what: "text(fallback)", summary: summary)
        }

        if pb.hasStrings || pb.hasURLs || pb.hasImages || !types.isEmpty {
            return CaptureOutcome(result: .failed, category: .readFailed,
                                  detail: "content present but read returned nil — paste denied (Settings › ClipAlt › Paste from Other Apps). \(summary)")
        }
        return CaptureOutcome(result: .empty, category: .skipped, detail: "pasteboard empty \(summary)")
    }

    private static func outcome(_ add: ClipStorage.AddOutcome, what: String, summary: String) -> CaptureOutcome {
        switch add {
        case .new: return CaptureOutcome(result: .saved, category: .saved, detail: "\(what) \(summary)")
        case .movedToTop: return CaptureOutcome(result: .saved, category: .movedToTop, detail: "\(what) duplicate → moved to top")
        case .rejected: return CaptureOutcome(result: .empty, category: .skipped, detail: "\(what) empty/whitespace or encode failed")
        }
    }

    private static func firstImageFromItems(_ pb: UIPasteboard) -> UIImage? {
        let imageTypes = ["public.png", "public.jpeg", "public.heic", "public.heif", "public.tiff", "com.compuserve.gif", "public.image"]
        for type in imageTypes {
            if let data = pb.data(forPasteboardType: type), let image = UIImage(data: data) { return image }
        }
        for item in pb.items {
            for (key, value) in item where UTType(key)?.conforms(to: .image) == true {
                if let image = value as? UIImage { return image }
                if let data = value as? Data, let image = UIImage(data: data) { return image }
            }
        }
        return nil
    }

    private static func textFromItems(_ pb: UIPasteboard) -> String? {
        for type in ["public.utf8-plain-text", "public.plain-text", "public.text"] {
            if let s = pb.value(forPasteboardType: type) as? String { return s }
            if let d = pb.data(forPasteboardType: type), let s = String(data: d, encoding: .utf8) { return s }
        }
        if let u = pb.value(forPasteboardType: "public.url") as? URL { return u.absoluteString }
        let rich: [(String, NSAttributedString.DocumentType)] = [
            ("public.rtf", .rtf), ("com.apple.flat-rtfd", .rtfd), ("public.html", .html)
        ]
        for (type, docType) in rich {
            if let d = pb.data(forPasteboardType: type),
               let attr = try? NSAttributedString(data: d, options: [.documentType: docType], documentAttributes: nil) {
                return attr.string
            }
        }
        return nil
    }

    /// Prompt-free hint about the content (logged for diagnostics). Cannot return the content itself.
    static func detectPatternsForLog(_ completion: @escaping (String) -> Void) {
        let patterns: Set<UIPasteboard.DetectionPattern> = [.probableWebURL, .probableWebSearch, .number]
        UIPasteboard.general.detectPatterns(for: patterns) { result in
            switch result {
            case .success(let found):
                completion("patterns=[\(found.map { $0.rawValue }.sorted().joined(separator: ","))]")
            case .failure(let error):
                completion("patterns=error(\(error.localizedDescription))")
            }
        }
    }

    static func copy(_ item: ClipItem, storage: ClipStorage = .shared) {
        let pb = UIPasteboard.general
        switch item.kind {
        case .text:
            pb.string = item.text ?? ""
        case .url:
            if let text = item.text, let url = URL(string: text) {
                pb.items = [["public.url": url, "public.utf8-plain-text": text]]
            } else {
                pb.string = item.text ?? ""
            }
        case .image:
            if let image = storage.image(for: item) { pb.image = image }
        }
        markSeen()
    }

    /// Remember the current change count so our own copies are not re-captured.
    static func markSeen() {
        UserDefaults.standard.set(UIPasteboard.general.changeCount, forKey: lastChangeKey)
    }
}
