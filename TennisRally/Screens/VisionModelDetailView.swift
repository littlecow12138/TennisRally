import SwiftUI

struct VisionModelDetailView: View {
    @EnvironmentObject private var visionModel: VisionModelStore
    @Environment(\.locale) private var locale
    @StateObject private var network = CellularNetworkMonitor()

    var body: some View {
        ZStack {
            CourtBackdrop()
            VStack(spacing: 20) {
                Image("LogoLockup")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .accessibilityLabel("TennisRally")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                modelCard
                factsCard
                Spacer(minLength: 12)
                actionSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .navigationTitle(Text("ai.model.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HardCourt.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(HardCourt.accent)
    }

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(visionModel.catalog.displayName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(HardCourt.text)
            Text(visionModel.catalog.formatLabel)
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.muted)
            HStack(spacing: 6) {
                Text(visionModel.catalog.approximateSizeLabel)
                    .foregroundStyle(HardCourt.text)
                Text("|")
                    .foregroundStyle(HardCourt.muted)
                Text(statusCaption)
                    .foregroundStyle(HardCourt.muted)
            }
            .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var factsCard: some View {
        VStack(spacing: 0) {
            factRow(icon: "internaldrive", titleKey: "ai.model.storage", value: visionModel.catalog.approximateSizeLabel)
            Divider().overlay(HardCourt.hairline).padding(.leading, 44)
            factRow(icon: "wifi", titleKey: "ai.model.recommended", valueKey: "ai.model.wifi")
            Divider().overlay(HardCourt.hairline).padding(.leading, 44)
            factRow(icon: "lock.shield", titleKey: "ai.model.privacy", valueKey: "ai.model.local_only")
        }
        .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func factRow(icon: String, titleKey: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HardCourt.accent)
                .frame(width: 24)
            Text(titleKey)
                .font(.system(size: 15))
                .foregroundStyle(HardCourt.text)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HardCourt.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func factRow(icon: String, titleKey: LocalizedStringKey, valueKey: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HardCourt.accent)
                .frame(width: 24)
            Text(titleKey)
                .font(.system(size: 15))
                .foregroundStyle(HardCourt.text)
            Spacer()
            Text(valueKey)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HardCourt.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var actionSection: some View {
        switch visionModel.status {
        case .notDownloaded, .failed:
            PrimaryButton(titleKey: "ai.model.download", systemImage: "arrow.down.circle.fill") {
                Task { await visionModel.startDownload() }
            }
            if network.isConstrainedOrExpensive {
                Text("ai.model.cellular_warning")
                    .font(.system(size: 12))
                    .foregroundStyle(HardCourt.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

        case let .downloading(progress, downloaded, total):
            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .tint(HardCourt.accent)
                Text(progressLabel(downloaded: downloaded, total: total))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HardCourt.text)
                Button("ai.model.cancel") {
                    Task { await visionModel.cancelDownload() }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HardCourt.danger)
            }

        case .ready:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(HardCourt.accent)
                Text("ai.model.ready_badge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HardCourt.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            PrimaryButton(titleKey: "ai.model.redownload", systemImage: "arrow.clockwise.circle.fill") {
                Task { await visionModel.redownload() }
            }

            Button("ai.model.remove") {
                visionModel.removeModel()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(HardCourt.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }

    private var statusCaption: String {
        switch visionModel.status {
        case .notDownloaded, .failed:
            return AppLocalization.text("ai.model.not_on_device", locale: locale)
        case .downloading:
            return AppLocalization.format(
                "ai.model.downloading_percent",
                locale: locale,
                visionModel.downloadProgressPercent as CVarArg
            )
        case .ready:
            return AppLocalization.text("ai.model.on_device", locale: locale)
        }
    }

    private func progressLabel(downloaded: Int64, total: Int64) -> String {
        let percent = total > 0 ? Int((Double(downloaded) / Double(total) * 100).rounded()) : visionModel.downloadProgressPercent
        return AppLocalization.format(
            "ai.model.progress_bytes",
            locale: locale,
            percent as CVarArg,
            byteLabel(downloaded) as CVarArg,
            byteLabel(total) as CVarArg
        )
    }

    private func byteLabel(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
