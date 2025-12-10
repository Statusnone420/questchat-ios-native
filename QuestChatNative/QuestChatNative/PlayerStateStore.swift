import Foundation
import Combine

/// Observable object representing the player's current state within QuestChat.
final class PlayerStateStore: ObservableObject {
    @Published var currentHP: Int
    @Published var maxHP: Int
    @Published var xp: Int
    @Published var level: Int
    @Published var hydration: Int
    @Published var mood: Int
    @Published var gutStatus: Int
    @Published var sleepQuality: Int
    @Published var activeDebuffs: [String]
    @Published var activeBuffs: [String]
    @Published var pendingLevelUp: PendingLevelUp?
    
    @Published var equippedBadgeID: String? {
        didSet { saveEquippedBadge() }
    }

    private let userDefaults: UserDefaults
    private let calendar = Calendar.current

    // Daily flags
    private var waterGoalXPGrantedToday: Bool
    private var sleepXPGrantedToday: Bool
    private var gutXPGrantedToday: Bool
    private var trifectaGrantedToday: Bool
    private var lastBuffResetDate: Date?

    init(
        currentHP: Int = 100,
        maxHP: Int = 100,
        xp: Int = 0,
        level: Int = 1,
        hydration: Int = 100,
        mood: Int = 0,
        gutStatus: Int = 0,
        sleepQuality: Int = 3,
        activeDebuffs: [String] = [],
        activeBuffs: [String] = [],
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.hydration = hydration
        self.mood = mood
        self.gutStatus = gutStatus
        self.sleepQuality = sleepQuality
        self.activeDebuffs = activeDebuffs
        self.activeBuffs = activeBuffs

        let storedXP = userDefaults.integer(forKey: Keys.xp)
        let storedLevel = userDefaults.integer(forKey: Keys.level)
        self.xp = storedXP > 0 ? storedXP : xp
        self.level = storedLevel > 0 ? storedLevel : level
        self.pendingLevelUp = nil

        let storedBadge = userDefaults.string(forKey: Keys.equippedBadgeID)
        self.equippedBadgeID = storedBadge

        self.waterGoalXPGrantedToday = userDefaults.bool(forKey: Keys.waterGoalXPGrantedToday)
        self.sleepXPGrantedToday = userDefaults.bool(forKey: Keys.sleepXPGrantedToday)
        self.gutXPGrantedToday = userDefaults.bool(forKey: Keys.gutXPGrantedToday)
        self.trifectaGrantedToday = userDefaults.bool(forKey: Keys.trifectaGrantedToday)
        self.lastBuffResetDate = userDefaults.object(forKey: Keys.lastBuffResetDate) as? Date

        refreshDailyStateIfNeeded()
    }

    var hpPercentage: Double {
        guard maxHP > 0 else { return 0 }
        let percentage = Double(currentHP) / Double(maxHP)
        return min(max(percentage, 0), 1)
    }
}

// MARK: - XP & Level rules (v3 - buff only)
extension PlayerStateStore {
    enum SessionType {
        case focus
        case selfCare
    }

    func grantSessionXP(minutes: Int, type: SessionType) {
        guard minutes > 0 else { return }
        applyDailyStateRefresh()
        let baseXP = minutes * 10
        addXPWithMultiplier(baseXP)
    }

    func grantHealthXPForWaterGoal() {
        applyDailyStateRefresh()
        guard !waterGoalXPGrantedToday else { return }
        activateBuff(.hydrated)
        addXPWithMultiplier(250)
        waterGoalXPGrantedToday = true
        userDefaults.set(true, forKey: Keys.waterGoalXPGrantedToday)
        grantHealthTrifectaIfEligible()
    }

    func grantHealthXPForSleep() {
        applyDailyStateRefresh()
        guard !sleepXPGrantedToday else { return }
        activateBuff(.rested)
        addXPWithMultiplier(250)
        sleepXPGrantedToday = true
        userDefaults.set(true, forKey: Keys.sleepXPGrantedToday)
        grantHealthTrifectaIfEligible()
    }

    func grantHealthXPForGut() {
        applyDailyStateRefresh()
        guard !gutXPGrantedToday else { return }
        activateBuff(.gutHappy)
        addXPWithMultiplier(250)
        gutXPGrantedToday = true
        userDefaults.set(true, forKey: Keys.gutXPGrantedToday)
        grantHealthTrifectaIfEligible()
    }

    func applyMoodBuffIfPositive() {
        applyDailyStateRefresh()
        activateBuff(.rayOfSunshine)
        grantHealthTrifectaIfEligible()
    }

    func grantHealthTrifectaIfEligible() {
        applyDailyStateRefresh()
        guard !trifectaGrantedToday else { return }
        let requiredBuffs: Set<Buff> = [.hydrated, .rested, .gutHappy]
        let activeSet = Set(activeBuffs.compactMap { Buff(rawValue: $0) })
        guard requiredBuffs.isSubset(of: activeSet) else { return }
        addXPWithMultiplier(500)
        trifectaGrantedToday = true
        userDefaults.set(true, forKey: Keys.trifectaGrantedToday)
    }

    func grantStreakXP() {
        applyDailyStateRefresh()
        addXPWithMultiplier(100)
    }

    func grantQuestXP(amount: Int) {
        applyDailyStateRefresh()
        guard amount > 0 else { return }
        addXPWithMultiplier(amount)
    }

    func resetXP() {
        xp = 0
        level = 1
        pendingLevelUp = nil
        persistProgress()
    }
}

// MARK: - Private helpers
private extension PlayerStateStore {
    enum Buff: String {
        case hydrated = "Hydrated"
        case rested = "Rested"
        case gutHappy = "Gut Happy"
        case rayOfSunshine = "Ray of Sunshine"
    }

    enum Keys {
        static let xp = "player_total_xp"
        static let level = "player_level"
        static let waterGoalXPGrantedToday = "water_goal_xp_granted_today"
        static let sleepXPGrantedToday = "sleep_xp_granted_today"
        static let gutXPGrantedToday = "gut_xp_granted_today"
        static let trifectaGrantedToday = "trifecta_xp_granted_today"
        static let lastBuffResetDate = "last_buff_reset_date"
        static let activeBuffs = "player_active_buffs"
        static let equippedBadgeID = "equippedBadgeID"
    }

    func addXPWithMultiplier(_ baseXP: Int) {
        let multiplier = 1.0 + 0.2 * Double(activeBuffs.count)
        let adjusted = Int((Double(baseXP) * multiplier).rounded())
        let previousLevel = level
        xp += adjusted
        level = min(100, (xp / 1000) + 1)
        persistProgress()

        if level > previousLevel {
            let tier = LevelUpTier.compute(oldLevel: previousLevel, newLevel: level)
            pendingLevelUp = PendingLevelUp(level: level, tier: tier)
        }
    }

    func activateBuff(_ buff: Buff) {
        if !activeBuffs.contains(buff.rawValue) {
            activeBuffs.append(buff.rawValue)
            userDefaults.set(activeBuffs, forKey: Keys.activeBuffs)
        }
    }

    func applyDailyStateRefresh() {
        refreshDailyStateIfNeeded()
    }

    func refreshDailyStateIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        if let lastReset = lastBuffResetDate, calendar.isDate(lastReset, inSameDayAs: today) {
            return
        }

        lastBuffResetDate = today
        userDefaults.set(today, forKey: Keys.lastBuffResetDate)

        waterGoalXPGrantedToday = false
        sleepXPGrantedToday = false
        gutXPGrantedToday = false
        trifectaGrantedToday = false

        userDefaults.set(false, forKey: Keys.waterGoalXPGrantedToday)
        userDefaults.set(false, forKey: Keys.sleepXPGrantedToday)
        userDefaults.set(false, forKey: Keys.gutXPGrantedToday)
        userDefaults.set(false, forKey: Keys.trifectaGrantedToday)

        activeBuffs = []
        userDefaults.set(activeBuffs, forKey: Keys.activeBuffs)
    }

    func persistProgress() {
        userDefaults.set(xp, forKey: Keys.xp)
        userDefaults.set(level, forKey: Keys.level)
    }
    
    func saveEquippedBadge() {
        userDefaults.set(equippedBadgeID, forKey: Keys.equippedBadgeID)
    }
}
