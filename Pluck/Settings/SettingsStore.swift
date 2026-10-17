import Combine
import Foundation

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    enum Keys {
        static let saveToHistory = "saveToHistory"
        static let playSounds = "playSounds"
        static let successSound = "successSound"
        static let errorSound = "errorSound"
        static let recognitionLevel = "recognitionLevel"
        static let ocrLanguage = "ocrLanguage"
        static let trimWhitespace = "trimWhitespace"
        static let mergeLineBreaks = "mergeLineBreaks"
        static let removeHyphenation = "removeHyphenation"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasInitializedDefaults = "hasInitializedDefaults"
        static let hideMenuBarIcon = "hideMenuBarIcon"
        static let pendingOnboardingResumeStep = "pendingOnboardingResumeStep"
    }

    private let defaults: UserDefaults

    @Published var saveToHistory: Bool {
        didSet { defaults.set(saveToHistory, forKey: Keys.saveToHistory) }
    }

    @Published var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: Keys.playSounds) }
    }

    @Published var successSound: String {
        didSet { defaults.set(successSound, forKey: Keys.successSound) }
    }

    @Published var errorSound: String {
        didSet { defaults.set(errorSound, forKey: Keys.errorSound) }
    }

    @Published var recognitionLevel: String {
        didSet { defaults.set(recognitionLevel, forKey: Keys.recognitionLevel) }
    }

    @Published var ocrLanguage: String {
        didSet { defaults.set(ocrLanguage, forKey: Keys.ocrLanguage) }
    }

    @Published var trimWhitespace: Bool {
        didSet { defaults.set(trimWhitespace, forKey: Keys.trimWhitespace) }
    }

    @Published var mergeLineBreaks: Bool {
        didSet { defaults.set(mergeLineBreaks, forKey: Keys.mergeLineBreaks) }
    }

    @Published var removeHyphenation: Bool {
        didSet { defaults.set(removeHyphenation, forKey: Keys.removeHyphenation) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    @Published var hideMenuBarIcon: Bool {
        didSet { defaults.set(hideMenuBarIcon, forKey: Keys.hideMenuBarIcon) }
    }

    @Published var pendingOnboardingResumeStep: Int? {
        didSet {
            if let step = pendingOnboardingResumeStep {
                defaults.set(step, forKey: Keys.pendingOnboardingResumeStep)
            } else {
                defaults.removeObject(forKey: Keys.pendingOnboardingResumeStep)
            }
            defaults.synchronize()
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults

        let hasInitialized = userDefaults.bool(forKey: Keys.hasInitializedDefaults)

        if !hasInitialized {
            // First run defaults
            let defaultSaveToHistory = MaccyDetector.isMaccyInstalled
            userDefaults.set(defaultSaveToHistory, forKey: Keys.saveToHistory)
            userDefaults.set(true, forKey: Keys.playSounds)
            userDefaults.set("Purr", forKey: Keys.successSound)
            userDefaults.set("Basso", forKey: Keys.errorSound)
            userDefaults.set("accurate", forKey: Keys.recognitionLevel)
            userDefaults.set("auto", forKey: Keys.ocrLanguage)
            userDefaults.set(false, forKey: Keys.trimWhitespace)
            userDefaults.set(false, forKey: Keys.mergeLineBreaks)
            userDefaults.set(false, forKey: Keys.removeHyphenation)
            userDefaults.set(false, forKey: Keys.hasCompletedOnboarding)
            userDefaults.set(false, forKey: Keys.hideMenuBarIcon)
            userDefaults.set(true, forKey: Keys.hasInitializedDefaults)

            self.saveToHistory = defaultSaveToHistory
            self.playSounds = true
            self.successSound = "Purr"
            self.errorSound = "Basso"
            self.recognitionLevel = "accurate"
            self.ocrLanguage = "auto"
            self.trimWhitespace = false
            self.mergeLineBreaks = false
            self.removeHyphenation = false
            self.hasCompletedOnboarding = false
            self.hideMenuBarIcon = false
            self.pendingOnboardingResumeStep = nil
        } else {
            self.saveToHistory = userDefaults.bool(forKey: Keys.saveToHistory)
            self.playSounds = userDefaults.object(forKey: Keys.playSounds) != nil ? userDefaults.bool(forKey: Keys.playSounds) : true
            self.successSound = userDefaults.string(forKey: Keys.successSound) ?? "Purr"
            self.errorSound = userDefaults.string(forKey: Keys.errorSound) ?? "Basso"
            self.recognitionLevel = userDefaults.string(forKey: Keys.recognitionLevel) ?? "accurate"
            self.ocrLanguage = userDefaults.string(forKey: Keys.ocrLanguage) ?? "auto"
            self.trimWhitespace = userDefaults.bool(forKey: Keys.trimWhitespace)
            self.mergeLineBreaks = userDefaults.bool(forKey: Keys.mergeLineBreaks)
            self.removeHyphenation = userDefaults.bool(forKey: Keys.removeHyphenation)
            self.hasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
            self.hideMenuBarIcon = userDefaults.bool(forKey: Keys.hideMenuBarIcon)
            if userDefaults.object(forKey: Keys.pendingOnboardingResumeStep) != nil {
                self.pendingOnboardingResumeStep = userDefaults.integer(forKey: Keys.pendingOnboardingResumeStep)
            } else {
                self.pendingOnboardingResumeStep = nil
            }
        }
    }

    /// Resets all settings to original defaults.
    func resetToDefaults() {
        defaults.removeObject(forKey: Keys.hasInitializedDefaults)
        defaults.removeObject(forKey: Keys.pendingOnboardingResumeStep)
        let defaultSaveToHistory = MaccyDetector.isMaccyInstalled
        saveToHistory = defaultSaveToHistory
        playSounds = true
        successSound = "Purr"
        errorSound = "Basso"
        recognitionLevel = "accurate"
        ocrLanguage = "auto"
        trimWhitespace = false
        mergeLineBreaks = false
        removeHyphenation = false
        hasCompletedOnboarding = false
        hideMenuBarIcon = false
        pendingOnboardingResumeStep = nil
        defaults.set(true, forKey: Keys.hasInitializedDefaults)
    }
}
