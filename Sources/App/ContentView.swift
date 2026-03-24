import SwiftUI
import WhisperGlassCore
import os

// MARK: - Content View

/// Main overlay content composing the transcript display and control bar.
/// Hosted inside the OverlayPanel via NSHostingView.
struct ContentView: View {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "ContentView"
    )

    // MARK: - Dependencies

    let transcriptionEngine: TranscriptionEngine
    let targetAppManager: TargetAppManager
    let textInjector: TextInjector
    let appSettings: AppSettings

    /// Closure provided by AppDelegate to toggle recording + audio pipeline
    let onToggleRecording: () -> Void
    /// Closure provided by AppDelegate to send transcript
    let onSendTranscript: () -> Void

    // MARK: - Local State

    @State private var transcriptionState: TranscriptionState = .idle
    @State private var selectedApp: TargetApp?
    @State private var sendMode: SendMode = .autoType

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            transcriptSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            controlBarSection
        }
        .frame(minWidth: 320, minHeight: 280)
        .onAppear {
            syncStateFromDependencies()
        }
        .onChange(of: transcriptionEngine.state) { _, newState in
            transcriptionState = newState
        }
        .onChange(of: targetAppManager.selectedApp) { _, newApp in
            selectedApp = newApp
        }
    }

    // MARK: - Sections

    private var transcriptSection: some View {
        TranscriptView(
            segments: transcriptionEngine.segments,
            partialText: transcriptionEngine.partialText
        )
    }

    private var controlBarSection: some View {
        ControlBar(
            transcriptionState: $transcriptionState,
            selectedApp: $selectedApp,
            sendMode: $sendMode,
            availableApps: targetAppManager.availableApps,
            onToggleRecording: {
                fputs("[WG-CV] Record button pressed\n", stderr)
                onToggleRecording()
            },
            onSend: {
                fputs("[WG-CV] Send button pressed\n", stderr)
                onSendTranscript()
            }
        )
    }

    // MARK: - Helpers

    private func syncStateFromDependencies() {
        transcriptionState = transcriptionEngine.state
        selectedApp = targetAppManager.selectedApp
        sendMode = appSettings.sendMode
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ContentView(
        transcriptionEngine: TranscriptionEngine(),
        targetAppManager: TargetAppManager(),
        textInjector: TextInjector(),
        appSettings: AppSettings(),
        onToggleRecording: {},
        onSendTranscript: {}
    )
    .frame(width: 340, height: 520)
}
#endif
