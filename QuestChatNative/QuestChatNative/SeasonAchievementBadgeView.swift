import SwiftUI

struct SeasonAchievementBadgeView: View {
    let title: String
    let iconName: String
    let isUnlocked: Bool
    let progressFraction: CGFloat
    let isCompact: Bool
    let size: BadgeSize
    
    enum BadgeSize {
        case grid      // 64pt - for stats grid
        case hero      // 120pt - for unlock overlay
        
        var diameter: CGFloat {
            switch self {
            case .grid: return 64
            case .hero: return 120
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .grid: return 28
            case .hero: return 52
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .grid: return 8
            case .hero: return 12
            }
        }
    }

    init(
        title: String,
        iconName: String,
        isUnlocked: Bool,
        progressFraction: CGFloat,
        isCompact: Bool = false,
        size: BadgeSize = .grid
    ) {
        self.title = title
        self.iconName = iconName
        self.isUnlocked = isUnlocked
        self.progressFraction = progressFraction
        self.isCompact = isCompact
        self.size = size
    }

    private var badgeDiameter: CGFloat {
        isCompact ? 32 : size.diameter
    }

    private var iconFontSize: CGFloat {
        isCompact ? 16 : size.iconSize
    }

    private var shadowRadius: CGFloat {
        isCompact ? 4 : size.shadowRadius
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer shadow for depth (3D effect)
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .blur(radius: 8)
                    .offset(y: 4)
                    .opacity(isUnlocked ? 1.0 : 0.3)
                
                // Main coin body with metallic gradient
                Circle()
                    .fill(backgroundGradient)
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.clear,
                                        Color.black.opacity(0.2)
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: badgeDiameter * 0.8
                                )
                            )
                    )
                    .opacity(isUnlocked ? 1.0 : 0.3)
                
                // Metallic rim/border
                Circle()
                    .strokeBorder(borderGradient, lineWidth: 4)
                    .opacity(isUnlocked ? 1.0 : 0.3)
                
                // Inner highlight for dimension
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        ),
                        lineWidth: 2
                    )
                    .padding(4)
                    .opacity(isUnlocked ? 1.0 : 0.3)

                iconView
                    .font(.system(size: iconFontSize, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isUnlocked ? [.white, .white.opacity(0.8)] : [.gray, .gray.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .opacity(isUnlocked ? 1.0 : 0.5)
            }
            .frame(width: badgeDiameter, height: badgeDiameter)
            .shadow(color: isUnlocked ? Color.purple.opacity(0.5) : .clear, radius: shadowRadius, y: isCompact ? 2 : 6)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

            if !isCompact {
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .opacity(isUnlocked ? 1.0 : 0.6)

                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                    .opacity(isUnlocked ? 1.0 : 0.4)
            }
        }
    }

    private var iconView: some View {
        if iconName.contains(".") == false && iconName.unicodeScalars.count == 1 {
            AnyView(Text(iconName))
        } else {
            AnyView(Image(systemName: iconName))
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: isUnlocked ? [
                .white,
                .yellow.opacity(0.9),
                .orange.opacity(0.7),
                .yellow.opacity(0.9),
                .white
            ] : [
                .gray.opacity(0.6),
                .black.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: isUnlocked ? [
                .purple.opacity(0.9),
                .purple,
                .blue.opacity(0.8),
                .blue,
                .purple.opacity(0.7)
            ] : [
                .gray.opacity(0.6),
                .black.opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            SeasonAchievementBadgeView(title: "Hydration Demon", iconName: "💧", isUnlocked: true, progressFraction: 1, size: .grid)
            SeasonAchievementBadgeView(title: "Focus", iconName: "bolt.fill", isUnlocked: false, progressFraction: 0.4, size: .grid)
        }
        
        Text("Hero Size (Unlock Overlay)")
            .font(.caption)
            .foregroundStyle(.secondary)
        
        SeasonAchievementBadgeView(title: "Tree of Life", iconName: "tree.fill", isUnlocked: true, progressFraction: 1, isCompact: true, size: .hero)
    }
    .padding()
    .background(Color.black)
    .previewLayout(.sizeThatFits)
}
