import SwiftUI

struct OfflineProcessingView: View {
    @EnvironmentObject private var store: AppSessionStore

    var body: some View {
        ZStack {
            CourtBackdrop()
            if let job = store.processing {
                processingContent(job)
            } else {
                idleContent
            }
        }
    }

    private func processingContent(_ job: ProcessingState) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    store.selectedTab = .library
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HardCourt.accent)
                }
                Spacer()
                Text(String(localized: "process.title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HardCourt.text)
                Spacer()
                Color.clear.frame(width: 18, height: 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 18) {
                    VideoPlaceholder(height: 200)
                        .padding(.horizontal, 20)
                    Text(job.filename)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(HardCourt.text)

                    ZStack {
                        Circle()
                            .stroke(HardCourt.surface, lineWidth: 10)
                            .frame(width: 148, height: 148)
                        Circle()
                            .trim(from: 0, to: job.progress)
                            .stroke(HardCourt.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 148, height: 148)
                        Text("\(job.progressPercent)%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(HardCourt.text)
                    }
                    .padding(.top, 8)

                    Text(String(localized: "process.detecting"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(HardCourt.text)
                    Text(String(localized: "process.offline"))
                        .font(.system(size: 14))
                        .foregroundStyle(HardCourt.muted)
                    Text(String(format: String(localized: "process.clip_progress"), job.detectedClipCount, job.estimatedClipCount))
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.muted)

                    HStack(spacing: 12) {
                        Button(String(localized: "process.cancel")) {
                            store.cancelProcessing()
                        }
                        .foregroundStyle(HardCourt.danger)
                        .font(.system(size: 16, weight: .semibold))

                        Button {
                            store.completeProcessing()
                        } label: {
                            Text("Demo finish")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HardCourt.accent)
                        }
                    }
                    .padding(.top, 28)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private var idleContent: some View {
        VStack(spacing: 18) {
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
            Text(String(localized: "process.idle_title"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(HardCourt.text)
            Text(String(localized: "process.idle_body"))
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            if let video = store.activeVideo, video.status != .processed {
                PrimaryButton(titleKey: "process.start", systemImage: "bolt.horizontal.circle") {
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
                .padding(.horizontal, 20)
                .padding(.top, 8)
            } else {
                Button(String(localized: "tab.library")) {
                    store.selectedTab = .library
                }
                .foregroundStyle(HardCourt.accent)
                .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}
