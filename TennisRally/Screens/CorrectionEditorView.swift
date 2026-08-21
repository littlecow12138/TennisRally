import SwiftUI

struct CorrectionEditorView: View {
    @EnvironmentObject private var store: AppSessionStore
    @Environment(\.locale) private var locale
    @State private var draft: Rally
    @State private var playhead: TimeInterval
    @State private var mapper: TrimTimelineMapper
    @State private var activeHandleDragOrigin: TimeInterval?

    init(rally: Rally) {
        _draft = State(initialValue: rally)
        _playhead = State(initialValue: (rally.start + rally.end) / 2)
        _mapper = State(initialValue: TrimTimelineMapper(rally: rally))
    }

    var body: some View {
        ZStack {
            CourtBackdrop()
            VStack(spacing: 16) {
                nav
                RallyClipPreviewView(
                    source: store.videoSourceForActiveClip,
                    start: draft.start,
                    end: draft.end,
                    height: 220,
                    showsScrubber: true
                )
                .padding(.horizontal, 16)
                timelineVisual
                boundReadout
                actions
                Text("correction.hint")
                    .font(.system(size: 13))
                    .foregroundStyle(HardCourt.muted)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .onChange(of: draft.start) { _, _ in
            playhead = min(max(playhead, draft.start), draft.end)
        }
        .onChange(of: draft.end) { _, _ in
            playhead = min(max(playhead, draft.start), draft.end)
        }
    }

    private var nav: some View {
        HStack {
            Button("correction.cancel") {
                store.showCorrection = false
            }
            .foregroundStyle(HardCourt.text)
            Spacer()
            Text(AppLocalization.format("common.rally", locale: locale, draft.index as CVarArg))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HardCourt.text)
            Spacer()
            Button("correction.done") {
                store.applyEditedRally(draft)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(HardCourt.accent)
        }
        .padding(.horizontal, 20)
    }

    private var timelineVisual: some View {
        GeometryReader { geo in
            let width = Double(geo.size.width)
            let startX = mapper.x(for: draft.start, width: width)
            let endX = mapper.x(for: draft.end, width: width)
            let playX = mapper.x(for: playhead, width: width)
            let selectionWidth = max(endX - startX, 2)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(HardCourt.surface)
                    .frame(height: 44)

                Capsule()
                    .fill(HardCourt.accent.opacity(0.28))
                    .frame(width: selectionWidth, height: 44)
                    .offset(x: startX)

                HStack(spacing: 2) {
                    ForEach(0..<40, id: \.self) { i in
                        Capsule()
                            .fill(HardCourt.accent.opacity(0.55))
                            .frame(width: 2, height: CGFloat(10 + (i % 7) * 3))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .allowsHitTesting(false)

                Rectangle()
                    .fill(HardCourt.text)
                    .frame(width: 2, height: 52)
                    .overlay(alignment: .bottom) {
                        Circle()
                            .fill(HardCourt.accent)
                            .frame(width: 10, height: 10)
                            .offset(y: 4)
                    }
                    .offset(x: min(max(playX - 1, 0), width - 2))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let t = mapper.time(atX: Double(value.location.x), width: width)
                                playhead = min(max(t, draft.start), draft.end)
                            }
                    )

                draggableHandle(labelKey: "correction.start", x: startX, width: width, originTime: draft.start) { proposed in
                    let newStart = mapper.clampedStart(proposed: proposed, currentEnd: draft.end)
                    draft.trim(start: newStart, end: draft.end)
                }

                draggableHandle(labelKey: "correction.end", x: endX, width: width, originTime: draft.end) { proposed in
                    let newEnd = mapper.clampedEnd(proposed: proposed, currentStart: draft.start)
                    draft.trim(start: draft.start, end: newEnd)
                }
            }
        }
        .frame(height: 88)
        .padding(.horizontal, 20)
    }

    private func draggableHandle(
        labelKey: LocalizedStringKey,
        x: Double,
        width: Double,
        originTime: TimeInterval,
        onProposedTime: @escaping (TimeInterval) -> Void
    ) -> some View {
        handleLabel(labelKey)
            .position(x: CGFloat(min(max(x, 18), width - 18)), y: 44)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeHandleDragOrigin == nil {
                            activeHandleDragOrigin = originTime
                        }
                        let delta = (Double(value.translation.width) / width) * mapper.windowDuration
                        let proposed = (activeHandleDragOrigin ?? originTime) + delta
                        onProposedTime(proposed)
                    }
                    .onEnded { _ in
                        activeHandleDragOrigin = nil
                    }
            )
            .accessibilityLabel(Text(labelKey))
    }

    private func handleLabel(_ key: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(HardCourt.accent)
            RoundedRectangle(cornerRadius: 4)
                .fill(HardCourt.accent)
                .frame(width: 28, height: 44)
                .overlay {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(.black.opacity(0.35)).frame(width: 2, height: 14)
                        }
                    }
                }
            Text(key)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HardCourt.accent)
        }
        .frame(width: 56, height: 78)
        .contentShape(Rectangle())
    }

    private var boundReadout: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("correction.start")
                    .font(.caption)
                    .foregroundStyle(HardCourt.muted)
                Text(Rally.formatClock(draft.start))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HardCourt.text)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("correction.end")
                    .font(.caption)
                    .foregroundStyle(HardCourt.muted)
                Text(Rally.formatClock(draft.end))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HardCourt.text)
            }
        }
        .padding(.horizontal, 20)
    }

    private var actions: some View {
        HStack(spacing: 0) {
            actionButton(titleKey: "correction.merge", systemImage: "arrow.left.arrow.right") {
                store.mergeEditingRallyWithPrevious()
                syncDraftFromStore()
            }
            actionButton(titleKey: "correction.split", systemImage: "scissors") {
                store.splitEditingRally(at: playhead)
                syncDraftFromStore()
            }
            actionButton(titleKey: "correction.reset", systemImage: "arrow.counterclockwise") {
                var copy = draft
                copy.reset()
                draft = copy
                mapper = TrimTimelineMapper(rally: draft)
                store.resetEditingRally()
                playhead = (draft.start + draft.end) / 2
            }
        }
        .padding(.horizontal, 8)
    }

    private func actionButton(titleKey: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(titleKey)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(HardCourt.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func syncDraftFromStore() {
        if let updated = store.editingRally {
            draft = updated
            mapper = TrimTimelineMapper(rally: updated)
            playhead = (updated.start + updated.end) / 2
        }
    }
}
