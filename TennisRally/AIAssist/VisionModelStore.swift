import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class VisionModelStore: ObservableObject, VisionModelReadiness {
    enum Keys {
        static let readyFlag = "ai.vision_model.ready"
    }

    let catalog: VisionModelCatalog
    let modelFileURL: URL

    @Published private(set) var status: VisionModelStatus

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let downloader: VisionModelDownloading
    private let idleTimerController: IdleTimerControlling
    private var downloadTask: Task<Void, Never>?

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    var settingsSubtitleKey: String {
        switch status {
        case .notDownloaded, .failed:
            return "ai.model.status.not_downloaded"
        case .downloading:
            return "ai.model.status.downloading"
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
        idleTimerController: IdleTimerControlling = SystemIdleTimerController()
    ) {
        self.catalog = catalog
        self.defaults = defaults
        self.fileManager = fileManager
        self.downloader = downloader
        self.idleTimerController = idleTimerController

        let directory = modelsDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VisionModels", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        modelFileURL = directory.appendingPathComponent(catalog.fileName)

        if fileManager.fileExists(atPath: modelFileURL.path) {
            status = .ready
            defaults.set(true, forKey: Keys.readyFlag)
        } else {
            status = .notDownloaded
            defaults.set(false, forKey: Keys.readyFlag)
        }
    }

    func startDownload() async {
        guard !status.isDownloading else { return }
        if fileManager.fileExists(atPath: modelFileURL.path) {
            status = .ready
            defaults.set(true, forKey: Keys.readyFlag)
            return
        }

        status = .downloading(progress: 0, downloadedBytes: 0, totalBytes: catalog.approximateBytes)
        idleTimerController.setIdleTimerDisabled(true)

        let destination = modelFileURL
        let remote = catalog.remoteURL
        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let partial = destination.appendingPathExtension("partial")
                try? self.fileManager.removeItem(at: partial)
                try await self.downloader.download(from: remote, to: partial) { [weak self] downloaded, total in
                    Task { @MainActor in
                        guard let self else { return }
                        guard case .downloading = self.status else { return }
                        let expected = total > 0 ? total : self.catalog.approximateBytes
                        let fraction = expected > 0 ? Double(downloaded) / Double(expected) : 0
                        self.status = .downloading(
                            progress: min(0.99, max(0, fraction)),
                            downloadedBytes: downloaded,
                            totalBytes: expected
                        )
                    }
                }
                try? self.fileManager.removeItem(at: destination)
                try self.fileManager.moveItem(at: partial, to: destination)
                self.status = .ready
                self.defaults.set(true, forKey: Keys.readyFlag)
            } catch is CancellationError {
                try? self.fileManager.removeItem(at: destination.appendingPathExtension("partial"))
                try? self.fileManager.removeItem(at: destination)
                self.status = .notDownloaded
                self.defaults.set(false, forKey: Keys.readyFlag)
            } catch {
                try? self.fileManager.removeItem(at: destination.appendingPathExtension("partial"))
                try? self.fileManager.removeItem(at: destination)
                self.status = .failed(message: error.localizedDescription)
                self.defaults.set(false, forKey: Keys.readyFlag)
            }
            self.idleTimerController.setIdleTimerDisabled(false)
            self.downloadTask = nil
        }

        await downloadTask?.value
    }

    func cancelDownload() async {
        guard status.isDownloading else { return }
        downloader.cancel()
        downloadTask?.cancel()
        await downloadTask?.value
        try? fileManager.removeItem(at: modelFileURL.appendingPathExtension("partial"))
        try? fileManager.removeItem(at: modelFileURL)
        status = .notDownloaded
        defaults.set(false, forKey: Keys.readyFlag)
        idleTimerController.setIdleTimerDisabled(false)
    }

    func removeModel() {
        guard !status.isDownloading else { return }
        try? fileManager.removeItem(at: modelFileURL)
        try? fileManager.removeItem(at: modelFileURL.appendingPathExtension("partial"))
        status = .notDownloaded
        defaults.set(false, forKey: Keys.readyFlag)
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
