import AppIntents
import UIKit
import UniformTypeIdentifiers

/// "Save Clipboard" — usable from Shortcuts, Siri, the Action Button and Back Tap
/// (Settings › Accessibility › Touch › Back Tap › pick the shortcut).
///
/// Tip: in Shortcuts, chain "Get Clipboard" → "Save to ClipAlt" (pass it as Text/Image).
/// Shortcuts reads the clipboard with its own permission, so ClipAlt itself never shows
/// the "Allow Paste" prompt. With no input, ClipAlt reads the clipboard directly.
@available(iOS 16.0, *)
struct SaveClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Clipboard to ClipAlt"
    static var description = IntentDescription("Saves what's on the clipboard (or the text/image you pass in) to ClipAlt's history. يحفظ المنسوخ في سجل ClipAlt.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Text", description: "Optional text to save instead of reading the clipboard.")
    var text: String?

    @Parameter(title: "Image", description: "Optional image to save.", supportedTypeIdentifiers: ["public.image"])
    var image: IntentFile?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$text) \(\.$image) to ClipAlt")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let storage = ClipStorage.shared
        var savedSomething = false
        var notes: [String] = []

        if let image, let ui = UIImage(data: image.data) {
            let r = storage.insertImage(ui)
            savedSomething = savedSomething || r != .rejected
            notes.append("image:\(r)")
        }
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let r = storage.insertText(text)
            savedSomething = savedSomething || r != .rejected
            notes.append("text(\(text.count) chars):\(r)")
        }

        if notes.isEmpty {
            // No input: read the clipboard ourselves (may show "Allow Paste" unless allowed in Settings).
            let outcome = PasteboardService.captureDetailed(storage: storage)
            CaptureLog.shared.log(outcome.category, "shortcut: " + outcome.detail, state: "intent")
            switch outcome.result {
            case .saved:
                return .result(dialog: "Saved to ClipAlt ✓")
            case .empty, .unchanged:
                return .result(dialog: "Clipboard is empty")
            case .failed:
                return .result(dialog: "Couldn't read the clipboard. Allow paste: Settings › ClipAlt › Paste from Other Apps › Allow.")
            }
        }

        CaptureLog.shared.log(savedSomething ? .saved : .skipped, "shortcut input: " + notes.joined(separator: " "), state: "intent")
        return .result(dialog: savedSomething ? IntentDialog("Saved to ClipAlt ✓") : IntentDialog("Nothing to save"))
    }
}

@available(iOS 16.0, *)
struct ClipAltShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveClipboardIntent(),
            phrases: [
                "Save clipboard in \(.applicationName)",
                "Save to \(.applicationName)"
            ],
            shortTitle: "Save Clipboard",
            systemImageName: "doc.on.clipboard"
        )
    }
}
