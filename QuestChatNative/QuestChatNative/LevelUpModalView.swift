import SwiftUI

struct LevelUpModalView: View {
    let level: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("\(QuestChatStrings.FocusView.levelUpTitlePrefix)\(level)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text(QuestChatStrings.FocusView.levelUpSubtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Button(QuestChatStrings.FocusView.levelUpButtonTitle) {
                onDismiss()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundColor(.black)
            .clipShape(Capsule())
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.9))
        )
        .shadow(radius: 20)
    }
}
