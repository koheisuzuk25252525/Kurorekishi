import Foundation

public struct Node: Codable, Identifiable {
    public let id: String
    public let route: String
    public let name: String
    public let detail: String
    public let cost: Int
    public let stars: Int
    public let requires: [String]
}

public struct Resonance: Codable, Identifiable {
    public let id: String
    public let name: String
    public let requires: [String]
    public let multiplier: Double
    public let chant: String
}

public struct Trial: Codable, Identifiable, Equatable {
    public let id: String
    public let rewards: [String]
    public let requires: [String]
    public let title: String
    public let place: String
    public let enemy: String
    public let opening: String
    public let crisis: String
    public let vow: String
    public let chant: String
    public let victory: String
    public let hp: Int
    public let attack: Int
}

public enum TrialStage: String, Codable { case approach, crisis, combat, reward }

public struct TrialProgress: Codable, Equatable {
    public let story: Trial
    public var stage: TrialStage = .approach
    public let previousSelection: Set<String>
}

public struct Catalog: Codable {
    public let nodes: [Node]
    public let resonances: [Resonance]
    public let trials: [Trial]
    public static func load() throws -> Catalog {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

public enum Phase: String, Codable { case notebook, battle, victory, defeat }

public struct Game: Codable, Equatable {
    // Optional for compatibility with saves created before story trials.
    public private(set) var trial: TrialProgress?
    public private(set) var unlocked: Set<String> = []
    public private(set) var selected: Set<String> = []
    public private(set) var ink = 3
    public private(set) var day = 1
    public private(set) var phase: Phase = .notebook
    public private(set) var enemyHP = 0
    public private(set) var vitality = 100
    public private(set) var charges = 3
    public private(set) var focused = false
    public private(set) var log = "最初の一行を、書き込め。"
    public init() {}

    /// Tutorial reward is applied only to a new game; existing saves are preserved.
    public mutating func completeIntroduction() {
        guard unlocked.isEmpty, phase == .notebook, day == 1 else { return }
        unlocked = ["arm1", "arm2"]
        selected = unlocked
        ink = 6
        day = 2
        log = "封印は解けた。次は、何を宿す？"
    }

    public func canBegin(_ story: Trial) -> Bool {
        phase == .notebook && trial == nil &&
        Set(story.requires).isSubset(of: unlocked) &&
        !Set(story.rewards).isSubset(of: unlocked)
    }

    public mutating func beginTrial(_ story: Trial) {
        guard canBegin(story) else { return }
        trial = TrialProgress(story: story, previousSelection: selected)
        log = story.opening
    }

    public mutating func confrontTrial() {
        guard trial?.stage == .approach else { return }
        trial?.stage = .crisis
        log = trial?.story.crisis ?? ""
    }

    public mutating func awakenTrial() {
        guard let progress = trial, progress.stage == .crisis else { return }
        trial?.stage = .combat
        selected.formUnion(progress.story.requires)
        selected.formUnion(progress.story.rewards)
        phase = .battle
        enemyHP = progress.story.hp
        vitality = 72
        charges = 3
        focused = false
        log = progress.story.chant
    }

    public mutating func abandonTrial() {
        guard let progress = trial, phase == .notebook else { return }
        selected = progress.previousSelection
        trial = nil
        log = "頁は、まだ閉じない。"
    }

    public func canUnlock(_ node: Node) -> Bool {
        !unlocked.contains(node.id) && ink >= node.cost && Set(node.requires).isSubset(of: unlocked)
    }
    public mutating func unlock(_ node: Node) {
        guard phase == .notebook, trial == nil, canUnlock(node) else { return }
        ink -= node.cost
        unlocked.insert(node.id)
        selected.insert(node.id)
        log = "《\(node.name)》を書き込んだ。設定は、力になる。"
    }
    public mutating func toggle(_ node: Node) {
        guard phase == .notebook, trial == nil, unlocked.contains(node.id) else { return }
        if selected.contains(node.id) { selected.remove(node.id) }
        else { selected.insert(node.id) }
    }
    public func activeResonances(_ catalog: Catalog) -> [Resonance] {
        catalog.resonances.filter { Set($0.requires).isSubset(of: selected) }
    }
    public func multiplier(_ catalog: Catalog) -> Double {
        let stars = catalog.nodes.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.stars }
        return activeResonances(catalog).reduce(1 + Double(stars) * 0.25) { $0 * $1.multiplier }
    }
    public func damage(_ catalog: Catalog) -> Int {
        Int((24 * multiplier(catalog) * (focused ? 1.5 : 1)).rounded())
    }
    public var enemyMaximum: Int { trial?.story.hp ?? (65 + (day - 1) * 20) }
    public mutating func manifest() {
        guard phase == .notebook, trial == nil, !selected.isEmpty else { return }
        phase = .battle
        enemyHP = enemyMaximum
        vitality = 100
        charges = 3
        focused = false
        log = "——書いた通りに。現実になる。\n……やれやれ。待たせたな。"
    }
    public mutating func act(_ action: String, catalog: Catalog) {
        guard phase == .battle else { return }
        switch action {
        case "skill":
            guard charges > 0 else { log = "詠唱が尽きた。今は、この拳で。"; return }
            let hit = damage(catalog)
            charges -= 1
            enemyHP = max(0, enemyHP - hit)
            focused = false
            log = "\(trial?.story.chant ?? activeResonances(catalog).first?.chant ?? "第一拘束、解除——闇に還れ。")\n\(hit)の威力で設定を上書きした。"
        case "focus":
            focused = true
            log = "……静まれ。次の技の威力 ×1.5。"
        case "punch":
            enemyHP = max(0, enemyHP - 14)
            log = "14の衝撃。……足りない。設定が、足りない。"
        default:
            log = "逃げる設定は、ノートにない。"
            return
        }
        if enemyHP == 0 {
            phase = .victory
            if let progress = trial {
                unlocked.formUnion(progress.story.rewards)
                trial?.stage = .reward
                log = progress.story.victory
            }
            let reward = 3 + day
            ink += reward
            log += "\n敵は設定に上書きされて消えた。記述点 +\(reward)。"
            return
        }
        vitality = max(0, vitality - (trial?.story.attack ?? (12 + day * 2)))
        if vitality == 0 { phase = .defeat; log += "\n……まだ、続きがある。ノートを開け。" }
        else { log += "\n反撃。存在強度 -\(trial?.story.attack ?? (12 + day * 2))。" }
    }
    public mutating func returnToNotebook() {
        guard phase == .victory || phase == .defeat else { return }
        if phase == .defeat, let progress = trial {
            selected = progress.previousSelection
        }
        if phase == .victory { day += 1 }
        trial = nil
        phase = .notebook
        focused = false
        log = "続きを、書こう。"
    }
}
