import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItemManager = StatusItemManager()

    public static var isTerminating: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pluck runs as a lightweight accessory menu bar app while idle
        NSApp.setActivationPolicy(.accessory)

        // Pre-warm Vision OCR engine in background for instant captures
        VisionOCRService.shared.prewarm()

        // Setup menu bar status item
        statusItemManager.setup()
        statusItemManager.onCaptureRequested = {
            CaptureCoordinator.shared.startCapture()
        }

        // Setup global hotkey (default ⌘⇧P)
        HotkeyManager.shared.setup {
            CaptureCoordinator.shared.startCapture()
        }

        // Hook capture coordinator permission missing handler -> deep-links to .permissions
        CaptureCoordinator.shared.onPermissionMissing = { [weak self] in
            self?.statusItemManager.updateStatusItemIcon()
            self?.openSettingsWindow(selecting: .permissions)
        }

        // Show onboarding on first launch or resume pending onboarding step
        let resumeStepRaw = SettingsStore.shared.pendingOnboardingResumeStep
        let resumeStep = resumeStepRaw.flatMap { OnboardingStep(rawValue: $0) }

        if let step = resumeStep {
            openOnboardingWindow(startingAt: step)
        } else if !SettingsStore.shared.hasCompletedOnboarding {
            openOnboardingWindow(startingAt: .welcome)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.isTerminating = true
    }

    // MARK: - Reopen & Dock Menu Handling

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow(selecting: .general)
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let dockMenu = NSMenu()
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromDockMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        dockMenu.addItem(settingsItem)
        return dockMenu
    }

    @objc private func openSettingsFromDockMenu() {
        openSettingsWindow(selecting: .general)
    }

    // MARK: - Window Management (Strict lazy creation, fully released on close)

    func openSettingsWindow(selecting tab: SettingsTab = .general) {
        SettingsWindowController.shared.onClose = { [weak self] in
            self?.statusItemManager.updateStatusItemIcon()
        }
        SettingsWindowController.shared.onRunOnboardingAgain = { [weak self] in
            self?.openOnboardingWindow(startingAt: .welcome)
        }
        SettingsWindowController.shared.showWindow(selecting: tab)
    }

    func openOnboardingWindow(startingAt step: OnboardingStep? = nil) {
        OnboardingWindowController.shared.onClose = { [weak self] in
            self?.statusItemManager.updateStatusItemIcon()
        }
        OnboardingWindowController.shared.showWindow(startingAt: step)
    }
}

@main
@MainActor
struct PluckApp {
    private static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        self.delegate = appDelegate
        app.delegate = appDelegate
        app.run()
    }
}
