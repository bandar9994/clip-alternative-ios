import Foundation

/// Lightweight diagnostics ring buffer shared by the app (and readable anywhere).
/// Stored as JSON Lines in the App Group container, capped at `maxEvents`.
/// Writes go through a serial queue + file coordinator so the app, keyboard, share
/// extension and Shortcuts intent don't corrupt the file.
final class CaptureLog {
    static let shared = CaptureLog()
    static let maxEvents = 200

    enum Category: String, Codable {
        case started, stopped
        case change          // pasteboard changeCount changed
        case saved           // a clip was stored (new)
        case movedToTop      // duplicate re-copied -> moved to top
        case skipped         // nothing worth saving
        case readFailed      // changeCount moved but we couldn't read contents
        case denied          // permission / access missing
        case info
    }

    struct Event: Codable, Identifiable {
        var id = UUID()
        var date: Date = Date()
        var category: Category
        var state: String       // "fg" / "keyboard" / "share" / "intent"
        var message: String
    }

    private let url: URL?
    private let queue = DispatchQueue(label: "com.bandar9994.clipalt.capturelog")

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    init() {
        let fm = FileManager.default
        if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            let dir = group.appendingPathComponent("ClipAlt", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("capture-log.jsonl")
        } else {
            let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            url = support?.appendingPathComponent("ClipAlt/capture-log.jsonl")
        }
    }

    func log(_ category: Category, _ message: String, state: String) {
        let event = Event(category: category, state: state, message: message)
        guard let url else { return }
        queue.async {
            guard let line = try? Self.encoder.encode(event),
                  let text = String(data: line, encoding: .utf8) else { return }
            var lines = (try? String(contentsOf: url, encoding: .utf8))?
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init) ?? []
            lines.append(text)
            if lines.count > Self.maxEvents { lines.removeFirst(lines.count - Self.maxEvents) }
            var error: NSError?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &error) { u in
                try? (lines.joined(separator: "\n") + "\n").data(using: .utf8)?.write(to: u, options: .atomic)
            }
        }
    }

    func load() -> [Event] {
        guard let url else { return [] }
        var text = ""
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { u in
            text = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
        }
        return text.split(separator: "\n", omittingEmptySubsequences: true).compactMap {
            guard let data = $0.data(using: .utf8) else { return nil }
            return try? Self.decoder.decode(Event.self, from: data)
        }
    }

    func clear() {
        guard let url else { return }
        queue.async {
            var error: NSError?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &error) { u in
                try? FileManager.default.removeItem(at: u)
            }
        }
    }

    /// Plain-text export, newest last.
    func exportText() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let header = "ClipAlt capture log — exported \(fmt.string(from: Date()))\n"
            + "format: time [state] CATEGORY message\n"
            + String(repeating: "-", count: 48) + "\n"
        let body = load().map { e in
            "\(fmt.string(from: e.date)) [\(e.state)] \(e.category.rawValue.uppercased()) \(e.message)"
        }.joined(separator: "\n")
        return header + body + "\n"
    }
}
