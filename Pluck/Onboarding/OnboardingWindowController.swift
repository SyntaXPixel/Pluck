import AppKit
import SwiftUI

private final class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return
        }
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: OnboardingWindow?
    private var hostingController: NSHostingController<OnboardingView>?

    var onClose: (() -> Void)?

    var isWindowVisible: Bool {
        window != nil && window?.isVisible == true
    }

    func showWindow(startingAt step: OnboardingStep? = nil) {
        let initialStep = step ?? SettingsStore.shared.pendingOnboardingResumeStep.flatMap { OnboardingStep(rawValue: $0) } ?? .welcome
        SettingsStore.shared.pendingOnboardingResumeStep = initialStep.rawValue

        NSApp.setActivationPolicy(.regular)

        if let existing = window {
            hostingController?.rootView = OnboardingView(startingAt: initialStep, onFinish: { [weak self] in
                self?.close()
            })
            if let screen = NSScreen.main {
                let visible = screen.visibleFrame
                let x = visible.origin.x + (visible.width - 520) / 2
                let y = visible.origin.y + (visible.height - 440) / 2
                existing.setFrameOrigin(NSPoint(x: x, y: y))
            }
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView(startingAt: initialStep, onFinish: { [weak self] in
            self?.close()
        })

        let hosting = NSHostingController(rootView: onboardingView)
        self.hostingController = hosting

        let newWindow = OnboardingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Welcome to Pluck"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.contentViewController = hosting
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self

        // True center on visible screen area
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.origin.x + (visible.width - 520) / 2
            let y = visible.origin.y + (visible.height - 440) / 2
            newWindow.setFrame(NSRect(x: x, y: y, width: 520, height: 440), display: true)
        } else {
            newWindow.center()
        }

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        cleanup()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        cleanup()
    }

    private func cleanup() {
        window?.contentViewController = nil
        hostingController = nil
        window?.delegate = nil
        window = nil

        // If user explicitly dismissed the onboarding window (and app is NOT restarting/terminating),
        // and they already finished onboarding before, clear the resume step.
        if SettingsStore.shared.hasCompletedOnboarding && !AppDelegate.isTerminating && !PermissionsHelper.isRelaunching {
            SettingsStore.shared.pendingOnboardingResumeStep = nil
        }

        if !SettingsWindowController.shared.isWindowVisible {
            NSApp.setActivationPolicy(.accessory)
        }
        onClose?()
    }
}
