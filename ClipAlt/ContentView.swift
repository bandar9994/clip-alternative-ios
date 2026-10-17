import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: ClipListModel
    @State private var query = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if model.items.isEmpty {
                    EmptyStateView()
                } else {
                    list
                }
            }
            .navigationTitle("ClipAlt")
            .searchable(text: $query, prompt: "Search clips / بحث")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // PasteButton never shows the system "Allow Paste" prompt.
                    PasteButton(payloadType: String.self) { strings in
                        Task { @MainActor in model.addPasted(strings) }
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.capsule)

                    Menu {
                        Button { model.saveClipboardNow() } label: {
                            Label("Save clipboard (text, link or image)", systemImage: "square.and.arrow.down")
                        }
                        Button(role: .destructive) { model.deleteAllUnpinned() } label: {
                            Label("Delete all unpinned", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { model.onBecameActive() }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(model)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var list: some View {
        let results = model.filtered(query)
        return List {
            ForEach(results) { item in
                ClipRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture { model.copy(item) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { model.delete(item) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { model.togglePin(item) } label: {
                            Label(item.pinned ? "Unpin" : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button { model.copy(item) } label: { Label("Copy", systemImage: "doc.on.doc") }
                        Button { model.togglePin(item) } label: {
                            Label(item.pinned ? "Unpin" : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
                        }
                        shareButton(for: item)
                        Button(role: .destructive) { model.delete(item) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            if results.isEmpty {
                Text("No results").foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func shareButton(for item: ClipItem) -> some View {
        switch item.kind {
        case .image:
            if let url = model.storage.imageURL(for: item) {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
            }
        case .text, .url:
            ShareLink(item: item.text ?? "") { Label("Share", systemImage: "square.and.arrow.up") }
        }
    }
}

struct ClipRow: View {
    let item: ClipItem
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.kind == .image {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                    } else {
                        Color.secondary.opacity(0.15)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: item.symbolName)
                    .foregroundStyle(item.kind == .url ? Color.blue : Color.accentColor)
                    .frame(width: 24)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .lineLimit(3)
                    .foregroundStyle(item.kind == .url ? Color.blue : Color.primary)
                HStack(spacing: 6) {
                    if item.pinned {
                        Image(systemName: "pin.fill").foregroundStyle(.orange)
                    }
                    Text(item.createdAt, style: .relative)
                    Text("ago")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .task(id: item.imageFileName) {
            if item.kind == .image {
                thumbnail = ClipStorage.shared.thumbnail(for: item, maxPixelSize: 200)
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No clips yet").font(.title3.weight(.semibold))
            Text("Copy something, then open ClipAlt — or tap the Paste button above.\nانسخ أي شي وافتح التطبيق، أو اضغط زر اللصق فوق.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
