import SwiftUI
import UIKit

struct MoreView: View {
    @ObservedObject var viewModel: MoreViewModel
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    remindersCard

                    hydrationSettingsCard

                    moreComingTeaser
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

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(QuestChatStrings.Reminders.settingsHeader)
                .font(.headline)
                .foregroundStyle(.secondary)

            reminderSection(
                title: QuestChatStrings.Reminders.hydrationTitle,
                subtitle: QuestChatStrings.Reminders.hydrationDescription,
                settings: $viewModel.hydrationReminderSettings,
                showFocusOnly: false
            )

            Divider()
                .padding(.vertical, 8)

            reminderSection(
                title: QuestChatStrings.Reminders.postureTitle,
                subtitle: QuestChatStrings.Reminders.postureDescription,
                settings: $viewModel.postureReminderSettings,
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
                        Text("Comfort drink per tap")
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
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var moreComingTeaser: some View {
        VStack(spacing: 8) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.mint)
                .imageScale(.large)
            Text(QuestChatStrings.MoreView.moreComing)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(QuestChatStrings.MoreView.moreComingSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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

private enum HapticsService {
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

#Preview {
    MoreView(viewModel: DependencyContainer.shared.moreViewModel)
}
