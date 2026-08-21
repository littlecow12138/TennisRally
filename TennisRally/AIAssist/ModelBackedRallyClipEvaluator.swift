import Foundation

@MainActor
final class ModelBackedRallyClipEvaluator: RallyClipEvaluating {
    private let modelStore: VisionModelLocating
    private let videoURLProvider: () -> URL?
    private let frameExtractor: RallyFrameExtracting
    private let inferencer: RallyVisionInferencing

    init(
        modelStore: VisionModelLocating,
        videoURLProvider: @escaping () -> URL?,
        frameExtractor: RallyFrameExtracting = AVAssetRallyFrameExtractor(),
        inferencer: RallyVisionInferencing = MiniCPMRallyVisionInferencer()
    ) {
        self.modelStore = modelStore
        self.videoURLProvider = videoURLProvider
        self.frameExtractor = frameExtractor
        self.inferencer = inferencer
    }

    func evaluate(_ rally: Rally) async -> AIRallyVerdict {
        guard modelStore.isReady else {
            return AIRallyVerdict(
                rallyID: rally.id,
                kind: .unclear,
                reasonKey: "ai.verdict.reason.unclear",
                confidence: .low
            )
        }

        guard let videoURL = videoURLProvider() else {
            return AIRallyVerdict(
                rallyID: rally.id,
                kind: .unclear,
                reasonKey: "ai.verdict.reason.no_video",
                confidence: .low
            )
        }

        do {
            let frameURL = try await frameExtractor.extractMidFrame(
                videoURL: videoURL,
                start: rally.start,
                end: rally.end
            )
            defer { try? FileManager.default.removeItem(at: frameURL) }

            let kind = try await inferencer.classifyRallyFrame(
                imagePath: frameURL.path,
                modelPath: modelStore.llmModelURL.path,
                mmprojPath: modelStore.mmprojModelURL.path
            )
            return AIRallyVerdict(
                rallyID: rally.id,
                kind: kind,
                reasonKey: kind.defaultReasonKey,
                confidence: .medium
            )
        } catch {
            return AIRallyVerdict(
                rallyID: rally.id,
                kind: .unclear,
                reasonKey: "ai.verdict.reason.inference_failed",
                confidence: .low
            )
        }
    }
}
