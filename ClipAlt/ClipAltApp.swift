import SwiftUI

@main
struct ClipAltApp: App {
    @StateObject private var model = ClipListModel()
    @StateObject private var background = BackgroundCaptureManager.shared
    @Environment(\.scenePhase) private var scenePhase

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
