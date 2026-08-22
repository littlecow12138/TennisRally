import XCTest
@testable import TennisRally

@MainActor
final class VisionModelStoreTests: XCTestCase {
    private var fileManager: FileManager!
    private var rootURL: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        fileManager = .default
        rootURL = fileManager.temporaryDirectory.appendingPathComponent("VisionModelStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        suiteName = "VisionModelStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: rootURL)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testStartsNotDownloadedWhenFileMissing() {
        let store = makeStore(downloader: MockVisionModelDownloader())
        XCTAssertEqual(store.status, .notDownloaded)
        XCTAssertFalse(store.isReady)
        XCTAssertEqual(store.settingsSubtitleKey, "ai.model.status.not_downloaded")
    }

    func testDownloadProgressThenReadyForBothArtifacts() async {
        let downloader = MockVisionModelDownloader()
        downloader.progressSteps = [(500, 1000), (1000, 1000)]
        let store = makeStore(downloader: downloader)

        await store.startDownload()

        XCTAssertEqual(store.status, .ready)
        XCTAssertTrue(store.isReady)
        XCTAssertEqual(store.settingsSubtitleKey, "ai.model.status.ready")
        XCTAssertTrue(fileManager.fileExists(atPath: store.llmModelURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: store.mmprojModelURL.path))
        XCTAssertEqual(defaults.bool(forKey: VisionModelStore.Keys.readyFlag), true)
    }

    func testCancelLeavesNotDownloadedAndCleansPartial() async {
        let downloader = MockVisionModelDownloader()
        downloader.hangUntilCancelled = true
        let store = makeStore(downloader: downloader)

        let task = Task { await store.startDownload() }
        await waitUntil { if case .connecting = store.status { return true }; return store.status.isDownloading }
        await store.cancelDownload()
        await task.value

        XCTAssertEqual(store.status, .notDownloaded)
        XCTAssertFalse(store.isReady)
        XCTAssertFalse(fileManager.fileExists(atPath: store.llmModelURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: store.mmprojModelURL.path))
    }

    func testRemoveDeletesReadyModel() async {
        let downloader = MockVisionModelDownloader()
        downloader.progressSteps = [(10, 10)]
        let store = makeStore(downloader: downloader)
        await store.startDownload()
        XCTAssertTrue(store.isReady)

        store.removeModel()

        XCTAssertEqual(store.status, .notDownloaded)
        XCTAssertFalse(store.isReady)
        XCTAssertFalse(fileManager.fileExists(atPath: store.llmModelURL.path))
        XCTAssertFalse(defaults.bool(forKey: VisionModelStore.Keys.readyFlag))
    }

    func testRedownloadReplacesReadyFiles() async {
        let downloader = MockVisionModelDownloader()
        downloader.progressSteps = [(10, 10)]
        let store = makeStore(downloader: downloader)
        await store.startDownload()
        let firstLLM = try? Data(contentsOf: store.llmModelURL)

        downloader.payload = Data("model-v2".utf8)
        await store.redownload()

        XCTAssertEqual(store.status, .ready)
        let secondLLM = try? Data(contentsOf: store.llmModelURL)
        XCTAssertNotEqual(firstLLM, secondLLM)
        XCTAssertEqual(secondLLM, Data("model-v2".utf8))
    }

    func testRelaunchRestoresReadyWhenFilesPresent() async {
        let downloader = MockVisionModelDownloader()
        downloader.progressSteps = [(10, 10)]
        let store = makeStore(downloader: downloader)
        await store.startDownload()

        let relaunched = makeStore(downloader: MockVisionModelDownloader())
        XCTAssertEqual(relaunched.status, .ready)
        XCTAssertTrue(relaunched.isReady)
    }

    // MARK: - LCOW-19 TC-01 … TC-14

    func testTC01_startDownloadShowsConnectingAtZeroPercent() async {
        let downloader = MockVisionModelDownloader()
        downloader.hangUntilCancelled = true
        let store = makeStore(downloader: downloader, stallThresholdSeconds: 60)

        let task = Task { await store.startDownload() }
        await waitUntil {
            if case let .connecting(downloaded, total) = store.status {
                return downloaded == 0 && total == VisionModelCatalog.miniCPMV4.approximateBytes
            }
            return false
        }

        if case let .connecting(downloaded, total) = store.status {
            XCTAssertEqual(downloaded, 0)
            XCTAssertEqual(total, VisionModelCatalog.miniCPMV4.approximateBytes)
            XCTAssertEqual(store.downloadProgressPercent, 0)
            XCTAssertEqual(store.settingsSubtitleKey, "ai.model.status.downloading")
        } else {
            XCTFail("Expected connecting state")
        }

        await store.cancelDownload()
        await task.value
    }

    func testTC02_byteProgressTransitionsToDownloading() async {
        let downloader = MockVisionModelDownloader()
        downloader.progressSteps = [(500, 1000)]
        downloader.slowAfterFirstProgress = true
        let store = makeStore(downloader: downloader, stallThresholdSeconds: 60)

        let task = Task { await store.startDownload() }
        await waitUntil {
            if case .downloading = store.status { return true }
            return false
        }

        if case let .downloading(_, downloaded, _) = store.status {
            XCTAssertGreaterThan(downloaded, 0)
        } else {
            XCTFail("Expected downloading state")
        }

        await store.cancelDownload()
        await task.value
        XCTAssertEqual(store.status, .notDownloaded)
    }

    func testTC03_stalledRetryReturnsToConnecting() async {
        let downloader = MockVisionModelDownloader()
        downloader.hangUntilCancelled = true
        let store = makeStore(downloader: downloader, stallThresholdSeconds: 0.05)

        let task = Task { await store.startDownload() }
        await waitUntil {
            if case .stalled = store.status { return true }
            return false
        }
        await task.value

        let retryTask = Task { await store.retryDownload() }
        await waitUntil {
            if case .connecting = store.status { return true }
            return false
        }
        await store.cancelDownload()
        await retryTask.value

        XCTAssertEqual(store.status, .notDownloaded)
    }

    func testTC04_failedRetryReturnsToConnecting() async {
        let downloader = MockVisionModelDownloader()
        downloader.failure = URLError(.notConnectedToInternet)
        downloader.failOnceThenHang = true
        let store = makeStore(downloader: downloader, stallThresholdSeconds: 60)

        await store.startDownload()
        guard case .failed = store.status else {
            return XCTFail("Expected failed state")
        }

        let retryTask = Task { await store.retryDownload() }
        await waitUntil {
            if case .connecting = store.status { return true }
            return false
        }
        await store.cancelDownload()
        await retryTask.value
    }

    func testTC05_cancelFromConnectingStalledAndDownloadingReturnsIdle() async {
        let connectingDownloader = MockVisionModelDownloader()
        connectingDownloader.hangUntilCancelled = true
        let connectingStore = makeStore(downloader: connectingDownloader, stallThresholdSeconds: 60)
        let connectingTask = Task { await connectingStore.startDownload() }
        await waitUntil { if case .connecting = connectingStore.status { return true }; return false }
        await connectingStore.cancelDownload()
        await connectingTask.value
        XCTAssertEqual(connectingStore.status, .notDownloaded)

        let stalledDownloader = MockVisionModelDownloader()
        stalledDownloader.hangUntilCancelled = true
        let stalledStore = makeStore(downloader: stalledDownloader, stallThresholdSeconds: 0.05)
        let stalledTask = Task { await stalledStore.startDownload() }
        await waitUntil { if case .stalled = stalledStore.status { return true }; return false }
        await stalledTask.value
        await stalledStore.cancelDownload()
        XCTAssertEqual(stalledStore.status, .notDownloaded)
        XCTAssertFalse(stalledStore.isReady)

        let downloadingDownloader = MockVisionModelDownloader()
        downloadingDownloader.progressSteps = [(1, 1000)]
        downloadingDownloader.slowAfterFirstProgress = true
        let downloadingStore = makeStore(downloader: downloadingDownloader, stallThresholdSeconds: 60)
        let downloadingTask = Task { await downloadingStore.startDownload() }
        await waitUntil { if case .downloading = downloadingStore.status { return true }; return false }
        await downloadingStore.cancelDownload()
        await downloadingTask.value
        XCTAssertEqual(downloadingStore.status, .notDownloaded)
    }

    func testTC07_zeroProgressTimeoutEntersStalled() async {
        let downloader = MockVisionModelDownloader()
        downloader.hangUntilCancelled = true
        let store = makeStore(downloader: downloader, stallThresholdSeconds: 0.05)

        let task = Task { await store.startDownload() }
        await waitUntil {
            if case let .stalled(downloaded, _) = store.status {
                return downloaded == 0
            }
            return false
        }
        await task.value

        if case .stalled = store.status {
            XCTAssertEqual(store.settingsSubtitleKey, "ai.model.status.stalled")
        } else {
            XCTFail("Expected stalled state")
        }
    }

    func testTC08_hardErrorEntersFailedNotIdle() async {
        let downloader = MockVisionModelDownloader()
        downloader.failure = URLError(.timedOut)
        let store = makeStore(downloader: downloader)

        await store.startDownload()

        guard case .failed = store.status else {
            return XCTFail("Expected failed, got \(store.status)")
        }
        XCTAssertFalse(store.isReady)
        XCTAssertEqual(store.settingsSubtitleKey, "ai.model.status.failed")
    }

    func testTC09_networkAndStorageFailuresMapToReadableReasons() {
        XCTAssertEqual(
            VisionModelDownloadFailure.map(from: URLError(.notConnectedToInternet)),
            .network
        )
        let storageError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        XCTAssertEqual(VisionModelDownloadFailure.map(from: storageError), .storage)
        XCTAssertEqual(
            VisionModelDownloadFailure.map(from: NSError(domain: "test", code: 1)).bodyLocalizationKey,
            VisionModelDownloadFailure.generic.bodyLocalizationKey
        )
    }

    func testTC10_failedSettingsSubtitleAndRetryDownload() async {
        let downloader = MockVisionModelDownloader()
        downloader.failure = URLError(.cannotFindHost)
        downloader.failOnceThenHang = true
        let store = makeStore(downloader: downloader, stallThresholdSeconds: 60)
        await store.startDownload()

        XCTAssertEqual(store.settingsSubtitleKey, "ai.model.status.failed")

        let task = Task { await store.retryDownload() }
        await waitUntil { if case .connecting = store.status { return true }; return false }
        await store.cancelDownload()
        await task.value
    }

    func testTC11_defaultStallThresholdWithinDesignWindow() {
        XCTAssertGreaterThanOrEqual(VisionModelStore.defaultStallThresholdSeconds, 20)
        XCTAssertLessThanOrEqual(VisionModelStore.defaultStallThresholdSeconds, 30)
    }

    func testTC12_connectingStalledAndFailedAreDistinctStates() {
        let connecting = VisionModelStatus.connecting(downloadedBytes: 0, totalBytes: 100)
        let stalled = VisionModelStatus.stalled(downloadedBytes: 0, totalBytes: 100)
        let failed = VisionModelStatus.failed(.network)

        XCTAssertNotEqual(connecting, stalled)
        XCTAssertNotEqual(connecting, failed)
        XCTAssertNotEqual(stalled, failed)
        XCTAssertTrue(connecting.isInDownloadFlow)
        XCTAssertTrue(stalled.isInDownloadFlow)
        XCTAssertFalse(failed.isInDownloadFlow)
    }

    func testTC13_settingsSubtitleKeysForStalledAndFailed() async {
        let stalledDownloader = MockVisionModelDownloader()
        stalledDownloader.hangUntilCancelled = true
        let stalledStore = makeStore(downloader: stalledDownloader, stallThresholdSeconds: 0.05)
        let stalledTask = Task { await stalledStore.startDownload() }
        await waitUntil { if case .stalled = stalledStore.status { return true }; return false }
        await stalledTask.value
        XCTAssertEqual(stalledStore.settingsSubtitleKey, "ai.model.status.stalled")

        let failedDownloader = MockVisionModelDownloader()
        failedDownloader.failure = URLError(.timedOut)
        let failedStore = makeStore(downloader: failedDownloader)
        await failedStore.startDownload()
        XCTAssertEqual(failedStore.settingsSubtitleKey, "ai.model.status.failed")
    }

    func testTC14_failedStateRemainsDistinctFromIdle() async {
        let downloader = MockVisionModelDownloader()
        downloader.failure = URLError(.notConnectedToInternet)
        let store = makeStore(downloader: downloader)
        await store.startDownload()

        guard case .failed = store.status else {
            return XCTFail("Expected failed state")
        }
        XCTAssertNotEqual(store.status, .notDownloaded)
        XCTAssertEqual(
            AppLocalization.text("ai.model.cellular_warning", locale: Locale(identifier: "en")),
            "Download uses cellular data if Wi-Fi is unavailable."
        )
    }

    private func makeStore(
        downloader: VisionModelDownloading,
        stallThresholdSeconds: TimeInterval = 0.05
    ) -> VisionModelStore {
        VisionModelStore(
            catalog: .miniCPMV4,
            modelsDirectory: rootURL,
            defaults: defaults,
            downloader: downloader,
            idleTimerController: NoopIdleTimerController(),
            stallThresholdSeconds: stallThresholdSeconds
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ predicate: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Condition not met before timeout")
    }
}

@MainActor
final class MockVisionModelDownloader: VisionModelDownloading {
    var progressSteps: [(Int64, Int64)] = [(1, 1)]
    var hangUntilCancelled = false
    var slowAfterFirstProgress = false
    var failOnceThenHang = false
    var payload = Data("model".utf8)
    var failure: Error?
    private(set) var cancelCount = 0
    private var attemptCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var cancelled = false

    func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        attemptCount += 1
        cancelled = false
        if failOnceThenHang, attemptCount == 1, let failure {
            throw failure
        }
        if !failOnceThenHang, let failure {
            throw failure
        }
        let shouldHang = hangUntilCancelled || (failOnceThenHang && attemptCount > 1)
        if shouldHang {
            if cancelled { throw CancellationError() }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                if cancelled {
                    cont.resume()
                } else {
                    continuation = cont
                }
            }
            throw CancellationError()
        }
        for (index, step) in progressSteps.enumerated() {
            progress(step.0, step.1)
            if slowAfterFirstProgress, index == 0 {
                if cancelled { throw CancellationError() }
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    if cancelled {
                        cont.resume()
                    } else {
                        continuation = cont
                    }
                }
                throw CancellationError()
            }
        }
        try payload.write(to: destination, options: .atomic)
    }

    func cancel() {
        cancelCount += 1
        cancelled = true
        continuation?.resume()
        continuation = nil
    }
}

struct NoopIdleTimerController: IdleTimerControlling {
    func setIdleTimerDisabled(_ disabled: Bool) {}
}
