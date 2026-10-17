import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var model: ClipListModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ClipListModel.autoCaptureKey) private var autoCapture = true
    @State private var confirmClear = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Save clipboard when the app opens", isOn: $autoCapture)
                } header: {
                    Text("Capture")
                } footer: {
                    Text("iOS may ask “Allow Paste” each time. To stop the prompt: Settings › ClipAlt › Paste from Other Apps › Allow.\nلإيقاف رسالة السماح باللصق: الإعدادات › ClipAlt › اللصق من التطبيقات الأخرى › السماح.")
                }

                Section("Save without opening the app / حفظ بدون فتح التطبيق") {
                    step(1, "Shortcuts app › + › add “Get Clipboard”, then “Save Clipboard to ClipAlt” and pass Clipboard as Text (or Image). No paste prompt this way.",
                         "تطبيق الاختصارات › + › أضف «الحصول على الحافظة» ثم «Save Clipboard to ClipAlt» ومرّر الحافظة كنص أو صورة. بهالطريقة ما تطلع رسالة السماح.")
                    step(2, "Back Tap: Settings › Accessibility › Touch › Back Tap › Double Tap › choose that shortcut.",
                         "النقر على الظهر: الإعدادات › تسهيلات الاستخدام › اللمس › النقر على الظهر › نقرتان › اختر الاختصار.")
                    step(3, "Action Button (iPhone 15 Pro and later): Settings › Action Button › Shortcut › choose it.",
                         "زر الإجراء (آيفون ١٥ برو وأحدث): الإعدادات › زر الإجراء › اختصار › اختره.")
                    step(4, "Share sheet: in any app tap Share › ClipAlt to save text, links or images.",
                         "قائمة المشاركة: من أي تطبيق اضغط مشاركة › ClipAlt عشان تحفظ نص أو رابط أو صورة.")
                }

                Section("Diagnostics") {
                    NavigationLink {
                        CaptureLogView()
                    } label: {
                        Label("Capture log / سجل الحفظ", systemImage: "list.bullet.rectangle")
                    }
                }

                Section("Enable the keyboard / تفعيل الكيبورد") {
                    step(1, "Settings › General › Keyboard › Keyboards › Add New Keyboard… › ClipAlt",
                         "الإعدادات › عام › لوحة المفاتيح › لوحات المفاتيح › إضافة لوحة مفاتيح › ClipAlt")
                    step(2, "Tap ClipAlt and turn on “Allow Full Access” (needed to read your saved clips).",
                         "اضغط ClipAlt وفعّل «السماح بالوصول الكامل» عشان يقرأ القصاصات المحفوظة.")
                    step(3, "In any app, hold 🌐 and choose ClipAlt. Tap a clip to insert it.",
                         "في أي تطبيق اضغط مطولًا على 🌐 واختر ClipAlt، واضغط على أي قصاصة عشان تنكتب.")
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open ClipAlt in Settings", systemImage: "gear")
                    }
                }

                Section("Storage") {
                    LabeledContent("Saved clips", value: "\(model.items.count)")
                    LabeledContent("Pinned", value: "\(model.items.filter { $0.pinned }.count)")
                    LabeledContent("Shared with keyboard", value: model.storage.isSharedContainer ? "Yes" : "No")
                    if !model.storage.isSharedContainer {
                        Text("The App Group is not available in this install, so the app and the keyboard keep separate histories. The keyboard can still save the clipboard itself.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Delete all unpinned clips", role: .destructive) { confirmClear = true }
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    Text("ClipAlt is open source (MIT). Everything stays on your device — no accounts, no sync, no tracking.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all unpinned clips?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { model.deleteAllUnpinned() }
            }
        }
    }

    private func step(_ n: Int, _ en: String, _ ar: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.headline)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
            VStack(alignment: .leading, spacing: 4) {
                Text(en)
                Text(ar)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .padding(.vertical, 2)
    }
}
