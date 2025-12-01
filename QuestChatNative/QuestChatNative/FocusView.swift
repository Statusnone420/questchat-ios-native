import SwiftUI

struct FocusView: View {
    @StateObject var viewModel: FocusTimerViewModel

    private let durationOptions: [Int] = [5, 10, 15, 20, 25, 30, 45, 60]

    private var formattedTime: String {
        let minutes = viewModel.remainingSeconds / 60
        let seconds = viewModel.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Focus Timer")
                    .font(.title.bold())

                Text(formattedTime)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .monospacedDigit()

                Text(viewModel.isRunning ? "Stay focused… you’ve got this. 💪" : "Stay focused until the timer hits zero.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Length")
                        .font(.headline)

                    Picker("Session Length", selection: $viewModel.selectedDurationMinutes) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isRunning)
                }
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button(action: viewModel.isRunning ? viewModel.pause : viewModel.start) {
                        Label(viewModel.isRunning ? "Pause" : "Start",
                              systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isRunning ? .orange : .accentColor)

                    Button(role: .destructive, action: viewModel.reset) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: viewModel.handleAppDidBecomeActive)
        }
    }
}

#Preview {
    FocusView(viewModel: FocusTimerViewModel())
}
