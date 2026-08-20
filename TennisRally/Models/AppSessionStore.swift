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
    @Published var alertMessage: String?

    private var processingTask: Task<Void, Never>?

    init(seedDemoData: Bool = false) {
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

    // MARK: - Import

    func importVideo(from sourceURL: URL, displayName: String? = nil) {
        do {
            let stored = try Self.copyIntoDocuments(sourceURL: sourceURL, preferredName: displayName)
            let title = displayName.map { Self.stripExtension($0) }
                ?? Self.stripExtension(sourceURL.lastPathComponent)
            let video = LibraryVideo(
                id: UUID(),
                title: title,
                duration: 0,
                status: .notProcessed,
                filename: stored.lastPathComponent,
                localURL: stored,
                lastErrorMessage: nil
            )
            videos.insert(video, at: 0)
            activeVideoID = video.id
            rallies = []
            startProcessing(for: video.id)
        } catch {
            alertMessage = String(localized: "error.decode_failed")
        }
    }

    /// Legacy demo helper used by unit tests.
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
            detectedClipCount: 2,
            statusMessageKey: "process.detecting"
        )
        selectedTab = .process
    }

    // MARK: - Processing

    func startProcessing(for videoID: UUID? = nil) {
        let id = videoID ?? activeVideoID
        guard let id,
              let index = videos.firstIndex(where: { $0.id == id }),
              let url = videos[index].localURL else {
            alertMessage = String(localized: "error.decode_failed")
            return
        }

        processingTask?.cancel()
        videos[index].status = .processing
        videos[index].lastErrorMessage = nil
        activeVideoID = id
        rallies = []
        processing = ProcessingState(
            videoID: id,
            filename: videos[index].filename,
            progress: 0.05,
            estimatedClipCount: 12,
            detectedClipCount: 0,
            statusMessageKey: "process.detecting"
        )
        selectedTab = .process

        let filename = videos[index].filename
        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await RallySegmentationService.segmentVideo(at: url) { [weak self] value in
                    Task { @MainActor in
                        self?.bumpProcessingProgress(to: value)
                    }
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.finishProcessing(
                        videoID: id,
                        duration: result.duration,
                        segments: result.segments,
                        filename: filename
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                let mapped = RallySegmentationError.from(error)
                await MainActor.run {
                    self.failProcessing(videoID: id, error: mapped)
                }
            }
        }
    }

    func bumpProcessingProgress(to value: Double) {
        guard var job = processing else { return }
        job.progress = min(1, max(0, value))
        let estimated = max(job.estimatedClipCount, 1)
        job.detectedClipCount = max(job.detectedClipCount, Int((job.progress * Double(estimated) * 0.85).rounded()))
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
        processingTask?.cancel()
        processingTask = nil
        if let job = processing,
           let index = videos.firstIndex(where: { $0.id == job.videoID }) {
            videos[index].status = .notProcessed
        }
        processing = nil
        rallies = []
        selectedTab = .library
    }

    private func finishProcessing(
        videoID: UUID,
        duration: TimeInterval,
        segments: [OnsetRallySegmenter.Segment],
        filename: String
    ) {
        if let index = videos.firstIndex(where: { $0.id == videoID }) {
            videos[index].status = .processed
            videos[index].duration = duration
            videos[index].lastErrorMessage = nil
        }
        rallies = segments.enumerated().map { idx, seg in
            Rally(index: idx + 1, start: seg.start, end: seg.end)
        }
        processing = ProcessingState(
            videoID: videoID,
            filename: filename,
            progress: 1,
            estimatedClipCount: segments.count,
            detectedClipCount: segments.count,
            statusMessageKey: "process.detecting"
        )
        processing = nil
        selectedTab = .rallies
    }

    private func failProcessing(videoID: UUID, error: RallySegmentationError) {
        let message = error.localizedDescription
        if let index = videos.firstIndex(where: { $0.id == videoID }) {
            videos[index].status = .failed
            videos[index].lastErrorMessage = message
        }
        processing = nil
        rallies = []
        alertMessage = message
        selectedTab = .library
    }

    // MARK: - Editing

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

    private static func stripExtension(_ name: String) -> String {
        (name as NSString).deletingPathExtension
    }

    private static func copyIntoDocuments(sourceURL: URL, preferredName: String?) throws -> URL {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imports = docs.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)

        let base = preferredName ?? sourceURL.lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let stem = stripExtension(base)
        let destName = "\(stem)-\(UUID().uuidString.prefix(8)).\(ext)"
        let dest = imports.appendingPathComponent(destName)

        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }
}
