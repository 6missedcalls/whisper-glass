import Foundation

/// A single transcribed segment with timing and confidence metadata.
public struct TranscriptSegment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Double
    public let language: String
    public let createdAt: Date
    public let isFinal: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double = 1.0,
        language: String = "en",
        createdAt: Date = Date(),
        isFinal: Bool = true
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.language = language
        self.createdAt = createdAt
        self.isFinal = isFinal
    }

    /// Duration of this segment in seconds.
    public var duration: TimeInterval {
        endTime - startTime
    }

    /// Returns a new segment with updated text, preserving all other fields.
    public func withText(_ newText: String) -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            text: newText,
            startTime: startTime,
            endTime: endTime,
            confidence: confidence,
            language: language,
            createdAt: createdAt,
            isFinal: isFinal
        )
    }

    /// Returns a new segment marked as final.
    public func finalized() -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            text: text,
            startTime: startTime,
            endTime: endTime,
            confidence: confidence,
            language: language,
            createdAt: createdAt,
            isFinal: true
        )
    }
}
