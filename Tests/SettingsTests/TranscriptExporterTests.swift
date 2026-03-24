import Testing
import Foundation
@testable import WhisperGlassCore

@Suite("TranscriptExporter")
struct TranscriptExporterTests {

    // MARK: - Test Fixtures

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func makeSegment(
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) -> TranscriptSegment {
        TranscriptSegment(
            id: UUID(),
            text: text,
            startTime: startTime,
            endTime: endTime,
            confidence: 0.95,
            language: "en",
            createdAt: fixedDate,
            isFinal: true
        )
    }

    private static func makeSession(
        segments: [TranscriptSegment] = []
    ) -> TranscriptSession {
        TranscriptSession(
            id: UUID(),
            segments: segments,
            startedAt: fixedDate,
            endedAt: fixedDate.addingTimeInterval(60)
        )
    }

    private static let sampleSegments: [TranscriptSegment] = [
        makeSegment(text: "Hello world", startTime: 0.0, endTime: 2.5),
        makeSegment(text: "How are you today", startTime: 3.0, endTime: 5.75),
        makeSegment(text: "I am fine", startTime: 6.0, endTime: 8.0),
    ]

    // MARK: - Plain Text Export

    @Test("exportAsText produces correct format with timestamps")
    func exportAsTextFormat() {
        let session = Self.makeSession(segments: Self.sampleSegments)
        let result = TranscriptExporter.exportAsText(session)

        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "[00:00:00 --> 00:00:02] Hello world")
        #expect(lines[1] == "[00:00:03 --> 00:00:05] How are you today")
        #expect(lines[2] == "[00:00:06 --> 00:00:08] I am fine")
    }

    @Test("exportAsText handles hour-length timestamps")
    func exportAsTextLongTimestamp() {
        let segment = Self.makeSegment(
            text: "Long recording",
            startTime: 3661.5,
            endTime: 3725.0
        )
        let session = Self.makeSession(segments: [segment])
        let result = TranscriptExporter.exportAsText(session)

        #expect(result == "[01:01:01 --> 01:02:05] Long recording")
    }

    @Test("exportAsText empty session returns empty string")
    func exportAsTextEmpty() {
        let session = Self.makeSession(segments: [])
        let result = TranscriptExporter.exportAsText(session)
        #expect(result == "")
    }

    // MARK: - SRT Export

    @Test("exportAsSRT produces valid SRT format")
    func exportAsSRTFormat() {
        let session = Self.makeSession(segments: Self.sampleSegments)
        let result = TranscriptExporter.exportAsSRT(session)

        let blocks = result.components(separatedBy: "\n\n")
        #expect(blocks.count == 3)

        // First block
        let firstLines = blocks[0].split(separator: "\n", omittingEmptySubsequences: false)
        #expect(firstLines.count == 3)
        #expect(firstLines[0] == "1")
        #expect(firstLines[1] == "00:00:00,000 --> 00:00:02,500")
        #expect(firstLines[2] == "Hello world")

        // Second block
        let secondLines = blocks[1].split(separator: "\n", omittingEmptySubsequences: false)
        #expect(secondLines.count == 3)
        #expect(secondLines[0] == "2")
        #expect(secondLines[1] == "00:00:03,000 --> 00:00:05,750")
        #expect(secondLines[2] == "How are you today")

        // Third block
        let thirdLines = blocks[2].split(separator: "\n", omittingEmptySubsequences: false)
        #expect(thirdLines.count == 3)
        #expect(thirdLines[0] == "3")
        #expect(thirdLines[1] == "00:00:06,000 --> 00:00:08,000")
        #expect(thirdLines[2] == "I am fine")
    }

    @Test("exportAsSRT sequential numbering starts at 1")
    func exportAsSRTSequenceNumbers() {
        let session = Self.makeSession(segments: Self.sampleSegments)
        let result = TranscriptExporter.exportAsSRT(session)

        let blocks = result.components(separatedBy: "\n\n")
        for (index, block) in blocks.enumerated() {
            let firstLine = block.split(separator: "\n").first
            #expect(firstLine == Substring("\(index + 1)"))
        }
    }

    @Test("exportAsSRT empty session returns empty string")
    func exportAsSRTEmpty() {
        let session = Self.makeSession(segments: [])
        let result = TranscriptExporter.exportAsSRT(session)
        #expect(result == "")
    }

    @Test("exportAsSRT timestamp format is HH:MM:SS,mmm")
    func exportAsSRTTimestampFormat() {
        let segment = Self.makeSegment(
            text: "Test",
            startTime: 3723.456,
            endTime: 3725.789
        )
        let session = Self.makeSession(segments: [segment])
        let result = TranscriptExporter.exportAsSRT(session)
        let lines = result.split(separator: "\n")

        #expect(lines[1] == "01:02:03,456 --> 01:02:05,789")
    }

    // MARK: - JSON Export

    @Test("exportAsJSON produces valid decodable JSON")
    func exportAsJSONDecodable() throws {
        let session = Self.makeSession(segments: Self.sampleSegments)
        let data = try TranscriptExporter.exportAsJSON(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TranscriptSession.self, from: data)

        #expect(decoded.id == session.id)
        #expect(decoded.segments.count == session.segments.count)
        #expect(decoded.startedAt == session.startedAt)
    }

    @Test("exportAsJSON preserves segment data")
    func exportAsJSONPreservesSegments() throws {
        let session = Self.makeSession(segments: Self.sampleSegments)
        let data = try TranscriptExporter.exportAsJSON(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TranscriptSession.self, from: data)

        for (original, decoded) in zip(session.segments, decoded.segments) {
            #expect(original.text == decoded.text)
            #expect(original.startTime == decoded.startTime)
            #expect(original.endTime == decoded.endTime)
            #expect(original.confidence == decoded.confidence)
        }
    }

    @Test("exportAsJSON empty session produces valid JSON")
    func exportAsJSONEmpty() throws {
        let session = Self.makeSession(segments: [])
        let data = try TranscriptExporter.exportAsJSON(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TranscriptSession.self, from: data)

        #expect(decoded.segments.isEmpty)
    }

    // MARK: - Multiple Segments Ordering

    @Test("Exports preserve segment order")
    func exportsPreserveOrder() {
        let session = Self.makeSession(segments: Self.sampleSegments)

        let textResult = TranscriptExporter.exportAsText(session)
        let textLines = textResult.split(separator: "\n")
        #expect(textLines[0].contains("Hello world"))
        #expect(textLines[1].contains("How are you today"))
        #expect(textLines[2].contains("I am fine"))

        let srtResult = TranscriptExporter.exportAsSRT(session)
        let srtBlocks = srtResult.components(separatedBy: "\n\n")
        #expect(srtBlocks[0].contains("Hello world"))
        #expect(srtBlocks[1].contains("How are you today"))
        #expect(srtBlocks[2].contains("I am fine"))
    }

    // MARK: - File Writing

    @Test("writeToFile creates file and returns URL")
    func writeToFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let content = "Test content"
        let url = try TranscriptExporter.writeToFile(
            content,
            filename: "test.txt",
            in: tempDir
        )

        #expect(FileManager.default.fileExists(atPath: url.path))
        let read = try String(contentsOf: url, encoding: .utf8)
        #expect(read == content)
    }
}
