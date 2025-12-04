import Foundation
import Combine

enum QuestType {
    case dailyCore
    case dailyHabit
    case bonus
    case weekly
    case streak
}

enum QuestCategory {
    case focus
    case hydration
    case hpCore
    case choresWork
    case meta
}

enum QuestDifficulty {
    case tiny
    case small
    case medium
    case big
}

enum QuestStatus {
    case pending
    case inProgress
    case completed
    case failed
}

struct QuestDefinition {
    let id: String
    let type: QuestType
    let category: QuestCategory
    let difficulty: QuestDifficulty
    let xpReward: Int
    let title: String
    let subtitle: String
    let countsForDailyChestDefault: Bool
}

struct QuestInstance: Identifiable {
    let id: UUID
    let definitionId: String
    let createdAt: Date
    var status: QuestStatus
    var progress: Int
    var target: Int

    init(
        id: UUID = UUID(),
        definitionId: String,
        createdAt: Date = Date(),
        status: QuestStatus = .pending,
        progress: Int = 0,
        target: Int = 1
    ) {
        self.id = id
        self.definitionId = definitionId
        self.createdAt = createdAt
        self.status = status
        self.progress = progress
        self.target = target
    }
}

final class QuestEngine: ObservableObject {
    @Published private(set) var dailyQuests: [QuestInstance] = []
    @Published private(set) var weeklyQuests: [QuestInstance] = []

    private let allDefinitions: [QuestDefinition]

    init(now: Date = Date()) {
        // For now, hard-code a tiny sample catalog.
        self.allDefinitions = [
            QuestDefinition(
                id: "LOAD_QUEST_LOG",
                type: .dailyCore,
                category: .meta,
                difficulty: .tiny,
                xpReward: 10,
                title: "Load today’s quest log",
                subtitle: "Open the quests tab to see what’s on deck.",
                countsForDailyChestDefault: true
            ),
            QuestDefinition(
                id: "PLAN_FOCUS_SESSION",
                type: .dailyCore,
                category: .focus,
                difficulty: .medium,
                xpReward: 35,
                title: "Plan one focus session",
                subtitle: "Pick a timer and commit to at least one run today.",
                countsForDailyChestDefault: true
            ),
            QuestDefinition(
                id: "HEALTHBAR_CHECKIN",
                type: .dailyCore,
                category: .hpCore,
                difficulty: .medium,
                xpReward: 35,
                title: "HealthBar check-in",
                subtitle: "Update mood, gut, and sleep for today.",
                countsForDailyChestDefault: true
            )
        ]

        self.generateDummyQuests(for: now)
    }

    private func generateDummyQuests(for date: Date) {
        // For now, just generate one QuestInstance per definition
        // so that we have something to display later.
        let instances = allDefinitions.map { definition in
            QuestInstance(
                definitionId: definition.id,
                createdAt: date,
                status: .pending,
                progress: 0,
                target: 1
            )
        }

        self.dailyQuests = instances
        self.weeklyQuests = [] // Will be filled in a later pass
    }
}
