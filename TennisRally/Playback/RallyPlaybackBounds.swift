import Foundation

struct RallyPlaybackBounds: Equatable {
    var start: TimeInterval
    var end: TimeInterval

    var duration: TimeInterval { max(0, end - start) }

    func clamp(_ time: TimeInterval) -> TimeInterval {
        min(max(time, start), end)
    }

    func progress(at time: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return (clamp(time) - start) / duration
    }

    func time(forProgress progress: Double) -> TimeInterval {
        let p = min(max(progress, 0), 1)
        return start + p * duration
    }

    func hasReachedEnd(_ time: TimeInterval, epsilon: TimeInterval = 0.05) -> Bool {
        time >= end - epsilon
    }
}

enum RallyVideoSource: Equatable {
    case missing
    case unavailable(URL)
    case ready(URL)

    static func resolve(localURL: URL?, fileManager: FileManager = .default) -> RallyVideoSource {
        guard let localURL else { return .missing }
        guard fileManager.fileExists(atPath: localURL.path) else {
            return .unavailable(localURL)
        }
        return .ready(localURL)
    }

    var localizationKey: String {
        switch self {
        case .missing:
            return "playback.missing_file"
        case .unavailable:
            return "playback.file_unavailable"
        case .ready:
            return "playback.ready"
        }
    }
}
