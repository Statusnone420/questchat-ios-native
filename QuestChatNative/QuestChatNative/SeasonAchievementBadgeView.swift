import SwiftUI

struct SeasonAchievementBadgeView: View {
    let title: String
    let iconName: String
    let isUnlocked: Bool
    let progressFraction: CGFloat
    let isCompact: Bool

    init(
        title: String,
        iconName: String,
        isUnlocked: Bool,
        progressFraction: CGFloat,
        isCompact: Bool = false
    ) {
        self.title = title
        self.iconName = iconName
        self.isUnlocked = isUnlocked
        self.progressFraction = progressFraction
        self.isCompact = isCompact
    }

    private var badgeDiameter: CGFloat {
        isCompact ? 32 : 64
    }

    private var iconFontSize: CGFloat {
        isCompact ? 16 : 28
    }

    private var shadowRadius: CGFloat {
        isCompact ? 4 : 8
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .strokeBorder(borderGradient, lineWidth: 3)
                    .background(Circle().fill(backgroundGradient))
                    .opacity(isUnlocked ? 1.0 : 0.3)

                iconView
                    .font(.system(size: iconFontSize))
                    .opacity(isUnlocked ? 1.0 : 0.5)
            }
            .frame(width: badgeDiameter, height: badgeDiameter)
            .shadow(radius: isUnlocked ? shadowRadius : 0, y: isCompact ? 2 : 4)

            if !isCompact {
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .opacity(isUnlocked ? 1.0 : 0.6)

                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                    .opacity(isUnlocked ? 1.0 : 0.4)
            }
        }
    }

    private var iconView: some View {
        if iconName.contains(".") == false && iconName.unicodeScalars.count == 1 {
            AnyView(Text(iconName))
        } else {
            AnyView(Image(systemName: iconName))
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: isUnlocked ? [.white, .gray] : [.gray.opacity(0.6), .black.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: isUnlocked ? [.purple, .blue] : [.gray.opacity(0.6), .black.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        SeasonAchievementBadgeView(title: "Hydration Demon", iconName: "💧", isUnlocked: true, progressFraction: 1)
        SeasonAchievementBadgeView(title: "Focus", iconName: "bolt.fill", isUnlocked: false, progressFraction: 0.4)
    }
    .padding()
    .background(Color.black)
    .previewLayout(.sizeThatFits)
}
