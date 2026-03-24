import SwiftUI

// MARK: - Onboarding View

/// Multi-step first-run setup wizard for WhisperGlass.
/// Clean, spacious design following Apple HIG — no unnecessary glass effects
/// inside the window. Glass is reserved for floating UI only.
public struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var permissionChecker = PermissionChecker()
    @State private var selectedModel: WhisperModel = .base
    @State private var downloadState: ModelDownloadState = .notStarted

    private let totalSteps = 5
    private let onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Content area
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 20)

            // Bottom bar
            Divider()
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                stepDots
                Spacer()
                if currentStep < totalSteps - 1 {
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isNextDisabled)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 520)
        .onAppear { permissionChecker.startAccessibilityPolling() }
        .onDisappear { permissionChecker.stopAccessibilityPolling() }
    }

    // MARK: - Step Router

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: welcomeStep
        case 1: microphoneStep
        case 2: accessibilityStep
        case 3: ModelSelectionStep(selectedModel: $selectedModel, downloadState: $downloadState)
        case 4: readyStep
        default: EmptyView()
        }
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == currentStep ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var isNextDisabled: Bool {
        switch currentStep {
        case 1: !permissionChecker.microphoneGranted
        case 2: false
        case 3: downloadState != .completed
        default: false
        }
    }
}

// MARK: - Step 1: Welcome

private extension OnboardingView {
    var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            Text("WhisperGlass")
                .font(.largeTitle.weight(.bold))
            Text("Hold a shortcut, speak, release.\nYour words appear at the cursor.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Spacer()
        }
    }
}

// MARK: - Step 2: Microphone

private extension OnboardingView {
    var microphoneStep: some View {
        VStack(spacing: 20) {
            Spacer()
            statusIcon("mic.fill", granted: permissionChecker.microphoneGranted)
            Text("Microphone Access")
                .font(.title3.weight(.semibold))
            Text("WhisperGlass needs your microphone\nto hear and transcribe your voice.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if permissionChecker.microphoneGranted {
                grantedLabel
            } else {
                Button("Allow Microphone") {
                    Task { await permissionChecker.checkMicrophone() }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }
}

// MARK: - Step 3: Accessibility

private extension OnboardingView {
    var accessibilityStep: some View {
        VStack(spacing: 20) {
            Spacer()
            statusIcon("keyboard.fill", granted: permissionChecker.accessibilityGranted)
            Text("Accessibility")
                .font(.title3.weight(.semibold))
            Text("Required to type transcribed text\ninto other applications.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if permissionChecker.accessibilityGranted {
                grantedLabel
            } else {
                VStack(spacing: 8) {
                    Button("Open System Settings") {
                        permissionChecker.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                    Text("You can skip this and grant later.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Step 5: Ready

private extension OnboardingView {
    var readyStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Ready")
                .font(.title3.weight(.semibold))
            HotkeyDemoView()
            Spacer()
            Button(action: onComplete) {
                Text("Start Using WhisperGlass")
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Shared

private extension OnboardingView {
    func statusIcon(_ name: String, granted: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 40))
            .foregroundStyle(granted ? .green : .secondary)
            .frame(width: 64, height: 64)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var grantedLabel: some View {
        Label("Granted", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.green)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    OnboardingView(onComplete: {})
}
#endif
