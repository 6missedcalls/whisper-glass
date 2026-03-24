import Foundation
import os

/// Coordinator for real-time speech transcription.
///
/// Uses an actor-isolated chunk queue so audio chunks are processed
/// sequentially — no chunks are dropped even when Whisper is busy.
@Observable
public final class TranscriptionEngine {

    private static let logger = Logger(
        subsystem: "com.whisper-glass.transcription",
        category: "TranscriptionEngine"
    )

    // MARK: - Public Observable State

    public private(set) var segments: [TranscriptSegment] = []
    public private(set) var partialText: String = ""
    public private(set) var state: TranscriptionState = .idle
    public private(set) var currentLanguage: String = "en"

    /// Called whenever a NEW segment is finalized. Set by AppDelegate for auto-type.
    public var onNewSegment: ((TranscriptSegment) -> Void)?

    // MARK: - Dependencies

    private let whisperBridge: WhisperBridge
    let modelManager: ModelManager

    /// Serial processing queue — chunks wait in line instead of being dropped
    private var chunkQueue: [([Float], Date)] = []
    private var isProcessing = false
    private var processingTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        whisperBridge: WhisperBridge = WhisperBridge(),
        modelManager: ModelManager = ModelManager()
    ) {
        self.whisperBridge = whisperBridge
        self.modelManager = modelManager
    }

    // MARK: - Lifecycle Controls

    public func start() throws {
        guard state == .idle else {
            throw TranscriptionError.invalidState(
                current: state.label,
                attempted: TranscriptionState.listening.label
            )
        }
        state = .listening
        partialText = ""
        chunkQueue.removeAll()
        isProcessing = false
        fputs("[WG-TE] Engine started — listening\n", stderr)
    }

    public func stop() {
        processingTask?.cancel()
        processingTask = nil
        chunkQueue.removeAll()
        isProcessing = false
        state = .idle
        partialText = ""
        fputs("[WG-TE] Engine stopped\n", stderr)
    }

    public func pause() throws {
        guard state == .listening || state == .transcribing else {
            throw TranscriptionError.invalidState(
                current: state.label,
                attempted: TranscriptionState.paused.label
            )
        }
        state = .paused
    }

    public func resume() throws {
        guard state == .paused else {
            throw TranscriptionError.invalidState(
                current: state.label,
                attempted: TranscriptionState.listening.label
            )
        }
        state = .listening
    }

    public func clearSegments() {
        segments = []
        partialText = ""
    }

    // MARK: - Audio Processing

    /// Enqueues an audio chunk for transcription. Chunks are processed
    /// serially so nothing is dropped even when Whisper is busy.
    public func processAudioChunk(_ audioFrames: [Float]) {
        guard state == .listening || state == .transcribing else { return }

        chunkQueue.append((audioFrames, Date()))

        // Keep queue bounded — drop oldest if too many pile up
        if chunkQueue.count > 3 {
            chunkQueue.removeFirst()
            fputs("[WG-TE] Queue overflow, dropped oldest chunk\n", stderr)
        }

        processNextChunkIfIdle()
    }

    // MARK: - One-Shot Transcription

    /// Transcribes a complete audio recording in one pass.
    /// This is the recommended approach — record the full utterance, then transcribe.
    public func transcribeAudio(_ samples: [Float]) async throws -> [TranscriptSegment] {
        return try await whisperBridge.transcribe(audioFrames: samples)
    }

    // MARK: - Model

    public func loadModel(_ model: WhisperModel) async throws {
        let modelURL: URL
        if modelManager.isModelDownloaded(model) {
            modelURL = modelManager.modelPath(model)
        } else {
            modelURL = try await modelManager.downloadModel(model)
        }
        try await whisperBridge.loadModel(model, from: modelURL)
    }

    public func setLanguage(_ language: String) {
        currentLanguage = language
        whisperBridge.language = language
    }

    // MARK: - Private

    private func processNextChunkIfIdle() {
        guard !isProcessing, !chunkQueue.isEmpty else { return }
        guard state == .listening || state == .transcribing else { return }

        isProcessing = true
        let (chunk, timestamp) = chunkQueue.removeFirst()

        processingTask = Task { [weak self] in
            guard let self else { return }

            self.state = .transcribing
            fputs("[WG-TE] Processing chunk (\(chunk.count) samples, queue=\(self.chunkQueue.count) remaining)\n", stderr)

            do {
                let newSegments = try await self.whisperBridge.transcribe(audioFrames: chunk)

                guard !Task.isCancelled else { return }

                for seg in newSegments {
                    fputs("[WG-TE] Transcribed: \"\(seg.text)\"\n", stderr)
                }

                if !newSegments.isEmpty {
                    let finalSegments = newSegments.map { $0.finalized() }

                    // Append new segments, filtering out blanks and Whisper artifacts
                    let junkPatterns = ["[BLANK_AUDIO]", "[MUSIC]", "[SILENCE]", "(silence)", "[NO_SPEECH]"]
                    for segment in finalSegments where !segment.text.trimmingCharacters(in: .whitespaces).isEmpty {
                        let trimmed = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if junkPatterns.contains(where: { trimmed.contains($0) }) {
                            fputs("[WG-TE] Skipping junk segment: \"\(trimmed)\"\n", stderr)
                            continue
                        }
                        self.segments.append(segment)
                        fputs("[WG-TE] Segment added, total=\(self.segments.count)\n", stderr)

                        // Notify for auto-type
                        self.onNewSegment?(segment)
                    }
                }
            } catch {
                fputs("[WG-TE] ERROR: \(error)\n", stderr)
            }

            self.isProcessing = false

            // If there are more chunks queued, process the next one
            if self.state == .transcribing {
                self.state = .listening
            }
            self.processNextChunkIfIdle()
        }
    }
}
