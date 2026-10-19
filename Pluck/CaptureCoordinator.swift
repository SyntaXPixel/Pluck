import AppKit
import Foundation
import os.log
import Vision

@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    private let logger = Logger(subsystem: "com.pluck.mac", category: "CaptureCoordinator")
    private var isCapturing = false

    /// Callback when permission is missing to open permission UI
    var onPermissionMissing: (() -> Void)?

    func startCapture() {
        guard !isCapturing else {
            logger.notice("startCapture called while already capturing; ignoring.")
            return
        }

        // 1. Check Screen Recording permission
        guard PermissionsHelper.isScreenRecordingGranted() else {
            logger.warning("Screen Recording permission is not granted.")
            SoundPlayer.shared.playError()
            onPermissionMissing?()
            return
        }

        isCapturing = true
        logger.info("Starting interactive capture...")
        NotificationCenter.default.post(name: .pluckDidStartCapture, object: nil)

        Task {
            defer {
                self.isCapturing = false
                self.logger.info("Interactive capture session ended.")
            }

            // 2. Interactive screen capture
            guard let cgImage = await CaptureService.shared.captureInteractiveArea() else {
                // User cancelled with Escape; exit silently with no sound
                self.logger.info("Capture cancelled by user (Escape) or empty file.")
                NotificationCenter.default.post(name: .pluckDidCancelCapture, object: nil)
                return
            }

            self.logger.info("Image captured successfully (\(cgImage.width)x\(cgImage.height)). Starting Vision OCR...")

            // 3. Vision OCR
            let recognitionLevel: VNRequestTextRecognitionLevel =
                SettingsStore.shared.recognitionLevel == "fast" ? .fast : .accurate
            let languageCode = SettingsStore.shared.ocrLanguage == "auto" ? nil : SettingsStore.shared.ocrLanguage

            let rawText: String
            do {
                rawText = try await VisionOCRService.shared.recognizeText(
                    in: cgImage,
                    level: recognitionLevel,
                    languageCode: languageCode
                )
            } catch {
                self.logger.error("Vision OCR failed with error: \(error.localizedDescription, privacy: .public)")
                NotificationCenter.default.post(
                    name: .pluckDidFailCapture,
                    object: nil,
                    userInfo: ["reason": "Text recognition encountered an error."]
                )
                SoundPlayer.shared.playError()
                return
            }

            // 4. Post-processing with TextCleaner
            let options = TextCleanerOptions(
                trimWhitespace: SettingsStore.shared.trimWhitespace,
                mergeLineBreaks: SettingsStore.shared.mergeLineBreaks,
                removeHyphenation: SettingsStore.shared.removeHyphenation
            )
            let cleanedText = TextCleaner.clean(rawText, options: options)

            // If no text was recognized or result is empty
            guard !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.logger.info("OCR completed but recognized text was empty or whitespace.")
                NotificationCenter.default.post(
                    name: .pluckDidFailCapture,
                    object: nil,
                    userInfo: ["reason": "No text detected in the selected area."]
                )
                SoundPlayer.shared.playError()
                return
            }

            self.logger.info("OCR successfully recognized text: '\(cleanedText.prefix(40))...'")

            // 5. Write to pasteboard
            // Save to history ON -> normal string
            // Save to history OFF -> transient string (Maccy skips)
            let transient = !SettingsStore.shared.saveToHistory
            let copySuccess = ClipboardWriter.shared.write(cleanedText, transient: transient)

            if copySuccess {
                self.logger.info("Text copied to pasteboard (transient: \(transient)). Playing success sound.")
                NotificationCenter.default.post(
                    name: .pluckDidCaptureText,
                    object: nil,
                    userInfo: ["text": cleanedText]
                )
                SoundPlayer.shared.playSuccess()
            } else {
                self.logger.error("Failed to copy text to pasteboard.")
                NotificationCenter.default.post(
                    name: .pluckDidFailCapture,
                    object: nil,
                    userInfo: ["reason": "Failed to copy text to clipboard."]
                )
                SoundPlayer.shared.playError()
            }
        }
    }
}
