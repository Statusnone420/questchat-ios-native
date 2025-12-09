import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Helpers

@available(iOS 16.1, *)
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

@available(iOS 16.1, *)
private func timeAbbrev(_ seconds: Int) -> String {
    let s = max(seconds, 0)
    if s >= 3600 { return "\(s / 3600)h" }
    if s >= 60 { return "\(s / 60)m" }
    return "\(s)s"
}

@available(iOS 16.1, *)
private func ringColor(forRemaining remaining: Int, total: Int) -> Color {
    let t = max(total, 1)
    let fraction = Double(max(remaining, 0)) / Double(t)
    if fraction >= 0.5 { return .green }
    if fraction >= 0.25 { return .yellow }
    return .red
}

@available(iOS 16.1, *)
private func symbolName(forTitle title: String) -> String {
    let t = title.lowercased()
    if t.contains("deep") || t.contains("focus") { return "brain.head.profile" }
    if t.contains("work") || t.contains("sprint") { return "bolt.circle" }
    if t.contains("chore") { return "house.fill" }
    if t.contains("self") || t.contains("care") { return "figure.mind.and.body" }
    if t.contains("game") { return "gamecontroller" }
    if t.contains("break") || t.contains("quick") { return "figure.run" }
    return "timer"
}

@available(iOS 16.1, *)
private func remainingSeconds(
    for context: ActivityViewContext<FocusSessionAttributes>,
    at date: Date = Date()
) -> Int {
    if context.state.isPaused {
        return max(context.state.remainingSeconds, 0)
    }
    return max(Int(ceil(context.state.endDate.timeIntervalSince(date))), 0)
}

@available(iOS 16.1, *)
private func progress(
    for context: ActivityViewContext<FocusSessionAttributes>,
    at date: Date = Date()
) -> Double {
    let total = max(context.attributes.totalSeconds, max(context.state.remainingSeconds, 1))
    let remaining = remainingSeconds(for: context, at: date)
    return Double(remaining) / Double(total)
}

@available(iOS 17.0, *)
private struct CircularTimerRing: View {
    let progress: Double
    let remainingSeconds: Int
    let ringColor: Color
    var size: CGFloat = 56
    var lineWidth: CGFloat = 8
    var showText: Bool = true
    var timerRange: ClosedRange<Date>? = nil

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
                if #available(iOSApplicationExtension 17.0, *), let timerRange {
                    Text(
                        timerInterval: timerRange,
                        pauseTime: nil,
                        countsDown: true,
                        showsHours: true
                    )
                    .font(.system(size: size * 0.32, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .foregroundStyle(.primary)
                    .frame(width: size * 0.9, alignment: .center)
                } else if let endDate = timerRange?.upperBound {
                    Text(endDate, style: .timer)
                        .font(.system(size: size * 0.32, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(.primary)
                        .frame(width: size * 0.9, alignment: .center)
                } else {
                    Text(formattedTime(remainingSeconds))
                        .font(.system(size: size * 0.32, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(.primary)
                        .frame(width: size * 0.9, alignment: .center)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Lock Screen / Expanded View

@available(iOS 16.1, *)
struct FocusSessionLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionAttributes>

    private var timerRange: ClosedRange<Date> { context.state.startDate...context.state.endDate }
    private var remaining: Int { remainingSeconds(for: context) }
    private var progressValue: Double { progress(for: context) }
    private var accentColor: Color { ringColor(forRemaining: remaining, total: max(context.attributes.totalSeconds, 1)) }

    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            liveActivity17
        } else {
            liveActivity16
        }
    }

    @ViewBuilder
    private var liveActivity17: some View {
        let range = timerRange

        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if context.state.isPaused {
                    Text(formattedTime(remaining))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                } else {
                    Text(
                        timerInterval: range,
                        pauseTime: nil,
                        countsDown: true,
                        showsHours: true
                    )
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                }
                Text("min left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.title)
                    .font(.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if context.state.isPaused {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .tint(accentColor)
                } else {
                    ProgressView(timerInterval: range, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.linear)
                    .tint(accentColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Ends")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(context.state.endDate, style: .time)
                    .font(.subheadline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .padding(.trailing, 10)
            }
            .frame(minWidth: 72, alignment: .trailing)
        }
        .padding()
    }

    @ViewBuilder
    private var liveActivity16: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if context.state.isPaused {
                    Text(formattedTime(remaining))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                } else {
                    Text(context.state.endDate, style: .timer)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                }
                Text("min left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.title)
                    .font(.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ProgressView(value: progressValue)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
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

@available(iOS 16.1, *)
struct FocusSessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            FocusSessionLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                let range = context.state.startDate...context.state.endDate
                let total = max(context.attributes.totalSeconds, max(context.state.remainingSeconds, 1))
                let remaining = remainingSeconds(for: context)
                let color = ringColor(forRemaining: remaining, total: total)
                let symbol = symbolName(forTitle: context.state.title)
                
                // Expanded Regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: symbol)
                            .symbolRenderingMode(.hierarchical)
                            .imageScale(.medium)
                            .font(.subheadline)
                            .foregroundStyle(color)

                        if #available(iOSApplicationExtension 17.0, *) {
                            let range = context.state.startDate...context.state.endDate

                            if context.state.isPaused {
                                // Frozen ring + time when paused
                                ZStack {
                                    ProgressView(value: progress(for: context))
                                        .progressViewStyle(.circular)
                                        .tint(color)

                                    Text(formattedTime(remaining))
                                        .font(.system(size: 11, weight: .medium))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)
                                        .padding(.horizontal, 2)
                                        .frame(width: 40, alignment: .center)
                                }
                                .frame(width: 40, height: 40)
                                .padding(2)
                            } else {
                                // Animated countdown while running
                                ZStack {
                                    ProgressView(timerInterval: range, countsDown: true) {
                                        EmptyView()
                                    } currentValueLabel: {
                                        EmptyView()
                                    }
                                    .progressViewStyle(.circular)
                                    .tint(color)

                                    Text(
                                        timerInterval: range,
                                        pauseTime: nil,
                                        countsDown: true,
                                        showsHours: false
                                    )
                                    .font(.system(size: 11, weight: .medium))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                    .padding(.horizontal, 5)
                                    .frame(width: 40, alignment: .center)
                                }
                                .frame(width: 40, height: 40)
                                .padding(2)
                            }
                        } else {
                            EmptyView()
                        }
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
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .padding(.trailing, 5)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if #available(iOSApplicationExtension 17.0, *) {
                        if context.state.isPaused {
                            // Frozen bar on pause
                            ProgressView(value: progress(for: context))
                                .progressViewStyle(.linear)
                                .tint(color)
                                .frame(height: 1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .padding(.bottom, 8)
                        } else {
                            // Animated bar while running
                            ProgressView(timerInterval: range, countsDown: true) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .progressViewStyle(.linear)
                            .tint(color)
                            .frame(height: 1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .padding(.bottom, 8)
                        }
                    } else {
                        // iOS 16 fallback
                        ProgressView(value: progress(for: context))
                            .progressViewStyle(.linear)
                            .tint(color)
                            .frame(height: 1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .padding(.bottom, 8)
                    }
                }
            } compactLeading: {
                let range = context.state.startDate...context.state.endDate
                let remaining = remainingSeconds(for: context)

                if #available(iOSApplicationExtension 17.0, *) {
                    if context.state.isPaused {
                        // Frozen countdown when paused
                        Text(formattedTime(remaining))
                            .font(.system(size: 14, weight: .medium))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .center)
                    } else {
                        // Animated system countdown when running
                        Text(
                            timerInterval: range,
                            pauseTime: nil,
                            countsDown: true,
                            showsHours: false
                        )
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .center)
                    }
                } else {
                    // super simple fallback for iOS 16.1–16.x
                    Text("\(remaining)s")
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .center)
                }
            } compactTrailing: {
                let range = context.state.startDate...context.state.endDate
                let total = max(context.attributes.totalSeconds,
                                max(context.state.remainingSeconds, 1))
                let remaining = remainingSeconds(for: context)
                let color = ringColor(forRemaining: remaining, total: total)

                if #available(iOSApplicationExtension 17.0, *) {
                    if context.state.isPaused {
                        // Frozen circular bar on pause
                        ProgressView(value: progress(for: context))
                            .progressViewStyle(.circular)
                            .tint(color)
                            .frame(width: 25, height: 25)
                            .padding(2)
                    } else {
                        // Animated circular bar while running
                        ProgressView(timerInterval: range, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .progressViewStyle(.circular)
                        .tint(color)
                        .frame(width: 25, height: 25)
                        .padding(2)
                    }
                } else {
                    EmptyView()
                }
            } minimal: {
                let range = context.state.startDate...context.state.endDate
                let total = max(context.attributes.totalSeconds, max(context.state.remainingSeconds, 1))
                let remaining = remainingSeconds(for: context)
                let color = ringColor(forRemaining: remaining, total: total)

                if #available(iOSApplicationExtension 17.0, *) {
                    ProgressView(timerInterval: range, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(color)
                    .frame(width: 16, height: 16)
                    .padding(2)
                } else {
                    EmptyView()
                }
            }
        }
    }
}
    
#if DEBUG
@available(iOS 17.0, *)
#Preview("Focus Session", as: .content, using: FocusSessionAttributes(sessionId: UUID(), totalSeconds: 1800)) {
    FocusSessionLiveActivityWidget()
} contentStates: {
    FocusSessionAttributes.ContentState(
        startDate: Date(),
        endDate: Date().addingTimeInterval(1500),
        isPaused: false,
        remainingSeconds: 1500,
        title: "Deep Work",
        category: "work"
    )
}
#endif

