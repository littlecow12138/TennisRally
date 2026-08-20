import SwiftUI

struct ReviewExportView: View {
    @EnvironmentObject private var store: AppSessionStore
    let rally: Rally

    private var current: Rally {
        store.rallies.first(where: { $0.id == store.reviewingRallyID }) ?? rally
    }

    private var currentIndex: Int {
        store.rallies.firstIndex(where: { $0.id == current.id }) ?? 0
    }

    var body: some View {
        ZStack {
            CourtBackdrop()
            VStack(spacing: 18) {
                nav
                videoBlock
                meta
                neighborNav
                PrimaryButton(titleKey: "review.export_clip", systemImage: "square.and.arrow.down") {}
                    .padding(.horizontal, 20)
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(String(localized: "review.share_photos"))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HardCourt.text)
                }
                Text(String(localized: "review.export_note"))
                    .font(.system(size: 12))
                    .foregroundStyle(HardCourt.muted)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var nav: some View {
        HStack {
            Button {
                store.showReview = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HardCourt.text)
                    .frame(width: 32, height: 32)
                    .background(HardCourt.surface, in: Circle())
            }
            Spacer()
            Text(String(format: String(localized: "common.rally"), current.index))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(HardCourt.text)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
    }

    private var videoBlock: some View {
        ZStack(alignment: .topLeading) {
            VideoPlaceholder(height: 240)
            if current.isCorrected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "review.corrected"))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HardCourt.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HardCourt.bg.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(12)
            }
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .foregroundStyle(HardCourt.text)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(HardCourt.surface).frame(height: 4)
                        Capsule().fill(HardCourt.accent).frame(width: geo.size.width * 0.35, height: 4)
                        Circle()
                            .fill(HardCourt.text)
                            .frame(width: 10, height: 10)
                            .offset(x: geo.size.width * 0.35 - 5)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 16)
                Text("00:00")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(HardCourt.muted)
                Text(String(format: "%02d:%02d", Int(current.duration) / 60, Int(current.duration) % 60))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(HardCourt.muted)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundStyle(HardCourt.text)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
    }

    private var meta: some View {
        let status = current.isCorrected
            ? String(localized: "review.corrected")
            : String(localized: "status.processed")
        return Text(
            String(
                format: String(localized: "review.meta"),
                current.timeRangeLabel,
                current.durationLabel,
                status
            )
        )
        .font(.system(size: 14))
        .foregroundStyle(HardCourt.text)
        .tint(HardCourt.accent)
    }

    private var neighborNav: some View {
        HStack(spacing: 12) {
            neighborButton(title: neighborTitle(offset: -1), systemImage: "chevron.left", enabled: currentIndex > 0) {
                store.selectAdjacentReview(offset: -1)
            }
            Rectangle()
                .fill(HardCourt.muted.opacity(0.4))
                .frame(width: 1, height: 18)
            neighborButton(title: neighborTitle(offset: 1), systemImage: "chevron.right", enabled: currentIndex < store.rallies.count - 1, trailingIcon: true) {
                store.selectAdjacentReview(offset: 1)
            }
        }
        .padding(.horizontal, 20)
    }

    private func neighborTitle(offset: Int) -> String {
        let idx = currentIndex + offset
        guard store.rallies.indices.contains(idx) else { return "—" }
        return String(format: String(localized: "common.rally"), store.rallies[idx].index)
    }

    private func neighborButton(title: String, systemImage: String, enabled: Bool, trailingIcon: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if !trailingIcon {
                    Image(systemName: systemImage)
                }
                Text(title)
                if trailingIcon {
                    Image(systemName: systemImage)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(enabled ? HardCourt.text : HardCourt.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(HardCourt.surface, in: Capsule())
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}
