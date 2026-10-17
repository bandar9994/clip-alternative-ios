import Foundation
import UIKit

enum CaptureResult {
    case saved
    case unchanged
    case empty
    case failed
}

/// Reads and writes the system pasteboard.
/// Note: on iOS 16+ reading the *contents* (string/url/image) can show the system
/// "Allow Paste" prompt unless the user sets Settings > ClipAlt > Paste from Other Apps > Allow.
/// Checking `changeCount` / `hasStrings` / `hasImages` does NOT trigger the prompt, so we only read
/// the contents when something actually changed.
enum PasteboardService {
    private static let lastChangeKey = "ClipAlt.lastPasteboardChangeCount"

    static func captureIfChanged(storage: ClipStorage = .shared) -> CaptureResult {
        let pb = UIPasteboard.general
        let count = pb.changeCount
        let defaults = UserDefaults.standard
        if defaults.object(forKey: lastChangeKey) != nil, defaults.integer(forKey: lastChangeKey) == count {
            return .unchanged
        }
        let result = capture(storage: storage)
        defaults.set(count, forKey: lastChangeKey)
        return result
    }

    static func capture(storage: ClipStorage = .shared) -> CaptureResult {
        let pb = UIPasteboard.general
        markSeen()
        if pb.hasImages {
            if let image = pb.image { return storage.addImage(image) ? .saved : .failed }
        }
        if pb.hasURLs, let url = pb.url {
            return storage.addText(url.absoluteString) ? .saved : .failed
        }
        if pb.hasStrings, let string = pb.string {
            return storage.addText(string) ? .saved : .empty
        }
        return .empty
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
