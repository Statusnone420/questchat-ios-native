import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Helpers

@available(iOS 17.0, *)
private func symbolName(forTitle title: String) -> String {
    let t = title.lowercased()
    if t.contains("deep") || t.contains("focus") { return "brain.head.profile" }
    if t.contains("work") || t.contains("sprint") { return "bolt.circle" }
    if t.contains("chore") { return "house.fill" }
    if t.contains("self") || t.contains("care") { return "figure.mind.and.body" }
    if t.contains("game") { return "gamecontroller" }
    if t.contains("break") || t.contains("quick") { return "cup.and.saucer.fill" }
    return "timer"
}

@available(iOS 17.0, *)
private struct CircularTimerRing: View {
    let progress: Double
    let ringColor: Color
    var timeLabel: String? = nil
    var size: CGFloat = 56
    var lineWidth: CGFloat = 8
    var showText: Bool = true

    var clampedProgress: CGFloat { CGFloat(min(max(progress, 0), 1)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
            if showText {
                if let timeLabel {
                    Text(timeLabel)
                        .font(.system(size: size * 0.32, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

@available(iOS 17.0, *)
private struct QuestHPBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 8

    private var clampedFraction: CGFloat { CGFloat(min(max(fraction, 0), 1)) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.primary.opacity(0.12))
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: proxy.size.width * clampedFraction)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Lock Screen / Expanded View

@available(iOS 17.0, *)
struct FocusSessionLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionAttributes>

    private var totalSeconds: Int {
        max(context.state.totalSeconds, 1)
    }

    private var remainingSeconds: Int {
        max(context.state.remainingSeconds, 0)
    }

    private var progress: Double {
        1 - Double(remainingSeconds) / Double(totalSeconds)
    }

    private var remainingFraction: Double {
        Double(remainingSeconds) / Double(totalSeconds)
    }

    private var ringColor: Color {
        switch remainingFraction {
        case 0.5...:  return .green
        case 0.25...: return .yellow
        default:      return .red
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let secs = s % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func shortRemainingLabel() -> String {
        let s = remainingSeconds
        if s >= 3600 {
            return String(format: "%dh", s / 3600)
        } else if s >= 60 {
            return String(format: "%dm", s / 60)
        } else {
            return String(format: "%ds", s)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CircularTimerRing(
                progress: progress,
                ringColor: ringColor,
                timeLabel: formattedTime(remainingSeconds),
                size: 56,
                lineWidth: 8,
                showText: true
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedTime(remainingSeconds))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(shortRemainingLabel()) left")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(context.state.title)
                            .font(.body)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Ends")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.endTime, style: .time)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(minWidth: 56, alignment: .trailing)
                    .padding(.trailing, 4)
                }

                QuestHPBar(
                    fraction: max(min(progress, 1.0), 0.0),
                    color: ringColor,
                    height: 8
                )
            }
        }
        .padding()
    }
}

// MARK: - Widget / Dynamic Island

@available(iOS 17.0, *)
struct FocusSessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            FocusSessionLiveActivityView(context: context)
        } dynamicIsland: { context in
            let totalSeconds = max(context.state.totalSeconds, 1)
            let remainingSeconds = max(context.state.remainingSeconds, 0)
            let progress = 1 - Double(remainingSeconds) / Double(totalSeconds)
            let remainingFraction = Double(remainingSeconds) / Double(totalSeconds)
            let ringColor: Color
            switch remainingFraction {
            case 0.5...: ringColor = .green
            case 0.25...: ringColor = .yellow
            default: ringColor = .red
            }
            let formattedTime: (Int) -> String = { seconds in
                let s = max(seconds, 0)
                let hours = s / 3600
                let minutes = (s % 3600) / 60
                let secs = s % 60
                if hours > 0 {
                    return String(format: "%d:%02d:%02d", hours, minutes, secs)
                } else {
                    return String(format: "%d:%02d", minutes, secs)
                }
            }

            DynamicIsland {
                // Expanded Regions
                DynamicIslandExpandedRegion(.leading) {
                    let symbol = symbolName(forTitle: context.state.title)

                    HStack(spacing: 6) {
                        Image(systemName: symbol)
                            .symbolRenderingMode(.hierarchical)
                            .imageScale(.medium)
                            .font(.subheadline)
                            .foregroundStyle(ringColor)
                        CircularTimerRing(
                            progress: progress,
                            ringColor: ringColor,
                            timeLabel: formattedTime(remainingSeconds),
                            size: 32,
                            lineWidth: 4,
                            showText: true
                        )
                        .padding(2)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Ends")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.endTime, style: .time)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(minWidth: 56, alignment: .trailing)
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    QuestHPBar(
                        fraction: max(min(progress, 1.0), 0.0),
                        color: ringColor,
                        height: 4
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                let seconds = max(context.state.remainingSeconds, 0)
                let label: String
                if seconds >= 3600 {
                    label = String(format: "%dh", seconds / 3600)
                } else if seconds >= 60 {
                    label = String(format: "%dm", seconds / 60)
                } else {
                    label = String(format: "%ds", seconds)
                }

                Text(label)
                    .font(.caption2.weight(.semibold))
            } compactTrailing: {
                CircularTimerRing(
                    progress: progress,
                    ringColor: ringColor,
                    size: 14,
                    lineWidth: 2.5,
                    showText: false
                )
                .padding(2)
            } minimal: {
                CircularTimerRing(
                    progress: progress,
                    ringColor: ringColor,
                    size: 16,
                    lineWidth: 2.5,
                    showText: false
                )
                .padding(2)
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Focus Session", as: .content, using: FocusSessionAttributes(sessionId: UUID())) {
    FocusSessionLiveActivityWidget()
} contentStates: {
    FocusSessionAttributes.ContentState(
        remainingSeconds: 1500,
        totalSeconds: 1800,
        title: "Deep Work",
        endTime: Date().addingTimeInterval(1500)
    )
}
#endif

