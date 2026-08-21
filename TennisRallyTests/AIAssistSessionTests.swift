import XCTest
@testable import TennisRally

@MainActor
final class AIAssistSessionTests: XCTestCase {
    func testGateRequiresReadyModel() {
        let session = AIAssistSession(
            modelStore: StubModelReadiness(isReady: false),
            evaluator: RecordingEvaluator(results: [])
        )
        XCTAssertEqual(session.beginAssist(for: [Rally.sample(index: 1, start: 0, end: 10)]), .needsModel)
    }

    func testRunsChecksAndAggregatesSummary() async {
        let rallies = [
            Rally.sample(index: 1, start: 0, end: 16),
            Rally.sample(index: 2, start: 20, end: 24),
            Rally.sample(index: 3, start: 30, end: 48)
        ]
        let evaluator = RecordingEvaluator(results: [
            .looksGood,
            .needsReview,
            .unclear
        ])
        let session = AIAssistSession(
            modelStore: StubModelReadiness(isReady: true),
            evaluator: evaluator,
            stepDelayNanoseconds: 0
        )

        XCTAssertEqual(session.beginAssist(for: rallies), .started)
        await session.waitUntilIdle()

        XCTAssertEqual(session.phase, .results)
        XCTAssertEqual(session.verdicts.count, 3)
        XCTAssertEqual(session.summary.looksGoodCount, 1)
        XCTAssertEqual(session.summary.needsReviewCount, 1)
        XCTAssertEqual(session.summary.unclearCount, 1)
        XCTAssertEqual(evaluator.evaluatedIDs, rallies.map(\.id))
    }

    func testStopKeepsFinishedVerdicts() async {
        let rallies = (1...4).map { Rally.sample(index: $0, start: Double($0 * 10), end: Double($0 * 10 + 16)) }
        let evaluator = GateEvaluator()
        let session = AIAssistSession(
            modelStore: StubModelReadiness(isReady: true),
            evaluator: evaluator,
            stepDelayNanoseconds: 0
        )

        XCTAssertEqual(session.beginAssist(for: rallies), .started)
        await evaluator.waitUntilEvaluated(count: 1)
        session.stop()
        await session.waitUntilIdle()

        XCTAssertEqual(session.phase, .results)
        XCTAssertEqual(session.verdicts.count, 1)
        XCTAssertLessThan(evaluator.evaluatedIDs.count, rallies.count)
    }

    func testHeuristicEvaluatorClassifiesDurationBands() async {
        let evaluator = OnDeviceRallyClipEvaluator()
        let short = await evaluator.evaluate(Rally.sample(index: 1, start: 0, end: 3))
        let normal = await evaluator.evaluate(Rally.sample(index: 2, start: 0, end: 16))
        let long = await evaluator.evaluate(Rally.sample(index: 3, start: 0, end: 95))

        XCTAssertEqual(short.kind, .needsReview)
        XCTAssertEqual(normal.kind, .looksGood)
        XCTAssertEqual(long.kind, .unclear)
    }
}

@MainActor
private final class StubModelReadiness: VisionModelReadiness {
    let isReady: Bool
    init(isReady: Bool) { self.isReady = isReady }
}

@MainActor
private final class RecordingEvaluator: RallyClipEvaluating {
    private var remaining: [AIRallyVerdictKind]
    private(set) var evaluatedIDs: [UUID] = []

    init(results: [AIRallyVerdictKind]) {
        remaining = results
    }

    func evaluate(_ rally: Rally) async -> AIRallyVerdict {
        evaluatedIDs.append(rally.id)
        let kind = remaining.isEmpty ? AIRallyVerdictKind.looksGood : remaining.removeFirst()
        return AIRallyVerdict(
            rallyID: rally.id,
            kind: kind,
            reasonKey: kind.defaultReasonKey,
            confidence: .medium
        )
    }
}

@MainActor
private final class GateEvaluator: RallyClipEvaluating {
    private(set) var evaluatedIDs: [UUID] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private var targetCount = 0

    func evaluate(_ rally: Rally) async -> AIRallyVerdict {
        if !evaluatedIDs.isEmpty {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        evaluatedIDs.append(rally.id)
        if evaluatedIDs.count >= targetCount {
            continuation?.resume()
            continuation = nil
        }
        return AIRallyVerdict(
            rallyID: rally.id,
            kind: .looksGood,
            reasonKey: AIRallyVerdictKind.looksGood.defaultReasonKey,
            confidence: .high
        )
    }

    func waitUntilEvaluated(count: Int) async {
        if evaluatedIDs.count >= count { return }
        targetCount = count
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuation = cont
        }
    }
}
