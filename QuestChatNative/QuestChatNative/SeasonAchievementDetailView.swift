import SwiftUI

struct SeasonAchievementDetailView: View {
    let achievement: SeasonAchievement
    let progress: SeasonAchievementProgress

    private var progressFraction: Double {
        guard achievement.threshold > 0 else { return 0 }
        return min(1.0, Double(progress.currentValue) / Double(achievement.threshold))
    }

    private var isUnlocked: Bool { progress.isUnlocked }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                badge

                VStack(alignment: .center, spacing: 8) {
                    Text(achievement.title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)

                    if let rewardTitle = achievement.rewardTitle {
                        Label("Title reward: \(rewardTitle)", systemImage: "wand.and.stars")
                            .font(.footnote)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }

                    Text(achievement.descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    detailRow(title: "Requirement", systemImage: "target") {
                        Text(achievement.requirementText)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    detailRow(title: "Progress", systemImage: "chart.bar") {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progressFraction)
                                .accentColor(isUnlocked ? .mint : .orange)
                            HStack {
                                Text("\(progress.currentValue) / \(achievement.threshold)")
                                    .font(.footnote.bold())
                                Spacer()
                                Text(isUnlocked ? "Unlocked" : "Locked")
                                    .font(.footnote)
                                    .foregroundStyle(isUnlocked ? .mint : .secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(20)
        }
        .background(Color.black.opacity(0.85))
    }

    private var badge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 120, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            if achievement.iconName.contains(".") {
                Image(systemName: achievement.iconName)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                    .opacity(isUnlocked ? 1 : 0.5)
                    .saturation(isUnlocked ? 1 : 0)
            } else {
                Text(achievement.iconName)
                    .font(.system(size: 48))
                    .opacity(isUnlocked ? 1 : 0.5)
                    .saturation(isUnlocked ? 1 : 0)
            }
        }
        .padding(.bottom, 4)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 12)
    }

    private func detailRow(title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SeasonAchievementDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SeasonAchievementDetailView(
            achievement: SeasonAchievement.allSeasonOne[0],
            progress: SeasonAchievementProgress(
                id: "hydration_demon",
                achievementId: "hydration_demon",
                currentValue: 12,
                unlockedAt: nil,
                lastUpdatedAt: Date()
            )
        )
        .preferredColorScheme(.dark)
    }
}
