import ActivityKit
import SwiftUI
import WidgetKit

@main
struct QuestChatLiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        FocusTimerLiveActivityWidget()
    }
}

struct FocusTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerAttributes.self) { context in
            ZStack {
                Color.black
                VStack(spacing: 8) {
                    Text(context.state.title)
                        .font(.headline)
                    Text(timerLabel(until: context.state.endDate))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding()
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.title)
                            .font(.headline)
                        Text(timerLabel(until: context.state.endDate))
                            .font(.system(.title2, design: .monospaced))
                    }
                }
            } compactLeading: {
                Text("⏱")
            } compactTrailing: {
                Text(shortTimerLabel(until: context.state.endDate))
                    .font(.system(.caption, design: .monospaced))
            } minimal: {
                Text("⏱")
            }
        }
    }
}

private func timerLabel(until endDate: Date) -> String {
    let remaining = max(0, Int(endDate.timeIntervalSinceNow))
    let minutes = remaining / 60
    let seconds = remaining % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

private func shortTimerLabel(until endDate: Date) -> String {
    let remaining = max(0, Int(endDate.timeIntervalSinceNow))
    let minutes = max(0, remaining / 60)
    return "\(minutes)m"
}
