import SwiftUI

struct StatusBarRow: View {
    let iconName: String
    let label: String
    let tint: Color
    let progress: Double
    let segments: Int

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private func fillFraction(for index: Int) -> Double {
        let raw = (clampedProgress * Double(segments)) - Double(index)
        return min(max(raw, 0), 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(label, systemImage: iconName)
                .font(.footnote.bold())
                .foregroundStyle(tint)
                .frame(width: 110, alignment: .leading)

            GeometryReader { geometry in
                let spacing = CGFloat(max(segments - 1, 0)) * 4
                let segmentWidth = max((geometry.size.width - spacing) / CGFloat(max(segments, 1)), 0)

                HStack(spacing: 4) {
                    ForEach(0..<segments, id: \.self) { index in
                        let fraction = fillFraction(for: index)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(tint)
                                .frame(width: segmentWidth * fraction)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        }
                        .frame(width: segmentWidth, height: 14)
                    }
                }
            }
            .frame(height: 16)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PlayerStatusBarsView: View {
    let hpProgress: Double
    let hydrationProgress: Double
    let sleepProgress: Double
    let moodProgress: Double
    let segments: Int

    init(
        hpProgress: Double,
        hydrationProgress: Double,
        sleepProgress: Double,
        moodProgress: Double,
        segments: Int = 10
    ) {
        self.hpProgress = hpProgress
        self.hydrationProgress = hydrationProgress
        self.sleepProgress = sleepProgress
        self.moodProgress = moodProgress
        self.segments = segments
    }

    var body: some View {
        VStack(spacing: 8) {
            StatusBarRow(
                iconName: "heart.fill",
                label: "HP",
                tint: .red,
                progress: hpProgress,
                segments: segments
            )

            StatusBarRow(
                iconName: "drop.fill",
                label: "Hydration",
                tint: .blue,
                progress: hydrationProgress,
                segments: segments
            )

            StatusBarRow(
                iconName: "moon.fill",
                label: "Sleep",
                tint: .purple,
                progress: sleepProgress,
                segments: segments
            )

            StatusBarRow(
                iconName: "face.smiling",
                label: "Mood",
                tint: .green,
                progress: moodProgress,
                segments: segments
            )
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PlayerStatusBarsView(
            hpProgress: 0.7,
            hydrationProgress: 0.4,
            sleepProgress: 0.9,
            moodProgress: 0.6
        )
    }
    .padding()
    .background(Color.black)
}
