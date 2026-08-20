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
        .alert(
            String(localized: "error.title"),
            isPresented: Binding(
                get: { store.alertMessage != nil && store.selectedTab == .process },
                set: { if !$0 { store.alertMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {
                store.alertMessage = nil
            }
        } message: {
            Text(store.alertMessage ?? "")
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

                    Text(NSLocalizedString(job.statusMessageKey, comment: ""))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(HardCourt.text)
                    Text(String(localized: "process.offline"))
                        .font(.system(size: 14))
                        .foregroundStyle(HardCourt.muted)
                    Text(String(format: String(localized: "process.clip_progress"), job.detectedClipCount, job.estimatedClipCount))
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.muted)

                    Button(String(localized: "process.cancel")) {
                        store.cancelProcessing()
                    }
                    .foregroundStyle(HardCourt.danger)
                    .font(.system(size: 16, weight: .semibold))
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

            if let video = store.activeVideo {
                if video.status == .failed {
                    Text(video.lastErrorMessage ?? String(localized: "error.decode_failed"))
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if video.localURL != nil, video.status != .processed {
                    PrimaryButton(titleKey: "process.start", systemImage: "bolt.horizontal.circle") {
                        store.startProcessing(for: video.id)
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
