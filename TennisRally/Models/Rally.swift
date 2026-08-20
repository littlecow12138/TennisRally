import Foundation

struct Rally: Identifiable, Equatable, Hashable {
    let id: UUID
    var index: Int
    var start: TimeInterval
    var end: TimeInterval
    var isCorrected: Bool
    let originalStart: TimeInterval
    let originalEnd: TimeInterval

    init(
        id: UUID = UUID(),
        index: Int,
        start: TimeInterval,
        end: TimeInterval,
        isCorrected: Bool = false,
        originalStart: TimeInterval? = nil,
        originalEnd: TimeInterval? = nil
    ) {
        self.id = id
        self.index = index
        self.start = start
        self.end = end
        self.isCorrected = isCorrected
        self.originalStart = originalStart ?? start
        self.originalEnd = originalEnd ?? end
    }

    var duration: TimeInterval { max(0, end - start) }

    var timeRangeLabel: String {
        "\(Self.formatClock(start)) – \(Self.formatClock(end))"
    }

    var durationLabel: String {
        "\(Int(duration.rounded()))s"
    }

    mutating func trim(start newStart: TimeInterval, end newEnd: TimeInterval) {
        guard newEnd > newStart else { return }
        start = newStart
        end = newEnd
        isCorrected = true
    }

    func split(at playhead: TimeInterval) -> (Rally, Rally) {
        let clamped = min(max(playhead, start + 0.1), end - 0.1)
        let left = Rally(
            id: id,
            index: index,
            start: start,
            end: clamped,
            isCorrected: true,
            originalStart: originalStart,
            originalEnd: originalEnd
        )
        let right = Rally(
            index: index + 1,
            start: clamped,
            end: end,
            isCorrected: true,
            originalStart: originalStart,
            originalEnd: originalEnd
        )
        return (left, right)
    }

    func merging(withPrevious previous: Rally) -> Rally {
        Rally(
            id: previous.id,
            index: previous.index,
            start: previous.start,
            end: end,
            isCorrected: true,
            originalStart: previous.originalStart,
            originalEnd: originalEnd
        )
    }

    mutating func reset() {
        start = originalStart
        end = originalEnd
        isCorrected = false
    }

    static func sample(index: Int, start: TimeInterval, end: TimeInterval) -> Rally {
        Rally(index: index, start: start, end: end)
    }

    static func formatClock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
