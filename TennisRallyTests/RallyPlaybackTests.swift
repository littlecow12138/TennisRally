import XCTest
@testable import TennisRally

final class RallyPlaybackBoundsTests: XCTestCase {
    func testClampsPlayheadInsideRange() {
        let bounds = RallyPlaybackBounds(start: 12, end: 28)
        XCTAssertEqual(bounds.clamp(10), 12, accuracy: 0.001)
        XCTAssertEqual(bounds.clamp(40), 28, accuracy: 0.001)
        XCTAssertEqual(bounds.clamp(20), 20, accuracy: 0.001)
    }

    func testProgressMapsAcrossDuration() {
        let bounds = RallyPlaybackBounds(start: 10, end: 20)
        XCTAssertEqual(bounds.progress(at: 10), 0, accuracy: 0.001)
        XCTAssertEqual(bounds.progress(at: 15), 0.5, accuracy: 0.001)
        XCTAssertEqual(bounds.progress(at: 20), 1, accuracy: 0.001)
    }

    func testTimeFromProgressStaysInRange() {
        let bounds = RallyPlaybackBounds(start: 41, end: 58)
        XCTAssertEqual(bounds.time(forProgress: 0), 41, accuracy: 0.001)
        XCTAssertEqual(bounds.time(forProgress: 1), 58, accuracy: 0.001)
        XCTAssertEqual(bounds.time(forProgress: 0.5), 49.5, accuracy: 0.001)
        XCTAssertEqual(bounds.time(forProgress: -0.2), 41, accuracy: 0.001)
        XCTAssertEqual(bounds.time(forProgress: 1.5), 58, accuracy: 0.001)
    }

    func testReachedEndUsesEpsilon() {
        let bounds = RallyPlaybackBounds(start: 0, end: 10)
        XCTAssertFalse(bounds.hasReachedEnd(9.8, epsilon: 0.05))
        XCTAssertTrue(bounds.hasReachedEnd(9.96, epsilon: 0.05))
        XCTAssertTrue(bounds.hasReachedEnd(10, epsilon: 0.05))
    }

    func testZeroDurationProgressIsZero() {
        let bounds = RallyPlaybackBounds(start: 5, end: 5)
        XCTAssertEqual(bounds.progress(at: 5), 0, accuracy: 0.001)
        XCTAssertEqual(bounds.duration, 0, accuracy: 0.001)
    }
}

final class RallyVideoSourceTests: XCTestCase {
    func testMissingURLResolvesToMissing() {
        XCTAssertEqual(RallyVideoSource.resolve(localURL: nil), .missing)
    }

    func testNonexistentFileResolvesToUnavailable() {
        let url = URL(fileURLWithPath: "/tmp/tennismrally-does-not-exist-\(UUID().uuidString).mov")
        XCTAssertEqual(RallyVideoSource.resolve(localURL: url), .unavailable(url))
    }

    func testExistingFileResolvesToReady() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tennismrally-ready-\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: url.path, contents: Data([0x00]), attributes: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(RallyVideoSource.resolve(localURL: url), .ready(url))
    }
}
