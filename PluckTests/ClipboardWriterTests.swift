import AppKit
import XCTest
@testable import Pluck

final class MockPasteboard: PasteboardProtocol {
    var storedStrings: [NSPasteboard.PasteboardType: String] = [:]
    var storedData: [NSPasteboard.PasteboardType: Data] = [:]
    var clearCount = 0

    func clearContents() -> Int {
        clearCount += 1
        storedStrings.removeAll()
        storedData.removeAll()
        return 0
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        storedStrings[dataType] = string
        return true
    }

    func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        if let data = data {
            storedData[dataType] = data
        } else {
            storedData.removeValue(forKey: dataType)
        }
        return true
    }

    var types: [NSPasteboard.PasteboardType]? {
        return Array(Set(storedStrings.keys).union(storedData.keys))
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        return storedStrings[dataType]
    }

    func data(forType dataType: NSPasteboard.PasteboardType) -> Data? {
        return storedData[dataType]
    }
}

final class ClipboardWriterTests: XCTestCase {
    func testNormalWriteAddsStringWithoutTransientType() {
        let mock = MockPasteboard()
        let writer = ClipboardWriter(pasteboard: mock)

        let success = writer.write("Sample OCR Text", transient: false)

        XCTAssertTrue(success)
        XCTAssertEqual(mock.clearCount, 1)
        XCTAssertEqual(mock.string(forType: .string), "Sample OCR Text")
        XCTAssertNil(mock.data(forType: ClipboardWriter.transientPasteboardType))
    }

    func testTransientWriteAddsStringAndTransientType() {
        let mock = MockPasteboard()
        let writer = ClipboardWriter(pasteboard: mock)

        let success = writer.write("Sensitive Or Skipped Text", transient: true)

        XCTAssertTrue(success)
        XCTAssertEqual(mock.clearCount, 1)
        XCTAssertEqual(mock.string(forType: .string), "Sensitive Or Skipped Text")
        XCTAssertNotNil(mock.data(forType: ClipboardWriter.transientPasteboardType))
        XCTAssertEqual(mock.data(forType: ClipboardWriter.transientPasteboardType), Data())
    }

    func testRealPasteboardIntegration() {
        let uniqueName = NSPasteboard.Name("com.pluck.test.pasteboard.\(UUID().uuidString)")
        let realPasteboard = NSPasteboard(name: uniqueName)
        let writer = ClipboardWriter(pasteboard: realPasteboard)

        // Test normal write
        writer.write("Hello Pluck", transient: false)
        XCTAssertEqual(realPasteboard.string(forType: .string), "Hello Pluck")
        XCTAssertFalse(realPasteboard.types?.contains(ClipboardWriter.transientPasteboardType) ?? false)

        // Test transient write
        writer.write("Hello Transient", transient: true)
        XCTAssertEqual(realPasteboard.string(forType: .string), "Hello Transient")
        XCTAssertTrue(realPasteboard.types?.contains(ClipboardWriter.transientPasteboardType) ?? false)
    }
}
