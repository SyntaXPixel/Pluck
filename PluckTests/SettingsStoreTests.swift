import XCTest
@testable import Pluck

final class SettingsStoreTests: XCTestCase {
    var userDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "com.pluck.tests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    func testInitialDefaults() {
        let store = SettingsStore(userDefaults: userDefaults)

        XCTAssertTrue(store.playSounds)
        XCTAssertEqual(store.successSound, "Purr")
        XCTAssertEqual(store.errorSound, "Basso")
        XCTAssertEqual(store.recognitionLevel, "accurate")
        XCTAssertEqual(store.ocrLanguage, "auto")
        XCTAssertFalse(store.trimWhitespace)
        XCTAssertFalse(store.mergeLineBreaks)
        XCTAssertFalse(store.removeHyphenation)
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(store.hideMenuBarIcon)
        XCTAssertNil(store.pendingOnboardingResumeStep)
    }

    func testUpdatingPropertiesPersistsToUserDefaults() {
        let store = SettingsStore(userDefaults: userDefaults)

        store.playSounds = false
        store.successSound = "Hero"
        store.errorSound = "None"
        store.recognitionLevel = "fast"
        store.ocrLanguage = "en-US"
        store.trimWhitespace = true
        store.mergeLineBreaks = true
        store.removeHyphenation = true
        store.hasCompletedOnboarding = true
        store.hideMenuBarIcon = true
        store.pendingOnboardingResumeStep = 2

        // Create a new instance pointing to same suite to verify persistence
        let store2 = SettingsStore(userDefaults: userDefaults)
        XCTAssertFalse(store2.playSounds)
        XCTAssertEqual(store2.successSound, "Hero")
        XCTAssertEqual(store2.errorSound, "None")
        XCTAssertEqual(store2.recognitionLevel, "fast")
        XCTAssertEqual(store2.ocrLanguage, "en-US")
        XCTAssertTrue(store2.trimWhitespace)
        XCTAssertTrue(store2.mergeLineBreaks)
        XCTAssertTrue(store2.removeHyphenation)
        XCTAssertTrue(store2.hasCompletedOnboarding)
        XCTAssertTrue(store2.hideMenuBarIcon)
        XCTAssertEqual(store2.pendingOnboardingResumeStep, 2)

        store2.pendingOnboardingResumeStep = nil
        let store3 = SettingsStore(userDefaults: userDefaults)
        XCTAssertNil(store3.pendingOnboardingResumeStep)
    }

    func testResetToDefaults() {
        let store = SettingsStore(userDefaults: userDefaults)

        store.playSounds = false
        store.successSound = "Glass"
        store.trimWhitespace = true
        store.hideMenuBarIcon = true
        store.pendingOnboardingResumeStep = 3

        store.resetToDefaults()

        XCTAssertTrue(store.playSounds)
        XCTAssertEqual(store.successSound, "Purr")
        XCTAssertFalse(store.trimWhitespace)
        XCTAssertFalse(store.hideMenuBarIcon)
        XCTAssertNil(store.pendingOnboardingResumeStep)
    }
}
