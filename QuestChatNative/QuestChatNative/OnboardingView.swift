import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

    private let hydrationPresets = [4, 6, 8, 10, 12]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    Spacer()

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
                    .frame(maxWidth: 500)

                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to WeeklyQuest")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("Turn your day into a set of clear quests with XP, levels, and a real-life HP bar.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 12) {
                bulletRow(text: "Start focus sessions for work, chores, and self-care.")
                bulletRow(text: "Keep your HP honest by logging sleep, mood, hydration, and gut.")
                bulletRow(text: "Complete daily and weekly quests to earn XP, badges, and titles for your player card.")
            }

            VStack(spacing: 10) {
                primaryButton(title: "Get started") {
                    viewModel.currentStep = .name
                }

                Button("Skip for now") {
                    viewModel.skip()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.white.opacity(0.7))
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pick your player name")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("This name will show on your Player Card next to your badges and title.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
            }

            VStack(spacing: 14) {
                TextField("Player Juan", text: $viewModel.playerName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .textInputAutocapitalization(.words)
                    .foregroundColor(.white)

                primaryButton(title: "Next", isDisabled: viewModel.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    viewModel.goToNextStep()
                }
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hydrationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set your daily water goal")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("Pick a goal that you know you won't fudge the numbers. You can always change this later.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
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
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.selectedHydrationGoalCups == cups ? Color.accentColor : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.selectedHydrationGoalCups == cups ? Color.accentColor : Color.white.opacity(0.6), lineWidth: 1)
                            )
                            .foregroundColor(viewModel.selectedHydrationGoalCups == cups ? .white : Color.white.opacity(0.85))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Goal: \(viewModel.selectedHydrationGoalCups) glasses (8oz) per day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.7))

                primaryButton(title: "Next") {
                    viewModel.goToNextStep()
                }
                .padding(.top, 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moodGutSleepStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("How is the mood/current vibe?")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text("Mood")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.8))
                moodGutRow(selection: $viewModel.selectedMoodState)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Gut")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.8))
                moodGutRow(selection: $viewModel.selectedGutState)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text("Last night's sleep")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.8))
                    Spacer()
                    Text(viewModel.selectedSleepValue.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.8))
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
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var howItWorksStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("You're ready to start your WeeklyQuest")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                bulletRow(text: "Quests: complete daily and weekly quests automatically based on progress to earn XP and badges.")
                bulletRow(text: "Focus: start timers for work, chores, and self-care. These help keep you focused.")
                bulletRow(text: "WeeklyQuest HP: keep your HP honest by updating sleep, mood, and gut each day so you know what you're working with.")
            }

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(title: "Name", value: viewModel.playerName.isEmpty ? QuestChatStrings.PlayerCard.defaultName : viewModel.playerName)
                summaryRow(title: "Water goal", value: "\(viewModel.selectedHydrationGoalCups) cups")
                summaryRow(title: "Mood", value: label(for: viewModel.selectedMoodState))
                summaryRow(title: "Gut", value: label(for: viewModel.selectedGutState))
                summaryRow(title: "Sleep", value: viewModel.selectedSleepValue.label)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.top, 18)

            primaryButton(title: "Enter WeeklyQuest") {
                viewModel.completeOnboarding()
            }
            .padding(.top, 22)
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
                    .font(.subheadline.weight(isSelected ? .bold : .semibold))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.6), lineWidth: 1)
            )
        }
        .foregroundColor(isSelected ? .white : Color.white.opacity(0.8))
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
                .foregroundColor(Color.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
    }

    private func bulletRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.mint)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            Text(text)
                .font(.body)
                .foregroundColor(Color.white.opacity(0.85))
        }
        .padding(.vertical, 2)
    }

    private func primaryButton(title: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDisabled ? Color.accentColor.opacity(0.35) : Color.accentColor)
                .foregroundColor(.black)
                .cornerRadius(20)
        }
        .disabled(isDisabled)
    }

    private func onboardingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    content()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 20)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

#Preview {
    let container = DependencyContainer.shared
    OnboardingView(viewModel: container.makeOnboardingViewModel())
        .preferredColorScheme(.dark)
}
