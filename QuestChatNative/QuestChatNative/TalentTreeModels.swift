import Foundation

struct TalentNode: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let tier: Int      // 1–5 (higher tier = deeper in the tree)
    let column: Int    // 0–3 (horizontal placement for UI later)
    let maxRanks: Int  // e.g. 3 or 5
    let prerequisiteIDs: [String]
    let sfSymbolName: String
}

enum TalentTreeConfig {
    static let defaultNodes: [TalentNode] = [
        TalentNode(
            id: "hydrationRookie",
            name: "Hydration Rookie",
            description: "You are slightly less likely to forget your water bottle.",
            tier: 1,
            column: 0,
            maxRanks: 5,
            prerequisiteIDs: [],
            sfSymbolName: "drop"
        ),
        TalentNode(
            id: "focusSpark",
            name: "Focus Spark",
            description: "You believe you can focus for at least one solid block.",
            tier: 1,
            column: 1,
            maxRanks: 5,
            prerequisiteIDs: [],
            sfSymbolName: "bolt"
        ),
        TalentNode(
            id: "gentleReset",
            name: "Gentle Reset",
            description: "You respect short breaks instead of doom-scrolling spirals.",
            tier: 1,
            column: 2,
            maxRanks: 3,
            prerequisiteIDs: [],
            sfSymbolName: "pause.circle"
        ),
        TalentNode(
            id: "moodTuner",
            name: "Mood Tuner",
            description: "You scan your mood instead of letting it run on autopilot.",
            tier: 1,
            column: 3,
            maxRanks: 3,
            prerequisiteIDs: [],
            sfSymbolName: "face.smiling"
        ),
        TalentNode(
            id: "hydrationHabit",
            name: "Hydration Habit",
            description: "Water breaks start feeling like a habit, not a chore.",
            tier: 2,
            column: 0,
            maxRanks: 5,
            prerequisiteIDs: ["hydrationRookie"],
            sfSymbolName: "drop.circle"
        ),
        TalentNode(
            id: "deepFocusDabbler",
            name: "Deep Focus Dabbler",
            description: "You occasionally drop into distraction-free focus.",
            tier: 2,
            column: 1,
            maxRanks: 5,
            prerequisiteIDs: ["focusSpark"],
            sfSymbolName: "brain.head.profile"
        ),
        TalentNode(
            id: "tidySweep",
            name: "Tidy Sweep",
            description: "Quick resets of your space feel less impossible.",
            tier: 2,
            column: 2,
            maxRanks: 3,
            prerequisiteIDs: ["gentleReset"],
            sfSymbolName: "sparkles"
        ),
        TalentNode(
            id: "softLanding",
            name: "Soft Landing",
            description: "You are kinder to yourself when the day goes sideways.",
            tier: 2,
            column: 3,
            maxRanks: 3,
            prerequisiteIDs: ["moodTuner"],
            sfSymbolName: "heart.text.square"
        ),
        TalentNode(
            id: "hydrationDemonLite",
            name: "Hydration Demon (Lite)",
            description: "Other people start noticing you always have a drink nearby.",
            tier: 3,
            column: 0,
            maxRanks: 5,
            prerequisiteIDs: ["hydrationHabit"],
            sfSymbolName: "drop.triangle"
        ),
        TalentNode(
            id: "deepFocusDiver",
            name: "Deep Focus Diver",
            description: "Longer focus sessions feel like sessions, not punishment.",
            tier: 3,
            column: 1,
            maxRanks: 5,
            prerequisiteIDs: ["deepFocusDabbler"],
            sfSymbolName: "timer"
        ),
        TalentNode(
            id: "momentumKeeper",
            name: "Momentum Keeper",
            description: "When you break the streak, you bounce back faster.",
            tier: 3,
            column: 2,
            maxRanks: 3,
            prerequisiteIDs: ["tidySweep"],
            sfSymbolName: "flame"
        ),
        TalentNode(
            id: "sleepRespecter",
            name: "Sleep Respecter",
            description: "You treat sleep like an actual stat, not an optional side quest.",
            tier: 3,
            column: 3,
            maxRanks: 3,
            prerequisiteIDs: ["softLanding"],
            sfSymbolName: "moon.zzz"
        ),
        TalentNode(
            id: "environmentArchitect",
            name: "Environment Architect",
            description: "You set up spaces that nudge you toward good behavior.",
            tier: 4,
            column: 0,
            maxRanks: 3,
            prerequisiteIDs: ["hydrationDemonLite"],
            sfSymbolName: "square.grid.2x2"
        ),
        TalentNode(
            id: "questlineThinker",
            name: "Questline Thinker",
            description: "You see your week as a questline, not random tasks.",
            tier: 4,
            column: 1,
            maxRanks: 3,
            prerequisiteIDs: ["deepFocusDiver"],
            sfSymbolName: "list.bullet.rectangle"
        ),
        TalentNode(
            id: "socialPing",
            name: "Social Ping",
            description: "Reaching out to one person feels doable, not like a full raid.",
            tier: 4,
            column: 2,
            maxRanks: 3,
            prerequisiteIDs: ["momentumKeeper"],
            sfSymbolName: "bubble.left.and.bubble.right"
        ),
        TalentNode(
            id: "recoveryPro",
            name: "Recovery Pro",
            description: "Bad days cost you fewer HP in your headcanon.",
            tier: 4,
            column: 3,
            maxRanks: 3,
            prerequisiteIDs: ["sleepRespecter"],
            sfSymbolName: "arrow.triangle.2.circlepath"
        ),
        TalentNode(
            id: "irlHealthBarGuardian",
            name: "IRL HealthBar Guardian",
            description: "You see your body as a character sheet worth guarding.",
            tier: 5,
            column: 0,
            maxRanks: 1,
            prerequisiteIDs: ["environmentArchitect"],
            sfSymbolName: "shield"
        ),
        TalentNode(
            id: "weeklyQuestStrategist",
            name: "WeeklyQuest Strategist",
            description: "You plan the week like a mini-campaign instead of winging it.",
            tier: 5,
            column: 1,
            maxRanks: 1,
            prerequisiteIDs: ["questlineThinker"],
            sfSymbolName: "calendar"
        ),
        TalentNode(
            id: "deepWorkChampion",
            name: "Deep Work Champion",
            description: "You are proud of how often you drop into deep work on purpose.",
            tier: 5,
            column: 2,
            maxRanks: 1,
            prerequisiteIDs: ["socialPing"],
            sfSymbolName: "brain"
        ),
        TalentNode(
            id: "resilientAF",
            name: "Resilient AF",
            description: "You identify as someone who gets knocked down and gets back up.",
            tier: 5,
            column: 3,
            maxRanks: 1,
            prerequisiteIDs: ["recoveryPro"],
            sfSymbolName: "arrow.up.circle"
        )
    ]
}
