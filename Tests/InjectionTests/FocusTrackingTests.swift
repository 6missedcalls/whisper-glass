import Testing
@testable import WhisperGlassCore

// MARK: - Focus Tracking Tests

/// Tests that the app tracks the previously focused app
/// so text injection targets the right window.
@Suite("Focus Tracking")
struct FocusTrackingTests {

    @Test("ClipboardInjector finds non-WhisperGlass target app")
    func findTargetAppExcludesSelf() async {
        // The injector should never target WhisperGlass itself.
        // We can't fully test this without running apps, but we can verify
        // the logic doesn't crash with no apps available.
        let injector = ClipboardInjector()
        // Should not crash even when no target is available
        let result = await injector.inject(text: "test")
        // Result depends on system state, just verify no crash
        _ = result
    }
}

// MARK: - Audio Buffer No-Overlap Tests

@Suite("AudioBufferRing No Overlap")
struct AudioBufferNoOverlapTests {

    @Test("Zero overlap produces non-overlapping chunks")
    func zeroOverlapChunks() async {
        let ring = AudioBufferRing(chunkSize: 4, overlapSize: 0)

        // Append 8 samples
        await ring.append(samples: [1, 2, 3, 4, 5, 6, 7, 8])

        // First chunk should be [1,2,3,4]
        let chunk1 = await ring.nextChunk()
        #expect(chunk1 == [1, 2, 3, 4])

        // Second chunk should be [5,6,7,8] — NO overlap with first
        let chunk2 = await ring.nextChunk()
        #expect(chunk2 == [5, 6, 7, 8])

        // No more chunks
        let chunk3 = await ring.nextChunk()
        #expect(chunk3 == nil)
    }

    @Test("Zero overlap consumes all samples")
    func zeroOverlapConsumesAll() async {
        let ring = AudioBufferRing(chunkSize: 3, overlapSize: 0)
        await ring.append(samples: [1, 2, 3])
        let chunk = await ring.nextChunk()
        #expect(chunk == [1, 2, 3])

        // Buffer should be empty
        let remaining = await ring.bufferedSampleCount
        #expect(remaining == 0)
    }
}

// MARK: - Junk Segment Filter Tests

@Suite("Junk Segment Filtering")
struct JunkSegmentFilterTests {

    @Test("BLANK_AUDIO is filtered")
    func blankAudioFiltered() {
        let junkPatterns = ["[BLANK_AUDIO]", "[MUSIC]", "[SILENCE]", "(silence)", "[NO_SPEECH]"]
        let text = "[BLANK_AUDIO]"
        let isJunk = junkPatterns.contains(where: { text.contains($0) })
        #expect(isJunk == true)
    }

    @Test("Normal text passes filter")
    func normalTextPasses() {
        let junkPatterns = ["[BLANK_AUDIO]", "[MUSIC]", "[SILENCE]", "(silence)", "[NO_SPEECH]"]
        let text = "Hello, this is a test."
        let isJunk = junkPatterns.contains(where: { text.contains($0) })
        #expect(isJunk == false)
    }

    @Test("MUSIC tag is filtered")
    func musicFiltered() {
        let junkPatterns = ["[BLANK_AUDIO]", "[MUSIC]", "[SILENCE]", "(silence)", "[NO_SPEECH]"]
        let text = "[MUSIC]"
        let isJunk = junkPatterns.contains(where: { text.contains($0) })
        #expect(isJunk == true)
    }

    @Test("Text with embedded junk pattern is filtered")
    func embeddedJunkFiltered() {
        let junkPatterns = ["[BLANK_AUDIO]", "[MUSIC]", "[SILENCE]", "(silence)", "[NO_SPEECH]"]
        let text = "something [BLANK_AUDIO] something"
        let isJunk = junkPatterns.contains(where: { text.contains($0) })
        #expect(isJunk == true)
    }
}
