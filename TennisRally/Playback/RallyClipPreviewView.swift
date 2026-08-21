import AVFoundation
import SwiftUI
import UIKit

struct RallyPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

struct RallyClipPreviewView: View {
    @StateObject private var model: RallyClipPlayerModel
    let source: RallyVideoSource
    let start: TimeInterval
    let end: TimeInterval
    var height: CGFloat = 220
    var showsScrubber: Bool = true

    init(
        source: RallyVideoSource,
        start: TimeInterval,
        end: TimeInterval,
        height: CGFloat = 220,
        showsScrubber: Bool = true
    ) {
        self.source = source
        self.start = start
        self.end = end
        self.height = height
        self.showsScrubber = showsScrubber
        _model = StateObject(
            wrappedValue: RallyClipPlayerModel(
                bounds: RallyPlaybackBounds(start: start, end: end)
            )
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black)
                if model.loadErrorKey == nil {
                    RallyPlayerLayerView(player: model.player)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let key = model.loadErrorKey {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(HardCourt.accent)
                        Text(LocalizedStringKey(key))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HardCourt.text)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                } else if !model.isReady {
                    ProgressView()
                        .tint(HardCourt.accent)
                }
            }
            .frame(height: height)

            if showsScrubber {
                HStack(spacing: 12) {
                    Button {
                        model.togglePlayPause()
                    } label: {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HardCourt.text)
                            .frame(width: 28, height: 28)
                    }
                    .disabled(model.loadErrorKey != nil)
                    .accessibilityLabel(Text(model.isPlaying ? "playback.pause" : "playback.play"))

                    GeometryReader { geo in
                        let width = max(geo.size.width, 1)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(HardCourt.surface)
                                .frame(height: 4)
                            Capsule()
                                .fill(HardCourt.accent)
                                .frame(width: width * model.progress, height: 4)
                            Circle()
                                .fill(HardCourt.text)
                                .frame(width: 12, height: 12)
                                .offset(x: width * model.progress - 6)
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let p = min(max(value.location.x / width, 0), 1)
                                    model.scrub(progress: p)
                                }
                        )
                    }
                    .frame(height: 24)

                    Text("\(model.displayTimeLabel) / \(model.durationLabel)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(HardCourt.muted)
                        .frame(minWidth: 72, alignment: .trailing)
                }
            }
        }
        .onAppear {
            model.load(source: source)
            model.updateBounds(RallyPlaybackBounds(start: start, end: end))
        }
        .onChange(of: source) { _, newSource in
            model.load(source: newSource)
        }
        .onChange(of: start) { _, newStart in
            model.updateBounds(RallyPlaybackBounds(start: newStart, end: end))
        }
        .onChange(of: end) { _, newEnd in
            model.updateBounds(RallyPlaybackBounds(start: start, end: newEnd))
        }
        .onDisappear {
            model.pause()
        }
    }
}

struct RallyThumbnailView: View {
    let source: RallyVideoSource
    let time: TimeInterval
    var size: CGSize = CGSize(width: 64, height: 40)

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HardCourt.surface)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if failed || !isReadySource {
                Image(systemName: "film")
                    .font(.system(size: 14))
                    .foregroundStyle(HardCourt.muted)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(HardCourt.accent)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: thumbnailTaskID) {
            await loadThumbnail()
        }
    }

    private var isReadySource: Bool {
        if case .ready = source { return true }
        return false
    }

    private var sourceURL: URL? {
        if case .ready(let url) = source { return url }
        return nil
    }

    private var thumbnailTaskID: String {
        "\(sourceURL?.path ?? "none")-\(time)"
    }

    private func loadThumbnail() async {
        image = nil
        failed = false
        guard case .ready(let url) = source else {
            failed = true
            return
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: size.width * 3, height: size.height * 3)
        let cm = CMTime(seconds: max(0, time), preferredTimescale: 600)
        do {
            let cgImage = try await generator.image(at: cm).image
            image = UIImage(cgImage: cgImage)
        } catch {
            failed = true
        }
    }
}
