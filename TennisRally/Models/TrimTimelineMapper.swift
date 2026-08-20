import Foundation

/// Maps correction-handle positions on a fixed time window (original rally ± pad).
struct TrimTimelineMapper: Equatable {
    let windowStart: TimeInterval
    let windowEnd: TimeInterval
    let minimumDuration: TimeInterval

    var windowDuration: TimeInterval { max(windowEnd - windowStart, 0.1) }

    init(rally: Rally, padding: TimeInterval = 8, minimumDuration: TimeInterval = 0.5) {
        self.windowStart = max(0, rally.originalStart - padding)
        self.windowEnd = rally.originalEnd + padding
        self.minimumDuration = minimumDuration
    }

    init(windowStart: TimeInterval, windowEnd: TimeInterval, minimumDuration: TimeInterval = 0.5) {
        self.windowStart = windowStart
        self.windowEnd = max(windowEnd, windowStart + minimumDuration)
        self.minimumDuration = minimumDuration
    }

    func x(for time: TimeInterval, width: Double) -> Double {
        let ratio = (time - windowStart) / windowDuration
        return ratio * width
    }

    func time(atX x: Double, width: Double) -> TimeInterval {
        guard width > 0 else { return windowStart }
        let ratio = min(max(x / width, 0), 1)
        return windowStart + ratio * windowDuration
    }

    func clampedStart(proposed: TimeInterval, currentEnd: TimeInterval) -> TimeInterval {
        let upper = currentEnd - minimumDuration
        return min(max(proposed, windowStart), upper)
    }

    func clampedEnd(proposed: TimeInterval, currentStart: TimeInterval) -> TimeInterval {
        let lower = currentStart + minimumDuration
        return min(max(proposed, lower), windowEnd)
    }
}
