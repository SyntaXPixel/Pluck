import XCTest
import KeyboardShortcuts
import Vision
@testable import Pluck

final class HotkeyManagerTests: XCTestCase {
    @MainActor
    func testResetToDefaultAndCustomization() {
        // Reset to default
        HotkeyManager.shared.resetToDefault()

        XCTAssertTrue(HotkeyManager.shared.isDefaultShortcut())
        XCTAssertEqual(HotkeyManager.shared.currentShortcutString(), "⌃⌘P")

        // Simulate user customizing shortcut to Command + Shift + O
        let customShortcut = KeyboardShortcuts.Shortcut(.o, modifiers: [.command, .shift])
        KeyboardShortcuts.setShortcut(customShortcut, for: .captureText)

        XCTAssertFalse(HotkeyManager.shared.isDefaultShortcut())
        XCTAssertEqual(HotkeyManager.shared.currentShortcutString(), "⇧⌘O")

        // Reset back to default
        HotkeyManager.shared.resetToDefault()

        XCTAssertTrue(HotkeyManager.shared.isDefaultShortcut())
        XCTAssertEqual(HotkeyManager.shared.currentShortcutString(), "⌃⌘P")
    }

    @MainActor
    func testRecorderNeverLeavesShortcutEmptyOnCancel() {
        // 1. Set a custom shortcut
        let customShortcut = KeyboardShortcuts.Shortcut(.k, modifiers: [.command, .shift])
        KeyboardShortcuts.setShortcut(customShortcut, for: .captureText)

        let control = PluckShortcutRecorderControl()
        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .captureText), customShortcut)

        // 2. Start recording (prompts for new key)
        control.startRecording()

        // 3. User cancels (clicks away / presses delete / presses escape)
        control.cancelRecording()

        // 4. Must fall back to previous custom shortcut (NOT empty!)
        XCTAssertNotNil(KeyboardShortcuts.getShortcut(for: .captureText))
        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .captureText), customShortcut)

        // 5. If shortcut was ever forced to nil, updateDisplay self-heals to default
        KeyboardShortcuts.setShortcut(nil, for: .captureText)
        control.updateDisplay()
        XCTAssertNotNil(KeyboardShortcuts.getShortcut(for: .captureText))
        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .captureText), KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .command]))
    }

    func testPluckDidCaptureTextNotification() {
        let expectation = expectation(description: "Receive pluckDidCaptureText notification")
        let testString = "Pluck Instant OCR Test String"

        let observer = NotificationCenter.default.addObserver(
            forName: .pluckDidCaptureText,
            object: nil,
            queue: .main
        ) { notification in
            let text = notification.userInfo?["text"] as? String
            XCTAssertEqual(text, testString)
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: .pluckDidCaptureText,
            object: nil,
            userInfo: ["text": testString]
        )

        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testVisionPreferredLanguageResolution() {
        let req = VNRecognizeTextRequest()
        let resolved = VisionOCRService.resolvePreferredLanguages(for: req)
        XCTAssertFalse(resolved.isEmpty, "Resolved languages should never be empty")
        XCTAssertTrue(resolved.contains("en-US") || !resolved.isEmpty)
    }
}
