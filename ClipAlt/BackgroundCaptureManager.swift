import Foundation
import CoreLocation
import UIKit

/// Keeps the app alive in the background so it can poll the clipboard.
///
/// Technique (same idea as Riley Testut's "Clip"): iOS gives an app continuous
/// background runtime when it has an active, authorized location session with the
/// `location` background mode. We request that session at the lowest possible
/// accuracy (we never use the coordinates), and run a short timer that watches
/// `UIPasteboard.general.changeCount`. We only read the clipboard *contents* when
/// the count changes, which keeps the system "Allow Paste" prompts to a minimum.
///
/// This is deliberately opt-in: it meaningfully increases battery use, and Apple
/// may reject this pattern on the App Store. It is intended for sideloaded /
/// re-signed installs (Signulous).
@MainActor
final class BackgroundCaptureManager: NSObject, ObservableObject {
    static let shared = BackgroundCaptureManager()
    static let enabledKey = "backgroundCapture"

    @Published private(set) var isActive = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastCaptureAt: Date?
    @Published private(set) var captureCount = 0

    private let manager = CLLocationManager()
    private let storage = ClipStorage.shared
    private var pollTimer: Timer?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var pendingStart = false

    /// How often we check the clipboard change counter while running.
    private let pollInterval: TimeInterval = 1.5

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.distanceFilter = 3000
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .other
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    var hasAlwaysAuthorization: Bool { authorizationStatus == .authorizedAlways }

    // MARK: - Public control

    /// Called at app launch and when returning to foreground.
    func startIfEnabled() {
        guard isEnabled else { return }
        start()
    }

    /// Turn the feature on. Requests Always authorization if needed, then begins
    /// the keep-alive location session and the clipboard poll.
    func enable() {
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        start()
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        stop()
    }

    private func start() {
        switch authorizationStatus {
        case .notDetermined:
            // Must ask for When In Use first; we escalate to Always in the delegate.
            pendingStart = true
            manager.requestWhenInUseAuthorization()
            return
        case .authorizedWhenInUse:
            pendingStart = true
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        case .denied, .restricted:
            return
        @unknown default:
            return
        }
        beginSession()
    }

    /// True when Info.plist declares the `location` background mode. Setting
    /// `allowsBackgroundLocationUpdates` without it crashes, so we check first
    /// (in case a re-signing service stripped it).
    static var hasLocationBackgroundMode: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        return modes.contains("location")
    }

    private func configureBackgroundUpdates() {
        guard Self.hasLocationBackgroundMode else { return }
        switch authorizationStatus {
        case .authorizedAlways:
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = false
        case .authorizedWhenInUse:
            // Works too, but iOS shows the blue location indicator while backgrounded.
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        default:
            break
        }
    }

    private func beginSession() {
        configureBackgroundUpdates()
        guard !isActive else { return }
        manager.startUpdatingLocation()
        startTimer()
        isActive = true
        // Capture whatever is on the clipboard right now.
        capture()
    }

    private func stop() {
        manager.stopUpdatingLocation()
        if Self.hasLocationBackgroundMode { manager.allowsBackgroundLocationUpdates = false }
        pollTimer?.invalidate()
        pollTimer = nil
        endBackgroundTask()
        isActive = false
    }

    // MARK: - Timer / polling

    private func startTimer() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.capture() }
        }
        // .common so it keeps firing while the app is kept alive in the background.
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func capture() {
        if PasteboardService.captureIfChanged(storage: storage) == .saved {
            lastCaptureAt = Date()
            captureCount += 1
        }
    }

    // MARK: - Background task (bridges short gaps, e.g. just after backgrounding)

    func appDidEnterBackground() {
        guard isActive else { return }
        beginBackgroundTask()
    }

    func appWillEnterForeground() {
        endBackgroundTask()
    }

    private func beginBackgroundTask() {
        endBackgroundTask()
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ClipAltCapture") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }
}

extension BackgroundCaptureManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            switch status {
            case .authorizedWhenInUse:
                if self.pendingStart || self.isEnabled {
                    self.manager.requestAlwaysAuthorization()
                    self.beginSession()
                }
            case .authorizedAlways:
                if self.pendingStart || self.isEnabled {
                    self.pendingStart = false
                    self.beginSession()
                }
            case .denied, .restricted:
                self.pendingStart = false
                self.stop()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // We don't use the coordinates; the session only exists to keep us running.
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore; a location failure doesn't stop pasteboard polling.
    }
}
