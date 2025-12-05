import Foundation
import Combine

enum QuestStatus {
    case pending
    case inProgress
    case completed
    case failed
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
        self.allDefinitions = QuestCatalog.allDailyQuests + QuestCatalog.allWeeklyQuests
        self.generateDummyQuests(for: now)
    }

    private func generateDummyQuests(for date: Date) {
        let dailyInstances = allDefinitions
            .filter { $0.type == .daily }
            .map { definition in
                QuestInstance(
                    definitionId: definition.id,
                    createdAt: date,
                    status: .pending,
                    progress: 0,
                    target: 1
                )
            }

        let weeklyInstances = allDefinitions
            .filter { $0.type == .weekly }
            .map { definition in
                QuestInstance(
                    definitionId: definition.id,
                    createdAt: date,
                    status: .pending,
                    progress: 0,
                    target: 1
                )
            }

        self.dailyQuests = dailyInstances
        self.weeklyQuests = weeklyInstances
    }
}
