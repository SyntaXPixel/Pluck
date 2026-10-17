import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureText = Self(
        "captureText",
        default: .init(.p, modifiers: [.control, .command])
    )
}

extension Notification.Name {
    static let pluckShortcutDidChange = Notification.Name("PluckShortcutDidChange")
    static let pluckDidStartCapture = Notification.Name("PluckDidStartCapture")
    static let pluckDidCaptureText = Notification.Name("PluckDidCaptureText")
    static let pluckDidFailCapture = Notification.Name("PluckDidFailCapture")
    static let pluckDidCancelCapture = Notification.Name("PluckDidCancelCapture")
    static let keyboardShortcutsByNameDidChange = Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")
}

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()
    static let defaultShortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .command])

    var onTrigger: (() -> Void)?

    func setup(handler: @escaping () -> Void) {
        self.onTrigger = handler

        // Migrate older default shortcuts (⌘⇧T or ⌘⇧P) to the new ⌃⌘P (Control+Command+P) default
        let migrationKey = "hasMigratedToControlCommandP"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            let oldShortcutT = KeyboardShortcuts.Shortcut(.t, modifiers: [.command, .shift])
            let oldShortcutP = KeyboardShortcuts.Shortcut(.p, modifiers: [.command, .shift])
            if let current = KeyboardShortcuts.getShortcut(for: .captureText),
               current == oldShortcutT || current == oldShortcutP {
                KeyboardShortcuts.setShortcut(.init(.p, modifiers: [.control, .command]), for: .captureText)
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }

        // Self-heal: If shortcut is currently disabled (e.g. 0 in UserDefaults) or nil, restore ⌃⌘P
        if KeyboardShortcuts.getShortcut(for: .captureText) == nil {
            KeyboardShortcuts.setShortcut(.init(.p, modifiers: [.control, .command]), for: .captureText)
        }

        // Listen for internal KeyboardShortcuts updates and forward them to Pluck observers
        NotificationCenter.default.addObserver(
            forName: .keyboardShortcutsByNameDidChange,
            object: nil,
            queue: .main
        ) { notification in
            if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, name == .captureText {
                NotificationCenter.default.post(name: .pluckShortcutDidChange, object: nil)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .captureText) { [weak self] in
            self?.onTrigger?()
        }
    }

    /// Resets the capture shortcut to the default ⌃⌘P.
    func resetToDefault() {
        KeyboardShortcuts.setShortcut(.init(.p, modifiers: [.control, .command]), for: .captureText)
        NotificationCenter.default.post(name: .pluckShortcutDidChange, object: nil)
    }

    /// Returns a human-readable representation of the current shortcut, or "⌃⌘P" by default.
    func currentShortcutString() -> String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .captureText) {
            return shortcut.description
        }
        return "⌃⌘P"
    }

    /// Checks if the current shortcut is the default ⌃⌘P.
    func isDefaultShortcut() -> Bool {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .captureText) else {
            return false
        }
        return shortcut == KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .command])
    }
}
