import SwiftUI

@main
struct ClipAltApp: App {
    @StateObject private var model = ClipListModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                model.onBecameActive()
            }
        }
    }
}
