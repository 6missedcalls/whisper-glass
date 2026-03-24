import Foundation
import Testing
@testable import WhisperGlassCore

@Suite("TranscriptionEngine State Machine")
struct TranscriptionEngineTests {

    // MARK: - Helpers

    private func makeEngine() -> TranscriptionEngine {
        TranscriptionEngine()
    }

    // MARK: - Initial State

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let engine = makeEngine()
        #expect(engine.state == .idle)
    }

    @Test("Initial segments are empty")
    func initialSegmentsAreEmpty() {
        let engine = makeEngine()
        #expect(engine.segments.isEmpty)
    }

    @Test("Initial partial text is empty")
    func initialPartialTextIsEmpty() {
        let engine = makeEngine()
        #expect(engine.partialText.isEmpty)
    }

    @Test("Initial language is English")
    func initialLanguageIsEnglish() {
        let engine = makeEngine()
        #expect(engine.currentLanguage == "en")
    }

    // MARK: - start()

    @Test("start() transitions from idle to listening")
    func startMovesToListening() throws {
        let engine = makeEngine()
        try engine.start()
        #expect(engine.state == .listening)
    }

    @Test("start() throws when not idle")
    func startThrowsWhenNotIdle() throws {
        let engine = makeEngine()
        try engine.start()
        // Now in listening state, starting again should throw
        #expect(throws: TranscriptionError.self) {
            try engine.start()
        }
    }

    // MARK: - pause()

    @Test("pause() transitions from listening to paused")
    func pauseFromListening() throws {
        let engine = makeEngine()
        try engine.start()
        try engine.pause()
        #expect(engine.state == .paused)
    }

    @Test("pause() throws when idle")
    func pauseThrowsWhenIdle() {
        let engine = makeEngine()
        #expect(throws: TranscriptionError.self) {
            try engine.pause()
        }
    }

    @Test("pause() throws when already paused")
    func pauseThrowsWhenAlreadyPaused() throws {
        let engine = makeEngine()
        try engine.start()
        try engine.pause()
        #expect(throws: TranscriptionError.self) {
            try engine.pause()
        }
    }

    // MARK: - resume()

    @Test("resume() transitions from paused to listening")
    func resumeFromPaused() throws {
        let engine = makeEngine()
        try engine.start()
        try engine.pause()
        try engine.resume()
        #expect(engine.state == .listening)
    }

    @Test("resume() throws when idle")
    func resumeThrowsWhenIdle() {
        let engine = makeEngine()
        #expect(throws: TranscriptionError.self) {
            try engine.resume()
        }
    }

    @Test("resume() throws when listening")
    func resumeThrowsWhenListening() throws {
        let engine = makeEngine()
        try engine.start()
        #expect(throws: TranscriptionError.self) {
            try engine.resume()
        }
    }

    // MARK: - stop()

    @Test("stop() moves to idle from listening")
    func stopFromListening() throws {
        let engine = makeEngine()
        try engine.start()
        engine.stop()
        #expect(engine.state == .idle)
    }

    @Test("stop() moves to idle from paused")
    func stopFromPaused() throws {
        let engine = makeEngine()
        try engine.start()
        try engine.pause()
        engine.stop()
        #expect(engine.state == .idle)
    }

    @Test("stop() is safe when already idle")
    func stopWhenIdle() {
        let engine = makeEngine()
        engine.stop()
        #expect(engine.state == .idle)
    }

    @Test("stop() clears partial text")
    func stopClearsPartialText() throws {
        let engine = makeEngine()
        try engine.start()
        engine.stop()
        #expect(engine.partialText.isEmpty)
    }

    // MARK: - clearSegments()

    @Test("clearSegments() empties the segments array")
    func clearSegmentsEmptiesArray() throws {
        let engine = makeEngine()
        engine.clearSegments()
        #expect(engine.segments.isEmpty)
    }

    @Test("clearSegments() clears partial text")
    func clearSegmentsClearsPartialText() {
        let engine = makeEngine()
        engine.clearSegments()
        #expect(engine.partialText.isEmpty)
    }

    // MARK: - setLanguage()

    @Test("setLanguage() updates current language")
    func setLanguageUpdatesCurrentLanguage() {
        let engine = makeEngine()
        engine.setLanguage("es")
        #expect(engine.currentLanguage == "es")
    }

    // MARK: - Full Lifecycle

    @Test("Full lifecycle: idle -> listening -> paused -> listening -> idle")
    func fullLifecycle() throws {
        let engine = makeEngine()
        #expect(engine.state == .idle)

        try engine.start()
        #expect(engine.state == .listening)

        try engine.pause()
        #expect(engine.state == .paused)

        try engine.resume()
        #expect(engine.state == .listening)

        engine.stop()
        #expect(engine.state == .idle)
    }
}
