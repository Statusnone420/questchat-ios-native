import SwiftUI

struct RPGStatBar: View {
    let iconName: String
    let label: String?
    let color: Color
    let progress: Double
    let segments: Int

    init(iconName: String, label: String? = nil, color: Color, progress: Double, segments: Int = 10) {
        self.iconName = iconName
        self.label = label
        self.color = color
        self.progress = progress
        self.segments = segments
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var filledSegments: Int {
        Int((clampedProgress * Double(segments)).rounded(.down))
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 22)

            if let label {
                Text(label)
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
            }

            GeometryReader { geometry in
                let totalSpacing = CGFloat(max(segments - 1, 0)) * 2
                let segmentWidth = max((geometry.size.width - totalSpacing) / CGFloat(max(segments, 1)), 0)

                HStack(spacing: 2) {
                    ForEach(0..<segments, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index < filledSegments ? color : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .frame(width: segmentWidth)
                    }
                }
            }
            .frame(height: 14)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        RPGStatBar(iconName: "heart.fill", label: "HP", color: .red, progress: 0.65)
        RPGStatBar(iconName: "drop.fill", label: "Hydration", color: .blue, progress: 0.35)
    }
    .padding()
    .background(Color.black)
}
