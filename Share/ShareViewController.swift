import UIKit
import UniformTypeIdentifiers

/// Share Extension: "Share › ClipAlt" saves text, links and images straight into the
/// shared history (no clipboard access, so no "Allow Paste" prompt).
final class ShareViewController: UIViewController {
    private let storage = ClipStorage.shared
    private let label = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        label.text = "Saving to ClipAlt…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 0
        spinner.startAnimating()
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 240),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])

        Task { await handleInput() }
    }

    @MainActor
    private func handleInput() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var saved = 0
        var notes: [String] = []

        for item in items {
            let providers = item.attachments ?? []
            for provider in providers {
                if let note = await save(provider) {
                    saved += 1
                    notes.append(note)
                }
            }
            // Some apps only send attributed text without attachments.
            if providers.isEmpty, let text = item.attributedContentText?.string,
               storage.insertText(text) != .rejected {
                saved += 1
                notes.append("attributedText")
            }
        }

        CaptureLog.shared.log(saved > 0 ? .saved : .skipped,
                              "share extension: \(saved) item(s) \(notes.joined(separator: ","))",
                              state: "share")
        spinner.stopAnimating()
        label.text = saved > 0 ? "Saved to ClipAlt ✓\nانحفظ ✓" : "Nothing to save"
        try? await Task.sleep(nanoseconds: 700_000_000)
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Image first, then URL, then text — one clip per attachment.
    private func save(_ provider: NSItemProvider) async -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let image = await loadImage(provider),
           storage.insertImage(image) != .rejected {
            return "image"
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
           let url = item as? URL,
           !url.isFileURL,
           storage.insertText(url.absoluteString) != .rejected {
            return "url"
        }
        for type in [UTType.plainText.identifier, UTType.text.identifier] where provider.hasItemConformingToTypeIdentifier(type) {
            if let item = try? await provider.loadItem(forTypeIdentifier: type) {
                var text: String?
                if let s = item as? String { text = s }
                else if let a = item as? NSAttributedString { text = a.string }
                else if let d = item as? Data { text = String(data: d, encoding: .utf8) }
                else if let u = item as? URL, u.isFileURL { text = try? String(contentsOf: u, encoding: .utf8) }
                if let text, storage.insertText(text) != .rejected { return "text" }
            }
        }
        return nil
    }

    private func loadImage(_ provider: NSItemProvider) async -> UIImage? {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) else { return nil }
        if let image = item as? UIImage { return image }
        if let data = item as? Data { return UIImage(data: data) }
        if let url = item as? URL, let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }
}
