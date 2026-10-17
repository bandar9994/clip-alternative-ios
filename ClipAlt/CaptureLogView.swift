import SwiftUI

struct CaptureLogView: View {
    @State private var events: [CaptureLog.Event] = []
    @State private var confirmClear = false
    @State private var exportURL: URL?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d HH:mm:ss"
        return f
    }()

    var body: some View {
        List {
            Section {
                Text("Last \(CaptureLog.maxEvents) capture events, newest first. Share this log if clips are missed.\nآخر \(CaptureLog.maxEvents) حدث، الأحدث فوق. شارك السجل إذا فيه نسخ ما انحفظ.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if events.isEmpty {
                Text("No events yet / ما فيه أحداث للحين").foregroundStyle(.secondary)
            }
            ForEach(events.reversed()) { event in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(Self.timeFormatter.string(from: event.date))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(event.state)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(event.state == "bg" ? Color.purple.opacity(0.2) : Color.green.opacity(0.2)))
                        Text(event.category.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: event.category))
                    }
                    Text(event.message)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Capture log / سجل الحفظ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { reload() } label: { Image(systemName: "arrow.clockwise") }
                if let exportURL {
                    ShareLink(item: exportURL) { Image(systemName: "square.and.arrow.up") }
                }
                Button(role: .destructive) { confirmClear = true } label: { Image(systemName: "trash") }
            }
        }
        .confirmationDialog("Clear the capture log?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear / مسح", role: .destructive) {
                CaptureLog.shared.clear()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { reload() }
            }
        }
        .onAppear { reload() }
        .refreshable { reload() }
    }

    private func reload() {
        events = CaptureLog.shared.load()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClipAlt-capture-log.txt")
        try? CaptureLog.shared.exportText().write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
    }

    private func color(for c: CaptureLog.Category) -> Color {
        switch c {
        case .saved, .movedToTop: return .green
        case .readFailed, .denied: return .red
        case .gap: return .orange
        case .change: return .blue
        case .heartbeat, .location: return .secondary
        default: return .primary
        }
    }
}
