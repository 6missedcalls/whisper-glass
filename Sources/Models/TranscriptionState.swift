import Foundation

/// State machine for the transcription engine lifecycle.
public enum TranscriptionState: String, Sendable {
    /// Engine is initialized but not capturing audio
    case idle

    /// Microphone is active, audio is being captured and buffered
    case listening

    /// Audio chunks are being processed by Whisper
    case transcribing

    /// Capture is paused, can be resumed without losing context
    case paused

    public var isActive: Bool {
        switch self {
        case .listening, .transcribing: true
        case .idle, .paused: false
        }
    }

    public var systemImage: String {
        switch self {
        case .idle: "mic"
        case .listening: "mic.fill"
        case .transcribing: "waveform"
        case .paused: "pause.circle.fill"
        }
    }

    public var label: String {
        switch self {
        case .idle: "Ready"
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .paused: "Paused"
        }
    }
}
