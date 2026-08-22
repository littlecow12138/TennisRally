import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class VisionModelStore: ObservableObject, VisionModelLocating {
    enum Keys {
        static let readyFlag = "ai.vision_model.ready"
    }

    static let defaultStallThresholdSeconds: TimeInterval = 25

    let catalog: VisionModelCatalog
    let modelsDirectory: URL
    let llmModelURL: URL
    let mmprojModelURL: URL
    let stallThresholdSeconds: TimeInterval

    /// Primary GGUF path (LLM). Kept for existing call sites / tests.
    var modelFileURL: URL { llmModelURL }

    @Published private(set) var status: VisionModelStatus

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let downloader: VisionModelDownloading
    private let idleTimerController: IdleTimerControlling
    private var downloadTask: Task<Void, Never>?
    private var stallMonitorTask: Task<Void, Never>?

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    var settingsSubtitleKey: String {
        switch status {
        case .notDownloaded:
            return "ai.model.status.not_downloaded"
        case .connecting, .downloading:
            return "ai.model.status.downloading"
        case .stalled:
            return "ai.model.status.stalled"
        case .failed:
            return "ai.model.status.failed"
        case .ready:
            return "ai.model.status.ready"
        }
    }

    var downloadProgressPercent: Int {
        Int((status.progressFraction * 100).rounded())
    }

    init(
        catalog: VisionModelCatalog = .miniCPMV4,
        modelsDirectory: URL? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        downloader: VisionModelDownloading = URLSessionVisionModelDownloader(),
        idleTimerController: IdleTimerControlling = SystemIdleTimerController(),
        stallThresholdSeconds: TimeInterval = VisionModelStore.defaultStallThresholdSeconds
    ) {
        self.catalog = catalog
        self.defaults = defaults
        self.fileManager = fileManager
        self.downloader = downloader
        self.idleTimerController = idleTimerController
        self.stallThresholdSeconds = stallThresholdSeconds

        let directory = modelsDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VisionModels", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.modelsDirectory = directory
        llmModelURL = directory.appendingPathComponent(catalog.llmFileName)
        mmprojModelURL = directory.appendingPathComponent(catalog.mmprojFileName)

        let ready = catalog.artifacts.allSatisfy { artifact in
            fileManager.fileExists(atPath: directory.appendingPathComponent(artifact.fileName).path)
        }
        if ready {
            status = .ready
            defaults.set(true, forKey: Keys.readyFlag)
        } else {
            status = .notDownloaded
            defaults.set(false, forKey: Keys.readyFlag)
        }
    }

    func startDownload() async {
        guard !status.isDownloadSessionActive else { return }
        if case .stalled = status { return }
        if filesPresentOnDisk() {
            status = .ready
            defaults.set(true, forKey: Keys.readyFlag)
            return
        }

        status = .connecting(downloadedBytes: 0, totalBytes: catalog.approximateBytes)
        idleTimerController.setIdleTimerDisabled(true)
        beginStallMonitor()

        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                var completedBytes: Int64 = 0
                let artifactCount = max(self.catalog.artifacts.count, 1)
                for (index, artifact) in self.catalog.artifacts.enumerated() {
                    let destination = self.modelsDirectory.appendingPathComponent(artifact.fileName)
                    if self.fileManager.fileExists(atPath: destination.path) {
                        completedBytes += self.catalog.approximateBytes / Int64(artifactCount)
                        continue
                    }
                    let partial = destination.appendingPathExtension("partial")
                    try? self.fileManager.removeItem(at: partial)
                    let baseCompleted = completedBytes
                    try await self.downloader.download(from: artifact.remoteURL, to: partial) { [weak self] downloaded, total in
                        Task { @MainActor in
                            guard let self else { return }
                            guard self.status.isInDownloadFlow else { return }
                            let artifactExpected = total > 0 ? total : (self.catalog.approximateBytes / Int64(artifactCount))
                            let overallExpected = self.catalog.approximateBytes
                            let overallDownloaded = baseCompleted + downloaded
                            let fraction = overallExpected > 0
                                ? Double(overallDownloaded) / Double(overallExpected)
                                : (Double(index) + Double(downloaded) / Double(max(artifactExpected, 1))) / Double(artifactCount)

                            if overallDownloaded > 0 {
                                self.cancelStallMonitor()
                                self.status = .downloading(
                                    progress: min(0.99, max(0, fraction)),
                                    downloadedBytes: overallDownloaded,
                                    totalBytes: overallExpected
                                )
                            } else if case .connecting = self.status {
                                self.status = .connecting(
                                    downloadedBytes: overallDownloaded,
                                    totalBytes: overallExpected
                                )
                            }
                        }
                    }
                    try? self.fileManager.removeItem(at: destination)
                    try self.fileManager.moveItem(at: partial, to: destination)
                    let artifactBytes = (try? self.fileManager.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.int64Value
                        ?? (self.catalog.approximateBytes / Int64(artifactCount))
                    completedBytes += artifactBytes
                }
                self.cancelStallMonitor()
                self.status = .ready
                self.defaults.set(true, forKey: Keys.readyFlag)
            } catch is CancellationError {
                self.cancelStallMonitor()
                self.cleanupPartials()
                if case .stalled = self.status {
                    // Stall monitor cancelled the underlying download intentionally.
                } else if !self.filesPresentOnDisk() {
                    self.removeModelFiles()
                    self.status = .notDownloaded
                    self.defaults.set(false, forKey: Keys.readyFlag)
                }
            } catch {
                self.cancelStallMonitor()
                self.cleanupPartials()
                self.removeModelFiles()
                self.status = .failed(VisionModelDownloadFailure.map(from: error))
                self.defaults.set(false, forKey: Keys.readyFlag)
            }
            self.idleTimerController.setIdleTimerDisabled(false)
            self.downloadTask = nil
        }

        await downloadTask?.value
    }

    func retryDownload() async {
        switch status {
        case .stalled, .failed:
            break
        default:
            return
        }
        cancelStallMonitor()
        cleanupPartials()
        removeModelFiles()
        status = .notDownloaded
        defaults.set(false, forKey: Keys.readyFlag)
        await startDownload()
    }

    func cancelDownload() async {
        guard status.isInDownloadFlow else { return }
        cancelStallMonitor()
        downloader.cancel()
        downloadTask?.cancel()
        await downloadTask?.value
        cleanupPartials()
        if !filesPresentOnDisk() {
            removeModelFiles()
            status = .notDownloaded
            defaults.set(false, forKey: Keys.readyFlag)
        }
        idleTimerController.setIdleTimerDisabled(false)
    }

    func removeModel() {
        guard !status.isDownloadSessionActive else { return }
        removeModelFiles()
        cleanupPartials()
        status = .notDownloaded
        defaults.set(false, forKey: Keys.readyFlag)
    }

    func redownload() async {
        guard !status.isDownloadSessionActive else { return }
        removeModel()
        await startDownload()
    }

    private func beginStallMonitor() {
        cancelStallMonitor()
        let threshold = stallThresholdSeconds
        stallMonitorTask = Task { [weak self] in
            let nanos = UInt64(threshold * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                guard case let .connecting(downloaded, total) = self.status, downloaded == 0 else { return }
                self.downloader.cancel()
                self.downloadTask?.cancel()
                self.status = .stalled(downloadedBytes: downloaded, totalBytes: total)
                self.idleTimerController.setIdleTimerDisabled(false)
            }
        }
    }

    private func cancelStallMonitor() {
        stallMonitorTask?.cancel()
        stallMonitorTask = nil
    }

    private func filesPresentOnDisk() -> Bool {
        catalog.artifacts.allSatisfy { artifact in
            fileManager.fileExists(atPath: modelsDirectory.appendingPathComponent(artifact.fileName).path)
        }
    }

    private func removeModelFiles() {
        for artifact in catalog.artifacts {
            try? fileManager.removeItem(at: modelsDirectory.appendingPathComponent(artifact.fileName))
        }
    }

    private func cleanupPartials() {
        for artifact in catalog.artifacts {
            let destination = modelsDirectory.appendingPathComponent(artifact.fileName)
            try? fileManager.removeItem(at: destination.appendingPathExtension("partial"))
        }
    }
}

final class URLSessionVisionModelDownloader: NSObject, VisionModelDownloading, URLSessionDownloadDelegate {
    private var session: URLSession!
    private var progressHandler: (@Sendable (Int64, Int64) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private var activeTask: URLSessionDownloadTask?

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        progressHandler = progress
        let tempURL: URL = try await withCheckedThrowingContinuation { cont in
            continuation = cont
            let task = session.downloadTask(with: url)
            activeTask = task
            task.resume()
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        progressHandler = nil
        activeTask = nil
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: CancellationError())
        }
        progressHandler = nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progressHandler?(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("vision-download-\(UUID().uuidString)")
        do {
            try FileManager.default.copyItem(at: location, to: temp)
            continuation?.resume(returning: temp)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled {
            continuation?.resume(throwing: CancellationError())
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
        progressHandler = nil
        activeTask = nil
    }
}

struct SystemIdleTimerController: IdleTimerControlling {
    func setIdleTimerDisabled(_ disabled: Bool) {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
        #endif
    }
}
