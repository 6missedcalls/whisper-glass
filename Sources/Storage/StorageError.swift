import Foundation

/// Typed errors for transcript storage operations.
public enum StorageError: LocalizedError, Sendable {
    case directoryCreationFailed(underlying: String)
    case saveFailed(underlying: String)
    case loadFailed(id: String, underlying: String)
    case sessionNotFound(id: String)
    case deleteFailed(id: String, underlying: String)
    case encodingFailed(underlying: String)
    case decodingFailed(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let underlying):
            return "Failed to create storage directory: \(underlying)"
        case .saveFailed(let underlying):
            return "Failed to save transcript session: \(underlying)"
        case .loadFailed(let id, let underlying):
            return "Failed to load transcript session \(id): \(underlying)"
        case .sessionNotFound(let id):
            return "Transcript session not found: \(id)"
        case .deleteFailed(let id, let underlying):
            return "Failed to delete transcript session \(id): \(underlying)"
        case .encodingFailed(let underlying):
            return "Failed to encode data: \(underlying)"
        case .decodingFailed(let underlying):
            return "Failed to decode data: \(underlying)"
        }
    }
}
