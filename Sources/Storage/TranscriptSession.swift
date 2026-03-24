import Foundation

/// A complete transcript session containing one or more segments.
public struct TranscriptSession: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let segments: [TranscriptSegment]
    public let startedAt: Date
    public let endedAt: Date?

    public init(
        id: UUID = UUID(),
        segments: [TranscriptSegment] = [],
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.id = id
        self.segments = segments
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Returns a new session with the given segments appended.
    public func appendingSegments(_ newSegments: [TranscriptSegment]) -> TranscriptSession {
        TranscriptSession(
            id: id,
            segments: segments + newSegments,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    /// Returns a new session marked as ended at the given date.
    public func ended(at date: Date = Date()) -> TranscriptSession {
        TranscriptSession(
            id: id,
            segments: segments,
            startedAt: startedAt,
            endedAt: date
        )
    }

    /// Total duration from first segment start to last segment end.
    public var duration: TimeInterval? {
        guard let first = segments.first, let last = segments.last else {
            return nil
        }
        return last.endTime - first.startTime
    }

    /// Combined text of all segments.
    public var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }
}
