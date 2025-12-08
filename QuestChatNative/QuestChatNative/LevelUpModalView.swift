import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LevelUpModalView: View {
    let level: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 0.9
    @State private var pulseOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // dimmed background
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [Color.accentColor.opacity(0.35), Color.clear]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 220
                )
                .frame(width: 360, height: 360)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .blur(radius: 20)
                .allowsHitTesting(false)

                VStack(spacing: 20) {
                    Text("\(QuestChatStrings.FocusView.levelUpTitlePrefix)\(level)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(QuestChatStrings.FocusView.levelUpSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button(action: onDismiss) {
                        Text(QuestChatStrings.FocusView.levelUpButtonTitle)
                            .font(.headline)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.accentColor)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.9))
                        .shadow(color: Color.accentColor.opacity(0.35),
                                radius: 22, x: 0, y: 10)
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            triggerHaptic()
            pulse()
        }
        .animation(.spring(response: 0.5,
                           dampingFraction: 0.8,
                           blendDuration: 0.2),
                   value: level)
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
        #endif
    }

    private func pulse() {
        if reduceMotion { return }

        // First subtle pulse
        pulseOpacity = 0.35
        pulseScale = 0.9
        withAnimation(.easeOut(duration: 0.8)) {
            pulseOpacity = 0.0
            pulseScale = 1.35
        }

        // Follow-up, even softer pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if reduceMotion { return }
            pulseOpacity = 0.25
            pulseScale = 0.9
            withAnimation(.easeOut(duration: 0.8)) {
                pulseOpacity = 0.0
                pulseScale = 1.25
            }
        }
    }
}
