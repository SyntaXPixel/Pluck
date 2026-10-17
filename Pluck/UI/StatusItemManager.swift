import AppKit
import Combine
import Foundation
import KeyboardShortcuts

@MainActor
final class StatusItemManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var cancellables = Set<AnyCancellable>()

    var onCaptureRequested: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = !SettingsStore.shared.hideMenuBarIcon
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        SettingsStore.shared.$hideMenuBarIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hide in
                self?.statusItem.isVisible = !hide
            }
            .store(in: &cancellables)

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutChanged),
            name: .pluckShortcutDidChange,
            object: nil
        )

        updateStatusItemIcon()
        rebuildMenu()
    }

    func updateStatusItemIcon() {
        guard let button = statusItem.button else { return }
        let hasPermission = PermissionsHelper.isScreenRecordingGranted()
        button.image = AssetHelper.statusBarIcon(hasPermission: hasPermission)
        button.toolTip = hasPermission ? "Pluck — Screen OCR" : "Pluck — Screen Recording Permission Required"
    }

    func rebuildMenu() {
        menu.removeAllItems()
        let hasPermission = PermissionsHelper.isScreenRecordingGranted()
        let isMaccyInstalled = MaccyDetector.isMaccyInstalled

        // 1. Permission Warning (if missing)
        if !hasPermission {
            let fixItem = NSMenuItem(
                title: "⚠️ Screen Recording Required…",
                action: #selector(fixPermissionTapped),
                keyEquivalent: ""
            )
            fixItem.target = self
            menu.addItem(fixItem)
            menu.addItem(NSMenuItem.separator())
        }

        // 2. Primary Trigger
        let shortcut = HotkeyManager.shared.currentShortcutString()
        let captureTitle = "Capture Text (\(shortcut))"
        let captureItem = NSMenuItem(
            title: captureTitle,
            action: #selector(captureTapped),
            keyEquivalent: ""
        )
        captureItem.target = self
        captureItem.isEnabled = hasPermission
        menu.addItem(captureItem)

        // 3. Text Cleaning (Cascading submenu on hover)
        let cleaningItem = NSMenuItem(title: "Text Cleaning", action: nil, keyEquivalent: "")
        let cleaningSubmenu = NSMenu()

        let trimItem = NSMenuItem(
            title: "Trim Whitespace",
            action: #selector(toggleTrimWhitespace),
            keyEquivalent: ""
        )
        trimItem.target = self
        trimItem.state = SettingsStore.shared.trimWhitespace ? .on : .off
        cleaningSubmenu.addItem(trimItem)

        let mergeItem = NSMenuItem(
            title: "Merge Line Breaks",
            action: #selector(toggleMergeLineBreaks),
            keyEquivalent: ""
        )
        mergeItem.target = self
        mergeItem.state = SettingsStore.shared.mergeLineBreaks ? .on : .off
        cleaningSubmenu.addItem(mergeItem)

        let hyphenItem = NSMenuItem(
            title: "Remove Hyphenation",
            action: #selector(toggleRemoveHyphenation),
            keyEquivalent: ""
        )
        hyphenItem.target = self
        hyphenItem.state = SettingsStore.shared.removeHyphenation ? .on : .off
        cleaningSubmenu.addItem(hyphenItem)

        cleaningItem.submenu = cleaningSubmenu
        menu.addItem(cleaningItem)

        menu.addItem(NSMenuItem.separator())

        // 4. History Section (Minimal naming)
        if isMaccyInstalled {
            let historyItem = NSMenuItem(
                title: "Save to Maccy",
                action: #selector(toggleHistoryTapped),
                keyEquivalent: ""
            )
            historyItem.target = self
            historyItem.state = SettingsStore.shared.saveToHistory ? .on : .off
            menu.addItem(historyItem)

            let openMaccyItem = NSMenuItem(
                title: "Open Maccy History",
                action: #selector(openMaccyTapped),
                keyEquivalent: ""
            )
            openMaccyItem.target = self
            menu.addItem(openMaccyItem)

            menu.addItem(NSMenuItem.separator())
        } else {
            let getMaccyItem = NSMenuItem(
                title: "Get Maccy…",
                action: #selector(getMaccyTapped),
                keyEquivalent: ""
            )
            getMaccyItem.target = self
            menu.addItem(getMaccyItem)

            menu.addItem(NSMenuItem.separator())
        }

        // 5. Application Controls (Minimal naming)
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(settingsTapped),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About",
            action: #selector(aboutTapped),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitTapped),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateStatusItemIcon()
        rebuildMenu()
    }

    // MARK: - Actions

    @objc private func fixPermissionTapped() {
        SettingsWindowController.shared.showWindow(selecting: .permissions)
    }

    @objc private func captureTapped() {
        onCaptureRequested?()
    }

    @objc private func toggleTrimWhitespace() {
        SettingsStore.shared.trimWhitespace.toggle()
        rebuildMenu()
    }

    @objc private func toggleMergeLineBreaks() {
        SettingsStore.shared.mergeLineBreaks.toggle()
        rebuildMenu()
    }

    @objc private func toggleRemoveHyphenation() {
        SettingsStore.shared.removeHyphenation.toggle()
        rebuildMenu()
    }

    @objc private func toggleHistoryTapped() {
        SettingsStore.shared.saveToHistory.toggle()
        rebuildMenu()
    }

    @objc private func openMaccyTapped() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: MaccyDetector.maccyBundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    @objc private func settingsTapped() {
        SettingsWindowController.shared.showWindow(selecting: .general)
    }

    @objc private func aboutTapped() {
        SettingsWindowController.shared.showWindow(selecting: .about)
    }

    @objc private func getMaccyTapped() {
        MaccyDetector.openReleases()
    }

    @objc private func systemAppearanceChanged() {
        updateStatusItemIcon()
    }

    @objc private func shortcutChanged() {
        rebuildMenu()
    }

    @objc private func quitTapped() {
        NSApp.terminate(nil)
    }
}
