import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Helpers

@available(iOS 17.0, *)
private func timeLabel(for seconds: Int) -> String {
    if seconds <= 0 { return "0s" }
    let minutes = seconds / 60
    let secs = seconds % 60
    if minutes > 0 {
        return "\(minutes)m"
    } else {
        return "\(secs)s"
    }
}

@available(iOS 17.0, *)
private func ringColor(forRemaining remaining: Int, total: Int) -> Color {
    let t = max(total, 1)
    let fraction = Double(max(remaining, 0)) / Double(t)
    if fraction >= 0.5 { return .green }
    if fraction >= 0.25 { return .yellow }
    return .red
}

@available(iOS 17.0, *)
private struct TimerSnapshot {
    let remainingSeconds: Int
    let totalSeconds: Int
    let progress: Double
    let ringColor: Color
}

@available(iOS 17.0, *)
private func timerSnapshot(for context: ActivityViewContext<FocusSessionAttributes>, at date: Date) -> TimerSnapshot {
    let total = max(context.state.totalSeconds, 1)
    let rawRemaining = context.state.endTime.timeIntervalSince(date)
    let remaining = max(Int(ceil(rawRemaining)), 0)
    let progress = min(1.0, max(0.0, 1.0 - (Double(remaining) / Double(total))))
    let color = ringColor(forRemaining: remaining, total: total)
    return TimerSnapshot(remainingSeconds: remaining, totalSeconds: total, progress: progress, ringColor: color)
}

@available(iOS 17.0, *)
private struct TimelineDriven<Content: View>: View {
    let context: ActivityViewContext<FocusSessionAttributes>
    let content: (TimerSnapshot) -> Content

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = timerSnapshot(for: context, at: timeline.date)
            content(snapshot)
        }
    }
}

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
    let remainingSeconds: Int
    let ringColor: Color
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
                Text(timeLabel(for: remainingSeconds))
                    .font(.system(size: size * 0.32, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Lock Screen / Expanded View

@available(iOS 17.0, *)
struct FocusSessionLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionAttributes>
    let snapshot: TimerSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeLabel(for: snapshot.remainingSeconds))
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                Text("remaining")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.title)
                    .font(.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ProgressView(value: snapshot.progress)
                    .progressViewStyle(.linear)
                    .tint(snapshot.ringColor)
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
            .frame(minWidth: 72, alignment: .trailing)
        }
        .padding()
    }
}

// MARK: - Widget / Dynamic Island

@available(iOS 17.0, *)
struct FocusSessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            TimelineDriven(context: context) { snapshot in
                FocusSessionLiveActivityView(context: context, snapshot: snapshot)
            }
        } dynamicIsland: { context in
            TimelineDriven(context: context) { snapshot in
                DynamicIsland {
                    // Expanded Regions
                    DynamicIslandExpandedRegion(.leading) {
                        let symbol = symbolName(forTitle: context.state.title)

                        HStack(spacing: 6) {
                            Image(systemName: symbol)
                                .symbolRenderingMode(.hierarchical)
                                .imageScale(.medium)
                                .font(.subheadline)
                                .foregroundStyle(snapshot.ringColor)
                            CircularTimerRing(
                                progress: snapshot.progress,
                                remainingSeconds: snapshot.remainingSeconds,
                                ringColor: snapshot.ringColor,
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
                        Text(context.state.endTime, style: .time)
                            .font(.subheadline)
                    }

                    DynamicIslandExpandedRegion(.bottom) {
                        ProgressView(value: snapshot.progress)
                            .progressViewStyle(.linear)
                            .tint(snapshot.ringColor)
                            .frame(height: 1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .padding(.bottom, 8)
                    }
                } compactLeading: {
                    Text(timeLabel(for: snapshot.remainingSeconds))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                } compactTrailing: {
                    CircularTimerRing(
                        progress: snapshot.progress,
                        remainingSeconds: snapshot.remainingSeconds,
                        ringColor: snapshot.ringColor,
                        size: 14,
                        lineWidth: 2.5,
                        showText: false
                    )
                    .padding(2)
                } minimal: {
                    ZStack {
                        CircularTimerRing(
                            progress: snapshot.progress,
                            remainingSeconds: snapshot.remainingSeconds,
                            ringColor: snapshot.ringColor,
                            size: 18,
                            lineWidth: 2.5,
                            showText: false
                        )

                        Text(timeLabel(for: snapshot.remainingSeconds))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                    }
                    .padding(2)
                }
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

