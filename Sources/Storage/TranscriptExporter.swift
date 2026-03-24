import Foundation
import os

/// Exports transcript sessions to various file formats.
public struct TranscriptExporter: Sendable {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "TranscriptExporter"
    )

    // MARK: - Plain Text

    /// Exports a session as plain text with timestamps, one segment per line.
    public static func exportAsText(_ session: TranscriptSession) -> String {
        guard !session.segments.isEmpty else { return "" }

        return session.segments
            .map { segment in
                let start = formatTimestamp(segment.startTime, includeMillis: false)
                let end = formatTimestamp(segment.endTime, includeMillis: false)
                return "[\(start) --> \(end)] \(segment.text)"
            }
            .joined(separator: "\n")
    }

    // MARK: - SRT (SubRip)

    /// Exports a session in SRT subtitle format.
    public static func exportAsSRT(_ session: TranscriptSession) -> String {
        guard !session.segments.isEmpty else { return "" }

        return session.segments
            .enumerated()
            .map { index, segment in
                let sequenceNumber = index + 1
                let start = formatSRTTimestamp(segment.startTime)
                let end = formatSRTTimestamp(segment.endTime)
                return "\(sequenceNumber)\n\(start) --> \(end)\n\(segment.text)"
            }
            .joined(separator: "\n\n")
    }

    // MARK: - JSON

    /// Exports a session as pretty-printed JSON data.
    public static func exportAsJSON(_ session: TranscriptSession) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(session)
        } catch {
            throw StorageError.encodingFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - File Writing

    /// Writes string content to a file and returns the file URL.
    @discardableResult
    public static func writeToFile(
        _ content: String,
        filename: String,
        in directory: URL
    ) throws -> URL {
        let fileURL = directory.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw StorageError.saveFailed(underlying: error.localizedDescription)
        }

        logger.info("Exported to \(fileURL.lastPathComponent)")
        return fileURL
    }

    // MARK: - Timestamp Formatting

    /// Formats seconds as HH:MM:SS for plain text export.
    private static func formatTimestamp(
        _ seconds: TimeInterval,
        includeMillis: Bool
    ) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if includeMillis {
            let millis = Int((seconds - Double(totalSeconds)) * 1000)
            return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    /// Formats seconds as HH:MM:SS,mmm for SRT format.
    private static func formatSRTTimestamp(_ seconds: TimeInterval) -> String {
        formatTimestamp(seconds, includeMillis: true)
    }
}
