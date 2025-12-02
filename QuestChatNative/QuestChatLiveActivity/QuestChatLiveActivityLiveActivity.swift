import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 17.0, *)
struct FocusSessionLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionAttributes>

    private var remainingMinutes: Int {
        max(0, Int(ceil(Double(context.state.remainingSeconds) / 60.0)))
    }

    private var progress: Double {
        guard context.state.totalSeconds > 0 else { return 0 }
        let elapsed = max(0, context.state.totalSeconds - context.state.remainingSeconds)
        return Double(elapsed) / Double(context.state.totalSeconds)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(remainingMinutes)")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Text("min left")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)
                    Text(context.state.title)
                        .font(.body)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Ends")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(context.state.endTime, style: .time)
                    .font(.headline)
                    .foregroundColor(.primary)
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
                    Text("\(max(0, Int(ceil(Double(context.state.remainingSeconds) / 60.0))))m")
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endTime, style: .time)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: Double(max(0, context.state.totalSeconds - context.state.remainingSeconds)), total: Double(max(1, context.state.totalSeconds)))
                        .progressViewStyle(.linear)
                }
            } compactLeading: {
                Text("\(max(0, Int(ceil(Double(context.state.remainingSeconds) / 60.0))))")
            } compactTrailing: {
                Text("min")
            } minimal: {
                Text("\(max(0, Int(ceil(Double(context.state.remainingSeconds) / 60.0))))m")
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Focus Session", as: .content, using: FocusSessionAttributes(sessionId: UUID())) {
    FocusSessionLiveActivityWidget()
} contentStates: {
    FocusSessionAttributes.ContentState(remainingSeconds: 1500, totalSeconds: 1800, title: "Deep Work", endTime: Date().addingTimeInterval(1500))
}
#endif
