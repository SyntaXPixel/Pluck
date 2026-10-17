import AppKit
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()

    static let noneSound = "None"
    static let defaultSuccessSound = "Purr"
    static let defaultErrorSound = "Basso"

    private let fallbackSounds = [
        "Blow", "Bottle", "Frog", "Funk", "Glass",
        "Hero", "Morse", "Ping", "Pop", "Purr",
        "Submarine", "Tink"
    ]

    /// Dynamically enumerates available positive system sounds for successful capture.
    /// Excludes failed/error sounds (Basso, Error, Error 2, Sosumi).
    func availableSuccessSounds() -> [String] {
        let excluded: Set<String> = ["Basso", "Error", "Error 2", "Sosumi"]
        let sounds = availableSystemSounds().filter { !excluded.contains($0) }
        return sounds.isEmpty ? fallbackSounds : sounds
    }

    /// Dynamically enumerates available system sounds in /System/Library/Sounds.
    func availableSystemSounds() -> [String] {
        let soundsURL = URL(fileURLWithPath: "/System/Library/Sounds")
        guard let files = try? FileManager.default.contentsOfDirectory(at: soundsURL, includingPropertiesForKeys: nil) else {
            return fallbackSounds
        }

        let sounds = files
            .filter { ["aiff", "wav", "mp3"].contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()

        return sounds.isEmpty ? fallbackSounds : sounds
    }

    /// Available error sounds, strictly restricted to: Basso (default), Ping, Error, Error 2, None.
    func availableErrorSounds() -> [String] {
        return ["Basso", "Ping", "Error", "Error 2", Self.noneSound]
    }

    /// Plays the configured success sound if playSounds is enabled.
    func playSuccess() {
        guard SettingsStore.shared.playSounds else { return }
        play(named: SettingsStore.shared.successSound)
    }

    /// Plays the configured error sound if playSounds is enabled and not "None".
    func playError() {
        guard SettingsStore.shared.playSounds else { return }
        let soundName = SettingsStore.shared.errorSound
        guard soundName != Self.noneSound else { return }
        play(named: soundName)
    }

    /// Plays a preview of a specified sound, regardless of the master playSounds toggle.
    func playPreview(named soundName: String) {
        guard soundName != Self.noneSound else { return }
        play(named: soundName)
    }

    private func play(named soundName: String) {
        DispatchQueue.main.async {
            var sound = NSSound(named: NSSound.Name(soundName))
            if sound == nil, let url = Bundle.main.url(forResource: soundName, withExtension: "aiff") {
                sound = NSSound(contentsOf: url, byReference: true)
            }
            if sound == nil {
                let path = "/System/Library/Sounds/\(soundName).aiff"
                sound = NSSound(contentsOfFile: path, byReference: true)
            }
            if let sound = sound {
                sound.stop()
                sound.play()
            }
        }
    }
}
