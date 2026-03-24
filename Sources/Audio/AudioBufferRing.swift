import Foundation
import os

/// Thread-safe ring buffer that accumulates audio samples and produces
/// fixed-size chunks with configurable overlap for streaming transcription.
public actor AudioBufferRing {
    private static let logger = Logger(
        subsystem: "com.whisper-glass.audio",
        category: "AudioBufferRing"
    )

    private let chunkSize: Int
    private let overlapSize: Int
    private var buffer: [Float]
    private var totalSamplesAppended: Int

    /// Number of new samples needed beyond the overlap to produce a chunk.
    private var strideSize: Int {
        chunkSize - overlapSize
    }

    /// Creates a new ring buffer with the given chunk and overlap sizes.
    ///
    /// - Parameters:
    ///   - chunkSize: Number of samples per output chunk (default: 3s at 16kHz).
    ///   - overlapSize: Number of overlapping samples between chunks (default: 0.5s at 16kHz).
    public init(
        chunkSize: Int = AudioConstants.chunkSampleCount,
        overlapSize: Int = AudioConstants.overlapSampleCount
    ) {
        precondition(chunkSize > overlapSize, "chunkSize must be greater than overlapSize")
        precondition(chunkSize > 0, "chunkSize must be positive")
        precondition(overlapSize >= 0, "overlapSize must be non-negative")
        self.chunkSize = chunkSize
        self.overlapSize = overlapSize
        self.buffer = []
        self.totalSamplesAppended = 0
    }

    /// Appends new audio samples to the internal buffer.
    ///
    /// - Parameter samples: Float32 PCM samples to append.
    public func append(samples: [Float]) {
        buffer.append(contentsOf: samples)
        totalSamplesAppended += samples.count
        Self.logger.debug("Appended \(samples.count) samples, buffer size: \(self.buffer.count)")
    }

    /// Returns the next complete chunk if enough samples are available.
    ///
    /// After extraction, the consumed (non-overlap) portion is removed
    /// so that the overlap region remains at the front for the next chunk.
    ///
    /// - Returns: An array of `chunkSize` Float samples, or `nil` if not enough data.
    public func nextChunk() -> [Float]? {
        guard buffer.count >= chunkSize else {
            return nil
        }

        let chunk = Array(buffer.prefix(chunkSize))
        buffer = Array(buffer.dropFirst(strideSize))

        Self.logger.debug("Produced chunk of \(chunk.count) samples, remaining: \(self.buffer.count)")
        return chunk
    }

    /// Resets the buffer, discarding all accumulated samples.
    public func clear() {
        buffer = []
        totalSamplesAppended = 0
        Self.logger.debug("Buffer cleared")
    }

    /// Total number of samples appended since creation or last clear.
    public var totalSamples: Int {
        totalSamplesAppended
    }

    /// Current number of buffered samples not yet consumed.
    public var bufferedSampleCount: Int {
        buffer.count
    }

    /// Timestamp (in seconds) corresponding to the total samples appended,
    /// based on Whisper's sample rate.
    public var currentTimestamp: TimeInterval {
        Double(totalSamplesAppended) / AudioConstants.whisperSampleRate
    }
}
