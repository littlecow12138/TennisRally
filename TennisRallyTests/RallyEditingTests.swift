import XCTest
@testable import TennisRally

final class RallyEditingTests: XCTestCase {
    func testDurationUsesEndMinusStart() {
        let rally = Rally(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            index: 3,
            start: 41,
            end: 58,
            isCorrected: false
        )
        XCTAssertEqual(rally.duration, 17, accuracy: 0.001)
    }

    func testTrimUpdatesBoundsAndMarksCorrected() {
        var rally = Rally.sample(index: 3, start: 41, end: 58)
        rally.trim(start: 42.5, end: 57)
        XCTAssertEqual(rally.start, 42.5, accuracy: 0.001)
        XCTAssertEqual(rally.end, 57, accuracy: 0.001)
        XCTAssertTrue(rally.isCorrected)
    }

    func testTrimRejectsInvertedBounds() {
        var rally = Rally.sample(index: 1, start: 10, end: 20)
        rally.trim(start: 25, end: 15)
        XCTAssertEqual(rally.start, 10, accuracy: 0.001)
        XCTAssertEqual(rally.end, 20, accuracy: 0.001)
        XCTAssertFalse(rally.isCorrected)
    }

    func testSplitCreatesSecondRallyAtPlayhead() {
        let original = Rally.sample(index: 3, start: 41, end: 58)
        let (left, right) = original.split(at: 49)
        XCTAssertEqual(left.start, 41, accuracy: 0.001)
        XCTAssertEqual(left.end, 49, accuracy: 0.001)
        XCTAssertEqual(right.start, 49, accuracy: 0.001)
        XCTAssertEqual(right.end, 58, accuracy: 0.001)
        XCTAssertTrue(left.isCorrected)
        XCTAssertTrue(right.isCorrected)
    }

    func testMergeWithPreviousJoinsBounds() {
        let previous = Rally.sample(index: 2, start: 24, end: 41)
        let current = Rally.sample(index: 3, start: 41, end: 58)
        let merged = current.merging(withPrevious: previous)
        XCTAssertEqual(merged.start, 24, accuracy: 0.001)
        XCTAssertEqual(merged.end, 58, accuracy: 0.001)
        XCTAssertTrue(merged.isCorrected)
        XCTAssertEqual(merged.index, 2)
    }

    func testResetRestoresOriginalBounds() {
        var rally = Rally.sample(index: 3, start: 41, end: 58)
        rally.trim(start: 45, end: 55)
        rally.reset()
        XCTAssertEqual(rally.start, 41, accuracy: 0.001)
        XCTAssertEqual(rally.end, 58, accuracy: 0.001)
        XCTAssertFalse(rally.isCorrected)
    }
}

@MainActor
final class SessionFlowTests: XCTestCase {
    func testImportStartsProcessingAndSwitchesToProcessTab() {
        let store = AppSessionStore(seedDemoData: false)
        store.importDemoVideo(named: "Saturday practice", duration: 724)
        XCTAssertEqual(store.videos.count, 1)
        XCTAssertEqual(store.videos[0].status, .processing)
        XCTAssertEqual(store.selectedTab, .process)
        XCTAssertNotNil(store.processing)
    }

    func testCompletingProcessingProducesRalliesAndSwitchesTab() {
        let store = AppSessionStore(seedDemoData: false)
        store.importDemoVideo(named: "Saturday practice", duration: 724)
        store.completeProcessing(rallyCount: 18)
        XCTAssertEqual(store.videos[0].status, .processed)
        XCTAssertEqual(store.rallies.count, 18)
        XCTAssertEqual(store.selectedTab, .rallies)
    }

    func testCancelProcessingReturnsToLibraryWithoutRallies() {
        let store = AppSessionStore(seedDemoData: false)
        store.importDemoVideo(named: "Saturday practice", duration: 724)
        store.cancelProcessing()
        XCTAssertEqual(store.videos[0].status, .notProcessed)
        XCTAssertTrue(store.rallies.isEmpty)
        XCTAssertEqual(store.selectedTab, .library)
        XCTAssertNil(store.processing)
    }
}
