import SwiftUI

// MARK: - Hotkey Demo View

/// Animated walkthrough showing how WhisperGlass hotkeys work in practice.
/// Cycles through a 3-step demo: press hotkey → speak → text appears in target app.
struct HotkeyDemoView: View {
    @State private var demoPhase: DemoPhase = .idle
    @State private var typedText = ""
    @State private var isAnimating = false

    private let fullText = "Refactor the auth middleware to use JWT"

    var body: some View {
        VStack(spacing: 10) {
            demoScene
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            phaseDescription
        }
        .onAppear { startDemoLoop() }
    }

    // MARK: - Demo Scene

    private var demoScene: some View {
        VStack(spacing: 12) {
            // Simulated target app title bar
            HStack(spacing: 6) {
                Circle().fill(.red.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(.yellow.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(.green.opacity(0.8)).frame(width: 8, height: 8)
                Text("VSCode — main.ts")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)

            // Simulated editor area
            VStack(alignment: .leading, spacing: 4) {
                Text("// TODO: ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    Text(typedText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                    cursorView
                    Spacer()
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 2))

            Spacer()

            // Hotkey indicator
            HStack(spacing: 8) {
                keystrokeView
                stateIndicator
            }
        }
    }

    // MARK: - Cursor

    private var cursorView: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 1.5, height: 14)
            .opacity(demoPhase == .idle ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
    }

    // MARK: - Keystroke Badge

    @ViewBuilder
    private var keystrokeView: some View {
        HStack(spacing: 3) {
            keyBadge("⌥")
            keyBadge("Space")
        }
        .opacity(demoPhase == .pressHotkey ? 1.0 : 0.4)
        .scaleEffect(demoPhase == .pressHotkey ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: demoPhase)
    }

    private func keyBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }

    // MARK: - State Indicator

    @ViewBuilder
    private var stateIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(demoPhase.indicatorColor)
                .frame(width: 6, height: 6)
            Text(demoPhase.statusLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Phase Description

    private var phaseDescription: some View {
        Text(demoPhase.description)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(height: 36)
            .animation(.easeInOut(duration: 0.2), value: demoPhase)
    }

    // MARK: - Demo Loop

    private func startDemoLoop() {
        isAnimating = true
        Task { @MainActor in
            while !Task.isCancelled {
                // Phase 1: Press hotkey
                demoPhase = .pressHotkey
                typedText = ""
                try? await Task.sleep(for: .seconds(1.2))

                // Phase 2: Speaking — text appears character by character
                demoPhase = .speaking
                for char in fullText {
                    guard !Task.isCancelled else { return }
                    typedText.append(char)
                    let delay = UInt64.random(in: 25...65)
                    try? await Task.sleep(for: .milliseconds(delay))
                }
                try? await Task.sleep(for: .seconds(1.0))

                // Phase 3: Done
                demoPhase = .done
                try? await Task.sleep(for: .seconds(1.5))

                // Reset
                demoPhase = .idle
                typedText = ""
                try? await Task.sleep(for: .seconds(0.8))
            }
        }
    }
}

// MARK: - Demo Phase

private enum DemoPhase: Equatable {
    case idle
    case pressHotkey
    case speaking
    case done

    var statusLabel: String {
        switch self {
        case .idle: "Ready"
        case .pressHotkey: "Recording"
        case .speaking: "Transcribing"
        case .done: "Sent"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .idle: .gray
        case .pressHotkey: .red
        case .speaking: .red
        case .done: .green
        }
    }

    var description: String {
        switch self {
        case .idle: "Press ⌥Space to start recording"
        case .pressHotkey: "Hotkey pressed — microphone is now active"
        case .speaking: "Speak naturally — text appears in your active app"
        case .done: "Done! Press ⌥Space again to stop"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HotkeyDemoView()
        .padding()
        .frame(width: 450, height: 400)
}
#endif
