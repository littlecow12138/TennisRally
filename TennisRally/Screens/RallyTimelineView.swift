import SwiftUI

struct RallyTimelineView: View {
    @EnvironmentObject private var store: AppSessionStore
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            CourtBackdrop()
            VStack(spacing: 0) {
                navBar
                if store.rallies.isEmpty {
                    Spacer()
                    Text("rallies.empty")
                        .font(.system(size: 15))
                        .foregroundStyle(HardCourt.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                } else {
                    header
                    list
                }
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button {
                store.selectedTab = .library
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HardCourt.accent)
            }
            Spacer()
            Text("rallies.title")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HardCourt.text)
            Spacer()
            Text("rallies.edit")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HardCourt.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.activeVideo?.title ?? "Saturday practice")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(HardCourt.text)
            Text(AppLocalization.format(
                "rallies.count",
                locale: locale,
                store.rallies.count as CVarArg,
                (store.activeVideo?.durationLabel ?? "12:04") as CVarArg
            ))
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.muted)

            HStack(spacing: 14) {
                Button("rallies.review_all") {
                    if let first = store.rallies.first {
                        store.openReview(for: first)
                    }
                }
                .foregroundStyle(HardCourt.accent)
                Rectangle()
                    .fill(HardCourt.muted.opacity(0.5))
                    .frame(width: 1, height: 14)
                Button("rallies.export") {}
                    .foregroundStyle(HardCourt.accent)
            }
            .font(.system(size: 15, weight: .semibold))

            Divider().overlay(HardCourt.hairline)
            Text("rallies.hint")
                .font(.system(size: 12))
                .foregroundStyle(HardCourt.muted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.rallies) { rally in
                    Button {
                        store.openCorrection(for: rally)
                    } label: {
                        HStack(spacing: 10) {
                            RallyThumbnailView(
                                source: store.videoSourceForActiveClip,
                                time: rally.start,
                                size: CGSize(width: 56, height: 36)
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(AppLocalization.format("common.rally", locale: locale, rally.index as CVarArg))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(HardCourt.text)
                                Text(rally.timeRangeLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(HardCourt.muted)
                            }
                            .frame(width: 78, alignment: .leading)

                            WaveformBar(seed: rally.index)
                                .frame(maxWidth: .infinity)

                            Text(rally.durationLabel)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(HardCourt.text)
                                .frame(width: 36, alignment: .trailing)

                            HStack(spacing: 2) {
                                Text("rallies.correct")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HardCourt.accent)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(HardCourt.hairline).padding(.leading, 20)
                }
            }
            .padding(.bottom, 24)
        }
    }
}
