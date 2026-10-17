import AppKit
import CoreGraphics
import Foundation

enum PermissionsHelper {
    static let screenCaptureSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!

    /// Checks if Screen Recording access is currently preflighted/granted.
    static func isScreenRecordingGranted() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Requests screen capture access from the system and opens the System Settings pane.
    @discardableResult
    static func requestScreenRecording() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        openScreenCaptureSettings()
        return granted
    }

    public static var isRelaunching: Bool = false

    /// Opens the Screen Recording Privacy settings pane in macOS System Settings.
    static func openScreenCaptureSettings() {
        NSWorkspace.shared.open(screenCaptureSettingsURL)
    }

    /// Relaunches Pluck. macOS often requires an app relaunch after Screen Recording permission is granted.
    static func relaunchApp() {
        isRelaunching = true
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}

/// A lightweight poller that checks permission periodically.
/// Strictly active ONLY while Onboarding Step 2 is presented.
/// Avoids running any timers while the app is idle.
final class PermissionPoller {
    private var timer: Timer?

    func startPolling(interval: TimeInterval = 1.0, onChange: @escaping (Bool) -> Void) {
        stopPolling()
        // Immediately notify with current status
        onChange(PermissionsHelper.isScreenRecordingGranted())

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let granted = PermissionsHelper.isScreenRecordingGranted()
            onChange(granted)
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopPolling()
    }
}
