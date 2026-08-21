import AVFoundation
import Foundation
import UIKit

enum RallyFrameExtractionError: Error {
    case invalidInterval
    case imageGenerationFailed
    case jpegEncodeFailed
}

protocol RallyFrameExtracting: AnyObject {
    func extractMidFrame(
        videoURL: URL,
        start: TimeInterval,
        end: TimeInterval
    ) async throws -> URL
}

final class AVAssetRallyFrameExtractor: RallyFrameExtracting {
    func extractMidFrame(
        videoURL: URL,
        start: TimeInterval,
        end: TimeInterval
    ) async throws -> URL {
        guard end > start else { throw RallyFrameExtractionError.invalidInterval }
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 768, height: 768)

        let mid = start + (end - start) / 2
        let time = CMTime(seconds: mid, preferredTimescale: 600)
        let cgImage: CGImage
        if #available(iOS 16.0, *) {
            cgImage = try await generator.image(at: time).image
        } else {
            cgImage = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CGImage, Error>) in
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
                    if let error {
                        cont.resume(throwing: error)
                        return
                    }
                    guard result == .succeeded, let image else {
                        cont.resume(throwing: RallyFrameExtractionError.imageGenerationFailed)
                        return
                    }
                    cont.resume(returning: image)
                }
            }
        }

        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else {
            throw RallyFrameExtractionError.jpegEncodeFailed
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("rally-frame-\(UUID().uuidString).jpg")
        try data.write(to: out, options: .atomic)
        return out
    }
}

protocol RallyVisionInferencing: AnyObject {
    func classifyRallyFrame(
        imagePath: String,
        modelPath: String,
        mmprojPath: String
    ) async throws -> AIRallyVerdictKind
}

enum RallyVisionInferenceError: Error {
    case modelInitFailed
    case imagePrefillFailed(String)
    case textPrefillFailed(String)
    case emptyOutput
}

/// Loads the downloaded MiniCPM-V GGUF + mmproj and classifies one rally frame.
final class MiniCPMRallyVisionInferencer: RallyVisionInferencing {
    static let classificationPrompt = """
    You are checking an auto-split tennis rally clip. Look at this single frame from the clip.
    Reply with exactly one label and nothing else:
    LOOKS_GOOD — the frame looks like a real tennis rally/point in play
    NEEDS_REVIEW — the split looks wrong (walk-on, idle, or cut mid-point)
    UNCLEAR — not enough visual evidence
    """

    func classifyRallyFrame(
        imagePath: String,
        modelPath: String,
        mmprojPath: String
    ) async throws -> AIRallyVerdictKind {
        try await Task.detached(priority: .userInitiated) {
            var params = mb_mtmd_params_default()
            params.n_predict = 24
            params.n_ctx = 2048
            params.n_ubatch = 256
            params.temperature = 0
            params.use_gpu = true
            params.mmproj_use_gpu = true
            params.warmup = false
            params.image_max_slice_nums = 1

            guard let ctx = mb_mtmd_init(modelPath, mmprojPath, &params) else {
                throw RallyVisionInferenceError.modelInitFailed
            }
            defer { mb_mtmd_free(ctx) }
            mb_mtmd_set_model_version(ctx, 40)

            let imageRC = imagePath.withCString { mb_mtmd_prefill_image(ctx, $0) }
            if imageRC != 0 {
                let message = mb_mtmd_get_last_error(ctx).map { String(cString: $0) } ?? "image prefill failed"
                throw RallyVisionInferenceError.imagePrefillFailed(message)
            }

            let prompt = Self.classificationPrompt
            let textRC = prompt.withCString { textC in
                "user".withCString { roleC in
                    mb_mtmd_prefill_text(ctx, textC, roleC)
                }
            }
            if textRC != 0 {
                let message = mb_mtmd_get_last_error(ctx).map { String(cString: $0) } ?? "text prefill failed"
                throw RallyVisionInferenceError.textPrefillFailed(message)
            }

            var output = ""
            for _ in 0..<48 {
                let token = mb_mtmd_loop(ctx)
                if let cString = token.token {
                    output += String(cString: cString)
                    mb_mtmd_string_free(cString)
                }
                if token.is_end { break }
            }

            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw RallyVisionInferenceError.emptyOutput }
            return Self.parseVerdict(from: trimmed)
        }.value
    }

    static func parseVerdict(from raw: String) -> AIRallyVerdictKind {
        let upper = raw.uppercased()
        if upper.contains("NEEDS_REVIEW") || upper.contains("NEED_REVIEW") {
            return .needsReview
        }
        if upper.contains("LOOKS_GOOD") || upper.contains("LOOKS GOOD") {
            return .looksGood
        }
        if upper.contains("UNCLEAR") {
            return .unclear
        }
        if upper.contains("REVIEW") || upper.contains("WRONG") {
            return .needsReview
        }
        if upper.contains("GOOD") || upper.contains("PASS") {
            return .looksGood
        }
        return .unclear
    }
}
