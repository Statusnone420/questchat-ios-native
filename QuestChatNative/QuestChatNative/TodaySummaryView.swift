import SwiftUI

struct TodaySummaryView: View {
    let completedQuests: Int
    let totalQuests: Int
    let focusMinutes: Int
    let selfCareMinutes: Int
    let dailyFocusTarget: Int
    let currentStreakDays: Int

    private var questProgress: Double {
        guard totalQuests > 0 else { return 0 }
        return Double(completedQuests) / Double(totalQuests)
    }

    private var minutesProgress: Double {
        guard dailyFocusTarget > 0 else { return 0 }
        let totalMinutes = focusMinutes + selfCareMinutes
        let progress = Double(totalMinutes) / Double(dailyFocusTarget)
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
            Label("Today", systemImage: "sun.max.fill")
                .font(.headline)
                .foregroundStyle(.qcAccentPurpleBright)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today: \(completedQuests) / \(totalQuests) quests done")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text("Focus: \(focusMinutes) / \(dailyFocusTarget) minutes")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text("Self care: \(selfCareMinutes) minutes")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(overallProgressLabel)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                ProgressView(value: overallProgress)
                    .progressViewStyle(.linear)
                    .tint(.qcAccentPurpleBright)
            }

            if currentStreakDays > 0 {
                Text("On a \(currentStreakDays)-day streak. Don't break it!")
                    .font(.footnote)
                    .foregroundStyle(.qcAccentPurple)
            }
        }
        .padding()
        .background(Color.qcCardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.qcAccentPurple.opacity(0.25), lineWidth: 1)
        )
    }
}

#Preview {
    TodaySummaryView(
        completedQuests: 2,
        totalQuests: 4,
        focusMinutes: 32,
        selfCareMinutes: 10,
        dailyFocusTarget: 40,
        currentStreakDays: 3
    )
    .padding()
    .preferredColorScheme(.dark)
}
