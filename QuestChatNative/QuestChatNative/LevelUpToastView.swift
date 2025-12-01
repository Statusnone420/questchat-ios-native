import SwiftUI

struct LevelUpToastView: View {
    let level: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Level \(level) reached!")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            Text("You're one step closer to Level 100 QuestChat Master.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 1)
        )
        .shadow(radius: 20)
    }
}
