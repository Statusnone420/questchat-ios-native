import SwiftUI

struct AboutHealthBarView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What is HealthBar IRL?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What is HealthBar IRL?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("HealthBar IRL is your real-life HP bar.\n\nIn games, you never walk into a boss fight at 60 HP with no buffs on. You top off, you drink a potion, you fix your loadout.\n\nIn real life, most of us do the opposite. We grind through work, family stuff, and social plans on low HP and then act surprised when everything feels harder than it should.\n\nHealthBar IRL turns your day into a simple health bar you can read at a glance so you can say:\n\n“Okay, I’m at about 62/100 HP right now. Why? And what can I do about it?”")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("Why should I care if I’m 10 HP down?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("Because being “a little off” stacks.\n\nGoing to your in-laws and you’re sitting at 60 HP? Every small thing hits harder.\n\nHeading into work after garbage sleep and two coffees but no food? That’s basically fighting the final boss with a broken sword and no health potions.\n\nKnowing you’re down 10–20 HP lets you actually do something about it instead of just saying, “I’m cranky for no reason.”")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("What does HealthBar IRL track?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("This is not a medical device. This is a self-awareness HUD.\n\nYou can track things like:")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Mood – how you’re actually feeling, not what you “should” be feeling.")
                        Text("• Gut status – did you eat like a human today? Are you regular, or not?")
                        Text("• Sleep vibes – rested, “meh,” or walking corpse.")
                        Text("• Hydration – actual water, not just iced coffee pretending to be hydration.")
                        Text("• Stress level – chill, tense, or “one more email and I scream.”")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                    Text("All of that feeds into your daily HealthBar so you can see: “Oh. I’m not broken, I’m just under-buffed.”")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("How do I use this?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("The loop is simple:\n\n1. Check your bar.\n2. Look at your HP and what’s dragging it down.\n3. Do 1–2 tiny fixes:\n   • Drink water.\n   • Move your body.\n   • Go to the bathroom.\n   • Step away from the screen for five minutes.\n4. Watch the pattern.\n\nOver time you start seeing, “Every time I don’t sleep and don’t take care of myself, my HP tanks.”\n\nThis isn’t about being perfect. It’s about being slightly more buffed than yesterday.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("What HealthBar IRL is NOT")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Not a doctor.")
                        Text("• Not a diet app.")
                        Text("• Not therapy or a replacement for professional help.")
                        Text("• Not here to shame you for goblin days.")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                    Text("It’s just a dashboard that says:\n“You’re going into a boss fight at 58 HP. Want to fix that first?”")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("What is HealthBar IRL?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutHealthBarView()
    }
}
