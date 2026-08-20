import SwiftUI

struct CourtBackdrop: View {
    var body: some View {
        ZStack {
            HardCourt.bg
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.22, blue: 0.14).opacity(0.55),
                    HardCourt.bg.opacity(0.2),
                    HardCourt.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.18))
                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.18))
                    path.move(to: CGPoint(x: w * 0.5, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.72))
                }
                .stroke(HardCourt.chalk.opacity(0.08), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(titleKey)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(HardCourt.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WaveformBar: View {
    var seed: Int

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<18, id: \.self) { i in
                let height = 6 + ((seed + i * 7) % 16)
                Capsule()
                    .fill(HardCourt.accent.opacity(0.85))
                    .frame(width: 2.5, height: CGFloat(height))
            }
        }
        .frame(height: 22)
    }
}

struct VideoPlaceholder: View {
    var height: CGFloat = 180

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.35, blue: 0.22),
                            Color(red: 0.08, green: 0.18, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: 8) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(HardCourt.accent.opacity(0.85))
                Text("TennisRally")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(HardCourt.accent)
            }
        }
        .frame(height: height)
    }
}
