import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case ocr = "OCR & Text"
    case clipboard = "Clipboard"
    case sound = "Sound"
    case permissions = "Permissions"
    case about = "About"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .ocr: return "text.viewfinder"
        case .clipboard: return "doc.on.clipboard"
        case .sound: return "speaker.wave.2"
        case .permissions: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

final class SettingsNavigationModel: ObservableObject {
    @Published var selectedTab: SettingsTab

    init(selectedTab: SettingsTab = .general) {
        self.selectedTab = selectedTab
    }
}

private final class SettingsWindow: NSWindow {
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
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: SettingsWindow?
    private var hostingController: NSHostingController<SettingsView>?
    private var navigationModel: SettingsNavigationModel?

    var onClose: (() -> Void)?
    var onRunOnboardingAgain: (() -> Void)?

    var isWindowVisible: Bool {
        window != nil && window?.isVisible == true
    }

    func showWindow(selecting tab: SettingsTab = .general) {
        // Display Pluck icon in the Dock while Settings is open
        NSApp.setActivationPolicy(.regular)
        setupMainMenuIfNeeded()

        if let existing = window {
            navigationModel?.selectedTab = tab
            centerWindow(existing)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let nav = SettingsNavigationModel(selectedTab: tab)
        self.navigationModel = nav

        let settingsView = SettingsView(
            navigation: nav,
            onRunOnboardingAgain: { [weak self] in
                guard let self = self else { return }
                self.close(switchingToOnboarding: true)
                self.onRunOnboardingAgain?()
                OnboardingWindowController.shared.showWindow(startingAt: .welcome)
            }
        )

        let hosting = NSHostingController(rootView: settingsView)
        self.hostingController = hosting

        let newWindow = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Settings"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.contentViewController = hosting
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self

        centerWindow(newWindow)

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func centerWindow(_ targetWindow: NSWindow) {
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.origin.x + (visible.width - 640) / 2
            let y = visible.origin.y + (visible.height - 460) / 2
            targetWindow.setFrame(NSRect(x: x, y: y, width: 640, height: 460), display: true)
        } else {
            targetWindow.center()
        }
    }

    private func setupMainMenuIfNeeded() {
        guard NSApp.mainMenu == nil else { return }
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Pluck")
        let aboutItem = NSMenuItem(title: "About Pluck", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())
        let prefItem = NSMenuItem(title: "Settings…", action: #selector(openPreferences), keyEquivalent: ",")
        prefItem.target = self
        appMenu.addItem(prefItem)
        appMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Pluck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = NSApp
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. Edit Menu (Critical for Cocoa text fields and keyboard responder chain)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 3. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openAbout() {
        showWindow(selecting: .about)
    }

    @objc private func openPreferences() {
        showWindow(selecting: .general)
    }

    func close(switchingToOnboarding: Bool = false) {
        window?.close()
        cleanup(switchingToOnboarding: switchingToOnboarding)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        cleanup()
    }

    private func cleanup(switchingToOnboarding: Bool = false) {
        window?.contentViewController = nil
        hostingController = nil
        navigationModel = nil
        window?.delegate = nil
        window = nil

        // Clear top-level menus and restore accessory mode only if not switching to onboarding
        // and onboarding is not currently visible
        if !switchingToOnboarding && !OnboardingWindowController.shared.isWindowVisible {
            NSApp.mainMenu = nil
            NSApp.setActivationPolicy(.accessory)
        }
        onClose?()
    }
}
