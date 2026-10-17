import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 6) {
            header
            if !model.hasFullAccess && model.items.isEmpty {
                fullAccessHint
            } else if model.items.isEmpty {
                Spacer()
                Text("No clips yet. Copy something, then tap “Save clipboard”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            } else {
                clipList
            }
            bottomRow
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var header: some View {
        HStack {
            Text(model.status ?? "ClipAlt")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(model.status == nil ? Color.primary : Color.accentColor)
            Spacer()
            Button(action: model.saveClipboard) {
                Label("Save clipboard", systemImage: "square.and.arrow.down")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var fullAccessHint: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "lock.shield").font(.title2).foregroundStyle(.secondary)
            Text("Turn on Full Access: Settings › General › Keyboard › Keyboards › ClipAlt › Allow Full Access")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Text("فعّل «السماح بالوصول الكامل» عشان يظهر سجل النسخ")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var clipList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(model.items) { item in
                    Button { model.tap(item) } label: { row(item) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { model.togglePin(item) } label: {
                                Label(item.pinned ? "Unpin" : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
                            }
                            Button(role: .destructive) { model.delete(item) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        HStack(spacing: 10) {
            if item.kind == .image, let thumb = model.thumbnail(for: item) {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: item.symbolName)
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
            }
            Text(item.preview)
                .font(.callout)
                .lineLimit(2)
                .foregroundStyle(item.kind == .url ? Color.blue : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.pinned {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .contentShape(Rectangle())
    }

    private var bottomRow: some View {
        HStack(spacing: 6) {
            if model.needsGlobe {
                key(systemImage: "globe", action: model.nextKeyboard)
                    .frame(width: 48)
            }
            key(title: "space", action: model.space)
            key(systemImage: "delete.left", action: model.backspace)
                .frame(width: 56)
            key(systemImage: "return", action: model.newline)
                .frame(width: 56)
        }
        .frame(height: 42)
    }

    private func key(title: String? = nil, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(title ?? "")
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.systemBackground).opacity(0.9))
                    .shadow(color: .black.opacity(0.2), radius: 0, x: 0, y: 1)
            )
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
    }
}
