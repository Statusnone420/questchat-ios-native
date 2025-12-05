import SwiftUI

struct MoreView: View {
    @ObservedObject var viewModel: MoreViewModel
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hydrationSection

                    reminderSection

                    LegacyMoreContentView()
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("More")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(viewModel: DependencyContainer.shared.settingsViewModel)
            }
        }
    }

    private var hydrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Stepper(value: $viewModel.ouncesPerWaterTap, in: 1...64) {
                    HStack {
                        Text("Water per tap")
                        Spacer()
                        Text("\(viewModel.ouncesPerWaterTap) oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $viewModel.ouncesPerComfortTap, in: 1...64) {
                    HStack {
                        Text("Comfort beverage per tap")
                        Spacer()
                        Text("\(viewModel.ouncesPerComfortTap) oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $viewModel.dailyWaterGoalOunces, in: 8...256) {
                    HStack {
                        Text("Daily water goal")
                        Spacer()
                        Text("\(viewModel.dailyWaterGoalOunces) oz")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(QuestChatStrings.Reminders.settingsHeader)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                reminderSettingsCard(
                    title: QuestChatStrings.Reminders.hydrationTitle,
                    description: QuestChatStrings.Reminders.hydrationDescription,
                    settings: $viewModel.hydrationReminderSettings,
                    showFocusOnly: false
                )

                reminderSettingsCard(
                    title: QuestChatStrings.Reminders.postureTitle,
                    description: QuestChatStrings.Reminders.postureDescription,
                    settings: $viewModel.postureReminderSettings,
                    showFocusOnly: true
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func reminderSettingsCard(
        title: String,
        description: String,
        settings: Binding<ReminderSettings>,
        showFocusOnly: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: settings.enabled) {
                    EmptyView()
                }
                .labelsHidden()
                .tint(.mint)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(QuestChatStrings.Reminders.cadenceLabel)
                    Spacer()
                    Picker("Cadence", selection: settings.cadenceMinutes) {
                        ForEach(cadenceOptions, id: \.self) { minutes in
                            Text(QuestChatStrings.Reminders.cadenceValue(minutes))
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text(QuestChatStrings.Reminders.startHourLabel)
                    Spacer()
                    Picker("Start", selection: settings.activeStartHour) {
                        ForEach(hourOptions, id: \.self) { hour in
                            Text(hourLabel(hour))
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text(QuestChatStrings.Reminders.endHourLabel)
                    Spacer()
                    Picker("End", selection: settings.activeEndHour) {
                        ForEach(hourOptions, id: \.self) { hour in
                            Text(hourLabel(hour))
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                }

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
}

struct LegacyMoreContentView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.mint)
                .imageScale(.large)
            Text(QuestChatStrings.MoreView.moreComing)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(QuestChatStrings.MoreView.timerDurationsTitle)
                        .foregroundStyle(.secondary)
                    Text(QuestChatStrings.MoreView.timerDurationsDescription)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    AboutHealthBarView()
                } label: {
                    HStack {
                        Label("About HealthBar IRL", systemImage: "info.circle")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MoreView(viewModel: DependencyContainer.shared.moreViewModel)
}
