import SwiftUI

struct AboutHealthBarView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What is WeeklyQuest?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What is WeeklyQuest?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("WeeklyQuest is your weekly questline for real life.\n\nIn games, you don’t level up by randomly doing stuff. You get a clear list of quests: do X, get Y XP, unlock cool titles and rewards.\n\nIn real life, most weeks are just chaos. You put out fires, scroll your phone, and then suddenly it’s Sunday and you have no idea what you actually did.\n\nWeeklyQuest turns your week into a simple set of quests so you can say:\n\n“Okay, these are my 3–5 small wins for this week. What can I knock out today?”")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("Why should I care about WeeklyQuest?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("Because “just get your life together” is useless advice.\n\nA whole week is too big. A whole self-improvement plan is too big. But 1–2 tiny quests you can actually finish? That’s doable.\n\nWeeklyQuest gives you bite-sized, repeatable wins. Instead of vaguely “trying to be better,” you get concrete things like:\n\n• Finish a Work focus session.\n• Do a small self-care quest.\n• Drink the water you said you would.\n\nEach completed quest is proof you actually did something that helped Future You.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("What does WeeklyQuest track?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("WeeklyQuest is not a medical tracker. It’s your “did I actually do the helpful stuff?” log.\n\nIt looks at things like:")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Focus timers – showing up for Work, Chores, Self Care, or Chill without doomscrolling the whole day.")
                        Text("• Self-care quests – the small, boring, unsexy moves that actually help (water, breaks, moving your body).")
                        Text("• Life admin – the annoying grown-up tasks you keep postponing until they become a crisis.")
                        Text("• Boundaries – closing the app, stepping away from screens, or not letting one bad day nuke your whole week.")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                    Text("All of that feeds into your WeeklyQuest progress so you can see: “Oh. I actually did a lot of good tiny things this week, even if my brain says I did nothing.”")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("How do I use this?")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    Text("The loop is simple:\n\n1. Open WeeklyQuest.\n2. Look at the quests for this week.\n3. Pick 1–2 that feel doable **today**, not “ideal version of me” stuff.\n4. Use the app like normal (timers, water, posture, etc.) and let the game auto-credit you when you hit those quests.\n5. Check back a few times this week and watch the bar and badges fill in.\n\nOver time you start seeing patterns like: “When I hit even a couple WeeklyQuests, my week feels less like a blur and more like progress.”\n\nThis isn’t about perfection. It’s about stacking tiny wins instead of tiny self-hates.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("What WeeklyQuest is NOT")
                        .font(.title3.bold())
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Not a productivity cult.")
                        Text("• Not a punishment system for “bad weeks.”")
                        Text("• Not therapy or a replacement for professional help.")
                        Text("• Not here to shame you for goblin-mode days.")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                    Text("It’s just a weekly quest log that says:\n“You’re not lazy, your brain just needs smaller quests. Want to pick one for today?”")
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
        .navigationTitle("What is WeeklyQuest?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutHealthBarView()
    }
}
