import SwiftUI

// MARK: - Control Bar

/// Bottom control area with record button, target app, and send mode.
/// Uses a clean vertical arrangement instead of cramming everything in one row.
public struct ControlBar: View {
    @Binding private var transcriptionState: TranscriptionState
    @Binding private var selectedApp: TargetApp?
    @Binding private var sendMode: SendMode

    private let availableApps: [TargetApp]
    private let onToggleRecording: () -> Void
    private let onSend: () -> Void

    public init(
        transcriptionState: Binding<TranscriptionState>,
        selectedApp: Binding<TargetApp?>,
        sendMode: Binding<SendMode>,
        availableApps: [TargetApp],
        onToggleRecording: @escaping () -> Void,
        onSend: @escaping () -> Void
    ) {
        self._transcriptionState = transcriptionState
        self._selectedApp = selectedApp
        self._sendMode = sendMode
        self.availableApps = availableApps
        self.onToggleRecording = onToggleRecording
        self.onSend = onSend
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            VStack(spacing: 10) {
                // Row 1: Record button (prominent, centered)
                recordButton

                // Row 2: Target app + send mode + send action
                HStack(spacing: 8) {
                    targetAppLabel

                    Spacer()

                    sendModePicker

                    if sendMode == .manual {
                        sendButton
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button(action: onToggleRecording) {
            HStack(spacing: 8) {
                Circle()
                    .fill(transcriptionState.isActive ? Color.red : Color.primary.opacity(0.25))
                    .frame(width: 8, height: 8)

                Text(recordLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(transcriptionState.isActive
                        ? Color.red.opacity(0.1)
                        : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        transcriptionState.isActive
                            ? Color.red.opacity(0.2)
                            : Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: transcriptionState)
    }

    private var recordLabel: String {
        switch transcriptionState {
        case .idle: "Start Recording"
        case .listening, .transcribing: "Recording"
        case .paused: "Resume"
        }
    }

    // MARK: - Target App

    private var targetAppLabel: some View {
        TargetAppPicker(
            selectedApp: $selectedApp,
            availableApps: availableApps
        )
    }

    // MARK: - Send Mode

    private var sendModePicker: some View {
        Menu {
            ForEach(SendMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        sendMode = mode
                    }
                } label: {
                    Label(mode.label, systemImage: mode.systemImage)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sendMode.systemImage)
                    .font(.system(size: 11))
                Text(sendMode.label)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
private let previewApps: [TargetApp] = [
    TargetApp(id: 1, bundleIdentifier: "com.microsoft.VSCode", name: "VS Code"),
    TargetApp(id: 2, bundleIdentifier: "com.apple.Safari", name: "Safari")
]

#Preview("Idle") {
    ControlBar(
        transcriptionState: .constant(.idle),
        selectedApp: .constant(nil),
        sendMode: .constant(.manual),
        availableApps: previewApps,
        onToggleRecording: {},
        onSend: {}
    )
    .frame(width: 340)
    .padding()
}

#Preview("Recording") {
    ControlBar(
        transcriptionState: .constant(.listening),
        selectedApp: .constant(nil),
        sendMode: .constant(.autoType),
        availableApps: previewApps,
        onToggleRecording: {},
        onSend: {}
    )
    .frame(width: 340)
    .padding()
}
#endif
