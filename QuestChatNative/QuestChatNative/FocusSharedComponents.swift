import SwiftUI

struct PotionsCard: View {
    let onHealthTap: () -> Void
    let onManaTap: () -> Void
    let onStaminaTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Potions")
                .font(.headline.weight(.semibold))

            PotionsRow(
                onHealthTap: onHealthTap,
                onManaTap: onManaTap,
                onStaminaTap: onStaminaTap
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PotionsRow: View {
    let onHealthTap: () -> Void
    let onManaTap: () -> Void
    let onStaminaTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 12
            let totalSpacing = spacing * 2
            let pillWidth = (geo.size.width - totalSpacing) / 3

            HStack(spacing: spacing) {
                Button(action: onHealthTap) {
                    potionPill(label: "Health", systemImage: "cross.case.fill", style: .health)
                }
                .frame(width: pillWidth)
                .buttonStyle(.plain)

                Button(action: onManaTap) {
                    potionPill(label: "Mana", systemImage: "drop.fill", style: .mana)
                }
                .frame(width: pillWidth)
                .buttonStyle(.plain)

                Button(action: onStaminaTap) {
                    potionPill(label: "Stamina", systemImage: "bolt.fill", style: .stamina)
                }
                .frame(width: pillWidth)
                .buttonStyle(.plain)
            }
        }
        .frame(height: 52)
    }

    private func potionPill(label: String, systemImage: String, style: PotionStyle) -> some View {
        Label {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
        } icon: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(style.backgroundColor)
        .foregroundStyle(Color.white)
        .clipShape(Capsule())
    }
}

private enum PotionStyle {
    case health
    case mana
    case stamina

    var backgroundColor: Color {
        switch self {
        case .health:
            return .green
        case .mana:
            return .cyan
        case .stamina:
            return .orange
        }
    }
}

struct TodaysQuestCard: View {
    let quest: Quest
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(QuestChatStrings.FocusView.todayQuestLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(quest.title)
                        .font(.headline)
                }

                Spacer()

                if quest.isCompleted {
                    Label(QuestChatStrings.FocusView.questCompletedLabel, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.mint)
                } else {
                    Text(QuestChatStrings.xpRewardText(quest.xpReward))
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.mint.opacity(0.15))
                        .foregroundStyle(.mint)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}
