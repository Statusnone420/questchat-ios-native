import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Helpers

@available(iOS 17.0, *)
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

@available(iOS 17.0, *)
private func timeAbbrev(_ seconds: Int) -> String {
    let s = max(seconds, 0)
    if s >= 3600 { return "\(s / 3600)h" }
    if s >= 60 { return "\(s / 60)m" }
    return "\(s)s"
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
private func timerMetrics(for state: FocusSessionAttributes.ContentState) -> (remainingSeconds: Int, progress: Double) {
    let totalInterval = state.endDate.timeIntervalSince(state.startDate)
    let remainingInterval: TimeInterval

    if state.isPaused {
        remainingInterval = TimeInterval(max(state.remainingSeconds, 0))
    } else {
        remainingInterval = max(0, state.endDate.timeIntervalSince(.now))
    }

    let total = max(totalInterval, 0.001)
    let clampedRemaining = max(remainingInterval, 0)
    let progress = min(max(1 - (clampedRemaining / total), 0), 1)

    return (Int(ceil(clampedRemaining)), progress)
}

@available(iOS 17.0, *)
private struct CircularTimerRing: View {
    let progress: Double
    let remainingSeconds: Int
    let ringColor: Color
    var size: CGFloat = 56
    var lineWidth: CGFloat = 8
    var showText: Bool = true
    var endDate: Date? = nil

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
                if let endDate {
                    Text(endDate, style: .timer)
                        .font(.system(size: size * 0.32, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                } else {
                    Text(formattedTime(remainingSeconds))
                        .font(.system(size: size * 0.32, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Lock Screen / Expanded View

@available(iOS 17.0, *)
struct FocusSessionLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionAttributes>

    var body: some View {
        let metrics = timerMetrics(for: context.state)
        let progress = metrics.progress

        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.endDate, style: .timer)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                Text("min left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.title)
                    .font(.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Ends")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(context.state.endDate, style: .time)
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
            FocusSessionLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Regions
                DynamicIslandExpandedRegion(.leading) {
                    let metrics = timerMetrics(for: context.state)
                    let color = ringColor(forRemaining: metrics.remainingSeconds, total: context.state.totalSeconds)
                    let symbol = symbolName(forTitle: context.state.title)

                    HStack(spacing: 6) {
                        Image(systemName: symbol)
                            .symbolRenderingMode(.hierarchical)
                            .imageScale(.medium)
                            .font(.subheadline)
                            .foregroundStyle(color)
                        CircularTimerRing(
                            progress: metrics.progress,
                            remainingSeconds: metrics.remainingSeconds,
                            ringColor: color,
                            size: 32,
                            lineWidth: 4,
                            showText: true,
                            endDate: context.state.endDate
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
                    Text(context.state.endDate, style: .time)
                        .font(.subheadline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    let metrics = timerMetrics(for: context.state)
                    let color = ringColor(forRemaining: metrics.remainingSeconds, total: context.state.totalSeconds)

                    ProgressView(value: metrics.progress)
                        .progressViewStyle(.linear)
                        .tint(color)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .padding(.bottom, 8)
                }
            } compactLeading: {
                let metrics = timerMetrics(for: context.state)
                Text(timeAbbrev(metrics.remainingSeconds))
                    .font(.caption2.weight(.semibold))
            } compactTrailing: {
                let metrics = timerMetrics(for: context.state)
                let color = ringColor(forRemaining: metrics.remainingSeconds, total: context.state.totalSeconds)

                CircularTimerRing(
                    progress: metrics.progress,
                    remainingSeconds: metrics.remainingSeconds,
                    ringColor: color,
                    size: 14,
                    lineWidth: 2.5,
                    showText: false
                )
                .padding(2)
            } minimal: {
                let metrics = timerMetrics(for: context.state)
                let color = ringColor(forRemaining: metrics.remainingSeconds, total: context.state.totalSeconds)

                CircularTimerRing(
                    progress: metrics.progress,
                    remainingSeconds: metrics.remainingSeconds,
                    ringColor: color,
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
        startDate: Date(),
        endDate: Date().addingTimeInterval(1500),
        isPaused: false,
        remainingSeconds: 1500,
        totalSeconds: 1800,
        title: "Deep Work"
    )
}
#endif

