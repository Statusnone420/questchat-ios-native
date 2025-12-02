import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 17.0, *)
struct FocusSessionLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionAttributes>

    private var remainingMinutesText: String {
        let minutes = max(0, context.state.remainingSeconds / 60)
        return "\(minutes)"
    }

    private var progressValue: Double {
        let total = max(1, context.state.totalSeconds)
        let remaining = max(0, context.state.remainingSeconds)
        let elapsed = max(0, Double(total - remaining))
        return min(elapsed, Double(total))
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(remainingMinutesText)
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.6)
                Text("min left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progressValue, total: Double(max(1, context.state.totalSeconds)))
                    .tint(.blue)
                Text(context.state.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Ends")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(context.state.endTime, style: .time)
                    .font(.headline)
            }
        }
        .padding()
    }
}

@available(iOS 17.0, *)
struct FocusSessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            FocusSessionLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(max(0, context.state.remainingSeconds / 60))m")
                        .font(.system(.title3, design: .monospaced))
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endTime, style: .time)
                        .font(.subheadline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: progressValue(for: context), total: Double(max(1, context.state.totalSeconds)))
                        .tint(.blue)
                }
            } compactLeading: {
                Text("\(max(0, context.state.remainingSeconds / 60))")
                    .font(.system(.title3, design: .monospaced))
            } compactTrailing: {
                Text("min")
                    .font(.caption2)
            } minimal: {
                Text("\(max(0, context.state.remainingSeconds / 60))")
                    .font(.system(.title3, design: .monospaced))
            }
        }
    }

    private func progressValue(for context: ActivityViewContext<FocusSessionAttributes>) -> Double {
        let total = max(1, context.state.totalSeconds)
        let remaining = max(0, context.state.remainingSeconds)
        let elapsed = max(0, Double(total - remaining))
        return min(elapsed, Double(total))
    }
}

