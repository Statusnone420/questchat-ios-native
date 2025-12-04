import SwiftUI

struct AchievementUnlockOverlayView: View {
    let achievement: StatsViewModel.SeasonAchievementItemViewModel
    let xpReward: Int
    let onEquipTitle: () -> Void
    let onDismiss: () -> Void

    @State private var animateIn = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .blur(radius: 8)

            VStack(spacing: 24) {
                Text("Season Achievement Unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: animateIn)

                SeasonAchievementBadgeView(
                    title: achievement.title,
                    iconName: achievement.iconName,
                    isUnlocked: true,
                    progressFraction: 1.0
                )
                .scaleEffect(animateIn ? 1.0 : 0.2)
                .opacity(animateIn ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateIn)

                VStack(spacing: 8) {
                    Text(achievement.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(achievement.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("+\(xpReward) XP • New title unlocked")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.1), value: animateIn)

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    Button(action: onEquipTitle) {
                        Text("Equip Title")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16).fill(.accent))
                            .foregroundColor(.white)
                    }

                    Button(action: onDismiss) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 32)
            .overlay(alignment: .top) {
                if showConfetti {
                    Color.clear
                        .frame(width: 1, height: 1)
                }
            }
        }
        .onAppear {
            animateIn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showConfetti = true
            }
        }
    }
}
