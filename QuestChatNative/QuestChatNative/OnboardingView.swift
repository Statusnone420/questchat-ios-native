import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

    private let hydrationPresets = [4, 6, 8, 10, 12]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    Spacer(minLength: 24)

                    onboardingCard {
                        switch viewModel.currentStep {
                        case .welcome:
                            welcomeStep
                        case .name:
                            nameStep
                        case .hydration:
                            hydrationStep
                        case .moodGutSleep:
                            moodGutSleepStep
                        case .howItWorks:
                            howItWorksStep
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to QuestChat")
                    .font(.largeTitle.bold())

                Text("Level up your day with quests, focus sessions, and honest habit tracking.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                bulletRow(text: "Start focus sessions for work, chores, and self-care")
                bulletRow(text: "Track sleep, mood, hydration, and gut health")
                bulletRow(text: "Earn XP, unlock badges, and fill your Health Bar IRL")
            }

            VStack(spacing: 12) {
                primaryButton(title: "Get started") {
                    viewModel.currentStep = .name
                }

                Button("Skip for now") {
                    viewModel.skip()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What should we call you?")
                    .font(.largeTitle.bold())

                Text("This name will show on your Player Card.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                TextField("Player name", text: $viewModel.playerName)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .textInputAutocapitalization(.words)
                    .foregroundColor(.white)

                primaryButton(title: "Next", isDisabled: viewModel.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    viewModel.goToNextStep()
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hydrationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set your daily water goal")
                    .font(.largeTitle.bold())

                Text("Pick a goal that feels realistic. You can always change this later.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(hydrationPresets, id: \.self) { cups in
                    Button {
                        viewModel.selectedHydrationGoalCups = cups
                    } label: {
                        Text("\(cups)")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedHydrationGoalCups == cups ? Color.mint : Color.clear)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.selectedHydrationGoalCups == cups ? Color.mint.opacity(0.95) : Color.white.opacity(0.2), lineWidth: 1.2)
                            )
                            .foregroundColor(viewModel.selectedHydrationGoalCups == cups ? .black : .white)
                    }
                }
            }

            Text("Goal: \(viewModel.selectedHydrationGoalCups) cups per day")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            primaryButton(title: "Next") {
                viewModel.goToNextStep()
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moodGutSleepStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("How are you feeling today?")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 12) {
                Text("Mood")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                moodGutRow(selection: $viewModel.selectedMoodState)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Gut")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                moodGutRow(selection: $viewModel.selectedGutState)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text("Last night's sleep")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.selectedSleepValue.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Slider(value: Binding<Double>(
                    get: { Double(viewModel.selectedSleepValue.rawValue) },
                    set: { newValue in
                        if let quality = SleepQuality(rawValue: Int(newValue)) {
                            viewModel.selectedSleepValue = quality
                        }
                    }
                ), in: 0...Double(SleepQuality.allCases.count - 1), step: 1)
            }

            primaryButton(title: "Next", isDisabled: viewModel.selectedMoodState == .none || viewModel.selectedGutState == .none) {
                viewModel.goToNextStep()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var howItWorksStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("You're ready to start")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 12) {
                bulletRow(text: "Quests: complete small quests to earn XP and badges.")
                bulletRow(text: "Focus: start timers for work, chores, and self-care.")
                bulletRow(text: "Health Bar IRL: keep your HP honest by updating sleep, mood, and gut each day.")
            }

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(title: "Name", value: viewModel.playerName.isEmpty ? QuestChatStrings.PlayerCard.defaultName : viewModel.playerName)
                summaryRow(title: "Water goal", value: "\(viewModel.selectedHydrationGoalCups) cups")
                summaryRow(title: "Mood", value: label(for: viewModel.selectedMoodState))
                summaryRow(title: "Gut", value: label(for: viewModel.selectedGutState))
                summaryRow(title: "Sleep", value: viewModel.selectedSleepValue.label)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            primaryButton(title: "Enter QuestChat") {
                viewModel.completeOnboarding()
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func moodGutRow(selection: Binding<MoodStatus>) -> some View {
        HStack(spacing: 12) {
            moodOption(title: "Rough", emoji: "😣", status: .bad, selection: selection)
            moodOption(title: "Okay", emoji: "😐", status: .neutral, selection: selection)
            moodOption(title: "Good", emoji: "🙂", status: .good, selection: selection)
        }
    }

    private func moodGutRow(selection: Binding<GutStatus>) -> some View {
        HStack(spacing: 12) {
            gutOption(title: "Rough", emoji: "😣", status: .rough, selection: selection)
            gutOption(title: "Okay", emoji: "😐", status: .meh, selection: selection)
            gutOption(title: "Great", emoji: "🙂", status: .great, selection: selection)
        }
    }

    private func moodOption(title: String, emoji: String, status: MoodStatus, selection: Binding<MoodStatus>) -> some View {
        selectablePill(isSelected: selection.wrappedValue == status, title: title, emoji: emoji) {
            selection.wrappedValue = status
        }
    }

    private func gutOption(title: String, emoji: String, status: GutStatus, selection: Binding<GutStatus>) -> some View {
        selectablePill(isSelected: selection.wrappedValue == status, title: title, emoji: emoji) {
            selection.wrappedValue = status
        }
    }

    private func selectablePill(isSelected: Bool, title: String, emoji: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(isSelected ? Color.mint : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.mint.opacity(0.95) : Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .foregroundColor(isSelected ? .black : .white)
    }

    private func label(for status: MoodStatus) -> String {
        switch status {
        case .good: return "Good"
        case .neutral: return "Okay"
        case .bad: return "Rough"
        case .none: return "Not set"
        }
    }

    private func label(for status: GutStatus) -> String {
        switch status {
        case .great: return "Great"
        case .meh: return "Okay"
        case .rough: return "Rough"
        case .none: return "Not set"
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func bulletRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.mint)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            Text(text)
                .font(.body)
        }
    }

    private func primaryButton(title: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDisabled ? Color.white.opacity(0.14) : Color.mint)
                .foregroundColor(isDisabled ? Color.white.opacity(0.7) : .black)
                .cornerRadius(16)
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
        .disabled(isDisabled)
    }

    private func onboardingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    content()
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: 500)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

#Preview {
    let container = DependencyContainer.shared
    OnboardingView(viewModel: container.makeOnboardingViewModel())
        .preferredColorScheme(.dark)
}
