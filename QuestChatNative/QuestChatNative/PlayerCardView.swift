import SwiftUI
import Combine

struct LevelTitleDefinition {
    let minLevel: Int
    let title: String
}

enum PlayerTitles {
    static let rookie   = "Focus Rookie"      // 1–9
    static let worker   = "Deep Inside Focus"       // 10–19
    static let knight   = "Quest Knight"      // 20–29
    static let master   = "Wookie Rookie"       // 30–39
    static let sage     = "Time Sage"         // 40–49
    static let fiend    = "Focus Fiend"       // 50–59
    static let guardian = "Grind Guardian"    // 60–69
    static let tyrant   = "Tempo Tyrant"      // 70–79
    static let overlord = "Attention Overlord"// 80–89
    static let noLifer  = "Focus No Lifer"    // 90–100
}

enum PlayerTitleConfig {
    static let levelTitles: [LevelTitleDefinition] = [
        .init(minLevel: 1,  title: PlayerTitles.rookie),
        .init(minLevel: 10, title: PlayerTitles.worker),
        .init(minLevel: 20, title: PlayerTitles.knight),
        .init(minLevel: 30, title: PlayerTitles.master),
        .init(minLevel: 40, title: PlayerTitles.sage),
        .init(minLevel: 50, title: PlayerTitles.fiend),
        .init(minLevel: 60, title: PlayerTitles.guardian),
        .init(minLevel: 70, title: PlayerTitles.tyrant),
        .init(minLevel: 80, title: PlayerTitles.overlord),
        .init(minLevel: 90, title: PlayerTitles.noLifer)
    ]

    static func unlockedLevelTitles(for level: Int) -> [String] {
        levelTitles
            .filter { level >= $0.minLevel }
            .map { $0.title }
    }

    static func bestTitle(for level: Int) -> String {
        unlockedLevelTitles(for: level).last ?? PlayerTitles.rookie
    }
}

struct Buff: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: Color
    let duration: TimeInterval
    let startedAt: Date

    var remaining: TimeInterval { max(0, duration - Date().timeIntervalSince(startedAt)) }
    var progress: CGFloat { duration > 0 ? CGFloat(remaining / duration) : 0 }

    enum CodingKeys: String, CodingKey { case id, name, description, icon, colorHex, duration, startedAt }

    // Encode Color as RGBA hex string
    private static func colorToHex(_ color: Color) -> String {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255)), ai = Int(round(a * 255))
        return String(format: "%02X%02X%02X%02X", ri, gi, bi, ai)
        #else
        return "FFFFFFFF"
        #endif
    }

    private static func colorFromHex(_ hex: String) -> Color {
        var hexStr = hex
        if hexStr.count == 6 { hexStr += "FF" }
        let scanner = Scanner(string: hexStr)
        var value: UInt64 = 0
        guard scanner.scanHexInt64(&value) else { return .white }
        let r = Double((value >> 24) & 0xFF) / 255.0
        let g = Double((value >> 16) & 0xFF) / 255.0
        let b = Double((value >> 8) & 0xFF) / 255.0
        let a = Double(value & 0xFF) / 255.0
        #if canImport(UIKit)
        return Color(UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a)))
        #else
        return Color(red: r, green: g, blue: b).opacity(a)
        #endif
    }

    init(name: String, description: String, icon: String, color: Color, duration: TimeInterval, startedAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.duration = duration
        self.startedAt = startedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let description = try container.decode(String.self, forKey: .description)
        let icon = try container.decode(String.self, forKey: .icon)
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        let duration = try container.decode(TimeInterval.self, forKey: .duration)
        let startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = Buff.colorFromHex(colorHex)
        self.duration = duration
        self.startedAt = startedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(icon, forKey: .icon)
        try container.encode(Buff.colorToHex(color), forKey: .colorHex)
        try container.encode(duration, forKey: .duration)
        try container.encode(startedAt, forKey: .startedAt)
    }
}

final class PotionManager: ObservableObject {
    static let shared = PotionManager()

    @Published var activeBuffs: [Buff] = []
    @Published var isHealthOnCooldown: Bool = false
    @Published var isManaOnCooldown: Bool = false
    @Published var isStaminaOnCooldown: Bool = false
    
    private static let buffNameAliases: [String: String] = [
        "Regeneration": "Full AF",
        "Clarity": "Hydrated",
        "Second Wind": "Energized"
    ]
    
    @Published var healthReadyAt: Date? = nil
    @Published var manaReadyAt: Date? = nil
    @Published var staminaReadyAt: Date? = nil

    private let buffsKey = "player.activeBuffs.v1"
    private let cooldownsKey = "player.cooldowns.v1"

    private struct CooldownState: Codable {
        let healthReadyAt: Date?
        let manaReadyAt: Date?
        let staminaReadyAt: Date?
    }

    private var timer: Timer?

    private func loadState() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: buffsKey) {
            if let decoded = try? JSONDecoder().decode([Buff].self, from: data) {
                // Drop expired buffs on load
                var filtered = decoded.filter { $0.remaining > 0 }
                // Migrate old names to new aliases to avoid duplicates
                for i in filtered.indices {
                    if let newName = PotionManager.buffNameAliases[filtered[i].name] {
                        // Recreate buff with new name but preserve original duration and start time so remaining stays correct
                        let migrated = Buff(
                            name: newName,
                            description: filtered[i].description,
                            icon: filtered[i].icon,
                            color: filtered[i].color,
                            duration: filtered[i].duration,
                            startedAt: filtered[i].startedAt
                        )
                        filtered[i] = migrated
                    }
                }
                // If migration changed anything, dedupe by name keeping the latest remaining duration
                var seen: [String: Buff] = [:]
                for b in filtered {
                    if let existing = seen[b.name] {
                        // Keep the one with more remaining time
                        seen[b.name] = (b.remaining >= existing.remaining) ? b : existing
                    } else {
                        seen[b.name] = b
                    }
                }
                self.activeBuffs = Array(seen.values)
                // Persist migrated state
                saveState()
            }
        }
        if let data = defaults.data(forKey: cooldownsKey) {
            if let decoded = try? JSONDecoder().decode(CooldownState.self, from: data) {
                self.healthReadyAt = decoded.healthReadyAt
                self.manaReadyAt = decoded.manaReadyAt
                self.staminaReadyAt = decoded.staminaReadyAt
                self.isHealthOnCooldown = (decoded.healthReadyAt ?? .distantPast) > Date()
                self.isManaOnCooldown = (decoded.manaReadyAt ?? .distantPast) > Date()
                self.isStaminaOnCooldown = (decoded.staminaReadyAt ?? .distantPast) > Date()
            }
        }
    }

    private func saveState() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(self.activeBuffs) {
            defaults.set(data, forKey: buffsKey)
        }
        let cooldowns = CooldownState(healthReadyAt: self.healthReadyAt, manaReadyAt: self.manaReadyAt, staminaReadyAt: self.staminaReadyAt)
        if let data = try? JSONEncoder().encode(cooldowns) {
            defaults.set(data, forKey: cooldownsKey)
        }
    }

    func cooldownProgress(readyAt: Date?, total: TimeInterval) -> CGFloat {
        guard let readyAt else { return 0 }
        let remaining = max(0, readyAt.timeIntervalSinceNow)
        guard total > 0 else { return 0 }
        return CGFloat(remaining / total) // 1 -> 0 as time elapses
    }

    func start() {
        stop()
        loadState()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func tick() {
        let before = activeBuffs
        activeBuffs.removeAll { $0.remaining <= 0 }
        if before != activeBuffs { saveState() }
        // Check cooldowns finishing and persist
        if let ready = healthReadyAt, ready <= Date() {
            isHealthOnCooldown = false; healthReadyAt = nil; saveState()
        }
        if let ready = manaReadyAt, ready <= Date() {
            isManaOnCooldown = false; manaReadyAt = nil; saveState()
        }
        if let ready = staminaReadyAt, ready <= Date() {
            isStaminaOnCooldown = false; staminaReadyAt = nil; saveState()
        }
    }
    
    func upsertBuff(name: String, description: String, icon: String, color: Color, duration: TimeInterval) {
        // Match by either the new name or any old alias that maps to this name
        let aliasMatches: (Buff) -> Bool = { buff in
            if buff.name == name { return true }
            // If this incoming name is a canonical new name, check if buff has any old alias that maps to it
            for (old, new) in PotionManager.buffNameAliases where new == name {
                if buff.name == old { return true }
            }
            return false
        }
        if let idx = activeBuffs.firstIndex(where: aliasMatches) {
            // Refresh by replacing with a new instance that restarts the timer
            let refreshed = Buff(name: name, description: description, icon: icon, color: color, duration: duration)
            activeBuffs[idx] = refreshed
        } else {
            let buff = Buff(name: name, description: description, icon: icon, color: color, duration: duration)
            activeBuffs.append(buff)
        }
        saveState()
    }
}

struct BuffBarView: View {
    @ObservedObject var manager: PotionManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manager.activeBuffs) { buff in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().stroke(buff.color.opacity(0.25), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: buff.progress)
                                .stroke(AngularGradient(colors: [buff.color, .white, buff.color], center: .center), lineWidth: 4)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.5), value: buff.progress)
                            Image(systemName: buff.icon).font(.caption.bold())
                        }
                        .frame(width: 28, height: 28)

                        Text(buff.name)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(buff.color)
                        
                        Text("\(max(1, Int(ceil(buff.remaining / 60))))m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
                    .accessibilityLabel("\(buff.name): \(buff.description). \(Int(buff.remaining))s remaining")
                }
            }
        }
    }
}

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var statsViewModel: StatsViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel
    @ObservedObject var dailyRatingsStore: DailyHealthRatingsStore = DependencyContainer.shared.dailyHealthRatingsStore
    let isEmbedded: Bool
    @State private var isTitlePickerPresented = false
    @State private var moodSliderValue: Int?
    @State private var gutSliderValue: Int?
    @State private var sleepSliderValue: Int?
    @State private var avatarSpin: Double = 0

    @StateObject private var potionManager = PotionManager()
    @State private var auraColor: Color? = nil
    
    @State private var showHealthPopover = false
    @State private var showManaPopover = false
    @State private var showStaminaPopover = false
    
    @State private var suppressNextTap = false
    
    private let healthCooldown: TimeInterval = 30
    private let manaCooldown: TimeInterval = 30
    private let staminaCooldown: TimeInterval = 45
    
    private let defaultBuffDuration: TimeInterval = 30 * 60 // 30 minutes

    @AppStorage("playerDisplayName") private var playerDisplayName: String = QuestChatStrings.PlayerCard.defaultName
    @AppStorage("playerId") private var playerIdString: String = UUID().uuidString
    @AppStorage("playerAvatarStyleIndex") private var avatarStyleIndex: Int = -1
    
    @AppStorage("playerAvatarShuffleBag") private var avatarShuffleBagData: Data = Data()
    @AppStorage("playerAvatarRecentHistory") private var avatarRecentHistoryData: Data = Data()

    private struct AvatarStyle {
        let symbolName: String
        let colors: [Color]
    }

    private let avatarStyles: [AvatarStyle] = [
        // Science & Tech
        AvatarStyle(symbolName: "atom", colors: [.cyan, .blue]),
        AvatarStyle(symbolName: "cpu.fill", colors: [.indigo, .purple]),
        AvatarStyle(symbolName: "antenna.radiowaves.left.and.right", colors: [.teal, .blue]),
        AvatarStyle(symbolName: "bolt.horizontal.circle.fill", colors: [.yellow, .orange]),

        // Magic & Fantasy
        AvatarStyle(symbolName: "sparkles", colors: [.teal, .cyan]),
        AvatarStyle(symbolName: "wand.and.stars", colors: [.purple, .pink]),
        AvatarStyle(symbolName: "moon.stars.fill", colors: [.indigo, .purple]),
        AvatarStyle(symbolName: "sun.max.fill", colors: [.orange, .red]),

        // Nature & Elements
        AvatarStyle(symbolName: "leaf.fill", colors: [.green, .teal]),
        AvatarStyle(symbolName: "flame.fill", colors: [.red, .orange]),
        AvatarStyle(symbolName: "drop.fill", colors: [.cyan, .blue]),
        AvatarStyle(symbolName: "wind", colors: [.mint, .teal]),

        // Gaming & Fun
        AvatarStyle(symbolName: "gamecontroller.fill", colors: [.mint, .teal]),
        AvatarStyle(symbolName: "die.face.5.fill", colors: [.pink, .purple]),
        AvatarStyle(symbolName: "gamecontroller", colors: [.blue, .indigo]),

        // Health & Mind
        AvatarStyle(symbolName: "brain.head.profile", colors: [.purple, .indigo]),
        AvatarStyle(symbolName: "heart.fill", colors: [.red, .pink]),
        AvatarStyle(symbolName: "bolt.fill", colors: [.orange, .pink]),

        // Space & Adventure
        AvatarStyle(symbolName: "globe.americas.fill", colors: [.blue, .green]),
        AvatarStyle(symbolName: "paperplane.fill", colors: [.teal, .cyan]),
        AvatarStyle(symbolName: "airplane.circle.fill", colors: [.pink, .orange]),

        // Tools & Craft
        AvatarStyle(symbolName: "hammer.fill", colors: [.gray, .orange]),
        AvatarStyle(symbolName: "wrench.fill", colors: [.blue, .gray]),
        AvatarStyle(symbolName: "paintbrush.pointed.fill", colors: [.pink, .teal]),

        // Music & Vibes
        AvatarStyle(symbolName: "music.note", colors: [.purple, .blue]),
        AvatarStyle(symbolName: "headphones", colors: [.indigo, .teal]),
        AvatarStyle(symbolName: "waveform", colors: [.red, .purple]),

        // Sports & Movement
        AvatarStyle(symbolName: "figure.walk", colors: [.green, .mint]),
        AvatarStyle(symbolName: "bicycle", colors: [.teal, .indigo]),
        AvatarStyle(symbolName: "figure.run", colors: [.orange, .red]),

        // Learning & Growth
        AvatarStyle(symbolName: "book.fill", colors: [.blue, .purple]),
        AvatarStyle(symbolName: "graduationcap.fill", colors: [.indigo, .teal]),
        AvatarStyle(symbolName: "lightbulb.fill", colors: [.yellow, .orange]),
    ]

    // MARK: Avatar randomization helpers
    private struct ShuffleState: Codable {
        var bag: [Int] = []
        var recent: [Int] = []
    }

    private var recentWindowSize: Int { max(2, min(4, avatarStyles.count / 2)) }

    private func loadShuffleState() -> ShuffleState {
        if let decoded = try? JSONDecoder().decode(ShuffleState.self, from: avatarShuffleBagData),
           let recent = try? JSONDecoder().decode([Int].self, from: avatarRecentHistoryData) {
            return ShuffleState(bag: decoded.bag, recent: Array(recent.suffix(recentWindowSize)))
        }
        return ShuffleState(bag: [], recent: [])
    }

    private func saveShuffleState(_ state: ShuffleState) {
        if let bagData = try? JSONEncoder().encode(ShuffleState(bag: state.bag, recent: [])) {
            avatarShuffleBagData = bagData
        }
        if let recentData = try? JSONEncoder().encode(Array(state.recent.suffix(recentWindowSize))) {
            avatarRecentHistoryData = recentData
        }
    }

    private func refillBag(excluding recent: [Int]) -> [Int] {
        let all = Array(0..<avatarStyles.count)
        let filtered = all.filter { !recent.contains($0) }
        // If filtering removes everything (small list), fall back to all
        return filtered.isEmpty ? all.shuffled() : filtered.shuffled()
    }

    private func nextRandomAvatarIndex() -> Int {
        var state = loadShuffleState()
        if state.bag.isEmpty {
            state.bag = refillBag(excluding: state.recent)
        }
        guard let next = state.bag.first else { return Int.random(in: 0..<avatarStyles.count) }
        state.bag.removeFirst()
        state.recent.append(next)
        if state.recent.count > recentWindowSize { state.recent.removeFirst(state.recent.count - recentWindowSize) }
        saveShuffleState(state)
        return next
    }

    private func deterministicAvatarIndex(from id: UUID) -> Int {
        let scalars = id.uuidString.unicodeScalars
        let hash = scalars.reduce(UInt32(0)) { partial, scalar in
            (partial &* 31) &+ scalar.value
        }
        return Int(hash % UInt32(avatarStyles.count))
    }

    private func avatarStyle(for id: UUID) -> AvatarStyle {
        let index = deterministicAvatarIndex(from: id)
        return avatarStyles[index]
    }

    private var playerId: UUID {
        if let existing = UUID(uuidString: playerIdString) {
            return existing
        }

        let generated = UUID()
        playerIdString = generated.uuidString
        return generated
    }

    init(
        store: SessionStatsStore,
        statsViewModel: StatsViewModel,
        healthBarViewModel: HealthBarViewModel,
        focusViewModel: FocusViewModel,
        isEmbedded: Bool = false
    ) {
        _store = ObservedObject(wrappedValue: store)
        _statsViewModel = ObservedObject(wrappedValue: statsViewModel)
        _healthBarViewModel = ObservedObject(wrappedValue: healthBarViewModel)
        _focusViewModel = ObservedObject(wrappedValue: focusViewModel)
        self.isEmbedded = isEmbedded

        // Initialize persistent avatar style index once
        if avatarStyleIndex < 0 || avatarStyleIndex >= avatarStyles.count {
            // Seed shuffle state once and pick a non-repeating random index
            var state = loadShuffleState()
            if state.bag.isEmpty { state.bag = refillBag(excluding: state.recent) }
            if let first = state.bag.first {
                state.bag.removeFirst()
                state.recent.append(first)
                if state.recent.count > recentWindowSize { state.recent.removeFirst(state.recent.count - recentWindowSize) }
                saveShuffleState(state)
                avatarStyleIndex = first
            } else {
                // Fallback to deterministic index if needed
                let baseIndex = deterministicAvatarIndex(from: UUID(uuidString: playerIdString) ?? UUID())
                avatarStyleIndex = baseIndex
            }
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            headerCard

            playerHUDSection

            // Active buffs
            if !potionManager.activeBuffs.isEmpty {
                BuffBarView(manager: potionManager)
                    .padding(.horizontal, 4)
            }

            // Quick potions row
            HStack(spacing: 12) {
                cooldownPotionButton(label: "Health", systemImage: "cross.case.fill", color: .green, cooldown: healthCooldown, readyAt: $potionManager.healthReadyAt, isCooling: $potionManager.isHealthOnCooldown, showPopover: $showHealthPopover) {
                    useHealthPotion()
                }
                .popover(isPresented: $showHealthPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    potionPopover(title: "Full AF", subtitle: "Food time! A good meal heals over time and leaves you feeling refreshed.", color: .green, icon: "leaf.fill")
                        .presentationCompactAdaptation(.none)
                        .onDisappear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { suppressNextTap = false }
                        }
                }

                cooldownPotionButton(label: "Mana", systemImage: "drop.fill", color: .cyan, cooldown: manaCooldown, readyAt: $potionManager.manaReadyAt, isCooling: $potionManager.isManaOnCooldown, showPopover: $showManaPopover) {
                    useManaPotion()
                }
                .popover(isPresented: $showManaPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    potionPopover(title: "Hydrated", subtitle: "Logs hydration and boosts clarity for a short while.", color: .cyan, icon: "sparkles")
                        .presentationCompactAdaptation(.none)
                        .onDisappear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { suppressNextTap = false }
                        }
                }

                cooldownPotionButton(label: "Stamina", systemImage: "bolt.fill", color: .orange, cooldown: staminaCooldown, readyAt: $potionManager.staminaReadyAt, isCooling: $potionManager.isStaminaOnCooldown, showPopover: $showStaminaPopover) {
                    useStaminaPotion()
                }
                .popover(isPresented: $showStaminaPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    potionPopover(title: "Energized", subtitle: "A burst of energy that helps you push through.", color: .orange, icon: "bolt.fill")
                        .presentationCompactAdaptation(.none)
                        .onDisappear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { suppressNextTap = false }
                        }
                }
            }
            .accessibilityElement(children: .contain)

            VStack(alignment: .leading, spacing: 12) {
                statRow(label: QuestChatStrings.PlayerCard.levelLabel, value: "\(store.level)", tint: .mint)
                statRow(label: QuestChatStrings.PlayerCard.totalXPLabel, value: "\(store.xp)", tint: .cyan)
                statRow(label: QuestChatStrings.PlayerCard.streakLabel, value: "\(store.currentStreakDays) days", tint: .orange)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
            .cornerRadius(16)

            HStack {
                Text(store.statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            statusSection

            Spacer(minLength: 0)
        }
        .padding()
    }

    var body: some View {
        ZStack {
            Group {
                if isEmbedded {
                    content
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        content
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }

            // Level-up overlay when Player Card is presented as a sheet
            if let levelUp = store.pendingLevelUp {
                LevelUpModalView(level: levelUp) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.pendingLevelUp = nil
                    }
                }
                .zIndex(100)
                .transition(.opacity.combined(with: .scale))
            }

            if let aura = auraColor {
                Color.clear
                    .background(aura)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(200)
            }
        }
        .background(Color.black.ignoresSafeArea())
        // Removed onAppear to rely solely on DailyHealthRatingsStore as canonical source for slider values
        .sheet(isPresented: $isTitlePickerPresented) {
            NavigationStack {
                VStack(spacing: 16) {
                    List {
                        Section("Level titles") {
                            ForEach(PlayerTitleConfig.unlockedLevelTitles(for: store.level), id: \.self) { title in
                                Button {
                                    // Treat level titles as the base track: clear any override and set base to this selection via the view model.
                                    statsViewModel.setBaseLevelTitle(title)
                                    isTitlePickerPresented = false
                                } label: {
                                    HStack {
                                        Text(title)
                                        Spacer()
                                        if statsViewModel.activeTitle == title {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                        }

                        Section("Achievement titles") {
                            ForEach(Array(statsViewModel.unlockedAchievementTitles).sorted(), id: \.self) { title in
                                Button {
                                    statsViewModel.equipOverrideTitle(title)
                                    isTitlePickerPresented = false
                                } label: {
                                    HStack {
                                        Text(title)
                                        Spacer()
                                        if statsViewModel.activeTitle == title {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                .navigationTitle("Choose Title")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isTitlePickerPresented = false
                        }
                    }
                }
            }
        }
        .onAppear { potionManager.start() }
        .onDisappear { potionManager.stop() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            let style = avatarStyles[max(0, min(avatarStyleIndex, avatarStyles.count - 1))]
            let avatarScale: CGFloat = 1.5
            let avatarSize: CGFloat = 56 * avatarScale

            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: style.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: avatarSize, height: avatarSize)

                    Image(systemName: style.symbolName)
                        .font(.system(size: avatarSize * 0.42, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(avatarSpin))
                        .scaleEffect(avatarSpin == 0 ? 1 : 1.06)
                }
                .onTapGesture { randomizeAvatar() }
                .overlay(alignment: .topTrailing) {
                    Button {
                        randomizeAvatar()
                    } label: {
                        Image(systemName: "dice.fill")
                            .font(.system(size: max(12, avatarSize * 0.10), weight: .bold))
                            .foregroundStyle(.white)
                            .padding(max(6, avatarSize * 0.04))
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                            .contentShape(Circle())
                            .accessibilityLabel("Randomize avatar")
                            .accessibilityHint("Generates a new avatar style")
                    }
                    .buttonStyle(.plain)
                    .offset(x: max(6, avatarSize * 0.11), y: -max(6, avatarSize * 0.11))
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField(QuestChatStrings.PlayerCard.namePlaceholder, text: $playerDisplayName)
                        .font(.title2.weight(.bold))
                        .textFieldStyle(.plain)
                        .layoutPriority(1)

                    HStack(spacing: 8) {
                        Text("Level \(store.level)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let label = statsViewModel.xpBoostLabel {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption2)

                                Text(label)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)              // never wrap
                                    .minimumScaleFactor(0.9)   // tiny shrink instead of wrapping if needed
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.cyan.opacity(0.7),
                                                Color.purple.opacity(0.7)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                            .foregroundColor(.white)
                            .fixedSize(horizontal: true, vertical: true) // size just to its content
                        }

                        Spacer()

                        Text("\(healthBarViewModel.currentHP) / \(healthBarViewModel.maxHP) HP")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    RPGStatBar(
                        iconName: "heart.fill",
                        label: "HP",
                        color: .red,
                        progress: healthBarViewModel.hpProgress,
                        segments: healthBarViewModel.hpSegments
                    )
                    .frame(height: 36)

                    Button {
                        isTitlePickerPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.caption)

                            Text(statsViewModel.activeTitle ?? "Choose a title")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.8)
                                .allowsTightening(true)

                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.cyan.opacity(0.26))
                        )
                    }
                    .buttonStyle(.plain)

                    // Removed badges row from here

                }

                Spacer()
            }

            let unlockedBadges = statsViewModel.seasonAchievements.filter { $0.isUnlocked }
            if !unlockedBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(unlockedBadges) { item in
                            SeasonAchievementBadgeView(
                                title: item.title,
                                iconName: item.iconName,
                                isUnlocked: true,
                                progressFraction: 1.0,
                                isCompact: true
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground).opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 2)
                .transition(.opacity.combined(with: .scale))
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: unlockedBadges.count)
            }

            Text("Your real-life stats, achivements, badges, and titles.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 16)
    }

    private func statRow(label: String, value: String, tint: Color) -> some View {
        HStack {
            Label(label, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.title3.bold())
        }
    }

    private func potionButton(label: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.22))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func cooldownPotionButton(
        label: String,
        systemImage: String,
        color: Color,
        cooldown: TimeInterval,
        readyAt: Binding<Date?>,
        isCooling: Binding<Bool>,
        showPopover: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        let progress = potionManager.cooldownProgress(readyAt: readyAt.wrappedValue, total: cooldown)

        return Button {
            if suppressNextTap {
                suppressNextTap = false
                return
            }
            guard !isCooling.wrappedValue else { return }
            action()
            // start cooldown
            isCooling.wrappedValue = true
            readyAt.wrappedValue = Date().addingTimeInterval(cooldown)
            // Persist cooldowns immediately
            potionManager.healthReadyAt = potionManager.healthReadyAt
            potionManager.manaReadyAt = potionManager.manaReadyAt
            potionManager.staminaReadyAt = potionManager.staminaReadyAt
            // The manager's tick will clear and persist when cooldowns finish
            DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
                isCooling.wrappedValue = false
                readyAt.wrappedValue = nil
            }
        } label: {
            ZStack {
                Label(label, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(color.opacity(0.22))
                    .foregroundStyle(color)
                    .clipShape(Capsule())

                if isCooling.wrappedValue {
                    GeometryReader { proxy in
                        let lineWidth: CGFloat = 3
                        ZStack(alignment: .leading) {
                            Capsule()
                                .stroke(color.opacity(0.25), lineWidth: lineWidth)
                            Capsule()
                                .trim(from: 0, to: max(0, min(1, progress)))
                                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                .animation(.linear(duration: 0.3), value: progress)
                        }
                    }
                    .allowsHitTesting(false)
                    .padding(2)
                }
            }
            .frame(height: 36)
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    showPopover.wrappedValue = true
                    // Suppress the next tap that can be generated on gesture end or popover dismiss
                    suppressNextTap = true
                }
        )
        .buttonStyle(.plain)
    }

    private func potionPopover(title: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func addAura(_ color: Color) {
        auraColor = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { auraColor = nil }
    }

    private func useHealthPotion() {
        guard !potionManager.isHealthOnCooldown else { return }
        // Refresh the buff duration instead of stacking
        potionManager.upsertBuff(name: "Full AF", description: "Heals over time.", icon: "leaf.fill", color: .green, duration: defaultBuffDuration)
        potionManager.isHealthOnCooldown = true
        if potionManager.healthReadyAt == nil { potionManager.healthReadyAt = Date().addingTimeInterval(healthCooldown) }
        // Persist state
        // The manager will save on next tick, but force an immediate save by calling a tiny state change
        potionManager.activeBuffs = potionManager.activeBuffs
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        addAura(.green.opacity(0.35))
        // Soft periodic heal (visual): ask IRL store to update from inputs to keep system coherent.
        // We simulate by logging a self-care session which already recalculates HP in HealthBarViewModel.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            healthBarViewModel.logSelfCareSession()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            potionManager.isHealthOnCooldown = false
        }
    }

    private func useManaPotion() {
        guard !potionManager.isManaOnCooldown else { return }
        // Refresh the buff duration instead of stacking
        potionManager.upsertBuff(name: "Hydrated", description: "Hydration boost + focus.", icon: "sparkles", color: .cyan, duration: defaultBuffDuration)
        potionManager.isManaOnCooldown = true
        if potionManager.manaReadyAt == nil { potionManager.manaReadyAt = Date().addingTimeInterval(manaCooldown) }
        // Persist state
        // The manager will save on next tick, but force an immediate save by calling a tiny state change
        potionManager.activeBuffs = potionManager.activeBuffs
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        addAura(.cyan.opacity(0.35))
        // Log hydration through existing focusViewModel pathway so quests and stats update.
        focusViewModel.logHydrationPillTapped()
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            potionManager.isManaOnCooldown = false
        }
    }

    private func useStaminaPotion() {
        guard !potionManager.isStaminaOnCooldown else { return }
        // Refresh the buff duration instead of stacking
        potionManager.upsertBuff(name: "Energized", description: "Temporary stamina surge.", icon: "bolt.fill", color: .orange, duration: defaultBuffDuration)
        potionManager.isStaminaOnCooldown = true
        if potionManager.staminaReadyAt == nil { potionManager.staminaReadyAt = Date().addingTimeInterval(staminaCooldown) }
        // Persist state
        // The manager will save on next tick, but force an immediate save by calling a tiny state change
        potionManager.activeBuffs = potionManager.activeBuffs
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        addAura(.orange.opacity(0.35))
        // Register a focus sprint to reflect stamina energy in your existing model.
        healthBarViewModel.logFocusSession()
        // Also let quests know something fun happened via existing event hooks if available.
        DependencyContainer.shared.questsViewModel.syncQuestProgress()
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            potionManager.isStaminaOnCooldown = false
        }
    }

    private var playerHUDSection: some View {
        PlayerStatusBarsView(
            hpProgress: statsViewModel.hpProgress,
            hydrationProgress: statsViewModel.hydrationProgress,
            sleepProgress: statsViewModel.sleepProgress,
            moodProgress: statsViewModel.moodProgress
        )
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.headline)

            DailyVitalsSlidersView(
                dailyRatingsStore: dailyRatingsStore,
                healthBarViewModel: healthBarViewModel,
                focusViewModel: focusViewModel
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        .cornerRadius(16)
    }
    
    private func randomizeAvatar() {
        let newIndex = nextRandomAvatarIndex()
        avatarStyleIndex = newIndex
        var state = loadShuffleState()
        state.recent.append(newIndex)
        if state.recent.count > recentWindowSize { state.recent.removeFirst(state.recent.count - recentWindowSize) }
        saveShuffleState(state)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            avatarSpin += 360
        }
        if avatarSpin >= 36000 { avatarSpin = 0 }
    }
}

/// Shared sliders for daily vitals (mood, gut, sleep, activity) used across the app and onboarding
/// so updates only need to be made in one place.
struct DailyVitalsSlidersView: View {
    @ObservedObject var dailyRatingsStore: DailyHealthRatingsStore
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RatingSliderRow(
                title: "Mood",
                systemImage: "face.smiling",
                tint: .purple,
                value: moodRatingBinding,
                labels: ["Terrible", "Low", "Okay", "Good", "Great"],
                allowsClearing: true,
                valueDescription: { HealthRatingMapper.label(for: $0) }
            )

            RatingSliderRow(
                title: "Gut",
                systemImage: "heart.text.square",
                tint: .orange,
                value: gutRatingBinding,
                labels: ["Terrible", "Low", "Okay", "Good", "Great"],
                allowsClearing: true,
                valueDescription: { HealthRatingMapper.label(for: $0) }
            )

            RatingSliderRow(
                title: "Sleep",
                systemImage: "bed.double.fill",
                tint: .indigo,
                value: sleepQualityBinding,
                labels: ["Terrible", "Low", "Okay", "Good", "Great"],
                allowsClearing: false,
                valueDescription: { HealthRatingMapper.label(for: $0) }
            )

            RatingSliderRow(
                title: "Activity",
                systemImage: "figure.walk",
                tint: .green,
                value: activityRatingBinding,
                labels: ["Barely moved", "Lightly active", "Some movement", "Active", "Very active"],
                allowsClearing: true,
                valueDescription: { HealthRatingMapper.activityLabel(for: $0) }
            )
        }
    }

    private var sleepQualityBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().sleep },
            set: { newValue in
                let previous = dailyRatingsStore.ratings().sleep
                dailyRatingsStore.setSleep(newValue)
                focusViewModel.sleepQuality = HealthRatingMapper.sleepQuality(for: newValue ?? 3) ?? .okay
                if previous == nil, newValue != nil {
                    DependencyContainer.shared.questsViewModel.completeQuestIfNeeded(id: "DAILY_HB_SLEEP_LOG")
                    if dailyRatingsStore.ratings().mood != nil && dailyRatingsStore.ratings().gut != nil && dailyRatingsStore.ratings().sleep != nil {
                        DependencyContainer.shared.questsViewModel.handleQuestEvent(.hpCheckinCompleted)
                    }
                }
            }
        )
    }

    private var moodRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().mood },
            set: { newValue in
                let previous = dailyRatingsStore.ratings().mood
                dailyRatingsStore.setMood(newValue)
                let status = HealthRatingMapper.moodStatus(for: newValue)
                healthBarViewModel.setMoodStatus(status)
                if previous == nil, newValue != nil {
                    DependencyContainer.shared.questsViewModel.completeQuestIfNeeded(id: "DAILY_HB_MORNING_CHECKIN")
                    if dailyRatingsStore.ratings().mood != nil && dailyRatingsStore.ratings().gut != nil && dailyRatingsStore.ratings().sleep != nil {
                        DependencyContainer.shared.questsViewModel.handleQuestEvent(.hpCheckinCompleted)
                    }
                }
            }
        )
    }

    private var gutRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().gut },
            set: { newValue in
                let previous = dailyRatingsStore.ratings().gut
                dailyRatingsStore.setGut(newValue)
                let status = HealthRatingMapper.gutStatus(for: newValue)
                healthBarViewModel.setGutStatus(status)
                if previous == nil, newValue != nil {
                    DependencyContainer.shared.questsViewModel.completeQuestIfNeeded(id: "DAILY_HB_GUT_CHECK")
                    if dailyRatingsStore.ratings().mood != nil && dailyRatingsStore.ratings().gut != nil && dailyRatingsStore.ratings().sleep != nil {
                        DependencyContainer.shared.questsViewModel.handleQuestEvent(.hpCheckinCompleted)
                    }
                }
            }
        )
    }

    private var activityRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().activity },
            set: { newValue in
                dailyRatingsStore.setActivity(newValue)
                focusViewModel.activityLevel = HealthRatingMapper.activityLevel(for: newValue)
            }
        )
    }
}

#Preview {
    let container = DependencyContainer.shared
    PlayerCardView(
        store: container.sessionStatsStore,
        statsViewModel: container.statsViewModel,
        healthBarViewModel: container.healthBarViewModel,
        focusViewModel: container.focusViewModel
    )
}

// Avatar now uses a UUID-based rolled SF Symbol + gradient style.


