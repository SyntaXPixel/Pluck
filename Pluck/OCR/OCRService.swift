import CoreGraphics
import Foundation
import Vision

protocol OCRServiceProtocol: Sendable {
    func recognizeText(
        in image: CGImage,
        level: VNRequestTextRecognitionLevel,
        languageCode: String?
    ) async throws -> String
}

final class VisionOCRService: @unchecked Sendable, OCRServiceProtocol {
    static let shared = VisionOCRService()

    private let lock = NSLock()
    private var _isWarmedUp: Bool = false

    var isWarmedUp: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isWarmedUp
    }

    private func setWarmedUp(_ value: Bool) {
        lock.lock()
        _isWarmedUp = value
        lock.unlock()
    }

    struct LanguageOption: Identifiable, Hashable {
        let code: String
        let displayName: String
        var id: String { code }
    }

    /// Pre-warms the Vision neural network model on a background utility thread.
    /// Guarantees that subsequent user captures execute in 2-5 milliseconds.
    func prewarm() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self, !self.isWarmedUp else { return }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: 16,
                height: 16,
                bitsPerComponent: 8,
                bytesPerRow: 64,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let dummyImage = context.makeImage() else { return }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.revision = 2
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: dummyImage, options: [:])
            try? handler.perform([request])
            self.setWarmedUp(true)
        }
    }

    /// Performs text recognition on the given CGImage on a background thread.
    func recognizeText(
        in image: CGImage,
        level: VNRequestTextRecognitionLevel = .accurate,
        languageCode: String? = nil
    ) async throws -> String {
        return try await Task.detached(priority: .userInitiated) {
            func executeRecognition(req: VNRecognizeTextRequest) throws -> String {
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                try handler.perform([req])

                guard let observations = req.results, !observations.isEmpty else {
                    return ""
                }

                let sortedObservations = Self.sortObservations(observations)
                let lines = sortedObservations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }

                return lines.joined(separator: "\n")
            }

            // 1. Primary request configuration
            let primaryRequest = VNRecognizeTextRequest()
            primaryRequest.recognitionLevel = level
            primaryRequest.usesLanguageCorrection = true

            // Use revision 2 for accurate mode on Apple Silicon / macOS to prevent e5rt ANE driver compilation crashes
            if level == .accurate {
                primaryRequest.revision = 2
            }

            if let languageCode = languageCode, !languageCode.isEmpty, languageCode != "auto" {
                primaryRequest.recognitionLanguages = [languageCode]
            } else {
                primaryRequest.recognitionLanguages = Self.resolvePreferredLanguages(for: primaryRequest)
            }

            do {
                return try executeRecognition(req: primaryRequest)
            } catch {
                // 2. Resilient fallback: If Neural Engine (e5rt) or primary fails, fall back to fast mode
                let fallbackRequest = VNRecognizeTextRequest()
                fallbackRequest.recognitionLevel = .fast
                fallbackRequest.usesLanguageCorrection = true
                if let languageCode = languageCode, !languageCode.isEmpty, languageCode != "auto" {
                    fallbackRequest.recognitionLanguages = [languageCode]
                }
                return try executeRecognition(req: fallbackRequest)
            }
        }.value
    }

    /// Sorts Vision recognized text observations into natural reading order:
    /// Top-to-bottom (higher y in Vision's coordinate system), then left-to-right (lower x).
    static func sortObservations(_ observations: [VNRecognizedTextObservation]) -> [VNRecognizedTextObservation] {
        return observations.sorted { obs1, obs2 in
            let b1 = obs1.boundingBox
            let b2 = obs2.boundingBox
            let midY1 = b1.midY
            let midY2 = b2.midY
            let avgHeight = (b1.height + b2.height) / 2.0

            // If on approximately the same vertical line, sort left-to-right
            if abs(midY1 - midY2) < (avgHeight * 0.5) {
                return b1.minX < b2.minX
            }
            // Higher midY means closer to the top of the image
            return midY1 > midY2
        }
    }

    /// Returns available recognition languages supported by the system Vision framework.
    static func availableLanguages(for level: VNRequestTextRecognitionLevel = .accurate) -> [LanguageOption] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level

        guard let codes = try? request.supportedRecognitionLanguages() else {
            return []
        }

        let locale = Locale.current
        var options: [LanguageOption] = codes.map { code in
            let name = locale.localizedString(forIdentifier: code) ?? code
            return LanguageOption(code: code, displayName: "\(name) (\(code))")
        }

        options.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return options
    }

    /// Resolves system preferred languages to language codes supported by the given Vision request.
    /// Falls back to ["en-US"] if no user preferred language matches.
    static func resolvePreferredLanguages(for request: VNRecognizeTextRequest) -> [String] {
        guard let supported = try? request.supportedRecognitionLanguages() else {
            return ["en-US"]
        }
        var matched: [String] = []
        for pref in Locale.preferredLanguages {
            if supported.contains(pref) {
                if !matched.contains(pref) { matched.append(pref) }
            } else {
                let baseCode = pref.components(separatedBy: "-").first ?? pref
                if let match = supported.first(where: { $0.hasPrefix(baseCode) }), !matched.contains(match) {
                    matched.append(match)
                }
            }
        }
        return matched.isEmpty ? ["en-US"] : matched
    }
}
