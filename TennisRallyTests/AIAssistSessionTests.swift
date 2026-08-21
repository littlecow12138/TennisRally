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

    func testModelBackedEvaluatorPassesModelPathsToInferencer() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let llm = root.appendingPathComponent("llm.gguf")
        let mmproj = root.appendingPathComponent("mmproj.gguf")
        try? Data("llm".utf8).write(to: llm)
        try? Data("mm".utf8).write(to: mmproj)
        let video = root.appendingPathComponent("clip.mov")
        try? Data("video".utf8).write(to: video)

        let locator = StubModelLocator(isReady: true, llm: llm, mmproj: mmproj)
        let frames = StubFrameExtractor(url: root.appendingPathComponent("frame.jpg"))
        try? Data("jpg".utf8).write(to: frames.url)
        let inferencer = RecordingInferencer(result: .needsReview)
        let evaluator = ModelBackedRallyClipEvaluator(
            modelStore: locator,
            videoURLProvider: { video },
            frameExtractor: frames,
            inferencer: inferencer
        )

        let verdict = await evaluator.evaluate(Rally.sample(index: 2, start: 1, end: 12))
        XCTAssertEqual(verdict.kind, .needsReview)
        XCTAssertEqual(inferencer.lastModelPath, llm.path)
        XCTAssertEqual(inferencer.lastMmprojPath, mmproj.path)
        XCTAssertEqual(inferencer.lastImagePath, frames.url.path)
    }

    func testParseVerdictLabelsFromModelOutput() {
        XCTAssertEqual(MiniCPMRallyVisionInferencer.parseVerdict(from: "LOOKS_GOOD"), .looksGood)
        XCTAssertEqual(MiniCPMRallyVisionInferencer.parseVerdict(from: "needs_review please"), .needsReview)
        XCTAssertEqual(MiniCPMRallyVisionInferencer.parseVerdict(from: "UNCLEAR"), .unclear)
    }
}

@MainActor
private final class StubModelReadiness: VisionModelReadiness {
    let isReady: Bool
    init(isReady: Bool) { self.isReady = isReady }
}

@MainActor
private final class StubModelLocator: VisionModelLocating {
    let isReady: Bool
    let llmModelURL: URL
    let mmprojModelURL: URL

    init(isReady: Bool, llm: URL, mmproj: URL) {
        self.isReady = isReady
        self.llmModelURL = llm
        self.mmprojModelURL = mmproj
    }
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

private final class StubFrameExtractor: RallyFrameExtracting {
    let url: URL
    init(url: URL) { self.url = url }

    func extractMidFrame(videoURL: URL, start: TimeInterval, end: TimeInterval) async throws -> URL {
        url
    }
}

private final class RecordingInferencer: RallyVisionInferencing {
    let result: AIRallyVerdictKind
    private(set) var lastImagePath: String?
    private(set) var lastModelPath: String?
    private(set) var lastMmprojPath: String?

    init(result: AIRallyVerdictKind) { self.result = result }

    func classifyRallyFrame(imagePath: String, modelPath: String, mmprojPath: String) async throws -> AIRallyVerdictKind {
        lastImagePath = imagePath
        lastModelPath = modelPath
        lastMmprojPath = mmprojPath
        return result
    }
}
