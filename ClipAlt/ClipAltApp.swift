import SwiftUI
import UIKit

@main
struct ClipAltApp: App {
    @StateObject private var model = ClipListModel()
    @StateObject private var background = BackgroundCaptureManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Also runs when iOS relaunches us in the background (significant location change),
        // where no window appears and onAppear would never fire.
        // Deferred so UIApplication is fully set up before we touch it.
        DispatchQueue.main.async {
            let bg = UIApplication.shared.applicationState == .background
            CaptureLog.shared.log(.info, "app launched", state: bg ? "bg" : "fg")
            Task { @MainActor in BackgroundCaptureManager.shared.startIfEnabled() }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(background)
                .onAppear { background.startIfEnabled() }
                .onReceive(background.$captureCount) { _ in model.reload() }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                background.appWillEnterForeground()
                background.startIfEnabled()
                model.onBecameActive()
            case .background:
                background.appDidEnterBackground()
            default:
                break
            }
        }
    }
}
