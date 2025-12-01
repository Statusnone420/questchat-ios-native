import SwiftUI

struct FocusView: View {
    @StateObject var viewModel: FocusViewModel

    private var formattedTime: String {
        let minutes = viewModel.secondsRemaining / 60
        let seconds = viewModel.secondsRemaining % 60
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

                if viewModel.hasFinishedOnce {
                    Text("Nice work. Start another?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Stay focused until the timer hits zero.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack(spacing: 16) {
                    Button(action: viewModel.startOrPause) {
                        Label(viewModel.isRunning ? "Pause" : "Start",
                              systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

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
        }
    }
}

#Preview {
    FocusView(viewModel: FocusViewModel())
}
