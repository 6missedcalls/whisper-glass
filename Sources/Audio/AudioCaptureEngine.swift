import AVFoundation
import Foundation
import os

/// Wraps AVAudioEngine to capture microphone input and produce a stream of
/// 16kHz mono Float32 audio buffers suitable for Whisper transcription.
///
/// Uses `AsyncStream` to deliver audio buffers and handles format conversion
/// and audio configuration changes gracefully.
@Observable
public final class AudioCaptureEngine {
    private static let logger = Logger(
        subsystem: "com.whisper-glass.audio",
        category: "AudioCaptureEngine"
    )

    // MARK: - Observable state

    public private(set) var isRunning: Bool = false
    public private(set) var currentSampleRate: Double = AudioConstants.whisperSampleRate

    // MARK: - Private engine state

    private var engine: AVAudioEngine?
    private var continuation: AsyncStream<[Float]>.Continuation?
    private var configChangeObserver: NSObjectProtocol?

    public init() {}

    deinit {
        removeObservers()
        stopEngine()
    }

    // MARK: - Public API

    /// Starts capturing audio and returns an async stream of Float32 sample buffers.
    ///
    /// Each buffer is converted to 16kHz mono Float32 format regardless of hardware
    /// sample rate. The stream finishes when `stop()` is called or an error occurs.
    ///
    /// - Throws: `AudioError` if the engine cannot be started.
    /// - Returns: An `AsyncStream` of Float32 audio sample arrays.
    public func startCapture() throws -> AsyncStream<[Float]> {
        stopEngine()

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode

        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        guard hardwareFormat.channelCount > 0 else {
            throw AudioError.noInputNode
        }

        currentSampleRate = hardwareFormat.sampleRate

        let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioConstants.whisperSampleRate,
            channels: AudioConstants.channelCount,
            interleaved: false
        )

        guard let targetFormat = whisperFormat else {
            throw AudioError.formatConversionFailed
        }

        let needsConversion = hardwareFormat.sampleRate != AudioConstants.whisperSampleRate
            || hardwareFormat.channelCount != AudioConstants.channelCount

        var converter: AVAudioConverter?
        if needsConversion {
            converter = AVAudioConverter(from: hardwareFormat, to: targetFormat)
            guard converter != nil else {
                throw AudioError.formatConversionFailed
            }
        }

        let stream = AsyncStream<[Float]> { [weak self] continuation in
            self?.continuation = continuation

            continuation.onTermination = { @Sendable _ in
                Self.logger.debug("Audio stream terminated")
            }
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: AudioConstants.tapBufferSize,
            format: hardwareFormat
        ) { [weak self] buffer, _ in
            self?.handleAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioError.engineStartFailed(underlying: error.localizedDescription)
        }

        engine = audioEngine
        isRunning = true
        setupObservers()

        Self.logger.info(
            "Capture started: hardware=\(hardwareFormat.sampleRate)Hz, channels=\(hardwareFormat.channelCount), needsConversion=\(needsConversion)"
        )

        return stream
    }

    /// Stops the audio capture engine and finishes the async stream.
    public func stop() {
        stopEngine()
        Self.logger.info("Capture stopped by caller")
    }

    /// Pauses audio capture without tearing down the engine.
    public func pause() {
        engine?.pause()
        isRunning = false
        Self.logger.info("Capture paused")
    }

    /// Resumes a previously paused capture session.
    ///
    /// - Throws: `AudioError` if the engine fails to restart.
    public func resume() throws {
        guard let audioEngine = engine else {
            throw AudioError.engineStartFailed(underlying: "No engine to resume")
        }

        do {
            try audioEngine.start()
            isRunning = true
            Self.logger.info("Capture resumed")
        } catch {
            throw AudioError.engineStartFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    private func handleAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter?,
        targetFormat: AVAudioFormat
    ) {
        guard let samples = extractSamples(
            from: buffer,
            converter: converter,
            targetFormat: targetFormat
        ) else {
            return
        }

        continuation?.yield(samples)
    }

    private func extractSamples(
        from buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter?,
        targetFormat: AVAudioFormat
    ) -> [Float]? {
        if let converter = converter {
            return convertBuffer(buffer, using: converter, targetFormat: targetFormat)
        }
        return directExtract(from: buffer)
    }

    private func directExtract(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        return samples
    }

    private func convertBuffer(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> [Float]? {
        let ratio = targetFormat.sampleRate / converter.inputFormat.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: estimatedFrames
        ) else {
            Self.logger.error("Failed to allocate conversion buffer")
            return nil
        }

        var inputConsumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        var conversionError: NSError?
        let status = converter.convert(
            to: convertedBuffer,
            error: &conversionError,
            withInputFrom: inputBlock
        )

        guard status != .error else {
            Self.logger.error(
                "Conversion failed: \(conversionError?.localizedDescription ?? "unknown")"
            )
            return nil
        }

        guard let channelData = convertedBuffer.floatChannelData else { return nil }
        let frameCount = Int(convertedBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
    }

    private func stopEngine() {
        if let audioEngine = engine {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        engine = nil
        continuation?.finish()
        continuation = nil
        isRunning = false
        removeObservers()
    }

    // MARK: - Notification observers (macOS)

    private func setupObservers() {
        let center = NotificationCenter.default

        // On macOS, AVAudioEngine posts configurationChange when the audio
        // hardware configuration changes (device connected/disconnected,
        // sample rate change, etc.).
        configChangeObserver = center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        if let observer = configChangeObserver {
            center.removeObserver(observer)
            configChangeObserver = nil
        }
    }

    private func handleConfigurationChange() {
        Self.logger.warning("Audio engine configuration changed")

        // The engine is automatically stopped on configuration changes.
        // Attempt to restart with the new configuration.
        isRunning = false

        guard let audioEngine = engine else { return }

        do {
            try audioEngine.start()
            isRunning = true
            Self.logger.info("Audio engine restarted after configuration change")
        } catch {
            Self.logger.error("Failed to restart engine: \(error.localizedDescription)")
            stopEngine()
        }
    }
}
