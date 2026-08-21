import SwiftUI

struct AIAssistCheckingView: View {
    @EnvironmentObject private var assist: AIAssistSession
    @Environment(\.locale) private var locale
    let modelName: String
    let onStop: () -> Void

    var body: some View {
        ZStack {
            CourtBackdrop()
            VStack(spacing: 24) {
                Spacer()
                progressRing
                VStack(spacing: 8) {
                    Text("ai.checking.title")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(HardCourt.text)
                    Text(progressCaption)
                        .font(.system(size: 15))
                        .foregroundStyle(HardCourt.muted)
                    Text(AppLocalization.format("ai.checking.on_device", locale: locale, modelName as CVarArg))
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.muted)
                }
                Spacer()
                Button("ai.checking.stop") {
                    onStop()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HardCourt.text)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }

    private var progressRing: some View {
        let fraction: Double = {
            if case let .checking(current, total) = assist.phase, total > 0 {
                return Double(current) / Double(total)
            }
            return 0
        }()
        let percent = Int((fraction * 100).rounded())

        return ZStack {
            Circle()
                .stroke(HardCourt.hairline, lineWidth: 10)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(HardCourt.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(HardCourt.text)
        }
        .frame(width: 140, height: 140)
    }

    private var progressCaption: String {
        if case let .checking(current, total) = assist.phase {
            return AppLocalization.format(
                "ai.checking.rally_progress",
                locale: locale,
                current as CVarArg,
                total as CVarArg
            )
        }
        return ""
    }
}

struct AIAssistModelGateSheet: View {
    let onSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(HardCourt.muted.opacity(0.45))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            Image(systemName: "cpu")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(HardCourt.accent)
                .padding(.top, 4)

            Text("ai.gate.title")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(HardCourt.text)
                .multilineTextAlignment(.center)

            Text("ai.gate.body")
                .font(.system(size: 15))
                .foregroundStyle(HardCourt.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            PrimaryButton(titleKey: "ai.gate.go_settings", systemImage: "gearshape") {
                onSettings()
            }

            Button("ai.gate.not_now") {
                onDismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(HardCourt.text)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .background(HardCourt.surface)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

struct RallyAIVerdictPanel: View {
    let verdict: AIRallyVerdict
    let onOpenEditor: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ai.assist.section")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HardCourt.muted)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Image(systemName: iconName(for: verdict.kind))
                Text(LocalizedStringKey(verdict.kind.titleKey))
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(color(for: verdict.kind))

            Text(LocalizedStringKey(verdict.reasonKey))
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.text)

            Text(confidenceLine)
                .font(.system(size: 12))
                .foregroundStyle(HardCourt.muted)

            PrimaryButton(titleKey: "ai.verdict.open_editor", systemImage: "slider.horizontal.3") {
                onOpenEditor()
            }

            Button("ai.verdict.dismiss") {
                onDismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(HardCourt.muted)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var confidenceLine: String {
        let label = String(localized: "ai.confidence.label")
        let level = String(localized: String.LocalizationValue(verdict.confidence.titleKey))
        return "\(label) · \(level)"
    }

    private func color(for kind: AIRallyVerdictKind) -> Color {
        switch kind {
        case .looksGood: return HardCourt.accent
        case .needsReview: return HardCourt.danger
        case .unclear: return HardCourt.muted
        }
    }

    private func iconName(for kind: AIRallyVerdictKind) -> String {
        switch kind {
        case .looksGood: return "checkmark.circle.fill"
        case .needsReview: return "exclamationmark.triangle.fill"
        case .unclear: return "questionmark.circle.fill"
        }
    }
}
