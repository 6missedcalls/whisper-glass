import Foundation

/// Shared constants for the audio capture pipeline.
public enum AudioConstants {
    /// Whisper's native sample rate.
    public static let whisperSampleRate: Double = 16_000

    /// Single channel (mono) for Whisper input.
    public static let channelCount: UInt32 = 1

    /// Default chunk duration in seconds for buffered processing.
    public static let defaultChunkDuration: TimeInterval = 3.0

    /// No overlap — prevents duplicate transcription of the same audio.
    public static let defaultOverlapDuration: TimeInterval = 0.0

    /// Number of samples in one chunk at Whisper's sample rate.
    public static var chunkSampleCount: Int {
        Int(whisperSampleRate * defaultChunkDuration)
    }

    /// Number of overlap samples at Whisper's sample rate.
    public static var overlapSampleCount: Int {
        Int(whisperSampleRate * defaultOverlapDuration)
    }

    /// Stride (non-overlapping portion) sample count.
    public static var strideSampleCount: Int {
        chunkSampleCount - overlapSampleCount
    }

    /// Default RMS energy threshold for voice activity detection.
    public static let defaultVADThreshold: Float = 0.01

    /// Minimum duration (in seconds) to keep VAD active after voice is detected.
    public static let defaultVADHysteresisDuration: TimeInterval = 0.8

    /// Buffer size for the audio engine tap.
    public static let tapBufferSize: UInt32 = 4096
}
