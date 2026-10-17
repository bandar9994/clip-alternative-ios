import Foundation
import CoreLocation
import UIKit

/// Keeps the app alive in the background so it can poll the clipboard.
///
/// Technique (same idea as Riley Testut's "Clip"): an authorized, continuous location
/// session plus the `location` UIBackgroundMode gives the app ongoing background runtime.
/// We ask for the lowest accuracy (≈3 km, coordinates are never used or stored) but with
/// `kCLDistanceFilterNone` so iOS keeps delivering updates instead of deferring them.
///
/// Reliability design:
/// - A `DispatchSourceTimer` on a utility queue (not a RunLoop `Timer`, which is tied to
///   run-loop modes and can stall) ticks every 1 s and reads only `changeCount`
///   (cheap, prompt-free). Contents are read on the main thread only when it changed.
/// - Every location update also triggers a check, as a second heartbeat.
/// - Significant-location-change monitoring is enabled as a safety net so iOS can
///   relaunch the app in the background after it was terminated.
/// - A background task is held and renewed before expiry (never left to expire, which
///   would get the process killed).
/// - Everything is written to `CaptureLog` for diagnostics.
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
    private let log = CaptureLog.shared
    private let timerQueue = DispatchQueue(label: "com.bandar9994.clipalt.poll", qos: .utility)
    private var pollTimer: DispatchSourceTimer?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var pendingStart = false

    // Diagnostics counters
    private var lastTick = Date()
    private var lastHeartbeat = Date()
    private var ticksSinceHeartbeat = 0
    private var locationTicksSinceHeartbeat = 0
    private var changesSinceHeartbeat = 0

    private let pollInterval: TimeInterval = 1.0
    private let heartbeatInterval: TimeInterval = 60
    private let gapThreshold: TimeInterval = 5

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .other
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var hasAlwaysAuthorization: Bool { authorizationStatus == .authorizedAlways }

    static var hasLocationBackgroundMode: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        return modes.contains("location")
    }

    var stateLabel: String {
        switch UIApplication.shared.applicationState {
        case .active: return "fg"
        case .background: return "bg"
        case .inactive: return "inactive"
        @unknown default: return "?"
        }
    }

    private func note(_ c: CaptureLog.Category, _ msg: String) {
        log.log(c, msg, state: stateLabel)
    }

    // MARK: - Public control

    func startIfEnabled() {
        guard isEnabled else { return }
        start()
    }

    func enable() {
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        note(.info, "background capture enabled by user")
        start()
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        note(.info, "background capture disabled by user")
        stop()
    }

    private func start() {
        switch authorizationStatus {
        case .notDetermined:
            pendingStart = true
            manager.requestWhenInUseAuthorization()
            return
        case .authorizedWhenInUse:
            pendingStart = true
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        case .denied, .restricted:
            note(.denied, "location permission denied/restricted — cannot run in background")
            return
        @unknown default:
            return
        }
        beginSession()
    }

    private func configureBackgroundUpdates() {
        guard Self.hasLocationBackgroundMode else {
            note(.denied, "UIBackgroundModes has no 'location' (stripped by signing?) — background capture impossible")
            return
        }
        switch authorizationStatus {
        case .authorizedAlways:
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = false
        case .authorizedWhenInUse:
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
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
        startTimer()
        isActive = true
        lastTick = Date()
        lastHeartbeat = Date()
        note(.started, "session started auth=\(authLabel) bgMode=\(Self.hasLocationBackgroundMode) changeCount=\(UIPasteboard.general.changeCount)")
        if UIApplication.shared.applicationState == .background { beginBackgroundTask() }
        check(reason: "start")
    }

    private func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        if Self.hasLocationBackgroundMode { manager.allowsBackgroundLocationUpdates = false }
        pollTimer?.cancel()
        pollTimer = nil
        endBackgroundTask()
        if isActive { note(.stopped, "session stopped") }
        isActive = false
    }

    private var authLabel: String {
        switch authorizationStatus {
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whenInUse"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Polling

    private func startTimer() {
        pollTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval, leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            // changeCount is cheap and prompt-free; compare off-main, hop to main only if needed.
            let count = UIPasteboard.general.changeCount
            Task { @MainActor in self?.timerTick(observedCount: count) }
        }
        timer.resume()
        pollTimer = timer
    }

    private func timerTick(observedCount: Int) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        if elapsed > gapThreshold {
            note(.gap, String(format: "no ticks for %.0fs (app was suspended/throttled by iOS) — resumed", elapsed))
        }
        lastTick = now
        ticksSinceHeartbeat += 1
        if PasteboardService.lastSeenChangeCount != observedCount {
            check(reason: "timer")
        }
        heartbeatIfDue(now)
    }

    /// Reads the pasteboard if its changeCount moved, and logs the outcome.
    private func check(reason: String) {
        let before = PasteboardService.lastSeenChangeCount
        let current = UIPasteboard.general.changeCount
        guard before != current else { return }
        changesSinceHeartbeat += 1
        let skipped = before.map { max(0, current - $0 - 1) } ?? 0
        var changeMsg = "changeCount \(before.map(String.init) ?? "nil")→\(current) via \(reason)"
        if skipped > 0 {
            changeMsg += " ⚠️ \(skipped) intermediate copy(ies) not observable (overwritten before check)"
        }
        note(.change, changeMsg + " " + PasteboardService.typeSummary())
        PasteboardService.detectPatternsForLog { [weak self] patterns in
            Task { @MainActor in self?.note(.info, "changeCount \(current) \(patterns)") }
        }
        guard let outcome = PasteboardService.captureIfChangedDetailed(storage: storage) else { return }
        note(outcome.category, outcome.detail)
        if outcome.result == .saved {
            lastCaptureAt = Date()
            captureCount += 1
        }
    }

    private func heartbeatIfDue(_ now: Date) {
        guard now.timeIntervalSince(lastHeartbeat) >= heartbeatInterval else { return }
        let app = UIApplication.shared
        let remaining = app.backgroundTimeRemaining
        let remainingText = remaining > 1e6 ? "unlimited" : String(format: "%.0fs", remaining)
        note(.heartbeat, "alive ticks=\(ticksSinceHeartbeat) locationUpdates=\(locationTicksSinceHeartbeat) changes=\(changesSinceHeartbeat) bgTimeRemaining=\(remainingText) bgTask=\(bgTask != .invalid) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
        lastHeartbeat = now
        ticksSinceHeartbeat = 0
        locationTicksSinceHeartbeat = 0
        changesSinceHeartbeat = 0
        // Renew the background task well before it expires.
        if app.applicationState == .background, remaining < 60 { beginBackgroundTask() }
    }

    // MARK: - Lifecycle

    func appDidEnterBackground() {
        note(.info, "entered background (session active=\(isActive))")
        guard isActive else { return }
        beginBackgroundTask()
    }

    func appWillEnterForeground() {
        if isActive { note(.info, "entered foreground") }
        endBackgroundTask()
    }

    private func beginBackgroundTask() {
        let old = bgTask
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ClipAltCapture") { [weak self] in
            // Expiring: end it ourselves so iOS doesn't kill the process; location keeps us alive.
            MainActor.assumeIsolated {
                self?.note(.info, "background task expired — ending it (location session keeps app alive)")
                self?.endBackgroundTask()
            }
        }
        if old != .invalid { UIApplication.shared.endBackgroundTask(old) }
    }

    private func endBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }

    fileprivate func handleLocationUpdate() {
        locationTicksSinceHeartbeat += 1
        let now = Date()
        if now.timeIntervalSince(lastTick) > gapThreshold {
            note(.gap, String(format: "woken by location update after %.0fs without timer ticks", now.timeIntervalSince(lastTick)))
            lastTick = now
        }
        check(reason: "location")
        heartbeatIfDue(now)
    }

    fileprivate func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        note(.info, "location authorization → \(authLabel)")
        switch status {
        case .authorizedWhenInUse:
            if pendingStart || isEnabled {
                manager.requestAlwaysAuthorization()
                beginSession()
            }
        case .authorizedAlways:
            if pendingStart || isEnabled {
                pendingStart = false
                beginSession()
            }
        case .denied, .restricted:
            pendingStart = false
            if isEnabled { note(.denied, "location denied — background capture stopped") }
            stop()
        default:
            break
        }
    }
}

extension BackgroundCaptureManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in BackgroundCaptureManager.shared.handleAuthorization(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in BackgroundCaptureManager.shared.handleLocationUpdate() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in BackgroundCaptureManager.shared.note(.info, "location error: \(message)") }
    }

    nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor in BackgroundCaptureManager.shared.note(.gap, "iOS PAUSED location updates (app may be suspended soon)") }
    }

    nonisolated func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor in BackgroundCaptureManager.shared.note(.info, "iOS resumed location updates") }
    }
}
