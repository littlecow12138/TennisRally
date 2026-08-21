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

    func testDownloadProgressThenReady() async {
        let downloader = MockVisionModelDownloader()
        downloader.progressSteps = [(500, 1000), (1000, 1000)]
        let store = makeStore(downloader: downloader)

        await store.startDownload()

        XCTAssertEqual(store.status, .ready)
        XCTAssertTrue(store.isReady)
        XCTAssertEqual(store.settingsSubtitleKey, "ai.model.status.ready")
        XCTAssertTrue(fileManager.fileExists(atPath: store.modelFileURL.path))
        XCTAssertEqual(defaults.bool(forKey: VisionModelStore.Keys.readyFlag), true)
    }

    func testCancelLeavesNotDownloadedAndCleansPartial() async {
        let downloader = MockVisionModelDownloader()
        downloader.hangUntilCancelled = true
        let store = makeStore(downloader: downloader)

        let task = Task { await store.startDownload() }
        await waitUntil { store.status.isDownloading }
        await store.cancelDownload()
        await task.value

        XCTAssertEqual(store.status, .notDownloaded)
        XCTAssertFalse(store.isReady)
        XCTAssertFalse(fileManager.fileExists(atPath: store.modelFileURL.path))
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
        XCTAssertFalse(fileManager.fileExists(atPath: store.modelFileURL.path))
        XCTAssertFalse(defaults.bool(forKey: VisionModelStore.Keys.readyFlag))
    }

    func testRelaunchRestoresReadyWhenFilePresent() async {
        let downloader = MockVisionModelDownloader()
        downloader.progressSteps = [(10, 10)]
        let store = makeStore(downloader: downloader)
        await store.startDownload()

        let relaunched = makeStore(downloader: MockVisionModelDownloader())
        XCTAssertEqual(relaunched.status, .ready)
        XCTAssertTrue(relaunched.isReady)
    }

    private func makeStore(downloader: VisionModelDownloading) -> VisionModelStore {
        VisionModelStore(
            catalog: .miniCPMV4,
            modelsDirectory: rootURL,
            defaults: defaults,
            downloader: downloader,
            idleTimerController: NoopIdleTimerController()
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
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
    private(set) var cancelCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var cancelled = false

    func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        if hangUntilCancelled {
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
        for step in progressSteps {
            progress(step.0, step.1)
        }
        try Data("model".utf8).write(to: destination, options: .atomic)
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
