import SwiftUI

struct AboutHealthBarView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What is HealthBar IRL?")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("HealthBar IRL is your real-life HP bar.")
                    Text("Gamers know you never walk into a boss fight at 60% HP with no buffs. You top off, you drink a potion, you fix your loadout.")
                    Text("Real life? We just raw dog our way into work, family drama, or social stuff on like 10 missing HP and then act surprised when everything feels harder than it should.")
                    Text("HealthBar IRL turns your day into a simple health bar you can read at a glance so you can say:")
                    Text("“Okay, I’m at like 62/100 HP right now. Why? And what can I do about it?”")
                }
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Why should I care if I’m 10 HP down?")
                        .font(.headline)
                    Text("Because being “a little off” stacks.")
                    Text("Going to your in-laws and you’re sitting at 60 HP?")
                    Text("Maybe slam some water, take a shit, stretch, and reset so you can fake caring about your father-in-law being an emotionally fragile man-child without wanting to explode.")
                    Text("Heading into work after garbage sleep and two coffees but no food?")
                    Text("That’s basically fighting the final boss with a broken sword and no health potions.")
                    Text("Knowing you’re down 10–20 HP lets you actually do something about it instead of just saying, “I’m cranky for no reason.”")
                }
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What does HealthBar IRL track?")
                        .font(.headline)
                    Text("This is not a medical device. This is a self-awareness HUD.")
                    Text("You can track stuff like:")
                    Text("• Mood – how you’re actually feeling, not what you “should” be feeling.")
                    Text("• Gut status – did you eat like a human or like a trash panda? Have you even pooped today?")
                    Text("• Sleep vibes – rested, “meh,” or walking corpse.")
                    Text("• Hydration – actual water, not just iced coffee pretending to be hydration.")
                    Text("• Stress level – chill, tense, or “one more email and I scream.”")
                    Text("All of that feeds into your daily HealthBar so you can see:")
                    Text("“Oh. I’m not broken, I’m just under-buffed.”")
                }
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("How do I use this?")
                        .font(.headline)
                    Text("The loop is simple:")
                    Text("Check your bar.")
                    Text("Look at your HP and what’s dragging it down.")
                    Text("Do 1–2 tiny fixes.")
                    Text("Drink water, move your body, go to the bathroom, step away from the screen for five minutes.")
                    Text("Watch the pattern.")
                    Text("Over time you start seeing “Oh cool, every time I don’t sleep and don’t poop, I want to fistfight the universe.”")
                    Text("This isn’t about being perfect. It’s about being slightly more buffed than yesterday.")
                }
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What HealthBar IRL is NOT")
                        .font(.headline)
                    Text("• Not a doctor.")
                    Text("• Not a diet app.")
                    Text("• Not here to shame you for goblin days.")
                    Text("It’s just a dashboard that says:")
                    Text("“You’re going into a boss fight at 58 HP. Want to fix that first?”")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("What is HealthBar IRL?")
    }
}

#Preview {
    NavigationStack {
        AboutHealthBarView()
    }
}
