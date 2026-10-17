import AppKit
import SwiftUI

enum AssetHelper {
    /// 1. Menu Bar Status Icon (Uses menu.svg with auto light/dark wallpaper inversion)
    static func statusBarIcon(hasPermission: Bool) -> NSImage {
        let baseImage: NSImage
        if let customSVG = NSImage(named: "MenuBarIcon") {
            baseImage = (customSVG.copy() as? NSImage) ?? customSVG
        } else {
            baseImage = NSImage(
                systemSymbolName: "text.viewfinder",
                accessibilityDescription: "Pluck"
            ) ?? NSImage()
        }
        baseImage.size = NSSize(width: 18, height: 18)

        // Normal state: pure template image.
        // macOS automatically renders white menu.svg as BLACK on light menu bars
        // and WHITE on dark menu bars.
        if hasPermission {
            baseImage.isTemplate = true
            return baseImage
        }

        // Permission missing state: composite dynamic foreground tint + orange dot badge.
        // Because adding a colored badge requires isTemplate = false, we explicitly query
        // the status bar button's effective appearance so the base icon still turns black on light bars.
        return badgedMenuBarIcon(from: baseImage)
    }

    /// Draws the menu.svg respecting Light/Dark appearance + an orange warning dot
    static func badgedMenuBarIcon(from baseImage: NSImage, isDarkMenuBar: Bool? = nil) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let composite = NSImage(size: size, flipped: false) { rect in
            // Reliably determine whether menu bar currently needs white or black glyph
            let isDark: Bool
            if let custom = isDarkMenuBar {
                isDark = custom
            } else if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"), style.caseInsensitiveCompare("dark") == .orderedSame {
                isDark = true
            } else if let appearance = NSAppearance.current {
                isDark = (appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
            } else {
                isDark = (NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
            }
            let iconTint: NSColor = isDark ? .white : .black

            // Draw base menu.svg masked with iconTint
            baseImage.draw(in: rect)
            iconTint.setFill()
            rect.fill(using: .sourceAtop)

            // Cut out a 1pt halo and draw high-contrast orange dot at bottom-right
            let badgeRect = NSRect(x: rect.maxX - 6.5, y: rect.minY + 0.5, width: 6, height: 6)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1, dy: -1)).fill()
            NSGraphicsContext.restoreGraphicsState()

            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: badgeRect).fill()
            return true
        }
        composite.isTemplate = false
        return composite
    }

    /// Legacy compatibility getters
    static var normalMenuIcon: NSImage {
        statusBarIcon(hasPermission: true)
    }

    static var warningMenuIcon: NSImage {
        statusBarIcon(hasPermission: false)
    }

    /// 2. Theme-Adaptive Hero Logo for Welcome & About Views (black.png in Light Mode, white.png in Dark Mode)
    @ViewBuilder
    static func themeAdaptiveHeroLogo(size: CGFloat = 72) -> some View {
        WelcomeLogoView(size: size)
    }

    /// 3. Brand Logo Vectors for About Settings
    @ViewBuilder
    static func gitHubLogo(size: CGFloat = 16) -> some View {
        if let img = NSImage(named: "GitHubLogo") {
            Image(nsImage: img)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "curlybraces")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    static func openSourceLogo(size: CGFloat = 16) -> some View {
        if let img = NSImage(named: "OpenSourceLogo") {
            Image(nsImage: img)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

private struct WelcomeLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    let size: CGFloat

    var body: some View {
        Group {
            let assetName = colorScheme == .dark ? "WhiteLogo" : "BlackLogo"
            if let nsImage = NSImage(named: assetName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else if let welcome = NSImage(named: "WelcomeLogo") {
                Image(nsImage: welcome)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "text.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}
