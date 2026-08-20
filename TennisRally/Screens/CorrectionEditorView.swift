import SwiftUI

struct CorrectionEditorView: View {
    @EnvironmentObject private var store: AppSessionStore
    @State private var draft: Rally
    @State private var playhead: TimeInterval

    init(rally: Rally) {
        _draft = State(initialValue: rally)
        _playhead = State(initialValue: (rally.start + rally.end) / 2)
    }

    var body: some View {
        ZStack {
            CourtBackdrop()
            VStack(spacing: 16) {
                nav
                VideoPlaceholder(height: 220)
                    .padding(.horizontal, 16)
                playbackRow
                timelineVisual
                trimSteppers
                actions
                Text(String(localized: "correction.hint"))
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
            Button(String(localized: "correction.cancel")) {
                store.showCorrection = false
            }
            .foregroundStyle(HardCourt.text)
            Spacer()
            Text(String(format: String(localized: "common.rally"), draft.index))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HardCourt.text)
            Spacer()
            Button(String(localized: "correction.done")) {
                store.applyEditedRally(draft)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(HardCourt.accent)
        }
        .padding(.horizontal, 20)
    }

    private var playbackRow: some View {
        HStack {
            Image(systemName: "play.fill")
                .foregroundStyle(HardCourt.text)
            Spacer()
            Text(String(format: "%.1f", playhead))
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(HardCourt.text)
            Spacer()
            Color.clear.frame(width: 16)
        }
        .padding(.horizontal, 24)
    }

    private var timelineVisual: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = max(draft.end - draft.start, 0.1)
            let playX = ((playhead - draft.start) / span) * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(HardCourt.surface)
                    .frame(height: 44)
                Capsule()
                    .fill(HardCourt.accent.opacity(0.28))
                    .frame(height: 44)

                HStack(spacing: 2) {
                    ForEach(0..<40, id: \.self) { i in
                        Capsule()
                            .fill(HardCourt.accent.opacity(0.7))
                            .frame(width: 2, height: CGFloat(10 + (i % 7) * 3))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)

                handleLabel("correction.start")
                    .position(x: 24, y: 35)

                handleLabel("correction.end")
                    .position(x: width - 24, y: 35)

                Rectangle()
                    .fill(HardCourt.text)
                    .frame(width: 2, height: 52)
                    .overlay(alignment: .bottom) {
                        Circle()
                            .fill(HardCourt.accent)
                            .frame(width: 10, height: 10)
                            .offset(y: 4)
                    }
                    .offset(x: min(max(playX, 0), width - 2))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let ratio = min(max(value.location.x / width, 0), 1)
                                playhead = draft.start + ratio * span
                            }
                    )
            }
        }
        .frame(height: 72)
        .padding(.horizontal, 20)
    }

    private func handleLabel(_ key: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(HardCourt.accent)
            RoundedRectangle(cornerRadius: 4)
                .fill(HardCourt.accent)
                .frame(width: 26, height: 40)
                .overlay {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(.black.opacity(0.35)).frame(width: 2, height: 14)
                        }
                    }
                }
            Text(NSLocalizedString(key, comment: ""))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HardCourt.accent)
        }
    }

    private var trimSteppers: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(String(localized: "correction.start"))
                    .font(.caption)
                    .foregroundStyle(HardCourt.muted)
                Stepper(value: Binding(
                    get: { draft.start },
                    set: { draft.trim(start: $0, end: draft.end) }
                ), in: 0...(draft.end - 0.5), step: 0.5) {
                    Text(Rally.formatClock(draft.start))
                        .foregroundStyle(HardCourt.text)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(String(localized: "correction.end"))
                    .font(.caption)
                    .foregroundStyle(HardCourt.muted)
                Stepper(value: Binding(
                    get: { draft.end },
                    set: { draft.trim(start: draft.start, end: $0) }
                ), in: (draft.start + 0.5)...(draft.start + 600), step: 0.5) {
                    Text(Rally.formatClock(draft.end))
                        .foregroundStyle(HardCourt.text)
                }
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
                store.resetEditingRally()
                playhead = (draft.start + draft.end) / 2
            }
        }
        .padding(.horizontal, 8)
    }

    private func actionButton(titleKey: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(NSLocalizedString(titleKey, comment: ""))
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
            playhead = (updated.start + updated.end) / 2
        }
    }
}
