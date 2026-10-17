import AppIntents
import UIKit
import UniformTypeIdentifiers

/// "Save to ClipAlt" — for Shortcuts, Siri, the Action Button and Back Tap.
///
/// Recommended shortcut: **Get Clipboard → Save to ClipAlt** (Content = Clipboard).
/// Shortcuts reads the clipboard with its own permission and passes it in as a file
/// (text, link, rich text or image). The intent never reads UIPasteboard itself: from the
/// background iOS denies or empties that read, which is what build-11's log showed.
@available(iOS 16.0, *)
struct SaveClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Save to ClipAlt"
    static var description = IntentDescription(
        "Saves the text, link, rich text or image you pass in (e.g. from “Get Clipboard”) to ClipAlt. يحفظ النص أو الرابط أو الصورة اللي توصله (مثلًا من «الحصول على الحافظة») في ClipAlt."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Content",
        description: "Text, link, rich text or image — usually the Clipboard from “Get Clipboard”.",
        supportedTypeIdentifiers: [
            "public.image", "public.url", "public.plain-text", "public.utf8-plain-text",
            "public.text", "public.rtf", "public.html", "public.data"
        ],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var content: IntentFile?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$content) to ClipAlt")
    }

    static let nothingReceived: IntentDialog =
        "ما وصل شي — أضف «الحصول على الحافظة» قبل هذه الخطوة / Nothing received — add Get Clipboard before this action"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let content else {
            CaptureLog.shared.log(.skipped, "shortcut input: none (no content passed — add Get Clipboard before this action)", state: "intent")
            return .result(dialog: Self.nothingReceived)
        }

        let data = content.data
        let typeID = content.type?.identifier ?? "nil"
        let fileURLDesc = content.fileURL.map { $0.isFileURL ? "file:\($0.lastPathComponent)" : $0.absoluteString } ?? "nil"
        var inputDesc = "shortcut input: name=\(content.filename) type=\(typeID) bytes=\(data.count) fileURL=\(fileURLDesc)"

        let parsed = IntentContentParser.parse(content)
        let storage = ClipStorage.shared
        let outcome: ClipStorage.AddOutcome
        switch parsed {
        case .image(let image):
            outcome = storage.insertImage(image)
            inputDesc += " → image \(Int(image.size.width))x\(Int(image.size.height))"
        case .text(let text, let how):
            outcome = storage.insertText(text)
            inputDesc += " → \(how) \(text.count) chars"
        case .nothing(let reason):
            CaptureLog.shared.log(.skipped, inputDesc + " → unusable (\(reason))", state: "intent")
            return .result(dialog: Self.nothingReceived)
        }

        switch outcome {
        case .new:
            CaptureLog.shared.log(.saved, inputDesc, state: "intent")
            return .result(dialog: "انحفظ في ClipAlt ✓ / Saved to ClipAlt ✓")
        case .movedToTop:
            CaptureLog.shared.log(.movedToTop, inputDesc + " (duplicate → moved to top)", state: "intent")
            return .result(dialog: "موجود من قبل، صار فوق ✓ / Already saved — moved to top ✓")
        case .rejected:
            CaptureLog.shared.log(.skipped, inputDesc + " → empty/whitespace", state: "intent")
            return .result(dialog: Self.nothingReceived)
        }
    }
}

/// Turns whatever Shortcuts handed us into a clip.
enum IntentContentParser {
    enum Parsed {
        case image(UIImage)
        case text(String, how: String)
        case nothing(String)
    }

    static func parse(_ file: IntentFile) -> Parsed {
        let data = file.data
        let type = file.type ?? UTType(filenameExtension: (file.filename as NSString).pathExtension)

        // A link sometimes arrives as a non-file URL with little or no data.
        if let url = file.fileURL, !url.isFileURL, let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return .text(url.absoluteString, how: "url(fileURL)")
        }
        if data.isEmpty { return .nothing("0 bytes") }

        if let type {
            if type.conforms(to: .image), let image = UIImage(data: data) {
                return .image(image)
            }
            if type.conforms(to: .url) || type.identifier == "com.apple.web-internet-location" {
                if let s = urlString(from: data) { return .text(s, how: "url") }
            }
            if type.conforms(to: .rtf), let s = attributed(data, .rtf) { return .text(s, how: "rtf") }
            if type.conforms(to: .html), let s = attributed(data, .html) { return .text(s, how: "html") }
            if type.conforms(to: .text), let s = decodeText(data) { return .text(s, how: "text") }
        }

        // Unknown/generic type: sniff.
        if let image = UIImage(data: data) { return .image(image) }
        if data.starts(with: Array("{\\rtf".utf8)), let s = attributed(data, .rtf) { return .text(s, how: "rtf(sniffed)") }
        if let s = decodeText(data) { return .text(s, how: "text(sniffed)") }
        return .nothing("type=\(type?.identifier ?? "unknown") not decodable")
    }

    private static func decodeText(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        return nil
    }

    private static func attributed(_ data: Data, _ docType: NSAttributedString.DocumentType) -> String? {
        try? NSAttributedString(data: data, options: [.documentType: docType], documentAttributes: nil).string
    }

    /// Plain URL text, or a .webloc / .url plist containing a URL.
    private static func urlString(from data: Data) -> String? {
        if let s = decodeText(data)?.trimmingCharacters(in: .whitespacesAndNewlines),
           ClipStorage.looksLikeURL(s) { return s }
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let s = plist["URL"] as? String { return s }
        if let text = decodeText(data),
           let line = text.split(separator: "\n").first(where: { $0.hasPrefix("URL=") }) {
            return String(line.dropFirst(4))
        }
        return nil
    }
}

// No AppShortcutsProvider on purpose: run alone (Siri/Spotlight) this action has no
// input and can only answer "Nothing received". It is used inside a user shortcut
// (Get Clipboard → Save to ClipAlt), and still appears in the Shortcuts action library.
