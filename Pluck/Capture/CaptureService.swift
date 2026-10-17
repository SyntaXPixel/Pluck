import AppKit
import CoreGraphics
import Foundation
import ImageIO

final class CaptureService {
    static let shared = CaptureService()

    /// Launches macOS screencapture interactive selection (-i) silently (-x).
    /// If user cancels (Esc), screencapture exits without creating the file; returns nil silently.
    /// Otherwise, decodes the image into memory immediately and deletes the temp file.
    func captureInteractiveArea() async -> CGImage? {
        let tempFilename = "pluck-capture-\(UUID().uuidString).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFilename)

        defer {
            // Clean up temporary capture file from disk
            try? FileManager.default.removeItem(at: tempURL)
        }

        let captureSuccess = await runScreencaptureProcess(outputURL: tempURL)
        guard captureSuccess else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            return nil
        }

        // Verify file is not empty
        if let attributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
           let fileSize = attributes[.size] as? UInt64, fileSize == 0 {
            return nil
        }

        // Read file contents into memory so we can safely delete the file on disk
        guard let data = try? Data(contentsOf: tempURL), !data.isEmpty else {
            return nil
        }

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        // Force immediate caching/decoding of pixels into memory
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, decodeOptions as CFDictionary) else {
            return nil
        }

        return cgImage
    }

    private func runScreencaptureProcess(outputURL: URL) async -> Bool {
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: interactive capture (selection or window)
            // -x: do not play capture shutter sound (Pluck handles feedback sounds)
            process.arguments = ["-i", "-x", outputURL.path]

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }
}
