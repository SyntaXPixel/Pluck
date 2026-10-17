import AppKit
import Foundation

enum MaccyDetector {
    static let maccyBundleIdentifier = "org.p0deje.Maccy"
    static let maccyReleasesURL = URL(string: "https://github.com/p0deje/Maccy/releases/latest")!

    /// Checks if Maccy is installed by looking up its bundle identifier in NSWorkspace.
    static var isMaccyInstalled: Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: maccyBundleIdentifier) != nil
    }

    /// Opens the official Maccy latest releases download page in the default browser.
    static func openReleases() {
        NSWorkspace.shared.open(maccyReleasesURL)
    }

    /// Compatibility helper pointing to the latest releases page.
    static func openWebsite() {
        openReleases()
    }
}
