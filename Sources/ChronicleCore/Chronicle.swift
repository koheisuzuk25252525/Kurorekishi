import Foundation

public struct Node: Codable, Identifiable {
    public let id: String
    public let route: String
    public let name: String
    public let detail: String
    public let cost: Int
    public let stars: Int
    public let requires: [String]
    public let reading: String?
    public let effect: String?
    public let verse: String?
}

public struct Resonance: Codable, Identifiable {
    public let id: String
    public let name: String
    public let requires: [String]
    public let multiplier: Double
    public let chant: String
}

/// Data-driven telegraphs; the action shown is the action resolved AFTER the player.
public enum EnemyStyle: String, Codable { case open, armored, hidden, silencer }
public enum Intent: String, Codable {
    case attack, windup, slam, recover, approach, lunge, interrupt
    public var title: String {
        switch self {
        case .attack: return "攻撃"
        case .windup: return "力を溜める"
        case .slam: return "強打・大ダメージ"
        case .recover: return "硬直・隙ができる"
        case .approach: return "足音が近づく"
        case .lunge: return "飛びかかる"
        case .interrupt: return "詠唱を妨害する"
        }
    }
}
public struct Encounter: Codable, Equatable {
    public let style: EnemyStyle
    public let pattern: [Intent]
    public let note: String
}
public enum CombatArt: String, Codable, CaseIterable {
    case arm, eye, chant
    public var title: String {
        switch self { case .arm: return "右腕"; case .eye: return "魔眼"; case .chant: return "詠唱" }
    }
}
public enum BattleAction: String, Codable {
    case strike, breakSeal, observe, chant, release, `guard`, focus, punch, escape, devour, rend, rewrite, trueName
}
public struct AscensionState: Codable, Equatable {
    public var absorbed = 0
    public var rewriteUsed = false
    public var silence = 0
    public init() {}
}
public struct BattleState: Codable, Equatable {
    public var ascension: AscensionState?
    public var turn = 0
    public var armor = 0
    public var revealed = 0
    public var chanting = 0
    public var ward = false
    public var art: CombatArt = .arm
    public var lastDamage = 0
    public var lastReceived = 0
    public var broken = false
    public var interrupted = false
    public init(style: EnemyStyle = .open) { armor = style == .armored ? 2 : 0 }
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
    public let encounter: Encounter?
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
    public var abilities: [Node] { nodes.filter { !$0.requires.isEmpty } }
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
    public private(set) var battle: BattleState?
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
        prepareBattle()
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
        prepareBattle()
    }
    /// Compatibility adapter for existing callers; there is only one turn resolver.
    public mutating func act(_ action: String, catalog: Catalog) {
        guard phase == .battle else { return }
        resumeBattle()
        let resolved = action == "skill" ? BattleAction.strike : BattleAction(rawValue: action)
        if let resolved { perform(resolved, catalog: catalog) }
    }
    public mutating func returnToNotebook() {
        guard phase == .victory || phase == .defeat else { return }
        if phase == .defeat, let progress = trial {
            selected = progress.previousSelection
        }
        if phase == .victory { day += 1 }
        trial = nil
        battle = nil
        phase = .notebook
        focused = false
        log = "続きを、書こう。"
    }

    public var enemyStyle: EnemyStyle { trial?.story.encounter?.style ?? .open }
    public var intent: Intent {
        if (battle?.ascension?.silence ?? 0) > 0 { return .recover }
        let pattern = trial?.story.encounter?.pattern ?? [.attack]
        guard !pattern.isEmpty else { return .attack }
        return pattern[(battle?.turn ?? 0) % pattern.count]
    }
    public var nextIntent: Intent {
        if (battle?.ascension?.silence ?? 0) > 1 { return .recover }
        let pattern = trial?.story.encounter?.pattern ?? [.attack]
        guard !pattern.isEmpty else { return .attack }
        return pattern[((battle?.turn ?? 0) + 1) % pattern.count]
    }
    public var availableArts: [CombatArt] {
        var arts: [CombatArt] = []
        if selected.contains("arm2") || selected.contains("arm3") { arts.append(.arm) }
        if hasEye { arts.append(.eye) }
        if hasChant { arts.append(.chant) }
        return arts
    }
    private var hasEye: Bool { !selected.isDisjoint(with: ["eye2", "eye3", "eye4"]) }
    private var hasChant: Bool { !selected.isDisjoint(with: ["chant2", "chant3", "chant4"]) }
    private var hostileIntent: Bool { [.attack, .slam, .lunge, .interrupt].contains(intent) }
    public var finisher: BattleAction {
        guard battle?.art == .chant, (battle?.chanting ?? 0) > 0 else { return .strike }
        return selected.contains("chant4") && battle?.chanting == 3 ? .trueName : .release
    }
    public var technique: BattleAction {
        switch battle?.art ?? .arm {
        case .arm:
            if selected.contains("arm5") && (battle?.ascension?.absorbed ?? 0) > 0 { return .rend }
            if selected.contains("arm4") && hostileIntent { return .devour }
            return .breakSeal
        case .eye:
            if selected.contains("eye4") && battle?.ascension?.rewriteUsed != true && hostileIntent { return .rewrite }
            return .observe
        case .chant: return .chant
        }
    }
    public mutating func chooseArt(_ art: CombatArt) {
        guard phase == .battle, availableArts.contains(art), battle != nil else { return }
        battle?.art = art
    }
    /// Upgrade the control state of a legacy save without changing HP, resources or rewards.
    public mutating func resumeBattle() {
        guard phase == .battle, battle == nil else { return }
        prepareBattle()
    }
    private mutating func prepareBattle() {
        battle = BattleState(style: enemyStyle)
        let newIds = trial?.story.rewards ?? []
        if newIds.contains(where: { $0.hasPrefix("eye") }) { battle?.art = .eye }
        else if newIds.contains(where: { $0.hasPrefix("chant") }) { battle?.art = .chant }
        else { let defaultArt = availableArts.first ?? .arm; battle?.art = defaultArt }
    }
    public func canPerform(_ action: BattleAction) -> Bool {
        guard phase == .battle, let state = battle else { return false }
        switch action {
        case .breakSeal: return selected.contains("arm3") && charges > 0
        case .observe: return hasEye
        case .chant: return hasChant && state.chanting < 3
        case .release: return hasChant && state.chanting > 0 && charges > 0
        case .devour: return selected.contains("arm4") && charges > 0 && hostileIntent
        case .rend: return selected.contains("arm5") && charges > 0 && (state.ascension?.absorbed ?? 0) > 0
        case .rewrite: return selected.contains("eye4") && state.ascension?.rewriteUsed != true && hostileIntent
        case .trueName: return selected.contains("chant4") && state.chanting == 3 && charges > 0
        case .strike: return charges > 0
        default: return true
        }
    }
    /// Defense and targeting are evaluated before damage: a larger multiplier cannot
    /// substitute for finding an invisible target or opening a shell.
    public func predictedDamage(_ action: BattleAction, catalog: Catalog) -> Int {
        guard canPerform(action), let state = battle else { return 0 }
        let base = enemyStyle == .open ? damage(catalog) :
            Int((Double(min(60, Int((24 * multiplier(catalog)).rounded()))) * (focused ? 1.5 : 1)).rounded())
        var hit: Int
        switch action {
        case .strike: hit = base
        case .punch: hit = 14
        case .release, .trueName: hit = base * (1 + state.chanting)
        case .rend: hit = base + (state.ascension?.absorbed ?? 0) * 3
        case .breakSeal: hit = state.armor > 0 ? max(8, base / 3) : base
        default: return 0
        }
        if action == .rend || action == .trueName { return hit }
        if action != .punch { hit += state.ascension?.absorbed ?? 0 }
        if enemyStyle == .hidden && state.revealed == 0 && intent != .recover { return 0 }
        if state.armor > 0 && action != .breakSeal { hit = max(1, hit / 5) }
        if action == .breakSeal && state.armor > 0 && intent != .recover && state.revealed == 0 { hit = 1 }
        // The choir swallows short attacks; a completed phrase crosses the silence.
        if enemyStyle == .silencer && action != .release { hit = max(1, hit / 4) }
        if state.revealed > 0 && action != .punch { hit *= 2 }
        return hit
    }
    public var defeatAdvice: String {
        switch enemyStyle {
        case .armored: return "強打は防御で受け、硬直した瞬間に黒龍で殻を砕こう。"
        case .hidden: return "魔眼で姿を捉えよう。飛びかかりは防御か見切りでしのぎ、見えている間に攻撃。"
        case .silencer: return "防御で妨害への備えを作り、予兆を見て詠唱を重ねよう。強打の前に解き放つ。"
        case .open: return "集中で技の残数を回復できる。強打の予兆には防御を。"
        }
    }

    public mutating func perform(_ action: BattleAction, catalog: Catalog) {
        guard canPerform(action), var state = battle else { return }
        let incoming = intent
        let hit = predictedDamage(action, catalog: catalog)
        state.lastDamage = hit
        state.lastReceived = 0
        state.broken = false
        state.interrupted = false
        var ascension = state.ascension ?? AscensionState()
        var text: [String] = []
        var guarding = false
        var dodging = false
        var nullifying = false
        switch action {
        case .strike, .punch, .release, .breakSeal, .rend, .trueName:
            if action != .punch { charges -= 1; focused = false }
            if action == .release || action == .trueName {
                if selected.contains("chant3") && state.chanting >= 2 {
                    ascension.silence = 2
                    text.append("終焉ノ詠唱——敵の行動を二手、静寂に葬る。")
                }
                state.chanting = 0
            }
            if action != .punch { ascension.absorbed = 0 }
            if action == .rend || action == .trueName {
                state.armor = 0
                state.revealed = 4
                state.broken = true
                text.append(action == .rend ? "終焉を掴む手——喰らった力で、防御という概念を引き裂く。" : "我が真名を刻め——防御を消し、存在を取り戻す。")
            }
            if action == .trueName { vitality = min(100, vitality + 24) }
            if action == .breakSeal && state.armor > 0 && (incoming == .recover || state.revealed > 0) {
                state.armor = 0
                state.broken = true
                text.append(state.revealed > 0 ? "魔眼が捉えた継ぎ目へ、黒龍を叩き込む。殻が砕けた。" : "硬直した殻へ黒龍の顎。防御を破壊した。")
            }
            enemyHP = max(0, enemyHP - hit)
            if hit == 0 { text.append("狙いが定まらない。魔眼で存在を捉えろ。") }
            else if state.armor > 0 { text.append("殻に弾かれ、\(hit)ダメージ。硬直か、見抜いた継ぎ目を狙え。") }
            else if enemyStyle == .silencer && action != .release { text.append("短い技は静寂に呑まれた。\(hit)ダメージ。詠唱を重ねて解き放て。") }
            else { text.append("\(hit)ダメージ。\(action == .release ? "積み重ねた詠唱が、現実を裂いた。" : "設定を叩き込んだ。")") }
        case .observe:
            state.revealed = 4 // Includes this turn; three subsequent decisions remain.
            dodging = incoming == .lunge || (selected.contains("eye3") && incoming == .slam)
            text.append(dodging ? "右目が、襲い来る軌道を視た。紙一重で見切る。" : "魔眼が弱点を捉えた。3手の間、狙いが定まり技の威力が2倍。")
        case .devour:
            charges -= 1
            let stolen = (trial?.story.attack ?? (12 + day * 2)) * ([.slam, .lunge].contains(incoming) ? 2 : 1)
            ascension.absorbed = min(60, stolen)
            nullifying = true
            text.append("神喰らいの右腕——襲来する力を喰らった。被害0。次の技に\(ascension.absorbed)を宿す。")
        case .rewrite:
            ascension.rewriteUsed = true
            state.revealed = 4
            nullifying = true
            text.append("世界の理を視る眼——その結末は、誤字だ。敵の一手を白紙に戻し、弱点を刻んだ。")
        case .chant:
            state.chanting += 1
            text.append("詠唱 \(state.chanting)/3。まだ終わらせない——。")
        case .guard:
            guarding = true
            state.ward = true
            text.append("右腕で受け止める。次の詠唱妨害への備えも整った。")
        case .focus:
            focused = true
            charges = min(3, charges + 1)
            text.append("……静まれ。残数を1回復、次の技は1.5倍。")
        case .escape:
            log = "逃げる設定は、ノートにない。"
            return
        }
        state.turn += 1
        state.revealed = max(0, state.revealed - 1)
        state.ascension = ascension
        if enemyHP == 0 {
            battle = state
            phase = .victory
            if let progress = trial {
                unlocked.formUnion(progress.story.rewards)
                trial?.stage = .reward
            }
            let reward = 3 + day
            ink += reward
            log = text.joined(separator: "\n") + "\n設定を証明した。記述点 +\(reward)。"
            return
        }
        let attack = trial?.story.attack ?? (12 + day * 2)
        var received = 0
        if nullifying || ascension.silence > 0 {
            if ascension.silence > 0 {
                ascension.silence -= 1
                text.append("静寂が、敵の行動を消した。")
            }
        } else {
        switch incoming {
        case .windup: text.append("敵が力を溜める。次の予兆を見ろ。")
        case .approach: text.append("敵は距離を詰める。次の動きに備えろ。")
        case .recover: text.append("敵は体勢を立て直している。")
        case .attack: received = attack
        case .slam, .lunge: received = dodging ? 0 : attack * 2
        case .interrupt:
            received = attack
            if state.chanting > 0 {
                if state.ward {
                    state.ward = false
                    text.append("備えが妨害を弾いた。詠唱は途切れない。")
                } else {
                    state.chanting = 0
                    state.interrupted = true
                    text.append("詠唱を断ち切られた。先に防御して妨害に備えよう。")
                }
            }
        }
        }
        state.ascension = ascension
        if guarding { received /= 4 }
        vitality = max(0, vitality - received)
        state.lastReceived = received
        if received > 0 { text.append("存在強度 -\(received)。") }
        battle = state
        if vitality == 0 {
            phase = .defeat
            text.append(defeatAdvice)
        }
        log = text.joined(separator: "\n")
    }

}
