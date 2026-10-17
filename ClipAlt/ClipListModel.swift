import SwiftUI
import UIKit

@MainActor
final class ClipListModel: ObservableObject {
    static let autoCaptureKey = "autoCapture"

    @Published private(set) var items: [ClipItem] = []
    @Published var toast: String?

    let storage = ClipStorage.shared
    private var toastTask: Task<Void, Never>?

    init() {
        UserDefaults.standard.register(defaults: [Self.autoCaptureKey: true])
        reload()
    }

    var autoCapture: Bool { UserDefaults.standard.bool(forKey: Self.autoCaptureKey) }

    func reload() {
        items = storage.load().sortedForDisplay()
    }

    func filtered(_ query: String) -> [ClipItem] {
        items.filter { $0.matches(query) }
    }

    func onBecameActive() {
        if autoCapture, PasteboardService.captureIfChanged(storage: storage) == .saved {
            show(NSLocalizedString("Saved from clipboard", comment: ""))
        }
        reload()
    }

    func saveClipboardNow() {
        switch PasteboardService.capture(storage: storage) {
        case .saved: show("Saved from clipboard")
        case .empty, .unchanged: show("Clipboard is empty")
        case .failed: show("Could not save clipboard")
        }
        reload()
    }

    func addPasted(_ strings: [String]) {
        var saved = false
        for s in strings where storage.addText(s) { saved = true }
        PasteboardService.markSeen()
        show(saved ? "Saved" : "Nothing to save")
        reload()
    }

    func copy(_ item: ClipItem) {
        PasteboardService.copy(item, storage: storage)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        show("Copied")
    }

    func togglePin(_ item: ClipItem) {
        storage.togglePin(item.id)
        reload()
    }

    func delete(_ item: ClipItem) {
        storage.delete([item.id])
        reload()
    }

    func deleteAllUnpinned() {
        storage.deleteAllUnpinned()
        reload()
    }

    func show(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }
}
