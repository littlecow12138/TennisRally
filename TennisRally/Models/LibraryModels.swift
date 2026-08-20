import Foundation

enum LibraryStatus: String, Equatable {
    case notProcessed
    case processing
    case processed
}

struct LibraryVideo: Identifiable, Equatable {
    let id: UUID
    var title: String
    var duration: TimeInterval
    var status: LibraryStatus
    var filename: String

    var durationLabel: String {
        let total = Int(duration.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    var statusLabelKey: String {
        switch status {
        case .notProcessed: return "status.not_processed"
        case .processing: return "status.processing"
        case .processed: return "status.processed"
        }
    }
}

struct ProcessingState: Equatable {
    var videoID: UUID
    var filename: String
    var progress: Double
    var estimatedClipCount: Int
    var detectedClipCount: Int

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case library
    case process
    case rallies

    var id: String { rawValue }
}

enum LibraryRoute: Hashable {
    case settings
}
