import Foundation

enum AIRallyVerdictKind: String, Equatable, CaseIterable, Sendable {
    case looksGood
    case needsReview
    case unclear

    var titleKey: String {
        switch self {
        case .looksGood: return "ai.verdict.looks_good"
        case .needsReview: return "ai.verdict.needs_review"
        case .unclear: return "ai.verdict.unclear"
        }
    }

    var defaultReasonKey: String {
        switch self {
        case .looksGood: return "ai.verdict.reason.looks_good"
        case .needsReview: return "ai.verdict.reason.needs_review"
        case .unclear: return "ai.verdict.reason.unclear"
        }
    }
}

enum AIRallyConfidence: String, Equatable, Sendable {
    case low
    case medium
    case high

    var titleKey: String {
        switch self {
        case .low: return "ai.confidence.low"
        case .medium: return "ai.confidence.medium"
        case .high: return "ai.confidence.high"
        }
    }
}

struct AIRallyVerdict: Equatable, Identifiable, Sendable {
    var id: UUID { rallyID }
    let rallyID: UUID
    let kind: AIRallyVerdictKind
    let reasonKey: String
    let confidence: AIRallyConfidence
}

struct AIAssistSummary: Equatable, Sendable {
    var looksGoodCount: Int = 0
    var needsReviewCount: Int = 0
    var unclearCount: Int = 0

    var total: Int { looksGoodCount + needsReviewCount + unclearCount }

    static func from(_ verdicts: [AIRallyVerdict]) -> AIAssistSummary {
        var summary = AIAssistSummary()
        for verdict in verdicts {
            switch verdict.kind {
            case .looksGood: summary.looksGoodCount += 1
            case .needsReview: summary.needsReviewCount += 1
            case .unclear: summary.unclearCount += 1
            }
        }
        return summary
    }
}

enum AIAssistPhase: Equatable {
    case idle
    case checking(currentIndex: Int, total: Int)
    case results
}

enum AIAssistStartResult: Equatable {
    case needsModel
    case started
    case nothingToCheck
}

@MainActor
protocol RallyClipEvaluating: AnyObject {
    func evaluate(_ rally: Rally) async -> AIRallyVerdict
}

/// On-device clip check used while the downloaded GGUF is present.
/// Classifies by duration bands so the Assist UX is exercisable without
/// embedding the full MiniCPM runtime in this slice; replace with VLM inference later.
@MainActor
final class OnDeviceRallyClipEvaluator: RallyClipEvaluating {
    func evaluate(_ rally: Rally) async -> AIRallyVerdict {
        let duration = rally.duration
        let kind: AIRallyVerdictKind
        let confidence: AIRallyConfidence
        if duration < 5 {
            kind = .needsReview
            confidence = .high
        } else if duration > 60 {
            kind = .unclear
            confidence = .low
        } else {
            kind = .looksGood
            confidence = .medium
        }
        return AIRallyVerdict(
            rallyID: rally.id,
            kind: kind,
            reasonKey: kind.defaultReasonKey,
            confidence: confidence
        )
    }
}

@MainActor
final class AIAssistSession: ObservableObject {
    @Published private(set) var phase: AIAssistPhase = .idle
    @Published private(set) var verdicts: [AIRallyVerdict] = []
    @Published private(set) var activeRallyID: UUID?

    private let modelStore: VisionModelReadiness
    private let evaluator: RallyClipEvaluating
    private let stepDelayNanoseconds: UInt64
    private var runTask: Task<Void, Never>?
    private var stopRequested = false

    var summary: AIAssistSummary { .from(verdicts) }

    init(
        modelStore: VisionModelReadiness,
        evaluator: RallyClipEvaluating? = nil,
        stepDelayNanoseconds: UInt64 = 180_000_000
    ) {
        self.modelStore = modelStore
        self.evaluator = evaluator ?? OnDeviceRallyClipEvaluator()
        self.stepDelayNanoseconds = stepDelayNanoseconds
    }

    func beginAssist(for rallies: [Rally]) -> AIAssistStartResult {
        guard modelStore.isReady else { return .needsModel }
        guard !rallies.isEmpty else { return .nothingToCheck }

        stopRequested = false
        runTask?.cancel()
        verdicts = []
        activeRallyID = nil
        phase = .checking(currentIndex: 1, total: rallies.count)

        let snapshot = rallies
        runTask = Task { [weak self] in
            guard let self else { return }
            for (offset, rally) in snapshot.enumerated() {
                if Task.isCancelled || self.stopRequested { break }
                self.phase = .checking(currentIndex: offset + 1, total: snapshot.count)
                self.activeRallyID = rally.id
                if self.stepDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: self.stepDelayNanoseconds)
                }
                if Task.isCancelled || self.stopRequested { break }
                let verdict = await self.evaluator.evaluate(rally)
                if Task.isCancelled || self.stopRequested { break }
                self.verdicts.append(verdict)
            }
            self.activeRallyID = nil
            self.phase = .results
            self.runTask = nil
        }
        return .started
    }

    func stop() {
        stopRequested = true
        runTask?.cancel()
    }

    func clearResults() {
        stop()
        verdicts = []
        phase = .idle
        activeRallyID = nil
    }

    func verdict(for rallyID: UUID) -> AIRallyVerdict? {
        verdicts.first { $0.rallyID == rallyID }
    }

    func dismissVerdict(for rallyID: UUID) {
        verdicts.removeAll { $0.rallyID == rallyID }
        if verdicts.isEmpty {
            phase = .idle
        }
    }

    func waitUntilIdle() async {
        while runTask != nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
