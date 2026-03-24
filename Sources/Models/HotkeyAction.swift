import Foundation

/// Global hotkey actions supported by WhisperGlass.
public enum HotkeyAction: String, CaseIterable, Codable, Sendable {
    case toggleRecording
    case sendTranscript
    case clearTranscript
    case toggleOverlay

    public var label: String {
        switch self {
        case .toggleRecording: "Toggle Recording"
        case .sendTranscript: "Send Transcript"
        case .clearTranscript: "Clear Transcript"
        case .toggleOverlay: "Toggle Overlay"
        }
    }

    public var defaultKeyCode: UInt16 {
        switch self {
        case .toggleRecording: 49   // Space
        case .sendTranscript: 36    // Return
        case .clearTranscript: 51   // Delete
        case .toggleOverlay: 5      // G
        }
    }

    /// Default modifier is Control+Shift (⌃⇧) — avoids macOS system conflicts
    public var defaultModifierDescription: String {
        switch self {
        case .toggleRecording: "⌃⇧Space"
        case .sendTranscript: "⌃⇧Return"
        case .clearTranscript: "⌃⇧Delete"
        case .toggleOverlay: "⌃⇧G"
        }
    }
}
