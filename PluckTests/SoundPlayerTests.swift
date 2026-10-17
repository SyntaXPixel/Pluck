import XCTest
@testable import Pluck

final class SoundPlayerTests: XCTestCase {
    func testAvailableSuccessSoundsExcludesFailedSounds() {
        let successSounds = SoundPlayer.shared.availableSuccessSounds()
        XCTAssertFalse(successSounds.isEmpty)
        XCTAssertTrue(successSounds.contains("Purr"))
        XCTAssertFalse(successSounds.contains("Basso"))
        XCTAssertFalse(successSounds.contains("Error"))
        XCTAssertFalse(successSounds.contains("Error 2"))
        XCTAssertFalse(successSounds.contains("Sosumi"))
    }

    func testAvailableErrorSoundsContents() {
        let errorSounds = SoundPlayer.shared.availableErrorSounds()
        XCTAssertEqual(errorSounds, ["Basso", "Ping", "Error", "Error 2", "None"])
    }
}
