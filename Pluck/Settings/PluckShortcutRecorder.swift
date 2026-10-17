import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import SwiftUI

struct PluckShortcutRecorderView: NSViewRepresentable {
    func makeNSView(context: Context) -> PluckShortcutRecorderControl {
        PluckShortcutRecorderControl()
    }

    func updateNSView(_ nsView: PluckShortcutRecorderControl, context: Context) {
        nsView.updateDisplay()
    }
}

final class PluckShortcutRecorderControl: NSView {
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton()

    private var isRecording: Bool = false
    private var eventMonitor: Any?
    private var windowResignObserver: NSObjectProtocol?
    private var shortcutObservers: [NSObjectProtocol] = []
    private var lastSavedShortcut: KeyboardShortcuts.Shortcut?

    override var intrinsicContentSize: CGSize {
        CGSize(width: 140, height: 26)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 140, height: 26))
        setupUI()
        setupNotifications()
        updateDisplay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupNotifications()
        updateDisplay()
    }

    deinit {
        cleanupRecording()
        for observer in shortcutObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.alignment = .center
        shortcutLabel.isEditable = false
        shortcutLabel.isSelectable = false
        shortcutLabel.isBezeled = false
        shortcutLabel.drawsBackground = false
        shortcutLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        shortcutLabel.textColor = .labelColor
        addSubview(shortcutLabel)

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isBordered = false
        actionButton.setButtonType(.momentaryChange)
        actionButton.imageScaling = .scaleProportionallyDown
        actionButton.target = self
        actionButton.action = #selector(handleActionClick)
        actionButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Change shortcut"
        )
        actionButton.contentTintColor = .secondaryLabelColor
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            shortcutLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            shortcutLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -4),
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 16),
            actionButton.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func setupNotifications() {
        let obs1 = NotificationCenter.default.addObserver(
            forName: .pluckShortcutDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDisplay()
        }

        let obs2 = NotificationCenter.default.addObserver(
            forName: .keyboardShortcutsByNameDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDisplay()
        }

        shortcutObservers = [obs1, obs2]
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    // MARK: - Mouse Interaction

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            startRecording()
        }
    }

    @objc private func handleActionClick() {
        if isRecording {
            cancelRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Recording Flow

    func startRecording() {
        guard !isRecording else { return }

        // Cache the currently active shortcut to restore upon cancel/blur/delete
        lastSavedShortcut = KeyboardShortcuts.getShortcut(for: .captureText) ?? HotkeyManager.defaultShortcut

        isRecording = true
        KeyboardShortcuts.isEnabled = false
        window?.makeFirstResponder(self)

        toolTip = "Press a shortcut or press Delete/Esc to cancel"
        actionButton.image = NSImage(
            systemSymbolName: "arrow.uturn.backward.circle.fill",
            accessibilityDescription: "Cancel and restore previous shortcut"
        )
        actionButton.toolTip = "Cancel and keep previous shortcut"

        // Visual recording state
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        shortcutLabel.stringValue = "Type shortcut…"
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.font = .systemFont(ofSize: 12, weight: .regular)

        // Install local event monitor to intercept keys, modifiers, and clicks
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            // Click outside detection (blur / cancel)
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let clickPoint = self.convert(event.locationInWindow, from: nil)
                let hitMargin: CGFloat = 2.0
                if !self.bounds.insetBy(dx: -hitMargin, dy: -hitMargin).contains(clickPoint) {
                    // Clicked outside: restore previous shortcut and pass event through
                    self.cancelRecording()
                    return event
                }
                return event
            }

            // Live modifier feedback while holding keys
            if event.type == .flagsChanged {
                let activeModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                if !activeModifiers.isEmpty {
                    var symbols = ""
                    if activeModifiers.contains(.control) { symbols += "⌃" }
                    if activeModifiers.contains(.option) { symbols += "⌥" }
                    if activeModifiers.contains(.shift) { symbols += "⇧" }
                    if activeModifiers.contains(.command) { symbols += "⌘" }
                    self.shortcutLabel.stringValue = "\(symbols) …"
                    self.shortcutLabel.textColor = .controlAccentColor
                } else {
                    self.shortcutLabel.stringValue = "Type shortcut…"
                    self.shortcutLabel.textColor = .secondaryLabelColor
                }
                return event
            }

            if event.type == .keyDown {
                // Escape key (keyCode 53): cancel & restore previous
                if event.keyCode == 53 {
                    self.cancelRecording()
                    return nil
                }

                // Delete/Backspace (51) or Forward Delete (117): cancel & restore previous
                if event.keyCode == 51 || event.keyCode == 117 {
                    self.cancelRecording()
                    return nil
                }

                // Tab without modifiers: cancel & allow focus transfer
                if event.keyCode == 48 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                    self.cancelRecording()
                    return event
                }

                // Require at least one modifier key
                let rawModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                let hasPrimaryModifier = !event.modifierFlags.intersection([.command, .option, .control]).isEmpty
                let isFunctionKey = (event.keyCode >= 96 && event.keyCode <= 101) ||
                                    (event.keyCode >= 109 && event.keyCode <= 111) ||
                                    (event.keyCode >= 118 && event.keyCode <= 122)

                guard hasPrimaryModifier || (rawModifiers.contains(.shift) && isFunctionKey) else {
                    NSSound.beep()
                    return nil
                }

                guard let newShortcut = KeyboardShortcuts.Shortcut(event: event) else {
                    NSSound.beep()
                    return nil
                }

                self.commitShortcut(newShortcut)
                return nil
            }

            return event
        }

        if let window = self.window {
            windowResignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.cancelRecording()
            }
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        cleanupRecording()

        // Fall back to previous saved shortcut (field is NEVER empty)
        let fallback = lastSavedShortcut ?? HotkeyManager.defaultShortcut
        KeyboardShortcuts.setShortcut(fallback, for: .captureText)
        updateDisplay()
    }

    private func commitShortcut(_ shortcut: KeyboardShortcuts.Shortcut) {
        cleanupRecording()

        lastSavedShortcut = shortcut
        KeyboardShortcuts.setShortcut(shortcut, for: .captureText)
        NotificationCenter.default.post(name: .pluckShortcutDidChange, object: nil)
        updateDisplay()
    }

    private func cleanupRecording() {
        isRecording = false
        KeyboardShortcuts.isEnabled = true

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let observer = windowResignObserver {
            NotificationCenter.default.removeObserver(observer)
            windowResignObserver = nil
        }
        window?.makeFirstResponder(nil)
    }

    // MARK: - Display

    func updateDisplay() {
        guard !isRecording else { return }

        // Guarantee never empty: Self-heal if nil
        if KeyboardShortcuts.getShortcut(for: .captureText) == nil {
            KeyboardShortcuts.setShortcut(HotkeyManager.defaultShortcut, for: .captureText)
        }

        let current = KeyboardShortcuts.getShortcut(for: .captureText)
        let text = current?.description ?? "⌃⌘P"

        shortcutLabel.stringValue = text
        shortcutLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        shortcutLabel.textColor = .labelColor

        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        toolTip = "Current shortcut: \(text). Click to change."
        actionButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Change shortcut"
        )
        actionButton.toolTip = "Change shortcut"
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil && isRecording {
            cancelRecording()
        }
    }
}
