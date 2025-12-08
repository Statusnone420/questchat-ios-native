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

    func updateDailyQuests(_ instances: [QuestInstance]) {
        dailyQuests = instances.map { normalizeStatus(for: $0) }
    }

    func updateWeeklyQuests(_ instances: [QuestInstance]) {
        weeklyQuests = instances.map { normalizeStatus(for: $0) }
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

    private func normalizeStatus(for instance: QuestInstance) -> QuestInstance {
        var updated = instance
        if updated.progress >= updated.target {
            updated.status = .completed
        } else if updated.progress > 0 {
            updated.status = .inProgress
        } else if updated.status == .completed {
            updated.status = .completed
        } else {
            updated.status = .pending
        }
        return updated
    }
}

extension QuestEngine {
    func handle(event: QuestEvent) {
        switch event {
        case .focusSessionCompleted(let minutes):
            handleFocusSessionCompleted(durationMinutes: minutes)
        default:
            break
        }
    }

    private func handleFocusSessionCompleted(durationMinutes: Int) {
        guard durationMinutes >= 25 else { return }
        guard let index = dailyQuests.firstIndex(where: { $0.definitionId == "finish-focus-session" }) else { return }

        var updatedQuest = dailyQuests[index]
        updatedQuest.progress = max(updatedQuest.progress, updatedQuest.target)
        updatedQuest = normalizeStatus(for: updatedQuest)
        dailyQuests[index] = updatedQuest
    }
}
