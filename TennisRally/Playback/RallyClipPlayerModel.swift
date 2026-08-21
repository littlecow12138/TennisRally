import AVFoundation
import Combine
import Foundation

@MainActor
final class RallyClipPlayerModel: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var loadErrorKey: String?
    @Published private(set) var isReady = false

    let player = AVPlayer()
    private var bounds: RallyPlaybackBounds
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var isSeeking = false

    init(bounds: RallyPlaybackBounds) {
        self.bounds = bounds
        self.currentTime = bounds.start
    }

    deinit {
        // Avoid MainActor isolation issues in deinit by clearing synchronously.
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObserver?.invalidate()
    }

    func updateBounds(_ newBounds: RallyPlaybackBounds) {
        bounds = newBounds
        currentTime = bounds.clamp(currentTime)
        if isReady {
            seek(to: currentTime, resume: isPlaying)
        }
    }

    func load(source: RallyVideoSource) {
        tearDownObservers()
        player.pause()
        isPlaying = false
        isReady = false
        loadErrorKey = nil
        currentTime = bounds.start

        switch source {
        case .missing:
            player.replaceCurrentItem(with: nil)
            loadErrorKey = "playback.missing_file"
        case .unavailable:
            player.replaceCurrentItem(with: nil)
            loadErrorKey = "playback.file_unavailable"
        case .ready(let url):
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            observeStatus(of: item)
            installTimeObserver()
            installEndObserver(for: item)
            seek(to: bounds.start, resume: false)
        }
    }

    func togglePlayPause() {
        guard isReady, loadErrorKey == nil else { return }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard isReady, loadErrorKey == nil else { return }
        if bounds.hasReachedEnd(currentTime) {
            seek(to: bounds.start, resume: true)
            return
        }
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func scrub(to time: TimeInterval) {
        let clamped = bounds.clamp(time)
        currentTime = clamped
        seek(to: clamped, resume: false)
    }

    func scrub(progress: Double) {
        scrub(to: bounds.time(forProgress: progress))
    }

    var progress: Double {
        bounds.progress(at: currentTime)
    }

    var displayTimeLabel: String {
        Rally.formatClock(currentTime)
    }

    var durationLabel: String {
        Rally.formatClock(bounds.duration)
    }

    private func seek(to time: TimeInterval, resume: Bool) {
        let clamped = bounds.clamp(time)
        isSeeking = true
        let cm = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                guard let self else { return }
                self.isSeeking = false
                if finished {
                    self.currentTime = clamped
                    if resume {
                        self.player.play()
                        self.isPlaying = true
                    }
                }
            }
        }
    }

    private func installTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.isSeeking else { return }
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                self.currentTime = self.bounds.clamp(seconds)
                if self.bounds.hasReachedEnd(seconds) {
                    self.pause()
                    self.seek(to: self.bounds.end, resume: false)
                }
            }
        }
    }

    private func installEndObserver(for item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.pause()
                self.seek(to: self.bounds.end, resume: false)
            }
        }
    }

    private func observeStatus(of item: AVPlayerItem) {
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isReady = true
                    self.loadErrorKey = nil
                case .failed:
                    self.isReady = false
                    self.loadErrorKey = "playback.decode_failed"
                    self.pause()
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func tearDownObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
    }
}
