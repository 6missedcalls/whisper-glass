import Foundation
import SwiftWhisper
import os

/// Wraps SwiftWhisper initialization, configuration, and transcription.
///
/// Converts between SwiftWhisper's `Segment` type and the app's `TranscriptSegment` model.
/// Handles model loading and provides a clean async interface for transcription.
public final class WhisperBridge: @unchecked Sendable {

    private static let logger = Logger(
        subsystem: "com.whisper-glass.transcription",
        category: "WhisperBridge"
    )

    /// The currently loaded Whisper instance, if any.
    private var whisper: Whisper?

    /// The model that is currently loaded.
    private var loadedModel: WhisperModel?

    /// Language code for transcription (e.g., "en", "auto").
    public var language: String = "en"

    /// Whether to enable translation to English.
    public var translateToEnglish: Bool = false

    /// Milliseconds-per-unit conversion factor for SwiftWhisper timestamps.
    /// SwiftWhisper Segment times are in milliseconds.
    private static let millisecondsToSeconds: Double = 1_000.0

    public init() {}

    // MARK: - Model Loading

    /// Loads a Whisper model from disk.
    ///
    /// - Parameters:
    ///   - model: The model variant to load.
    ///   - fileURL: The local file URL of the GGML model binary.
    /// - Throws: `TranscriptionError.modelLoadFailed` if loading fails.
    public func loadModel(_ model: WhisperModel, from fileURL: URL) async throws {
        Self.logger.info("Loading model: \(model.displayName) from \(fileURL.path)")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TranscriptionError.modelFileNotFound(path: fileURL.path)
        }

        let params = WhisperParams()
        params.language = .auto
        params.translate = translateToEnglish

        let instance = Whisper(fromFileURL: fileURL, withParams: params)
        whisper = instance
        loadedModel = model
        Self.logger.info("Model loaded successfully: \(model.displayName)")
    }

    // MARK: - Transcription

    /// Transcribes audio frames using the loaded Whisper model.
    ///
    /// Uses the callback-based API instead of the async/await wrapper to avoid
    /// a race condition in SwiftWhisper 1.2.0 where the library's `inProgress`
    /// flag isn't reset before the async continuation resumes, causing the
    /// second call to deadlock inside `whisper_full()`.
    ///
    /// - Parameter audioFrames: 16kHz mono Float32 audio samples.
    /// - Returns: An array of `TranscriptSegment` converted from Whisper output.
    /// - Throws: `TranscriptionError.modelNotLoaded` or `TranscriptionError.transcriptionFailed`.
    public func transcribe(audioFrames: [Float]) async throws -> [TranscriptSegment] {
        guard let whisper = whisper else {
            throw TranscriptionError.modelNotLoaded
        }

        Self.logger.debug("Transcribing \(audioFrames.count) frames")

        return try await withCheckedThrowingContinuation { continuation in
            whisper.transcribe(audioFrames: audioFrames) { [weak self] result in
                guard let self else {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(
                        underlying: "WhisperBridge deallocated"
                    ))
                    return
                }
                switch result {
                case .success(let segments):
                    let converted = segments.map { self.convertSegment($0) }
                    Self.logger.debug("Transcribed \(converted.count) segments")
                    continuation.resume(returning: converted)
                case .failure(let error):
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(
                        underlying: error.localizedDescription
                    ))
                }
            }
        }
    }

    /// Whether a model is currently loaded and ready for transcription.
    public var isModelLoaded: Bool {
        whisper != nil
    }

    /// The currently loaded model variant, if any.
    public var currentModel: WhisperModel? {
        loadedModel
    }

    /// Unloads the current model, freeing resources.
    public func unloadModel() {
        whisper = nil
        loadedModel = nil
        Self.logger.info("Model unloaded")
    }

    // MARK: - Conversion

    /// Converts a SwiftWhisper `Segment` to our `TranscriptSegment`.
    private func convertSegment(_ segment: Segment) -> TranscriptSegment {
        let startSeconds = Double(segment.startTime) / Self.millisecondsToSeconds
        let endSeconds = Double(segment.endTime) / Self.millisecondsToSeconds
        let trimmedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)

        return TranscriptSegment(
            text: trimmedText,
            startTime: startSeconds,
            endTime: endSeconds,
            confidence: 1.0,
            language: language,
            isFinal: true
        )
    }
}
