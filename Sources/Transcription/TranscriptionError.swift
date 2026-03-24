import Foundation

/// Typed errors for the transcription engine.
public enum TranscriptionError: LocalizedError, Sendable {
    case modelNotLoaded
    case modelLoadFailed(underlying: String)
    case transcriptionFailed(underlying: String)
    case invalidState(current: String, attempted: String)
    case downloadFailed(underlying: String)
    case downloadCancelled
    case fileSystemError(underlying: String)
    case modelFileNotFound(path: String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No Whisper model is loaded. Download or load a model first."
        case .modelLoadFailed(let underlying):
            return "Failed to load Whisper model: \(underlying)"
        case .transcriptionFailed(let underlying):
            return "Transcription failed: \(underlying)"
        case .invalidState(let current, let attempted):
            return "Cannot transition from \(current) to \(attempted)"
        case .downloadFailed(let underlying):
            return "Model download failed: \(underlying)"
        case .downloadCancelled:
            return "Model download was cancelled"
        case .fileSystemError(let underlying):
            return "File system error: \(underlying)"
        case .modelFileNotFound(let path):
            return "Model file not found at: \(path)"
        }
    }
}
