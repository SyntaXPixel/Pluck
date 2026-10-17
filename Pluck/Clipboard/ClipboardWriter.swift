import AppKit
import Foundation

protocol PasteboardProtocol {
    func clearContents() -> Int
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
    func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool
    var types: [NSPasteboard.PasteboardType]? { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func data(forType dataType: NSPasteboard.PasteboardType) -> Data?
}

extension NSPasteboard: PasteboardProtocol {}

final class ClipboardWriter {
    static let shared = ClipboardWriter()

    /// Standard pasteboard type honored by Maccy and other macOS clipboard managers
    /// to ignore transient copies (e.g. password managers, transient snippets).
    static let transientPasteboardType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private let pasteboard: PasteboardProtocol

    init(pasteboard: PasteboardProtocol = NSPasteboard.general) {
        self.pasteboard = pasteboard
    }

    /// Writes recognized text to the pasteboard.
    /// - Parameters:
    ///   - text: The text string to copy.
    ///   - transient: When true, adds `org.nspasteboard.TransientType` so Maccy skips it.
    /// - Returns: True if string was successfully set.
    @discardableResult
    func write(_ text: String, transient: Bool) -> Bool {
        _ = pasteboard.clearContents()
        let stringSuccess = pasteboard.setString(text, forType: .string)

        if transient {
            _ = pasteboard.setData(Data(), forType: Self.transientPasteboardType)
        }

        return stringSuccess
    }
}
