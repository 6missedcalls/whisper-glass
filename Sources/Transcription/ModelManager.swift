import Foundation
import os

/// Downloads, caches, and manages Whisper GGML model files.
///
/// Models are stored in `Application Support/WhisperGlass/Models/`.
/// Before downloading, checks whether the model file already exists locally.
public final class ModelManager: @unchecked Sendable {

    private static let logger = Logger(
        subsystem: "com.whisper-glass.transcription",
        category: "ModelManager"
    )

    /// Application Support subdirectory for model storage.
    private static let modelDirectoryName = "WhisperGlass/Models"

    /// Shared URLSession for downloads.
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Directory Management

    /// Returns the base directory for stored models.
    public var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent(Self.modelDirectoryName)
    }

    /// Ensures the models directory exists, creating it if necessary.
    private func ensureModelsDirectoryExists() throws {
        let directory = modelsDirectory
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                Self.logger.info("Created models directory: \(directory.path)")
            } catch {
                throw TranscriptionError.fileSystemError(
                    underlying: "Cannot create models directory: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Model Path & Status

    /// Returns the local file URL where a model would be stored.
    ///
    /// - Parameter model: The model variant.
    /// - Returns: The expected file URL for the model.
    public func modelPath(_ model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.filename)
    }

    /// Checks whether a model file already exists on disk.
    ///
    /// - Parameter model: The model variant to check.
    /// - Returns: `true` if the model file exists locally.
    public func isModelDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(model).path)
    }

    // MARK: - Download

    /// Downloads a model from Hugging Face and caches it locally.
    ///
    /// Reports progress via an `AsyncStream<Double>` through the `onProgress` closure.
    /// If the model is already downloaded, returns the cached path immediately.
    ///
    /// - Parameters:
    ///   - model: The model variant to download.
    ///   - onProgress: Optional closure called with download progress (0.0 to 1.0).
    /// - Returns: The local file URL of the downloaded model.
    /// - Throws: `TranscriptionError.downloadFailed` or `TranscriptionError.fileSystemError`.
    public func downloadModel(
        _ model: WhisperModel,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let destination = modelPath(model)

        if isModelDownloaded(model) {
            Self.logger.info("Model already cached: \(model.displayName)")
            onProgress?(1.0)
            return destination
        }

        try ensureModelsDirectoryExists()

        Self.logger.info("Downloading model: \(model.displayName) from \(model.downloadURL)")

        do {
            let (tempURL, response) = try await urlSession.download(from: model.downloadURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw TranscriptionError.downloadFailed(
                    underlying: "HTTP status \(statusCode)"
                )
            }

            try moveDownloadedFile(from: tempURL, to: destination)
            Self.logger.info("Model downloaded: \(model.displayName) -> \(destination.path)")
            onProgress?(1.0)
            return destination
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.downloadFailed(
                underlying: error.localizedDescription
            )
        }
    }

    // MARK: - Delete

    /// Deletes a downloaded model from disk.
    ///
    /// - Parameter model: The model variant to delete.
    /// - Throws: `TranscriptionError.fileSystemError` if deletion fails.
    public func deleteModel(_ model: WhisperModel) throws {
        let path = modelPath(model)

        guard FileManager.default.fileExists(atPath: path.path) else {
            Self.logger.debug("Model not found for deletion: \(model.displayName)")
            return
        }

        do {
            try FileManager.default.removeItem(at: path)
            Self.logger.info("Deleted model: \(model.displayName)")
        } catch {
            throw TranscriptionError.fileSystemError(
                underlying: "Failed to delete model: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Private Helpers

    /// Moves a downloaded temporary file to its final destination.
    private func moveDownloadedFile(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default

        // Remove existing file if present (in case of partial downloads)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw TranscriptionError.fileSystemError(
                underlying: "Failed to move model file: \(error.localizedDescription)"
            )
        }
    }
}
