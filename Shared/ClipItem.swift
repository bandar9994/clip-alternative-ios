import Foundation

enum ClipKind: String, Codable {
    case text
    case url
    case image
}

struct ClipItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: ClipKind
    var text: String?
    var imageFileName: String?
    var createdAt: Date = Date()
    var pinned: Bool = false

    /// One-line preview used in lists and the keyboard.
    var preview: String {
        switch kind {
        case .text, .url:
            let raw = text ?? ""
            let collapsed = raw.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
            return String(collapsed.prefix(300))
        case .image:
            return "Image"
        }
    }

    var symbolName: String {
        switch kind {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .image: return "photo"
        }
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        switch kind {
        case .text, .url:
            return (text ?? "").localizedCaseInsensitiveContains(q)
        case .image:
            return "image".localizedCaseInsensitiveContains(q) || "صورة".contains(q)
        }
    }
}

extension Array where Element == ClipItem {
    /// Pinned first, then newest first.
    func sortedForDisplay() -> [ClipItem] {
        sorted { a, b in
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            return a.createdAt > b.createdAt
        }
    }
}
