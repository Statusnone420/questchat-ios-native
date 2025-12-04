import SwiftUI

struct SeasonAchievementBadgeView: View {
    let title: String
    let iconName: String
    let isUnlocked: Bool
    let progressFraction: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .strokeBorder(borderGradient, lineWidth: 3)
                    .background(Circle().fill(backgroundGradient))
                    .opacity(isUnlocked ? 1.0 : 0.3)

                iconView
                    .font(.system(size: 28))
                    .opacity(isUnlocked ? 1.0 : 0.5)
            }
            .frame(width: 64, height: 64)
            .shadow(radius: isUnlocked ? 8 : 0, y: 4)

            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .opacity(isUnlocked ? 1.0 : 0.6)

            ProgressView(value: progressFraction)
                .progressViewStyle(.linear)
                .opacity(isUnlocked ? 0.8 : 0.4)
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
