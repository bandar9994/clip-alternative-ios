import SwiftUI
import UIKit
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var model: ClipListModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ClipListModel.autoCaptureKey) private var autoCapture = true
    @State private var confirmClear = false
    @ObservedObject private var background = BackgroundCaptureManager.shared
    @State private var backgroundOn = UserDefaults.standard.bool(forKey: BackgroundCaptureManager.enabledKey)

    private var locationStatusText: String {
        switch background.authorizationStatus {
        case .authorizedAlways: return "Always ✅ / دائمًا"
        case .authorizedWhenInUse: return "While Using ⚠️ / أثناء الاستخدام"
        case .denied: return "Denied ❌ / مرفوض"
        case .restricted: return "Restricted ❌ / مقيّد"
        case .notDetermined: return "Not asked yet / لم يُطلب"
        @unknown default: return "Unknown"
        }
    }

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

                Section {
                    Toggle("Background capture / الحفظ بالخلفية", isOn: $backgroundOn)
                        .onChange(of: backgroundOn) { on in
                            if on { background.enable() } else { background.disable() }
                        }
                    LabeledContent("Location permission", value: locationStatusText)
                    LabeledContent("Background capture", value: background.isActive ? "Running ✅ / شغال" : "Off / متوقف")
                    if let last = background.lastCaptureAt {
                        LabeledContent("Last saved") { Text(last, style: .time) }
                    }
                    NavigationLink {
                        CaptureLogView()
                    } label: {
                        Label("Capture log / سجل الحفظ", systemImage: "list.bullet.rectangle")
                    }
                    if !BackgroundCaptureManager.hasLocationBackgroundMode {
                        Text("This install has no background location mode (the signing service removed it), so background capture can't run.")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    if backgroundOn && background.authorizationStatus != .authorizedAlways {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        } label: {
                            Label("Set Location to “Always” / اجعل الموقع «دائمًا»", systemImage: "location")
                        }
                    }
                } header: {
                    Text("Background capture")
                } footer: {
                    Text("""
                    ⚠️ Uses more battery. ClipAlt keeps a low-accuracy location session open only to stay running, and checks the clipboard every ~1.5 s. Your location is never saved or sent.
                    For it to work: Settings › ClipAlt › Location › Always, and Paste from Other Apps › Allow.

                    ⚠️ يستهلك بطارية أكثر. التطبيق يفتح الموقع بدقة منخفضة بس عشان يظل شغال بالخلفية، ويشيك على المنسوخ كل ثانية ونص تقريبًا. موقعك ما ينحفظ ولا ينرسل.
                    عشان يشتغل: الإعدادات › ClipAlt › الموقع › دائمًا، واللصق من التطبيقات الأخرى › السماح.
                    """)
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
