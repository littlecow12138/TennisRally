import Foundation

enum RallySegmentationError: LocalizedError, Equatable {
    case decodeFailed
    case noAudioTrack
    case noRalliesDetected
    case cancelled

    var errorDescription: String? {
        switch self {
        case .decodeFailed:
            return String(localized: "error.decode_failed")
        case .noAudioTrack:
            return String(localized: "error.no_audio")
        case .noRalliesDetected:
            return String(localized: "error.no_rallies")
        case .cancelled:
            return String(localized: "error.cancelled")
        }
    }

    static func from(_ error: Error) -> RallySegmentationError {
        if let e = error as? RallySegmentationError { return e }
        if let e = error as? VideoAudioExtractorError {
            switch e {
            case .noAudioTrack, .emptyAudio:
                return .noAudioTrack
            case .cannotOpenAsset, .readerFailed, .decodeFailed:
                return .decodeFailed
            }
        }
        if error is CancellationError {
            return .cancelled
        }
        return .decodeFailed
    }
}

struct RallySegmentationResult: Equatable {
    var duration: TimeInterval
    var segments: [OnsetRallySegmenter.Segment]
}

enum RallySegmentationService {
    static func segmentVideo(at url: URL, progress: (@Sendable (Double) -> Void)? = nil) async throws -> RallySegmentationResult {
        try Task.checkCancellation()
        progress?(0.08)

        let extracted: (samples: [Float], sampleRate: Int, duration: TimeInterval)
        do {
            extracted = try await VideoAudioExtractor.extractMono16k(from: url)
        } catch {
            throw RallySegmentationError.from(error)
        }

        try Task.checkCancellation()
        progress?(0.55)

        let segmenter = OnsetRallySegmenter()
        let segments = segmenter.segment(samples: extracted.samples, sampleRate: extracted.sampleRate)

        try Task.checkCancellation()
        progress?(0.95)

        guard !segments.isEmpty else {
            throw RallySegmentationError.noRalliesDetected
        }

        progress?(1.0)
        return RallySegmentationResult(duration: extracted.duration, segments: segments)
    }
}
