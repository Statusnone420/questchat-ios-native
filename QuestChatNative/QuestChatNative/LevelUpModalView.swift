import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LevelUpModalView: View {
    let levelUp: PendingLevelUp
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 0.9
    @State private var pulseOpacity: Double = 0.0
    @State private var flashOpacity: Double = 0.0
    @State private var iconScale: CGFloat = 0.0
    @State private var iconRotation: Double = 0.0

    var body: some View {
        ZStack {
            // dimmed background
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // Flash effect for jackpot
            if levelUp.tier == .jackpot {
                Color.white
                    .opacity(flashOpacity)
                    .ignoresSafeArea()
            }

            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [gradientColor.opacity(gradientOpacity), Color.clear]),
                    center: .center,
                    startRadius: 10,
                    endRadius: gradientEndRadius
                )
                .frame(width: gradientSize, height: gradientSize)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .blur(radius: gradientBlur)
                .allowsHitTesting(false)

                VStack(spacing: tierSpacing) {
                    // Tier-specific icon
                    if let icon = tierIcon {
                        Image(systemName: icon)
                            .font(.system(size: iconSize))
                            .foregroundStyle(iconGradient)
                            .scaleEffect(iconScale)
                            .rotationEffect(.degrees(iconRotation))
                            .shadow(color: iconColor.opacity(0.5), radius: 10)
                    }

                    Text("\(QuestChatStrings.FocusView.levelUpTitlePrefix)\(levelUp.level)")
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: shadowColor, radius: shadowRadius)

                    Text(tierSubtitle)
                        .font(subtitleFont)
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
                    .background(buttonBackground)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)
                    .shadow(color: buttonShadowColor, radius: buttonShadowRadius)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.9))
                        .shadow(color: cardShadowColor,
                                radius: cardShadowRadius, x: 0, y: 10)
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            triggerHaptic()
            pulse()
            animateIcon()
            if levelUp.tier == .jackpot {
                triggerFlash()
            }
        }
        .animation(.spring(response: 0.5,
                           dampingFraction: 0.8,
                           blendDuration: 0.2),
                   value: levelUp.level)
    }

    // MARK: - Tier-based styling properties
    
    private var gradientSize: CGFloat {
        switch levelUp.tier {
        case .normal: 360
        case .milestone: 450
        case .jackpot: 550
        }
    }
    
    private var gradientEndRadius: CGFloat {
        switch levelUp.tier {
        case .normal: 220
        case .milestone: 280
        case .jackpot: 350
        }
    }
    
    private var gradientBlur: CGFloat {
        switch levelUp.tier {
        case .normal: 20
        case .milestone: 25
        case .jackpot: 35
        }
    }
    
    private var gradientColor: Color {
        switch levelUp.tier {
        case .normal: .accentColor
        case .milestone: .purple
        case .jackpot: .yellow
        }
    }
    
    private var gradientOpacity: Double {
        switch levelUp.tier {
        case .normal: 0.35
        case .milestone: 0.45
        case .jackpot: 0.6
        }
    }
    
    private var titleSize: CGFloat {
        switch levelUp.tier {
        case .normal: 34
        case .milestone: 42
        case .jackpot: 54
        }
    }
    
    private var tierSpacing: CGFloat {
        switch levelUp.tier {
        case .normal: 20
        case .milestone: 24
        case .jackpot: 28
        }
    }
    
    private var tierIcon: String? {
        switch levelUp.tier {
        case .normal: nil
        case .milestone: "star.circle.fill"
        case .jackpot: "crown.fill"
        }
    }
    
    private var iconSize: CGFloat {
        switch levelUp.tier {
        case .normal: 0
        case .milestone: 40
        case .jackpot: 60
        }
    }
    
    private var iconColor: Color {
        switch levelUp.tier {
        case .normal: .clear
        case .milestone: .purple
        case .jackpot: .yellow
        }
    }
    
    private var iconGradient: LinearGradient {
        switch levelUp.tier {
        case .normal:
            LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        case .milestone:
            LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)
        case .jackpot:
            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private var tierSubtitle: String {
        switch levelUp.tier {
        case .normal:
            QuestChatStrings.FocusView.levelUpSubtitle
        case .milestone:
            "🎯 Milestone Achievement! Keep grinding!"
        case .jackpot:
            "SPECIAL LEVEL UP ACHIVEMENT SCREEN THINGY! YAY!"
        }
    }
    
    private var subtitleFont: Font {
        switch levelUp.tier {
        case .normal: .subheadline
        case .milestone: .headline.weight(.semibold)
        case .jackpot: .title3.weight(.bold)
        }
    }
    
    private var shadowColor: Color {
        switch levelUp.tier {
        case .normal: .clear
        case .milestone: .purple.opacity(0.5)
        case .jackpot: .yellow.opacity(0.7)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch levelUp.tier {
        case .normal: 0
        case .milestone: 10
        case .jackpot: 20
        }
    }
    
    private var buttonBackground: Color {
        switch levelUp.tier {
        case .normal: .accentColor
        case .milestone: .purple
        case .jackpot: .yellow
        }
    }
    
    private var buttonShadowColor: Color {
        switch levelUp.tier {
        case .normal: .clear
        case .milestone: .purple.opacity(0.5)
        case .jackpot: .yellow.opacity(0.7)
        }
    }
    
    private var buttonShadowRadius: CGFloat {
        switch levelUp.tier {
        case .normal: 0
        case .milestone: 8
        case .jackpot: 15
        }
    }
    
    private var cardShadowColor: Color {
        switch levelUp.tier {
        case .normal: Color.accentColor.opacity(0.35)
        case .milestone: Color.purple.opacity(0.5)
        case .jackpot: Color.yellow.opacity(0.7)
        }
    }
    
    private var cardShadowRadius: CGFloat {
        switch levelUp.tier {
        case .normal: 22
        case .milestone: 30
        case .jackpot: 40
        }
    }
    
    // MARK: - Animation methods

    private func triggerHaptic() {
        #if canImport(UIKit)
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let intensity: CGFloat
        
        switch levelUp.tier {
        case .normal:
            style = .soft
            intensity = 0.9
        case .milestone:
            style = .medium
            intensity = 1.0
        case .jackpot:
            style = .heavy
            intensity = 1.0
        }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
        
        // Extra haptics for milestone and jackpot
        if levelUp.tier == .milestone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                generator.impactOccurred(intensity: 0.8)
            }
        }
        
        if levelUp.tier == .jackpot {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                generator.impactOccurred(intensity: 0.9)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                generator.impactOccurred(intensity: 0.8)
            }
        }
        #endif
    }

    private func pulse() {
        if reduceMotion { return }

        let pulseCount: Int
        switch levelUp.tier {
        case .normal: pulseCount = 2
        case .milestone: pulseCount = 3
        case .jackpot: pulseCount = 4
        }

        for i in 0..<pulseCount {
            let delay = Double(i) * 0.25
            let intensity = 1.0 - (Double(i) * 0.15)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if self.reduceMotion { return }
                self.pulseOpacity = 0.35 * intensity
                self.pulseScale = 0.9
                withAnimation(.easeOut(duration: 0.8)) {
                    self.pulseOpacity = 0.0
                    self.pulseScale = 1.35
                }
            }
        }
    }
    
    private func animateIcon() {
        guard tierIcon != nil, !reduceMotion else { return }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            iconScale = 1.0
        }
        
        if levelUp.tier == .jackpot {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                iconRotation = 10
            }
        }
    }
    
    private func triggerFlash() {
        guard !reduceMotion else { return }
        
        flashOpacity = 0.3
        withAnimation(.easeOut(duration: 0.15)) {
            flashOpacity = 0.0
        }
        
        // Second flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.flashOpacity = 0.2
            withAnimation(.easeOut(duration: 0.15)) {
                self.flashOpacity = 0.0
            }
        }
    }
}
