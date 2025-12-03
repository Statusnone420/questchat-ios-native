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
private func ringColor(forRemaining remaining: Int, total: Int) -> Color {
    let t = max(total, 1)
    let fraction = Double(max(remaining, 0)) / Double(t)
    if fraction >= 0.5 { return .green }
    if fraction >= 0.25 { return .yellow }
    return .red
}

@available(iOS 17.0, *)
private func remainingSeconds(for state: FocusSessionAttributes.ContentState, at date: Date) -> Int {
    if state.isRunning, let endTime = state.endTime {
        return max(Int(ceil(endTime.timeIntervalSince(date))), 0)
    }
    return max(state.remainingSeconds, 0)
}

@available(iOS 17.0, *)
private struct VitalHeartView: View {
    let color: Color
    let percent: Double

    private var clampedPercent: Double { min(max(percent, 0), 1) }

    var body: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "heart.fill")
                .foregroundStyle(color.opacity(0.25))
                .font(.system(size: 16, weight: .bold))
            Image(systemName: "heart.fill")
                .foregroundStyle(color)
                .font(.system(size: 16, weight: .bold))
                .mask(
                    GeometryReader { proxy in
                        let width = proxy.size.width * clampedPercent
                        Rectangle()
                            .frame(width: width)
                    }
                )
                .opacity(clampedPercent > 0 ? 1 : 0)
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("Vital at \(Int(clampedPercent * 100)) percent")
    }
}

@available(iOS 17.0, *)
private struct CategoryIconRing: View {
    let symbol: String
    let progress: Double
    let isRunning: Bool

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(isRunning ? 1 : 0.4)
            Image(systemName: symbol)
                .imageScale(.medium)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .opacity(isRunning ? 1 : 0.7)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Lock Screen / Expanded View

@available(iOS 17.0, *)
struct FocusSessionLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionAttributes>

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            let now = timeline.date
            let total = max(context.state.totalSeconds, 1)
            let remaining = remainingSeconds(for: context.state, at: now)
            let progress = 1 - (Double(remaining) / Double(total))
            let isRunning = context.state.isRunning && context.state.endTime != nil
            let progressTint = ringColor(forRemaining: remaining, total: total)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if let endTime = context.state.endTime, isRunning {
                        Text(timerInterval: now...endTime, countsDown: true)
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .allowsTightening(true)
                    } else {
                        Text(formattedTime(remaining))
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    Text(isRunning ? "min left" : "Paused")
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
                        .tint(progressTint)
                }

                Spacer()

                if let endTime = context.state.endTime {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Ends")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(endTime, style: .time)
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .frame(minWidth: 72, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
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
                // Expanded Regions as HealthBar HUD
                DynamicIslandExpandedRegion(.leading) {
                    TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                        let now = timeline.date
                        let remaining = remainingSeconds(for: context.state, at: now)
                        let progress = 1 - (Double(remaining) / Double(max(context.state.totalSeconds, 1)))
                        CategoryIconRing(
                            symbol: context.state.categorySymbolName,
                            progress: progress,
                            isRunning: context.state.isRunning
                        )
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(context.state.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("Lv \(context.state.level)")
                                .font(.footnote.weight(.semibold))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            vitalRow(label: "HP", color: .green, percent: context.state.hpPercent)
                            vitalRow(label: "Hydration", color: .blue, percent: context.state.hydrationPercent)
                            vitalRow(label: "Mood", color: .yellow, percent: context.state.moodPercent)
                            vitalRow(label: "Stamina", color: .red, percent: context.state.staminaPercent)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if let endTime = context.state.endTime, context.state.isRunning {
                            Text(endTime, style: .time)
                                .font(.subheadline)
                        } else {
                            Text("Paused")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("Lv \(context.state.level)")
                            .font(.footnote.weight(.semibold))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                        let now = timeline.date
                        let total = max(context.state.totalSeconds, 1)
                        let remaining = remainingSeconds(for: context.state, at: now)
                        let progress = 1 - (Double(remaining) / Double(total))

                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .tint(.accentColor)
                            HStack {
                                if let endTime = context.state.endTime {
                                    Text("Ends \(endTime, style: .time)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Quest in progress — don't let future you down.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    }
                }
            } compactLeading: {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    let now = timeline.date
                    let remaining = remainingSeconds(for: context.state, at: now)
                    let progress = 1 - (Double(remaining) / Double(max(context.state.totalSeconds, 1)))
                    CategoryIconRing(
                        symbol: context.state.categorySymbolName,
                        progress: progress,
                        isRunning: context.state.isRunning
                    )
                }
            } compactTrailing: {
                HStack(spacing: 4) {
                    VitalHeartView(color: .green, percent: context.state.hpPercent)
                    VitalHeartView(color: .blue, percent: context.state.hydrationPercent)
                    VitalHeartView(color: .yellow, percent: context.state.moodPercent)
                    VitalHeartView(color: .red, percent: context.state.staminaPercent)
                }
            } minimal: {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    let now = timeline.date
                    let remaining = remainingSeconds(for: context.state, at: now)
                    let progress = 1 - (Double(remaining) / Double(max(context.state.totalSeconds, 1)))
                    CategoryIconRing(
                        symbol: context.state.categorySymbolName,
                        progress: progress,
                        isRunning: context.state.isRunning
                    )
                }
            }
        }
    }

    @available(iOS 17.0, *)
    private func vitalRow(label: String, color: Color, percent: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(width: 64, alignment: .leading)
            ProgressView(value: min(max(percent, 0), 1))
                .progressViewStyle(.linear)
                .tint(color)
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
        endTime: Date().addingTimeInterval(1500),
        isRunning: true,
        level: 10,
        overallProgress: 0.25,
        hpPercent: 0.8,
        hydrationPercent: 0.6,
        moodPercent: 0.7,
        staminaPercent: 0.4,
        categorySymbolName: "brain.head.profile"
    )
}
#endif
