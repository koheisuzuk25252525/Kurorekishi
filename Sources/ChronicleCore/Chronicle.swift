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

public struct Catalog: Codable {
    public let nodes: [Node]
    public let resonances: [Resonance]
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

    public func canUnlock(_ node: Node) -> Bool {
        !unlocked.contains(node.id) && ink >= node.cost && Set(node.requires).isSubset(of: unlocked)
    }
    public mutating func unlock(_ node: Node) {
        guard phase == .notebook, canUnlock(node) else { return }
        ink -= node.cost
        unlocked.insert(node.id)
        selected.insert(node.id)
        log = "《\(node.name)》を書き込んだ。設定は、力になる。"
    }
    public mutating func toggle(_ node: Node) {
        guard phase == .notebook, unlocked.contains(node.id) else { return }
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
    public var enemyMaximum: Int { 65 + (day - 1) * 20 }
    public mutating func manifest() {
        guard phase == .notebook, !selected.isEmpty else { return }
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
            log = "\(activeResonances(catalog).first?.chant ?? "第一拘束、解除——闇に還れ。")\n\(hit)の威力で設定を上書きした。"
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
            let reward = 3 + day
            ink += reward
            log += "\n敵は設定に上書きされて消えた。記述点 +\(reward)。"
            return
        }
        vitality = max(0, vitality - (12 + day * 2))
        if vitality == 0 { phase = .defeat; log += "\n……まだ、続きがある。ノートを開け。" }
        else { log += "\n反撃。存在強度 -\(12 + day * 2)。" }
    }
    public mutating func returnToNotebook() {
        guard phase == .victory || phase == .defeat else { return }
        if phase == .victory { day += 1 }
        phase = .notebook
        focused = false
        log = "続きを、書こう。"
    }
}
