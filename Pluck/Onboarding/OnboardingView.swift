import AppKit
import KeyboardShortcuts
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 1
    case permissions = 2
    case history = 3
    case sandbox = 4

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .permissions: return "Screen Recording"
        case .history: return "Clipboard History"
        case .sandbox: return "Interactive OCR Test"
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var settings = SettingsStore.shared
    var onFinish: (() -> Void)?

    @State private var currentStep: OnboardingStep
    @State private var isScreenRecordingGranted: Bool = PermissionsHelper.isScreenRecordingGranted()
    @State private var isMaccyInstalled: Bool = MaccyDetector.isMaccyInstalled
    @State private var poller = PermissionPoller()
    @State private var showHistoryInfo: Bool = false

    init(startingAt step: OnboardingStep = .welcome, onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        self._currentStep = State(initialValue: step)
    }

    // Step 4 sandbox live test state
    enum SandboxState: Equatable {
        case waiting
        case capturing
        case success(String)
        case failure(String)
    }
    @State private var sandboxState: SandboxState = .waiting
    @State private var initialChangeCount: Int = NSPasteboard.general.changeCount
    @State private var sandboxTimer: Timer? = nil
    @State private var currentShortcutDisplay: String = HotkeyManager.shared.currentShortcutString()

    var body: some View {
        VStack(spacing: 0) {
            // Main step content area
            VStack(spacing: 0) {
                switch currentStep {
                case .welcome:
                    welcomeView
                case .permissions:
                    permissionsView
                case .history:
                    historyView
                case .sandbox:
                    sandboxView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Footer Navigation Bar
            footerView
        }
        .frame(width: 520, height: 440)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            settings.pendingOnboardingResumeStep = currentStep.rawValue
            isScreenRecordingGranted = PermissionsHelper.isScreenRecordingGranted()
            isMaccyInstalled = MaccyDetector.isMaccyInstalled
            currentShortcutDisplay = HotkeyManager.shared.currentShortcutString()
            if currentStep == .permissions && !isScreenRecordingGranted {
                startPermissionPolling()
            }
        }
        .onChange(of: currentStep) { newStep in
            settings.pendingOnboardingResumeStep = newStep.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .pluckShortcutDidChange)) { _ in
            currentShortcutDisplay = HotkeyManager.shared.currentShortcutString()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pluckDidStartCapture)) { _ in
            if currentStep == .sandbox {
                withAnimation(.easeInOut(duration: 0.15)) {
                    sandboxState = .capturing
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pluckDidCaptureText)) { notification in
            if currentStep == .sandbox {
                let text = (notification.userInfo?["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        sandboxState = .success(text)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pluckDidFailCapture)) { notification in
            if currentStep == .sandbox {
                let reason = notification.userInfo?["reason"] as? String ?? "No text detected in selected area."
                withAnimation(.easeInOut(duration: 0.15)) {
                    sandboxState = .failure(reason)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pluckDidCancelCapture)) { _ in
            if currentStep == .sandbox {
                if case .capturing = sandboxState {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        sandboxState = .waiting
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isScreenRecordingGranted = PermissionsHelper.isScreenRecordingGranted()
        }
        .onDisappear {
            stopPermissionPolling()
            stopSandboxWatcher()
        }
    }

    // MARK: - Step 1: Welcome

    @ViewBuilder
    private var welcomeView: some View {
        VStack(spacing: 8) {
            AssetHelper.themeAdaptiveHeroLogo(size: 64)
                .padding(.top, 4)

            Text("Welcome to Pluck")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text("Capture text from anywhere on your screen.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer().frame(height: 20)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(
                    symbol: "command",
                    title: "Capture with \(currentShortcutDisplay)",
                    description: "Start a capture from anywhere in macOS."
                )

                featureRow(
                    symbol: "viewfinder",
                    title: "Select any area",
                    description: "Extract text from images, PDFs, code, and interface labels."
                )

                featureRow(
                    symbol: "doc.on.clipboard",
                    title: "Copy instantly",
                    description: "Hear capture feedback and paste the result with ⌘V."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)

            Spacer().frame(height: 20)

            Text("No text selection required. Just capture, copy, and continue working.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func featureRow(symbol: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 20, height: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Step 2: Screen Recording Permission

    @ViewBuilder
    private var permissionsView: some View {
        VStack(spacing: 8) {
            Image(systemName: isScreenRecordingGranted ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(isScreenRecordingGranted ? .green : .primary)
                .padding(.top, 8)

            Text("Screen Recording")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text("macOS needs permission for Pluck to read pixels inside your selection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            // Compact permission status row
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isScreenRecordingGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isScreenRecordingGranted ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isScreenRecordingGranted ? "Permission granted" : "Permission required")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(isScreenRecordingGranted ? "Screen capture is ready to use." : "Enable Screen & System Audio Recording access for Pluck in System Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            Spacer().frame(height: 22)

            if !isScreenRecordingGranted {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Open System Settings") {
                            settings.pendingOnboardingResumeStep = OnboardingStep.permissions.rawValue
                            UserDefaults.standard.synchronize()
                            PermissionsHelper.requestScreenRecording()
                        }
                        .pluckProminentButton(shape: .capsule)
                        .controlSize(.regular)

                        Button("Restart Pluck") {
                            settings.pendingOnboardingResumeStep = OnboardingStep.permissions.rawValue
                            UserDefaults.standard.synchronize()
                            PermissionsHelper.relaunchApp()
                        }
                        .pluckGlassButton(shape: .roundedRectangle(radius: 6))
                        .controlSize(.regular)
                    }

                    Text("If access was just enabled, restart Pluck if macOS still reports it as unavailable.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            } else {
                VStack(spacing: 4) {
                    Text("You're ready to proceed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
            }

            Spacer()
        }
        .onAppear {
            isScreenRecordingGranted = PermissionsHelper.isScreenRecordingGranted()
            if !isScreenRecordingGranted {
                startPermissionPolling()
            }
        }
    }

    // MARK: - Step 3: Clipboard History

    @ViewBuilder
    private var historyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.primary)
                .padding(.top, 8)

            Text("Clipboard History")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text("Choose whether Pluck's captures are saved to clipboard history.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 20)

            // Maccy Integration subtle rounded configuration group
            VStack(spacing: 0) {
                // Row 1: Maccy Detection
                HStack {
                    Text("Maccy")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)

                    Spacer()

                    if isMaccyInstalled {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.subheadline.weight(.semibold))
                            Text("Installed")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider()

                // Row 2: History Preference with Info Button
                HStack(alignment: .center, spacing: 6) {
                    Text("Save captures to Maccy history")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)

                    Button {
                        showHistoryInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("When disabled, Pluck tells Maccy and clipboard managers to ignore your captures so they won't be saved.")
                    .popover(isPresented: $showHistoryInfo, arrowEdge: .top) {
                        Text("When disabled, Pluck tells Maccy and clipboard managers to ignore your captures so they won't be saved.")
                            .font(.callout)
                            .padding(12)
                            .frame(width: 240)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.saveToHistory)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .pluckGlassContainer(cornerRadius: 10)

            Spacer()
        }
        .onAppear {
            isMaccyInstalled = MaccyDetector.isMaccyInstalled
        }
    }

    // MARK: - Step 4: Interactive OCR Test

    @ViewBuilder
    private var sandboxView: some View {
        VStack(spacing: 8) {
            Text("Try a Capture")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 4)

            Text("Use your shortcut to capture the sample below.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 14)

            // Section Label
            Text("SAMPLE TEXT")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            // Interactive Target Frame
            Text("Pluck extracts unselectable text instantly.")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundColor(Color.primary.opacity(0.25))
                )

            Spacer().frame(height: 16)

            // Live Capture Status Area (reserved consistent height)
            statusArea
                .frame(minHeight: 52)

            Spacer()
        }
        .onAppear {
            startSandboxWatcher()
        }
        .onDisappear {
            stopSandboxWatcher()
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        switch sandboxState {
        case .waiting:
            HStack(spacing: 10) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready to test")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("Press \(currentShortcutDisplay) and select the sample text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )

        case .capturing:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Capturing text…")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("Reading pixels and extracting text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )

        case .success(let capturedText):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture successful")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text("\"\(capturedText)\"")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.green.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )

        case .failure(let reason):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture failed")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Try Again") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        sandboxState = .waiting
                    }
                }
                .pluckGlassButton()
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Footer Navigation Bar

    @ViewBuilder
    private var footerView: some View {
        ZStack {
            // Step Indicator Dots (Centered in the middle)
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(stepIndicatorColor(for: step))
                        .frame(width: 6.5, height: 6.5)
                }
            }
            .accessibilityLabel("Step \(currentStep.rawValue) of 4: \(currentStep.title)")

            // Edge Navigation: Back on completely left, Next on completely right
            HStack {
                // Back Button (Towards completely left)
                if currentStep != .welcome {
                    Button("← Back") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            goToPreviousStep()
                        }
                    }
                    .pluckGlassButton(shape: .capsule)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.regular)
                }

                Spacer()

                // Next Button (Towards completely right)
                switch currentStep {
                case .welcome:
                    Button("Next →") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            advanceToPermissions()
                        }
                    }
                    .pluckProminentButton(shape: .capsule)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)

                case .permissions:
                    Button("Next →") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            advanceToHistory()
                        }
                    }
                    .pluckProminentButton(shape: .capsule)
                    .controlSize(.regular)
                    .disabled(!isScreenRecordingGranted)
                    .keyboardShortcut(.defaultAction)

                case .history:
                    Button("Next →") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            advanceToSandbox()
                        }
                    }
                    .pluckProminentButton(shape: .capsule)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)

                case .sandbox:
                    if case .success = sandboxState {
                        Button("Finish Setup") {
                            completeOnboarding()
                        }
                        .pluckProminentButton(shape: .capsule)
                        .controlSize(.regular)
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Skip Test & Finish") {
                            completeOnboarding()
                        }
                        .pluckGlassButton(shape: .capsule)
                        .controlSize(.regular)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func stepIndicatorColor(for step: OnboardingStep) -> Color {
        if step == currentStep {
            return Color.primary
        } else if step.rawValue < currentStep.rawValue {
            return Color.secondary.opacity(0.6)
        } else {
            return Color.secondary.opacity(0.2)
        }
    }

    // MARK: - Navigation & Polling Helpers

    private func goToPreviousStep() {
        stopPermissionPolling()
        stopSandboxWatcher()
        if currentStep.rawValue > 1 {
            let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
            currentStep = prev
            settings.pendingOnboardingResumeStep = prev.rawValue
        }
    }

    private func advanceToPermissions() {
        currentStep = .permissions
        settings.pendingOnboardingResumeStep = OnboardingStep.permissions.rawValue
        isScreenRecordingGranted = PermissionsHelper.isScreenRecordingGranted()
        if !isScreenRecordingGranted {
            startPermissionPolling()
        }
    }

    private func advanceToHistory() {
        isScreenRecordingGranted = PermissionsHelper.isScreenRecordingGranted()
        guard isScreenRecordingGranted else { return }
        stopPermissionPolling()
        currentStep = .history
        settings.pendingOnboardingResumeStep = OnboardingStep.history.rawValue
    }

    private func advanceToSandbox() {
        currentStep = .sandbox
        settings.pendingOnboardingResumeStep = OnboardingStep.sandbox.rawValue
        sandboxState = .waiting
        startSandboxWatcher()
    }

    private func startPermissionPolling() {
        stopPermissionPolling()
        poller.startPolling(interval: 1.0) { granted in
            if granted && !isScreenRecordingGranted {
                isScreenRecordingGranted = true
                SoundPlayer.shared.playSuccess()
                stopPermissionPolling()
            } else {
                isScreenRecordingGranted = granted
            }
        }
    }

    private func stopPermissionPolling() {
        poller.stopPolling()
    }

    private func startSandboxWatcher() {
        stopSandboxWatcher()
        initialChangeCount = NSPasteboard.general.changeCount
        sandboxTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let currentCount = NSPasteboard.general.changeCount
            if currentCount != initialChangeCount {
                initialChangeCount = currentCount
                if let str = NSPasteboard.general.string(forType: .string), !str.isEmpty {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            sandboxState = .success(trimmed)
                        }
                    }
                }
            }
        }
    }

    private func stopSandboxWatcher() {
        sandboxTimer?.invalidate()
        sandboxTimer = nil
    }

    private func completeOnboarding() {
        stopPermissionPolling()
        stopSandboxWatcher()
        settings.pendingOnboardingResumeStep = nil
        settings.hasCompletedOnboarding = true
        UserDefaults.standard.synchronize()
        onFinish?()
    }
}
