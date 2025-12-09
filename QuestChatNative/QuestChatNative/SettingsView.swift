import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var moreViewModel: MoreViewModel
    @State private var pendingReset: ResetWindow?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    VStack(spacing: 16) {
                        remindersCard

                        hydrationSettingsCard

                        aboutWeeklyQuestCard

#if DEBUG
                        debugToolsCard
#endif

                        resetCard
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Confirm reset", isPresented: Binding(
                get: { pendingReset != nil },
                set: { newValue in
                    if !newValue { pendingReset = nil }
                }
            ), actions: {
                Button("Cancel", role: .cancel) {
                    pendingReset = nil
                }
                Button("Confirm", role: .destructive) {
                    if let window = pendingReset {
                        viewModel.reset(window: window)
                    }
                    pendingReset = nil
                }
            }, message: {
                Group {
                    if let pendingReset {
                        switch pendingReset {
                        case .full:
                            Text("This will erase all locally stored progress and settings. The app may need to be fully restarted afterward.")
                        case .today, .last7Days:
                            Text("This will remove data recorded in the selected time window, including sessions, XP, health logs, daily ratings, and quest progress for the affected days.")
                        }
                    } else {
                        Text("")
                    }
                }
            })
        }
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(QuestChatStrings.Reminders.settingsHeader)
                .font(.headline)
                .foregroundStyle(.secondary)

            reminderSection(
                title: QuestChatStrings.Reminders.hydrationTitle,
                subtitle: QuestChatStrings.Reminders.hydrationDescription,
                settings: $moreViewModel.hydrationReminderSettings,
                showFocusOnly: false
            )

            Divider()
                .padding(.vertical, 8)

            reminderSection(
                title: QuestChatStrings.Reminders.postureTitle,
                subtitle: QuestChatStrings.Reminders.postureDescription,
                settings: $moreViewModel.postureReminderSettings,
                showFocusOnly: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func reminderSection(
        title: String,
        subtitle: String,
        settings: Binding<ReminderSettings>,
        showFocusOnly: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: settings.enabled) {
                    EmptyView()
                }
                .labelsHidden()
                .tint(.mint)
                .onChange(of: settings.enabled.wrappedValue) { _ in
                    HapticsService.lightImpact()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                reminderPickerRow(
                    label: QuestChatStrings.Reminders.everyLabel,
                    selection: settings.cadenceMinutes,
                    options: cadenceOptions,
                    titleForOption: QuestChatStrings.Reminders.everyValue
                )

                reminderPickerRow(
                    label: QuestChatStrings.Reminders.startHourLabel,
                    selection: settings.activeStartHour,
                    options: hourOptions,
                    titleForOption: hourLabel
                )

                reminderPickerRow(
                    label: QuestChatStrings.Reminders.endHourLabel,
                    selection: settings.activeEndHour,
                    options: hourOptions,
                    titleForOption: hourLabel
                )

                if showFocusOnly {
                    Toggle(isOn: settings.onlyDuringFocusSessions) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(QuestChatStrings.Reminders.focusOnlyLabel)
                                .font(.subheadline)
                            Text(QuestChatStrings.Reminders.focusOnlyDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.mint)
                }
            }
            .font(.subheadline)
        }
    }

    private func reminderPickerRow(
        label: String,
        selection: Binding<Int>,
        options: [Int],
        titleForOption: @escaping (Int) -> String
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { value in
                    Text(titleForOption(value))
                        .tag(value)
                }
            }
            .pickerStyle(.menu)
        }
        .onChange(of: selection.wrappedValue) { _ in
            HapticsService.selectionChanged()
        }
    }

    private var hydrationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(QuestChatStrings.MoreView.hydrationSettingsTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(QuestChatStrings.MoreView.hydrationSettingsSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Stepper(value: $moreViewModel.ouncesPerWaterTap, in: 1...64) {
                    HStack {
                        Text("Water per tap")
                        Spacer()
                        Text("\(moreViewModel.ouncesPerWaterTap) oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $moreViewModel.ouncesPerComfortTap, in: 1...64) {
                    HStack {
                        Text("Comfort drink per tap")
                        Spacer()
                        Text("\(moreViewModel.ouncesPerComfortTap) oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $moreViewModel.dailyWaterGoalOunces, in: 8...256) {
                    HStack {
                        Text("Daily water goal")
                        Spacer()
                        Text("\(moreViewModel.dailyWaterGoalOunces) oz")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var aboutWeeklyQuestCard: some View {
        NavigationLink {
            AboutHealthBarView()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .imageScale(.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text("What is WeeklyQuest?")
                        .font(.headline)
                    Text("Learn how the weekly questline works.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

#if DEBUG
    private var debugToolsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug tools")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                let stats = DependencyContainer.shared.sessionStatsStore
                let xpRemainingInLevel = max(stats.xpNeededToLevelUp(from: stats.level) - stats.xpIntoCurrentLevel, 0)
                let xpGrant = max(xpRemainingInLevel, 1)
                stats.grantXP(xpGrant, source: "DEBUG_SIMULATE_LEVEL_UP")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.mint)
                    Text("Simulate Level Up")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mint.opacity(0.18))
                .foregroundStyle(.mint)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                let stats = DependencyContainer.shared.sessionStatsStore
                stats.grantXP(500, source: "DEBUG_XP_GRANT")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.mint)
                    Text("Grant +500 XP")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mint.opacity(0.18))
                .foregroundStyle(.mint)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
#endif

    private var resetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                resetButton(title: "Reset today", window: .today)
                resetButton(title: "Reset last 7 days", window: .last7Days)
                resetButton(title: "Full reset", window: .full, role: .destructive)
            }
            .font(.subheadline)

            Text("Time-window resets remove recent sessions, XP, and health logs only. Full reset clears all local progress and settings; restart the app afterward for a fresh start.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cadenceOptions: [Int] { [30, 45, 60, 90] }
    private var hourOptions: [Int] { Array(0...23) }

    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func resetButton(title: String, window: ResetWindow, role: ButtonRole? = nil) -> some View {
        Button(role: role) {
            pendingReset = window
        } label: {
            Text(title)
                .foregroundColor(role == .destructive ? .red : .primary)
        }
    }
}

private enum HapticsService {
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

#Preview {
    let hydrationSettingsStore = HydrationSettingsStore()
    let reminderSettingsStore = ReminderSettingsStore()
    let playerStateStore = DependencyContainer.shared.playerStateStore
    let playerTitleStore = DependencyContainer.shared.playerTitleStore
    let talentTreeStore = DependencyContainer.shared.talentTreeStore
    let statsStore = SessionStatsStore(
        playerStateStore: playerStateStore,
        playerTitleStore: playerTitleStore,
        talentTreeStore: talentTreeStore
    )

    SettingsView(
        viewModel: SettingsViewModel(resetter: GameDataResetter(
            healthStatsStore: HealthBarIRLStatsStore(),
            xpStore: statsStore,
            sessionStatsStore: statsStore,
            dailyHealthRatingsStore: DailyHealthRatingsStore()
        )),
        moreViewModel: MoreViewModel(
            hydrationSettingsStore: hydrationSettingsStore,
            reminderSettingsStore: reminderSettingsStore
        )
    )
}

