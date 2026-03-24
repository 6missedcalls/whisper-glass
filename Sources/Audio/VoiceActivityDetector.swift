import Foundation
import os

/// RMS energy-based voice activity detector with hysteresis.
///
/// Calculates the root-mean-square energy of an audio buffer and compares
/// it against a configurable threshold. Hysteresis prevents rapid toggling
/// by keeping the detector active for a minimum duration after voice is last detected.
public final class VoiceActivityDetector: @unchecked Sendable {
    private static let logger = Logger(
        subsystem: "com.whisper-glass.audio",
        category: "VoiceActivityDetector"
    )

    /// RMS energy threshold; buffers with RMS above this are considered speech.
    public let threshold: Float

    /// Minimum seconds the detector stays active after last detecting voice.
    public let hysteresisDuration: TimeInterval

    /// Sample rate used to convert sample counts to time for hysteresis.
    public let sampleRate: Double

    // MARK: - Mutable state protected by lock

    private let lock = NSLock()
    private var lastVoiceTime: TimeInterval = -.infinity
    private var totalSamplesProcessed: Int = 0

    /// Creates a new voice activity detector.
    ///
    /// - Parameters:
    ///   - threshold: RMS energy threshold for speech detection.
    ///   - hysteresisDuration: Minimum seconds to stay active after voice.
    ///   - sampleRate: Audio sample rate for timestamp calculation.
    public init(
        threshold: Float = AudioConstants.defaultVADThreshold,
        hysteresisDuration: TimeInterval = AudioConstants.defaultVADHysteresisDuration,
        sampleRate: Double = AudioConstants.whisperSampleRate
    ) {
        precondition(threshold >= 0, "Threshold must be non-negative")
        precondition(hysteresisDuration >= 0, "Hysteresis duration must be non-negative")
        self.threshold = threshold
        self.hysteresisDuration = hysteresisDuration
        self.sampleRate = sampleRate
    }

    /// Evaluates whether voice is active in the given audio samples.
    ///
    /// - Parameter samples: Float32 PCM audio samples.
    /// - Returns: `true` if voice is detected or hysteresis is still active.
    public func isVoiceActive(in samples: [Float]) -> Bool {
        let rms = Self.calculateRMS(samples)
        let currentEnergy = rms >= threshold

        lock.lock()
        let currentTime = Double(totalSamplesProcessed) / sampleRate
        totalSamplesProcessed += samples.count

        if currentEnergy {
            lastVoiceTime = currentTime
            lock.unlock()
            Self.logger.debug("Voice detected: RMS=\(rms, format: .fixed(precision: 6))")
            return true
        }

        let lastVoice = lastVoiceTime
        lock.unlock()

        let elapsed = currentTime - lastVoice
        let hysteresisActive = elapsed < hysteresisDuration && lastVoice > -.infinity

        if hysteresisActive {
            Self.logger.debug(
                "Hysteresis active: \(elapsed, format: .fixed(precision: 3))s since last voice"
            )
        }

        return hysteresisActive
    }

    /// Calculates the RMS energy of an audio sample buffer.
    ///
    /// - Parameter samples: Float32 PCM audio samples.
    /// - Returns: The root-mean-square energy value.
    public static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        let sumOfSquares = samples.reduce(Float(0)) { accumulator, sample in
            accumulator + sample * sample
        }

        return sqrt(sumOfSquares / Float(samples.count))
    }

    /// Resets the detector's internal state.
    public func reset() {
        lock.lock()
        lastVoiceTime = -.infinity
        totalSamplesProcessed = 0
        lock.unlock()
    }
}
