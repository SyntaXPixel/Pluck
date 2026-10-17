import SwiftUI

// MARK: - macOS 27 Liquid Glass Styling Extensions

public enum PluckButtonShape {
    case capsule
    case roundedRectangle(radius: CGFloat)
}

extension View {
    /// Applies macOS 27 Liquid Glass Prominent button style with high-radius round capsule shape by default.
    @ViewBuilder
    func pluckProminentButton(shape: PluckButtonShape = .capsule) -> some View {
        if #available(macOS 26.0, *) {
            switch shape {
            case .capsule:
                self
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
            case .roundedRectangle(let radius):
                self
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: radius))
            }
        } else if #available(macOS 14.0, *) {
            switch shape {
            case .capsule:
                self
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            case .roundedRectangle(let radius):
                self
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: radius))
            }
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Applies macOS 27 Liquid Glass standard button style with high-radius round capsule shape by default.
    @ViewBuilder
    func pluckGlassButton(shape: PluckButtonShape = .capsule) -> some View {
        if #available(macOS 26.0, *) {
            switch shape {
            case .capsule:
                self
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
            case .roundedRectangle(let radius):
                self
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: radius))
            }
        } else if #available(macOS 14.0, *) {
            switch shape {
            case .capsule:
                self
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            case .roundedRectangle(let radius):
                self
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: radius))
            }
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Applies macOS 27 Liquid Glass container effect, falling back to clean rounded background on older releases.
    @ViewBuilder
    func pluckGlassContainer(cornerRadius: CGFloat = 10) -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    /// Hides the automatic sidebar toggle button on macOS 14+ NavigationSplitView.
    @ViewBuilder
    func removeSidebarToggleIfAvailable() -> some View {
        if #available(macOS 14.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}
