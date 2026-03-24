import Foundation
import Testing
@testable import WhisperGlassCore

@Suite("SegmentMerger")
struct SegmentMergerTests {

    // MARK: - Helpers

    private func makeSegment(
        text: String = "test",
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double = 1.0,
        language: String = "en"
    ) -> TranscriptSegment {
        TranscriptSegment(
            text: text,
            startTime: start,
            endTime: end,
            confidence: confidence,
            language: language,
            isFinal: true
        )
    }

    // MARK: - No Overlap

    @Test("Non-overlapping segments are all preserved")
    func noOverlapReturnsAllSegments() {
        let existing = [
            makeSegment(text: "Hello", start: 0.0, end: 1.0),
            makeSegment(text: "world", start: 1.5, end: 2.5)
        ]
        let incoming = [
            makeSegment(text: "foo", start: 3.0, end: 4.0),
            makeSegment(text: "bar", start: 5.0, end: 6.0)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: incoming)

        #expect(result.count == 4)
        #expect(result[0].text == "Hello")
        #expect(result[1].text == "world")
        #expect(result[2].text == "foo")
        #expect(result[3].text == "bar")
    }

    // MARK: - Full Overlap / Deduplication

    @Test("Full overlap deduplicates to single segment")
    func fullOverlapDeduplicates() {
        let existing = [
            makeSegment(text: "Hello", start: 0.0, end: 2.0, confidence: 0.8)
        ]
        let incoming = [
            makeSegment(text: "Hello world", start: 0.0, end: 2.0, confidence: 0.95)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].text == "Hello world")
        #expect(result[0].confidence == 0.95)
    }

    // MARK: - Partial Overlap

    @Test("Partial overlap merges correctly with higher confidence winning")
    func partialOverlapHigherConfidenceWins() {
        // Segment A: 1.0 - 3.0 (duration 2.0)
        // Segment B: 1.5 - 3.5 (duration 2.0)
        // Overlap: 1.5 - 3.0 = 1.5s, ratio = 1.5/2.0 = 0.75 > 0.5 threshold
        let existing = [
            makeSegment(text: "low conf", start: 1.0, end: 3.0, confidence: 0.7)
        ]
        let incoming = [
            makeSegment(text: "high conf", start: 1.5, end: 3.5, confidence: 0.9)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].text == "high conf")
        #expect(result[0].confidence == 0.9)
    }

    @Test("Partial overlap keeps existing when it has higher confidence")
    func partialOverlapExistingWinsWithHigherConfidence() {
        let existing = [
            makeSegment(text: "existing", start: 1.0, end: 3.0, confidence: 0.95)
        ]
        let incoming = [
            makeSegment(text: "incoming", start: 1.5, end: 3.5, confidence: 0.8)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].text == "existing")
        #expect(result[0].confidence == 0.95)
    }

    // MARK: - Empty Inputs

    @Test("Empty existing returns incoming")
    func emptyExistingReturnsIncoming() {
        let incoming = [
            makeSegment(text: "hello", start: 0.0, end: 1.0)
        ]

        let result = SegmentMerger.merge(existing: [], incoming: incoming)

        #expect(result.count == 1)
        #expect(result[0].text == "hello")
    }

    @Test("Empty incoming returns existing")
    func emptyIncomingReturnsExisting() {
        let existing = [
            makeSegment(text: "hello", start: 0.0, end: 1.0)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: [])

        #expect(result.count == 1)
        #expect(result[0].text == "hello")
    }

    @Test("Both empty returns empty")
    func bothEmptyReturnsEmpty() {
        let result = SegmentMerger.merge(existing: [], incoming: [])
        #expect(result.isEmpty)
    }

    // MARK: - Sort Order

    @Test("Result is sorted by startTime after merge")
    func resultSortedByStartTime() {
        let existing = [
            makeSegment(text: "second", start: 2.0, end: 3.0)
        ]
        let incoming = [
            makeSegment(text: "first", start: 0.0, end: 1.0),
            makeSegment(text: "third", start: 4.0, end: 5.0)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: incoming)

        #expect(result.count == 3)
        #expect(result[0].text == "first")
        #expect(result[1].text == "second")
        #expect(result[2].text == "third")
        #expect(result[0].startTime < result[1].startTime)
        #expect(result[1].startTime < result[2].startTime)
    }

    // MARK: - Adjacent Non-Overlapping

    @Test("Adjacent but non-overlapping segments are preserved")
    func adjacentNonOverlappingPreserved() {
        let existing = [
            makeSegment(text: "first", start: 0.0, end: 1.0)
        ]
        let incoming = [
            makeSegment(text: "second", start: 1.0, end: 2.0)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: incoming)

        #expect(result.count == 2)
        #expect(result[0].text == "first")
        #expect(result[1].text == "second")
    }

    // MARK: - Below Threshold

    @Test("Overlap below threshold does not merge")
    func belowThresholdNoMerge() {
        // Segment A: 0.0 - 2.0 (duration 2.0)
        // Segment B: 1.5 - 4.0 (duration 2.5)
        // Overlap: 1.5 - 2.0 = 0.5s, ratio = 0.5/2.0 = 0.25 < 0.5 threshold
        let existing = [
            makeSegment(text: "first", start: 0.0, end: 2.0)
        ]
        let incoming = [
            makeSegment(text: "second", start: 1.5, end: 4.0)
        ]

        let result = SegmentMerger.merge(existing: existing, incoming: incoming)

        #expect(result.count == 2)
    }
}
