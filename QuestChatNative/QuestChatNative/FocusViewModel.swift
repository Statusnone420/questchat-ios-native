import Foundation
import Combine

/// Manages the state for the Focus timer screen.
final class FocusViewModel: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var secondsRemaining: Int = 25 * 60
    @Published var hasFinishedOnce: Bool = false

    private var timerCancellable: AnyCancellable?

    /// Starts or pauses the timer depending on the current state.
    func startOrPause() {
        if isRunning {
            stopTimer()
        } else {
            if secondsRemaining == 0 {
                secondsRemaining = 25 * 60
                hasFinishedOnce = false
            }
            startTimer()
        }
    }

    /// Resets the timer back to the full duration and clears completion state.
    func reset() {
        stopTimer()
        secondsRemaining = 25 * 60
        hasFinishedOnce = false
    }

    private func startTimer() {
        isRunning = true
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.secondsRemaining > 0 {
                    self.secondsRemaining -= 1
                } else {
                    self.stopTimer()
                    self.hasFinishedOnce = true
                }
            }
    }

    private func stopTimer() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
