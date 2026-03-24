import Foundation
import os

/// Deduplicates and merges overlapping transcript segments from sliding-window audio chunks.
///
/// When Whisper processes overlapping audio windows, the resulting segments may partially
/// or fully overlap in time. `SegmentMerger` detects these overlaps and produces a clean,
/// deduplicated segment list sorted by start time.
public enum SegmentMerger {

    private static let logger = Logger(
        subsystem: "com.whisper-glass.transcription",
        category: "SegmentMerger"
    )

    /// Minimum overlap ratio (relative to the shorter segment's duration) to trigger a merge.
    private static let overlapThreshold: Double = 0.5

    /// Merges new segments into an existing list, deduplicating overlaps.
    ///
    /// - Parameters:
    ///   - existing: Previously committed segments, sorted by startTime.
    ///   - incoming: Newly transcribed segments from the latest audio chunk.
    /// - Returns: A merged, deduplicated list sorted by startTime.
    public static func merge(
        existing: [TranscriptSegment],
        incoming: [TranscriptSegment]
    ) -> [TranscriptSegment] {
        guard !existing.isEmpty else {
            return sortedByStartTime(incoming)
        }
        guard !incoming.isEmpty else {
            return sortedByStartTime(existing)
        }

        var result = existing
        for newSegment in incoming {
            let overlapIndex = findOverlappingIndex(in: result, for: newSegment)
            if let index = overlapIndex {
                let existingSegment = result[index]
                let merged = resolveOverlap(existing: existingSegment, incoming: newSegment)
                result = replaced(in: result, at: index, with: merged)
                logger.debug("Merged segment at index \(index): \"\(merged.text)\"")
            } else {
                result = result + [newSegment]
            }
        }

        return sortedByStartTime(result)
    }

    // MARK: - Private Helpers

    /// Finds the index of the first segment in `segments` that overlaps with `target`
    /// beyond the overlap threshold.
    private static func findOverlappingIndex(
        in segments: [TranscriptSegment],
        for target: TranscriptSegment
    ) -> Int? {
        for (index, segment) in segments.enumerated() {
            if isOverlapping(segment, target) {
                return index
            }
        }
        return nil
    }

    /// Determines whether two segments overlap by more than the threshold.
    private static func isOverlapping(
        _ a: TranscriptSegment,
        _ b: TranscriptSegment
    ) -> Bool {
        let overlapStart = max(a.startTime, b.startTime)
        let overlapEnd = min(a.endTime, b.endTime)
        let overlapDuration = overlapEnd - overlapStart

        guard overlapDuration > 0 else { return false }

        let shorterDuration = min(a.duration, b.duration)
        guard shorterDuration > 0 else { return false }

        let overlapRatio = overlapDuration / shorterDuration
        return overlapRatio > overlapThreshold
    }

    /// Resolves an overlap between two segments, preferring the one with higher confidence.
    private static func resolveOverlap(
        existing: TranscriptSegment,
        incoming: TranscriptSegment
    ) -> TranscriptSegment {
        if incoming.confidence > existing.confidence {
            return incoming
        }
        return existing
    }

    /// Returns a new array with the element at `index` replaced by `newElement`.
    private static func replaced(
        in array: [TranscriptSegment],
        at index: Int,
        with newElement: TranscriptSegment
    ) -> [TranscriptSegment] {
        var copy = array
        copy[index] = newElement
        return copy
    }

    /// Returns segments sorted by startTime.
    private static func sortedByStartTime(
        _ segments: [TranscriptSegment]
    ) -> [TranscriptSegment] {
        segments.sorted { $0.startTime < $1.startTime }
    }
}
