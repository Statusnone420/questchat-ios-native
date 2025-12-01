import SwiftUI

struct LevelUpModalView: View {
    let level: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // dimmed background
            Color.black.opacity(0.55)
                .ignoresSafeArea()

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
        .animation(.spring(response: 0.5,
                           dampingFraction: 0.8,
                           blendDuration: 0.2),
                   value: level)
    }
}
