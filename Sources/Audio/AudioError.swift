import Foundation

/// Typed errors for the audio capture pipeline.
public enum AudioError: LocalizedError, Sendable {
    case engineStartFailed(underlying: String)
    case noInputNode
    case formatConversionFailed
    case deviceNotFound(id: String)
    case permissionDenied
    case interrupted
    case bufferAllocationFailed

    public var errorDescription: String? {
        switch self {
        case .engineStartFailed(let underlying):
            return "Audio engine failed to start: \(underlying)"
        case .noInputNode:
            return "No audio input node available"
        case .formatConversionFailed:
            return "Failed to convert audio format to 16kHz mono Float32"
        case .deviceNotFound(let id):
            return "Audio device not found: \(id)"
        case .permissionDenied:
            return "Microphone permission denied"
        case .interrupted:
            return "Audio session was interrupted"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        }
    }
}
