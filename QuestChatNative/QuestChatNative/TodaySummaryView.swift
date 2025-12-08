import SwiftUI

struct TodaySummaryView: View {
    let title: String
    let completedQuests: Int
    let totalQuests: Int
    let focusMinutes: Int
    let focusGoalMinutes: Int
    let reachedFocusGoal: Bool
    let focusAreaLabel: String?
    let currentStreakDays: Int

    private var questProgress: Double {
        guard totalQuests > 0 else { return 0 }
        return Double(completedQuests) / Double(totalQuests)
    }

    private var minutesProgress: Double {
        guard focusGoalMinutes > 0 else { return 0 }
        let progress = Double(focusMinutes) / Double(focusGoalMinutes)
        return min(progress, 1)
    }

    private var overallProgress: Double {
        (questProgress + minutesProgress) / 2
    }

    private var overallProgressLabel: String {
        let percentage = Int(overallProgress * 100)
        return "Overall progress: \(percentage)%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(title, systemImage: "sun.max.fill")
                    .font(.headline)
                    .foregroundStyle(.mint)
                Spacer()
                if let focusAreaLabel {
                    Text(focusAreaLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(title): \(completedQuests) / \(totalQuests) quests done")
                    .font(.subheadline)
                HStack(spacing: 8) {
                    Text("Focus: \(focusMinutes) / \(focusGoalMinutes) minutes")
                        .font(.subheadline)
                    if reachedFocusGoal {
                        Text("Goal hit!")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.mint.opacity(0.2))
                            .foregroundColor(.mint)
                            .cornerRadius(10)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(overallProgressLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ProgressView(value: overallProgress)
                    .progressViewStyle(.linear)
                    .tint(.mint)
            }

            if currentStreakDays > 0 {
                Text("On a \(currentStreakDays)-day streak. Don't break it!")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }
}

#Preview {
    TodaySummaryView(
        title: "Today",
        completedQuests: 2,
        totalQuests: 4,
        focusMinutes: 32,
        focusGoalMinutes: 40,
        reachedFocusGoal: true,
        focusAreaLabel: "💼 Work",
        currentStreakDays: 3
    )
    .padding()
    .preferredColorScheme(.dark)
}
