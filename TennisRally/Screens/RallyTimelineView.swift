import SwiftUI

struct RallyTimelineView: View {
    @EnvironmentObject private var store: AppSessionStore
    @EnvironmentObject private var visionModel: VisionModelStore
    @EnvironmentObject private var assist: AIAssistSession
    @Environment(\.locale) private var locale
    @State private var showModelGate = false

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
        .sheet(isPresented: $showModelGate) {
            AIAssistModelGateSheet(
                onSettings: {
                    showModelGate = false
                    store.openVisionModelSettings()
                },
                onDismiss: { showModelGate = false }
            )
            .presentationBackground(HardCourt.surface)
        }
        .fullScreenCover(isPresented: $store.showAIChecking) {
            AIAssistCheckingView(modelName: visionModel.catalog.displayName) {
                assist.stop()
                store.showAIChecking = false
            }
            .onChange(of: assist.phase) { _, phase in
                if case .results = phase {
                    store.showAIChecking = false
                }
            }
        }
        .sheet(item: inspectingRallyBinding) { rally in
            if let verdict = assist.verdict(for: rally.id) {
                NavigationStack {
                    RallyAIVerdictDetailView(rally: rally, verdict: verdict)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var inspectingRallyBinding: Binding<Rally?> {
        Binding(
            get: { store.inspectingVerdictRally },
            set: { store.inspectingVerdictRallyID = $0?.id }
        )
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

            if assist.phase == .results, !assist.verdicts.isEmpty {
                summaryStrip
            }

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
                Rectangle()
                    .fill(HardCourt.muted.opacity(0.5))
                    .frame(width: 1, height: 14)
                Button {
                    startAIAssist()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text(assist.phase == .results ? "ai.assist.recheck" : "ai.assist.entry")
                    }
                }
                .foregroundStyle(HardCourt.accent)
            }
            .font(.system(size: 15, weight: .semibold))

            Divider().overlay(HardCourt.hairline)
            Text(assist.phase == .results ? "rallies.hint" : "ai.assist.hint")
                .font(.system(size: 12))
                .foregroundStyle(HardCourt.muted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var summaryStrip: some View {
        let summary = assist.summary
        return Text(AppLocalization.format(
            "ai.summary.strip",
            locale: locale,
            summary.looksGoodCount as CVarArg,
            summary.needsReviewCount as CVarArg,
            summary.unclearCount as CVarArg
        ))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(HardCourt.text)
        .padding(.vertical, 4)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.rallies) { rally in
                    Button {
                        if let _ = assist.verdict(for: rally.id) {
                            store.openVerdictInspector(for: rally)
                        } else {
                            store.openCorrection(for: rally)
                        }
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

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(rally.durationLabel)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(HardCourt.text)
                                if let verdict = assist.verdict(for: rally.id) {
                                    Text(LocalizedStringKey(verdict.kind.titleKey))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(verdictColor(verdict.kind))
                                } else {
                                    HStack(spacing: 2) {
                                        Text("rallies.correct")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HardCourt.accent)
                                }
                            }
                            .frame(width: 110, alignment: .trailing)
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

    private func startAIAssist() {
        switch assist.beginAssist(for: store.rallies) {
        case .needsModel:
            showModelGate = true
        case .started:
            store.showAIChecking = true
        case .nothingToCheck:
            break
        }
    }

    private func verdictColor(_ kind: AIRallyVerdictKind) -> Color {
        switch kind {
        case .looksGood: return HardCourt.accent
        case .needsReview: return HardCourt.danger
        case .unclear: return HardCourt.muted
        }
    }
}

struct RallyAIVerdictDetailView: View {
    @EnvironmentObject private var store: AppSessionStore
    @EnvironmentObject private var assist: AIAssistSession
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    let rally: Rally
    let verdict: AIRallyVerdict

    var body: some View {
        ZStack {
            CourtBackdrop()
            VStack(spacing: 16) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(HardCourt.accent)
                    }
                    Spacer()
                    Text(AppLocalization.format("common.rally", locale: locale, rally.index as CVarArg))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HardCourt.text)
                    Spacer()
                    Button("rallies.edit") {
                        dismiss()
                        store.openCorrection(for: rally)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HardCourt.accent)
                }
                .padding(.horizontal, 20)

                RallyClipPreviewView(
                    source: store.videoSourceForActiveClip,
                    start: rally.start,
                    end: rally.end,
                    height: 200,
                    showsScrubber: false
                )
                .padding(.horizontal, 16)

                VStack(spacing: 4) {
                    Text(rally.timeRangeLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HardCourt.text)
                    Text(rally.durationLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.muted)
                }

                RallyAIVerdictPanel(
                    verdict: verdict,
                    onOpenEditor: {
                        dismiss()
                        store.openCorrection(for: rally)
                    },
                    onDismiss: {
                        assist.dismissVerdict(for: rally.id)
                        dismiss()
                    }
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
}
