import XCTest
@testable import WhisperGlassCore

final class AudioBufferRingTests: XCTestCase {

    // MARK: - Empty buffer

    func testEmptyBufferReturnsNilFromNextChunk() async {
        let ring = AudioBufferRing(chunkSize: 100, overlapSize: 10)
        let chunk = await ring.nextChunk()
        XCTAssertNil(chunk, "Empty buffer should return nil")
    }

    // MARK: - Basic append and retrieve

    func testAppendAndRetrieveChunkOfCorrectSize() async {
        let chunkSize = 100
        let ring = AudioBufferRing(chunkSize: chunkSize, overlapSize: 10)

        let samples = [Float](repeating: 0.5, count: chunkSize)
        await ring.append(samples: samples)

        let chunk = await ring.nextChunk()
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.count, chunkSize)
    }

    func testInsufficientSamplesReturnsNil() async {
        let ring = AudioBufferRing(chunkSize: 100, overlapSize: 10)

        let samples = [Float](repeating: 0.5, count: 50)
        await ring.append(samples: samples)

        let chunk = await ring.nextChunk()
        XCTAssertNil(chunk, "Should return nil when buffer has fewer samples than chunkSize")
    }

    // MARK: - Overlap behavior

    func testOverlapProducesCorrectOverlapRegion() async {
        let chunkSize = 10
        let overlapSize = 3
        let ring = AudioBufferRing(chunkSize: chunkSize, overlapSize: overlapSize)

        // Create samples where each value equals its index for easy verification
        let totalSamples = [Float](stride(from: 0, to: 20, by: 1).map { Float($0) })
        await ring.append(samples: totalSamples)

        let firstChunk = await ring.nextChunk()
        let secondChunk = await ring.nextChunk()

        XCTAssertNotNil(firstChunk)
        XCTAssertNotNil(secondChunk)

        guard let first = firstChunk, let second = secondChunk else { return }

        // The last `overlapSize` samples of the first chunk should equal
        // the first `overlapSize` samples of the second chunk.
        let firstTail = Array(first.suffix(overlapSize))
        let secondHead = Array(second.prefix(overlapSize))

        XCTAssertEqual(
            firstTail, secondHead,
            "Overlap region should match: first tail=\(firstTail), second head=\(secondHead)"
        )
    }

    // MARK: - Clear

    func testClearResetsBufferState() async {
        let ring = AudioBufferRing(chunkSize: 10, overlapSize: 2)

        await ring.append(samples: [Float](repeating: 1.0, count: 20))
        await ring.clear()

        let chunk = await ring.nextChunk()
        XCTAssertNil(chunk, "Buffer should be empty after clear")

        let total = await ring.totalSamples
        XCTAssertEqual(total, 0, "Total samples should reset to 0 after clear")
    }

    // MARK: - Sequential chunks maintain ordering

    func testMultipleSequentialChunksMaintainCorrectOrdering() async {
        let chunkSize = 5
        let overlapSize = 1
        let strideSize = chunkSize - overlapSize
        let ring = AudioBufferRing(chunkSize: chunkSize, overlapSize: overlapSize)

        // Append enough for 3 chunks: need chunkSize + 2 * strideSize = 5 + 8 = 13
        let samples = (0..<13).map { Float($0) }
        await ring.append(samples: samples)

        let chunk1 = await ring.nextChunk()
        let chunk2 = await ring.nextChunk()
        let chunk3 = await ring.nextChunk()

        XCTAssertNotNil(chunk1)
        XCTAssertNotNil(chunk2)
        XCTAssertNotNil(chunk3)

        // Chunk 1 should start at index 0
        XCTAssertEqual(chunk1?.first, 0.0)
        // Chunk 2 should start at index strideSize (4)
        XCTAssertEqual(chunk2?.first, Float(strideSize))
        // Chunk 3 should start at index 2 * strideSize (8)
        XCTAssertEqual(chunk3?.first, Float(2 * strideSize))
    }

    // MARK: - Timestamp calculation

    func testCurrentTimestampReflectsSamplesAppended() async {
        let ring = AudioBufferRing(chunkSize: 100, overlapSize: 10)

        let sampleCount = Int(AudioConstants.whisperSampleRate) // 1 second worth
        await ring.append(samples: [Float](repeating: 0, count: sampleCount))

        let timestamp = await ring.currentTimestamp
        XCTAssertEqual(timestamp, 1.0, accuracy: 0.001)
    }

    // MARK: - Concurrent append and read

    func testConcurrentAppendAndReadDoesNotCrash() async {
        let ring = AudioBufferRing(chunkSize: 50, overlapSize: 5)

        await withTaskGroup(of: Void.self) { group in
            // Writer tasks
            for i in 0..<10 {
                group.addTask {
                    let samples = [Float](repeating: Float(i), count: 20)
                    await ring.append(samples: samples)
                }
            }

            // Reader tasks
            for _ in 0..<10 {
                group.addTask {
                    _ = await ring.nextChunk()
                }
            }
        }

        // If we get here without a crash, the test passes.
        let buffered = await ring.bufferedSampleCount
        XCTAssertTrue(buffered >= 0, "Buffer count should be non-negative")
    }
}
