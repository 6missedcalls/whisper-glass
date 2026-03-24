import Foundation
import os

/// Manages transcript session persistence as JSON files in Application Support.
public struct TranscriptStore: Sendable {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "TranscriptStore"
    )

    private let baseDirectory: URL

    /// Creates a store using the default Application Support directory.
    public init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.baseDirectory = appSupport
            .appendingPathComponent("WhisperGlass", isDirectory: true)
            .appendingPathComponent("Transcripts", isDirectory: true)
        try ensureDirectoryExists()
    }

    /// Creates a store using a custom directory (useful for testing).
    public init(directory: URL) throws {
        self.baseDirectory = directory
        try ensureDirectoryExists()
    }

    // MARK: - Directory Management

    private func ensureDirectoryExists() throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: baseDirectory.path) else { return }

        do {
            try fileManager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw StorageError.directoryCreationFailed(
                underlying: error.localizedDescription
            )
        }
    }

    // MARK: - File Path

    private func fileURL(for id: UUID) -> URL {
        baseDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - CRUD Operations

    /// Saves a transcript session as a JSON file.
    public func saveSession(_ session: TranscriptSession) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(session)
        } catch {
            throw StorageError.encodingFailed(underlying: error.localizedDescription)
        }

        let url = fileURL(for: session.id)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw StorageError.saveFailed(underlying: error.localizedDescription)
        }

        Self.logger.info("Saved session \(session.id.uuidString)")
    }

    /// Loads a single transcript session by ID.
    public func loadSession(id: UUID) throws -> TranscriptSession {
        let url = fileURL(for: id)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageError.sessionNotFound(id: id.uuidString)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw StorageError.loadFailed(
                id: id.uuidString,
                underlying: error.localizedDescription
            )
        }

        return try decodeSession(from: data, id: id.uuidString)
    }

    /// Lists all saved transcript sessions, sorted by start date (newest first).
    public func listSessions() throws -> [TranscriptSession] {
        let fileManager = FileManager.default

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw StorageError.loadFailed(
                id: "all",
                underlying: error.localizedDescription
            )
        }

        let jsonFiles = contents.filter { $0.pathExtension == "json" }
        var sessions: [TranscriptSession] = []

        for fileURL in jsonFiles {
            let data = try Data(contentsOf: fileURL)
            let session = try decodeSession(
                from: data,
                id: fileURL.lastPathComponent
            )
            sessions.append(session)
        }

        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    /// Deletes a transcript session by ID.
    public func deleteSession(id: UUID) throws {
        let url = fileURL(for: id)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageError.sessionNotFound(id: id.uuidString)
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw StorageError.deleteFailed(
                id: id.uuidString,
                underlying: error.localizedDescription
            )
        }

        Self.logger.info("Deleted session \(id.uuidString)")
    }

    // MARK: - Helpers

    private func decodeSession(from data: Data, id: String) throws -> TranscriptSession {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(TranscriptSession.self, from: data)
        } catch {
            throw StorageError.decodingFailed(underlying: error.localizedDescription)
        }
    }
}
