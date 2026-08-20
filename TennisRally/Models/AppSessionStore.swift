import Foundation
import SwiftUI

@MainActor
final class AppSessionStore: ObservableObject {
    @Published var videos: [LibraryVideo] = []
    @Published var rallies: [Rally] = []
    @Published var processing: ProcessingState?
    @Published var selectedTab: AppTab = .library
    @Published var activeVideoID: UUID?
    @Published var editingRallyID: UUID?
    @Published var reviewingRallyID: UUID?
    @Published var showCorrection = false
    @Published var showReview = false

    init(seedDemoData: Bool = true) {
        if seedDemoData {
            let video = LibraryVideo(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "Saturday practice",
                duration: 724,
                status: .notProcessed,
                filename: "Saturday practice.mov"
            )
            videos = [video]
            activeVideoID = video.id
        }
    }

    var activeVideo: LibraryVideo? {
        videos.first { $0.id == activeVideoID } ?? videos.first
    }

    var editingRally: Rally? {
        rallies.first { $0.id == editingRallyID }
    }

    var reviewingRally: Rally? {
        rallies.first { $0.id == reviewingRallyID }
    }

    func importDemoVideo(named title: String, duration: TimeInterval) {
        let video = LibraryVideo(
            id: UUID(),
            title: title,
            duration: duration,
            status: .processing,
            filename: "\(title).mov"
        )
        videos.insert(video, at: 0)
        activeVideoID = video.id
        processing = ProcessingState(
            videoID: video.id,
            filename: video.filename,
            progress: 0.12,
            estimatedClipCount: 18,
            detectedClipCount: 2
        )
        selectedTab = .process
    }

    func bumpProcessingProgress(to value: Double) {
        guard var job = processing else { return }
        job.progress = min(1, max(0, value))
        job.detectedClipCount = max(1, Int((job.progress * Double(job.estimatedClipCount)).rounded()))
        processing = job
        if let index = videos.firstIndex(where: { $0.id == job.videoID }) {
            videos[index].status = .processing
        }
    }

    func completeProcessing(rallyCount: Int = 18) {
        guard let job = processing else { return }
        if let index = videos.firstIndex(where: { $0.id == job.videoID }) {
            videos[index].status = .processed
        }
        rallies = Self.makeDemoRallies(count: rallyCount)
        processing = nil
        selectedTab = .rallies
    }

    func cancelProcessing() {
        if let job = processing,
           let index = videos.firstIndex(where: { $0.id == job.videoID }) {
            videos[index].status = .notProcessed
        }
        processing = nil
        rallies = []
        selectedTab = .library
    }

    func openCorrection(for rally: Rally) {
        editingRallyID = rally.id
        showCorrection = true
    }

    func applyEditedRally(_ rally: Rally) {
        guard let index = rallies.firstIndex(where: { $0.id == rally.id }) else { return }
        rallies[index] = rally
        reindexRallies()
        showCorrection = false
    }

    func splitEditingRally(at playhead: TimeInterval) {
        guard let id = editingRallyID,
              let index = rallies.firstIndex(where: { $0.id == id }) else { return }
        let (left, right) = rallies[index].split(at: playhead)
        rallies[index] = left
        rallies.insert(right, at: index + 1)
        reindexRallies()
        editingRallyID = left.id
    }

    func mergeEditingRallyWithPrevious() {
        guard let id = editingRallyID,
              let index = rallies.firstIndex(where: { $0.id == id }),
              index > 0 else { return }
        let merged = rallies[index].merging(withPrevious: rallies[index - 1])
        rallies[index - 1] = merged
        rallies.remove(at: index)
        reindexRallies()
        editingRallyID = merged.id
    }

    func resetEditingRally() {
        guard let id = editingRallyID,
              let index = rallies.firstIndex(where: { $0.id == id }) else { return }
        var rally = rallies[index]
        rally.reset()
        rallies[index] = rally
    }

    func openReview(for rally: Rally) {
        reviewingRallyID = rally.id
        showReview = true
    }

    func selectAdjacentReview(offset: Int) {
        guard let id = reviewingRallyID,
              let index = rallies.firstIndex(where: { $0.id == id }) else { return }
        let next = index + offset
        guard rallies.indices.contains(next) else { return }
        reviewingRallyID = rallies[next].id
    }

    private func reindexRallies() {
        for i in rallies.indices {
            rallies[i].index = i + 1
        }
    }

    private static func makeDemoRallies(count: Int) -> [Rally] {
        var result: [Rally] = []
        var cursor: TimeInterval = 12
        let lengths: [TimeInterval] = [16, 17, 17, 18, 15, 19, 16, 14, 20, 17, 15, 18, 16, 17, 19, 15, 16, 18]
        for i in 0..<count {
            let length = lengths[i % lengths.count]
            let start = cursor
            let end = start + length
            result.append(Rally(index: i + 1, start: start, end: end))
            cursor = end + 6
        }
        return result
    }
}
