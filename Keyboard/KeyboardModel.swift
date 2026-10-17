import UIKit
import SwiftUI

final class KeyboardModel: ObservableObject {
    weak var controller: KeyboardViewController?

    @Published var items: [ClipItem] = []
    @Published var hasFullAccess = false
    @Published var needsGlobe = true
    @Published var status: String?

    private let storage = ClipStorage.shared
    private var thumbnails: [String: UIImage] = [:]
    private var statusWorkItem: DispatchWorkItem?

    func refresh(hasFullAccess: Bool, needsGlobe: Bool) {
        self.hasFullAccess = hasFullAccess
        self.needsGlobe = needsGlobe
        reload()
    }

    func reload() {
        items = Array(storage.load().sortedForDisplay().prefix(60))
    }

    func thumbnail(for item: ClipItem) -> UIImage? {
        guard let name = item.imageFileName else { return nil }
        if let cached = thumbnails[name] { return cached }
        let image = storage.thumbnail(for: item, maxPixelSize: 160)
        if let image { thumbnails[name] = image }
        return image
    }

    func tap(_ item: ClipItem) {
        switch item.kind {
        case .text, .url:
            controller?.insert(item.text ?? "")
            UIDevice.current.playInputClick()
        case .image:
            // Keyboards can only type text; for images we put the image on the clipboard instead.
            guard hasFullAccess else {
                flash("Turn on Full Access to copy images")
                return
            }
            PasteboardService.copy(item, storage: storage)
            flash("Image copied — long-press the text field and Paste")
        }
    }

    func saveClipboard() {
        guard hasFullAccess else {
            flash("Turn on Full Access in Settings first")
            return
        }
        let outcome = PasteboardService.captureDetailed(storage: storage)
        CaptureLog.shared.log(outcome.category, "keyboard save: " + outcome.detail, state: "keyboard")
        switch outcome.result {
        case .saved: flash("Saved")
        case .empty, .unchanged: flash("Clipboard is empty")
        case .failed: flash("Could not save")
        }
        reload()
    }

    func togglePin(_ item: ClipItem) {
        guard hasFullAccess else { return flash("Turn on Full Access in Settings first") }
        storage.togglePin(item.id)
        reload()
    }

    func delete(_ item: ClipItem) {
        guard hasFullAccess else { return flash("Turn on Full Access in Settings first") }
        storage.delete([item.id])
        reload()
    }

    func space() { controller?.insert(" ") }
    func newline() { controller?.insert("\n") }
    func backspace() { controller?.deleteBackward() }
    func nextKeyboard() { controller?.nextKeyboard() }

    private func flash(_ message: String) {
        statusWorkItem?.cancel()
        status = message
        let work = DispatchWorkItem { [weak self] in self?.status = nil }
        statusWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
}
