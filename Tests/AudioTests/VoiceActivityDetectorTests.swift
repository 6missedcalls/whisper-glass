import XCTest
@testable import WhisperGlassCore

final class VoiceActivityDetectorTests: XCTestCase {

    // MARK: - Silence detection

    func testSilenceReturnsInactive() {
        let detector = VoiceActivityDetector(threshold: 0.01, hysteresisDuration: 0)

        let silence = [Float](repeating: 0.0, count: 1600)
        let result = detector.isVoiceActive(in: silence)

        XCTAssertFalse(result, "Zero samples should not trigger voice detection")
    }

    func testEmptySamplesReturnInactive() {
        let detector = VoiceActivityDetector(threshold: 0.01, hysteresisDuration: 0)

        let result = detector.isVoiceActive(in: [])

        XCTAssertFalse(result, "Empty samples should not trigger voice detection")
    }

    // MARK: - Loud samples

    func testLoudSamplesAboveThresholdReturnActive() {
        let threshold: Float = 0.01
        let detector = VoiceActivityDetector(threshold: threshold, hysteresisDuration: 0)

        // Samples well above threshold
        let loud = [Float](repeating: 0.5, count: 1600)
        let result = detector.isVoiceActive(in: loud)

        XCTAssertTrue(result, "Loud samples should trigger voice detection")
    }

    // MARK: - Below threshold

    func testSamplesJustBelowThresholdReturnInactive() {
        let threshold: Float = 0.1
        let detector = VoiceActivityDetector(threshold: threshold, hysteresisDuration: 0)

        // RMS of constant value 0.05 = 0.05, which is below 0.1
        let quiet = [Float](repeating: 0.05, count: 1600)
        let result = detector.isVoiceActive(in: quiet)

        XCTAssertFalse(result, "Samples with RMS below threshold should not trigger detection")
    }

    // MARK: - Hysteresis

    func testHysteresisKeepsActiveAfterBriefSilence() {
        let sampleRate: Double = 16_000
        let hysteresisDuration: TimeInterval = 0.5
        let detector = VoiceActivityDetector(
            threshold: 0.01,
            hysteresisDuration: hysteresisDuration,
            sampleRate: sampleRate
        )

        // First: send loud samples (0.1s worth = 1600 samples)
        let loud = [Float](repeating: 0.5, count: 1600)
        let voiceResult = detector.isVoiceActive(in: loud)
        XCTAssertTrue(voiceResult, "Loud samples should activate voice detection")

        // Then: send silent samples for less than hysteresis duration
        // 0.2s worth = 3200 samples, still within 0.5s hysteresis
        let shortSilence = [Float](repeating: 0.0, count: 3200)
        let hysteresisResult = detector.isVoiceActive(in: shortSilence)
        XCTAssertTrue(hysteresisResult, "Hysteresis should keep detector active during brief silence")
    }

    func testHysteresisExpiresAfterSufficientSilence() {
        let sampleRate: Double = 16_000
        let hysteresisDuration: TimeInterval = 0.1
        let detector = VoiceActivityDetector(
            threshold: 0.01,
            hysteresisDuration: hysteresisDuration,
            sampleRate: sampleRate
        )

        // First: send loud samples (0.1s worth)
        let loud = [Float](repeating: 0.5, count: 1600)
        _ = detector.isVoiceActive(in: loud)

        // Then: send enough silence to exceed hysteresis (0.3s >> 0.1s)
        let longSilence = [Float](repeating: 0.0, count: 4800)
        let result = detector.isVoiceActive(in: longSilence)
        XCTAssertFalse(result, "Detector should deactivate after silence exceeds hysteresis duration")
    }

    // MARK: - Custom threshold

    func testCustomThresholdWorksCorrectly() {
        let highThreshold: Float = 0.5
        let detector = VoiceActivityDetector(threshold: highThreshold, hysteresisDuration: 0)

        // Moderate volume — above default threshold but below custom threshold
        let moderate = [Float](repeating: 0.3, count: 1600)
        let result = detector.isVoiceActive(in: moderate)

        XCTAssertFalse(result, "Moderate samples should not exceed high custom threshold")

        // Very loud — above custom threshold
        let veryLoud = [Float](repeating: 0.8, count: 1600)
        let loudResult = detector.isVoiceActive(in: veryLoud)

        XCTAssertTrue(loudResult, "Very loud samples should exceed even a high threshold")
    }

    // MARK: - RMS calculation

    func testCalculateRMSWithKnownValues() {
        // RMS of [3, 4] = sqrt((9 + 16) / 2) = sqrt(12.5) ≈ 3.5355
        let rms = VoiceActivityDetector.calculateRMS([3.0, 4.0])
        XCTAssertEqual(rms, sqrt(12.5), accuracy: 0.0001)
    }

    func testCalculateRMSOfEmptyArrayReturnsZero() {
        let rms = VoiceActivityDetector.calculateRMS([])
        XCTAssertEqual(rms, 0.0)
    }

    func testCalculateRMSOfUniformSignal() {
        // RMS of constant value c = c
        let constant: Float = 0.25
        let samples = [Float](repeating: constant, count: 100)
        let rms = VoiceActivityDetector.calculateRMS(samples)
        XCTAssertEqual(rms, constant, accuracy: 0.0001)
    }

    // MARK: - Reset

    func testResetClearsState() {
        let detector = VoiceActivityDetector(
            threshold: 0.01,
            hysteresisDuration: 1.0,
            sampleRate: 16_000
        )

        // Activate detector
        let loud = [Float](repeating: 0.5, count: 1600)
        _ = detector.isVoiceActive(in: loud)

        // Reset
        detector.reset()

        // Now silence should immediately return false (no hysteresis carryover)
        let silence = [Float](repeating: 0.0, count: 1600)
        let result = detector.isVoiceActive(in: silence)
        XCTAssertFalse(result, "After reset, silence should return inactive")
    }
}
