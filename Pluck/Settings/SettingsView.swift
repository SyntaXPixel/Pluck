import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI
import Vision

struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigationModel
    @ObservedObject var settings = SettingsStore.shared
    var onRunOnboardingAgain: (() -> Void)?

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $navigation.selectedTab) { tab in
                Label {
                    Text(tab.rawValue)
                        .font(.system(size: 13))
                } icon: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
                .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 185, ideal: 185, max: 185)
            .removeSidebarToggleIfAvailable()
        } detail: {
            Group {
                switch navigation.selectedTab {
                case .general:
                    GeneralSettingsPane(onRunOnboardingAgain: onRunOnboardingAgain)
                case .ocr:
                    OCRSettingsPane()
                case .clipboard:
                    ClipboardSettingsPane()
                case .sound:
                    SoundSettingsPane()
                case .permissions:
                    PermissionsSettingsPane()
                case .about:
                    AboutSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 460)
    }
}

// MARK: - 1. General Settings Pane

private struct GeneralSettingsPane: View {
    @ObservedObject private var settings = SettingsStore.shared
    var onRunOnboardingAgain: (() -> Void)?

    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLogin.Toggle {
                    Text("Launch Pluck at login")
                }
            }

            Section("Menu Bar") {
                Toggle("Hide menu bar icon", isOn: $settings.hideMenuBarIcon)
                if settings.hideMenuBarIcon {
                    Text("Pluck runs invisibly in the background. Open Pluck from Applications, Launchpad, or Spotlight to access Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Global Shortcut") {
                HStack {
                    Text("Capture Shortcut:")
                    Spacer()
                    PluckShortcutRecorderView()
                        .frame(width: 140, height: 26)
                }

                Text("Press a key combination with at least one modifier (e.g., ⌘, ⌥, ⌃, ⇧).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let shortcut = KeyboardShortcuts.getShortcut(for: .captureText),
                   shortcut == KeyboardShortcuts.Shortcut(.p, modifiers: [.command, .shift]) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shortcut Advisory")
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                            Text("Note: ⌘⇧P may be used by some editors (e.g. Command Palette).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                HStack {
                    Button("Reset to Default (⌃⌘P)") {
                        HotkeyManager.shared.resetToDefault()
                    }
                    .pluckGlassButton(shape: .capsule)
                    .controlSize(.small)
                    Spacer()
                }
            }

            Section("Setup Assistant") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Onboarding Guide")
                            .font(.body)
                        Text("Re-run the first-launch setup wizard at any time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Run Setup Wizard…") {
                        onRunOnboardingAgain?()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 2. OCR Settings Pane

private struct OCRSettingsPane: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var availableLanguages: [VisionOCRService.LanguageOption] = []

    private let sampleRawText = "  Pluck ex-\ntracts text across\nmultiple lines.  "

    private var previewCleanedText: String {
        let options = TextCleanerOptions(
            trimWhitespace: settings.trimWhitespace,
            mergeLineBreaks: settings.mergeLineBreaks,
            removeHyphenation: settings.removeHyphenation
        )
        return TextCleaner.clean(sampleRawText, options: options)
    }

    var body: some View {
        Form {
            Section("Vision Engine") {
                Picker("Recognition Level", selection: $settings.recognitionLevel) {
                    Text("Accurate").tag("accurate")
                    Text("Fast").tag("fast")
                }
                .pickerStyle(.segmented)

                Picker("Language", selection: $settings.ocrLanguage) {
                    Text("Auto-Detect").tag("auto")
                    ForEach(availableLanguages) { lang in
                        Text(lang.displayName).tag(lang.code)
                    }
                }
            }

            Section("Post-Processing") {
                Toggle("Trim leading & trailing whitespace", isOn: $settings.trimWhitespace)
                Toggle("Merge single line breaks", isOn: $settings.mergeLineBreaks)
                Toggle("Remove line-end hyphenation", isOn: $settings.removeHyphenation)
            }

            Section("Live Cleaning Preview") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw OCR Input:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(sampleRawText)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Output after Cleanup:")
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                        Text(previewCleanedText)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.08))
                            )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            let level: VNRequestTextRecognitionLevel = settings.recognitionLevel == "fast" ? .fast : .accurate
            availableLanguages = VisionOCRService.availableLanguages(for: level)
        }
    }
}

// MARK: - 3. Clipboard Settings Pane

private struct ClipboardSettingsPane: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var isMaccyInstalled = MaccyDetector.isMaccyInstalled

    var body: some View {
        Form {
            Section("Maccy Integration") {
                HStack {
                    Text("Maccy Status")
                    Spacer()
                    if isMaccyInstalled {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                            Text("Installed")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("Not Detected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Link("Install", destination: MaccyDetector.maccyReleasesURL)
                                .font(.subheadline.bold())
                                .pluckProminentButton(shape: .capsule)
                                .controlSize(.small)
                        }
                    }
                }

                Toggle("Save captured text to History", isOn: $settings.saveToHistory)

                Text("When disabled, Pluck tells Maccy and clipboard managers to ignore your captures so they won't be saved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            isMaccyInstalled = MaccyDetector.isMaccyInstalled
        }
    }
}

// MARK: - 4. Sound Settings Pane

private struct SoundSettingsPane: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Audio Feedback") {
                Toggle("Play sound effects", isOn: $settings.playSounds)

                HStack {
                    Text("Capture Success:")
                    Spacer()
                    Picker("", selection: $settings.successSound) {
                        ForEach(SoundPlayer.shared.availableSuccessSounds(), id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)

                    Button {
                        SoundPlayer.shared.playPreview(named: settings.successSound)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                    }
                    .pluckGlassButton()
                    .controlSize(.small)
                    .help("Preview success sound")
                }

                HStack {
                    Text("Capture Failed / Empty:")
                    Spacer()
                    Picker("", selection: $settings.errorSound) {
                        ForEach(SoundPlayer.shared.availableErrorSounds(), id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)

                    Button {
                        SoundPlayer.shared.playPreview(named: settings.errorSound)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                    }
                    .pluckGlassButton()
                    .controlSize(.small)
                    .help("Preview error sound")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 5. Permissions Settings Pane

private struct PermissionsSettingsPane: View {
    @State private var isScreenRecordingGranted = PermissionsHelper.isScreenRecordingGranted()
    @State private var poller = PermissionPoller()

    var body: some View {
        Form {
            Section("Screen Recording Access") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: isScreenRecordingGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(isScreenRecordingGranted ? Color.green : Color.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isScreenRecordingGranted ? "Screen Recording Granted" : "Permission Required")
                                .font(.headline)
                            Text(isScreenRecordingGranted ? "Pluck can capture any region of your screen." : "macOS requires Screen Recording access to read pixels from the screen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Button("Open System Settings → Screen Recording") {
                            PermissionsHelper.openScreenCaptureSettings()
                        }
                        .pluckProminentButton()
                        .controlSize(.small)

                        if !isScreenRecordingGranted {
                            Button("Restart Pluck") {
                                PermissionsHelper.relaunchApp()
                            }
                            .pluckGlassButton(shape: .roundedRectangle(radius: 6))
                            .controlSize(.small)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isScreenRecordingGranted ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
        .formStyle(.grouped)
        .onAppear {
            isScreenRecordingGranted = PermissionsHelper.isScreenRecordingGranted()
            poller.startPolling { granted in
                isScreenRecordingGranted = granted
            }
        }
        .onDisappear {
            poller.stopPolling()
        }
    }
}

// MARK: - 6. About Settings Pane

private struct AboutSettingsPane: View {
    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    AssetHelper.themeAdaptiveHeroLogo(size: 68)
                        .padding(.top, 4)

                    Text("Pluck")
                        .font(.system(size: 22, weight: .bold))

                    Text(versionString)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("0% Idle CPU • Pure AppKit Shell • Zero Telemetry")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                        )
                        .foregroundStyle(.primary)

                    Text("Developed by AJ")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .padding(.top, 4)

                    HStack(spacing: 12) {
                        Link(destination: URL(string: "https://github.com/SyntaXPixel")!) {
                            HStack(spacing: 8) {
                                AssetHelper.gitHubLogo(size: 16)
                                Text("GitHub")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Link(destination: URL(string: "https://github.com/SyntaXPixel/Pluck")!) {
                            HStack(spacing: 8) {
                                AssetHelper.openSourceLogo(size: 16)
                                Text("Open Source")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Acknowledgments") {
                VStack(spacing: 12) {
                    acknowledgmentRow(
                        title: "Maccy",
                        author: "Alexey Rodionov",
                        note: "Clipboard manager integration",
                        url: "https://github.com/p0deje/Maccy"
                    )

                    Divider()

                    acknowledgmentRow(
                        title: "macOCR",
                        author: "Guillermo Rauch & schappim",
                        note: "OCR architecture and vision inspiration",
                        url: "https://github.com/schappim/macOCR"
                    )

                    Divider()

                    acknowledgmentRow(
                        title: "KeyboardShortcuts",
                        author: "Sindre Sorhus",
                        note: "Global keyboard shortcuts",
                        url: "https://github.com/sindresorhus/KeyboardShortcuts"
                    )

                    Divider()

                    acknowledgmentRow(
                        title: "LaunchAtLogin-Modern",
                        author: "Sindre Sorhus",
                        note: "macOS login item management",
                        url: "https://github.com/sindresorhus/LaunchAtLogin-Modern"
                    )
                }
                .padding(.vertical, 6)
            }

            Section("License") {
                Text("Released under the MIT License.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func acknowledgmentRow(title: String, author: String, note: String, url: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("|")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.4))

                    Text(author)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.85))
            }

            Spacer()

            Link(destination: URL(string: url)!) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Open \(title) repository")
        }
        .padding(.vertical, 2)
    }
}

