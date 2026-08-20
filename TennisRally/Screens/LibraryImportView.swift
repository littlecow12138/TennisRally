import SwiftUI

struct LibraryImportView: View {
    @EnvironmentObject private var store: AppSessionStore

    var body: some View {
        ZStack {
            CourtBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    PrimaryButton(titleKey: "library.import", systemImage: "square.and.arrow.up") {
                        store.importDemoVideo(named: "Saturday practice", duration: 724)
                        store.bumpProcessingProgress(to: 0.62)
                    }

                    if store.videos.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.videos) { video in
                            videoRow(video)
                        }
                        dropZone
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Image("LogoLockup")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .accessibilityLabel("TennisRally")
                Text(String(localized: "library.tagline"))
                    .font(.system(size: 15))
                    .foregroundStyle(HardCourt.muted)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 12, weight: .medium))
                Text(String(localized: "library.works_offline"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(HardCourt.muted)
            .padding(.top, 4)
        }
    }

    private func videoRow(_ video: LibraryVideo) -> some View {
        Button {
            store.activeVideoID = video.id
            if video.status == .processed {
                store.selectedTab = .rallies
            } else {
                store.selectedTab = .process
                if store.processing == nil {
                    store.processing = ProcessingState(
                        videoID: video.id,
                        filename: video.filename,
                        progress: 0.62,
                        estimatedClipCount: 18,
                        detectedClipCount: 7
                    )
                    if let index = store.videos.firstIndex(where: { $0.id == video.id }) {
                        store.videos[index].status = .processing
                    }
                }
            }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HardCourt.surface)
                    .frame(width: 72, height: 54)
                    .overlay {
                        Image(systemName: "camera.viewfinder")
                            .foregroundStyle(HardCourt.accent.opacity(0.8))
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HardCourt.text)
                    Text("\(video.durationLabel) • \(NSLocalizedString(video.statusLabelKey, comment: ""))")
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HardCourt.muted)
            }
            .padding(12)
            .background(HardCourt.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(HardCourt.muted)
            Text(String(localized: "library.drop_hint"))
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [7, 6]))
                .foregroundStyle(HardCourt.muted.opacity(0.55))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            Text(String(localized: "library.empty_title"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HardCourt.text)
            Text(String(localized: "library.empty_body"))
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.muted)
                .multilineTextAlignment(.center)
            dropZone
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}
