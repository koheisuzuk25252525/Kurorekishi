import SwiftUI
import UIKit

@main
struct ChronicleApp: App {
    var body: some Scene { WindowGroup { ChronicleView() } }
}

struct ChronicleView: View {
    private let paper = Color(red: 0.95, green: 0.92, blue: 0.84)
    private let crimson = Color(red: 0.79, green: 0.09, blue: 0.18)
    @State private var game: Game
    @State private var catalog: Catalog?
    @State private var error: String?
    private let persistence: SessionPersistence
    @State private var awakeningNode: Node?
    @State private var showingPlaytest = false
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReset = false
    @State private var introductionComplete: Bool
    @State private var showingTree = false
    @State private var showingMemories = false
    @State private var impact = false
    @State private var showingBattleHelp = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(playtest: Bool = false) {
        let store = SessionPersistence(isPlaytest: playtest)
        persistence = store
        _game = State(initialValue: store.loadGame())
        _introductionComplete = State(initialValue: store.loadIntroduction())
    }

    var body: some View {
        ZStack {
            (isPaper ? paper : Color(red: 0.03, green: 0.02, blue: 0.05)).ignoresSafeArea()
            if let catalog {
                if isCombatScreen {
                    GeometryReader { _ in
                        if dynamicTypeSize.isAccessibilitySize {
                            ScrollView { battle(catalog, compact: true) }.padding(16)
                        } else {
                            ViewThatFits(in: .vertical) {
                                battle(catalog, compact: false).fixedSize(horizontal: false, vertical: true)
                                battle(catalog, compact: true).fixedSize(horizontal: false, vertical: true)
                                ScrollView { battle(catalog, compact: true) }
                            }.padding(16).frame(maxHeight: .infinity)
                        }
                    }
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if !introductionComplete { introduction(catalog) }
                        else if let progress = game.trial, progress.stage != .combat { trialScene(progress, catalog: catalog) }
                        else if game.phase == .notebook { notebook(catalog) }
                        else { battle(catalog, compact: false) }
                        if introductionComplete && game.phase != .notebook && game.trial?.stage != .reward {
                        Text(game.log).font(.footnote).lineSpacing(4).padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(crimson.opacity(0.1))
                        }
                    }.padding(20)
                }
                }
            } else if let error {
                Text(error).foregroundStyle(crimson).padding()
            } else { ProgressView() }
        }

        .foregroundStyle(isPaper ? Color.black : paper)
        .task {
            do { catalog = try Catalog.load(); game.resumeBattle() }
            catch { self.error = "設定データを読み込めませんでした：\(error.localizedDescription)" }
        }
        .onChange(of: game) { _, value in persistence.save(value) }
        .onChange(of: introductionComplete) { _, value in persistence.saveIntroduction(value) }
        .fullScreenCover(isPresented: $showingPlaytest) { ChronicleView(playtest: true) }
        .fullScreenCover(item: $awakeningNode) { node in
            AwakeningRitual(node: node, onManifest: {
                game.awakenTrial()
                awakeningNode = nil
            }, onCancel: { awakeningNode = nil })
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if persistence.isPlaytest {
                HStack {
                    Text("試遊中・進行は保存されません").font(.caption)
                    Spacer()
                    Button("試遊を終える") { dismiss() }.font(.caption.bold())
                        .frame(minHeight: 44)
                }.padding(.horizontal, 16).foregroundStyle(.white).background(Color.black)
            }
        }
        .sheet(isPresented: $showingBattleHelp) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("禁書の注釈").font(.title.bold()).fontDesign(.serif)
                    Text(game.trial?.story.encounter?.note ?? "敵の予兆を読み、設定を使い分ける。")
                    Text("右腕：硬直か見抜いた弱点へ龍顎。殻を壊す。\n魔眼：3手の間狙いを定める。飛びかかりに合わせれば見切れる。\n詠唱：最大3段階。防御で次の妨害を1回防ぎ、強打の前に解き放つ。")
                    Text("集中：技の残数を1回復し、次の攻撃技を1.5倍。敵にも1手を渡す。\n防御：その手の被害を1/4にする。\n系統の切替は手番を消費しない。")
                    Text("上位解放：神喰らいは攻撃の手に現れる。喰らった力があれば終焉を掴める。因果の眼は強打も見切る。終焉ノ詠唱は二節以上で二手を封じ、真名解放は三節で発動する。")
                    if let story = game.trial?.story {
                        Text("設定証明：" + story.proofTitle).font(.headline)
                        Text("勝利だけで能力は習得できる。証明は任意の挑戦で、追憶戦でも達成できる。")
                    }
                    Text("直前の一手").font(.headline)
                    Text(game.log)
                    Button("戦場に戻る") { showingBattleHelp = false }
                }.padding(24)
            }
        }
        .confirmationDialog("ノートを最初から書き直しますか？", isPresented: $confirmingReset) {
            Button("最初から", role: .destructive) {
                game = Game()
                introductionComplete = false
                showingTree = false
            }
        }
    }

    private var isCombatScreen: Bool {
        introductionComplete && game.phase != .notebook && game.trial?.stage != .reward
    }

    private var isPaper: Bool {
        introductionComplete && game.phase == .notebook && game.trial == nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("第\(game.day)頁 ／ \(isPaper ? "記述" : "現実")")
                Spacer()
                if !persistence.isPlaytest {
                    Button("覚醒から試遊") { showingPlaytest = true }.font(.caption)
                }
                Button("書き直す") { confirmingReset = true }.font(.caption)
            }.font(.caption.monospaced()).foregroundStyle(crimson)
            Text("黒歴史ノート").font(.system(size: 34, weight: .black, design: .serif))
            Rectangle().fill(crimson).frame(height: 2)
        }
    }

    private func introduction(_ catalog: Catalog) -> some View {
        AwakeningIntroduction(catalog: catalog, crimson: crimson, onUnlock: {
            game.completeIntroduction()
        }, onContinue: {
            introductionComplete = true
        })
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).padding(.vertical, 16).frame(maxWidth: .infinity)
        }.buttonStyle(.borderedProminent).tint(crimson)
    }

    private var monster: MonsterView { MonsterView(crimson: crimson) }

    private func notebook(_ catalog: Catalog) -> some View {
        VStack(spacing: 20) {
            Text(catalog.trials.contains(where: { game.canBegin($0) }) ? "力は、まだ始まったばかりだ。" : "次は、その力を使いこなせ。").font(.title2.bold()).fontDesign(.serif)
            Text("昔の自分が書いた一行で、今日の絶望を覆す。").font(.footnote)
            let available = catalog.trials.filter { game.canBegin($0) }
            ForEach(available) { story in
                VStack(alignment: .leading, spacing: 10) {
                    Text(story.place).font(.caption).foregroundStyle(crimson)
                    Text(story.title).font(.title3.bold()).fontDesign(.serif)
                    Text("獲得する力：\(rewardName(story, catalog: catalog))")
                        .font(.footnote.bold())
                    Button("この兆候を追う") { game.beginTrial(story) }
                        .buttonStyle(.borderedProminent).tint(crimson)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(crimson.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            }
            if available.isEmpty {
                Text("——十の封印、完全解放——").font(.title2.bold()).fontDesign(.serif)
                Text("世界が否定した全てを、このノートは肯定した。").font(.footnote)
            }
            Text("禁書・終焉ノ能力系譜").font(.title2.bold()).fontDesign(.serif)
            SkillConstellation(catalog: catalog, learned: game.unlocked, highlighted: [], crimson: crimson,
                               proven: provenAbilities(catalog))
                .frame(height: 430).background(Color.black, in: RoundedRectangle(cornerRadius: 18))
            memories(catalog)
            Button(showingTree ? "設定を閉じる" : "習得済みの設定を組み替える") { showingTree.toggle() }
                .font(.footnote).tint(crimson)
            if showingTree {
                ForEach(catalog.nodes.filter { game.unlocked.contains($0.id) }) { node in
                    Button {
                        game.toggle(node)
                    } label: {
                        HStack {
                            Text(game.selected.contains(node.id) ? "◆" : "◇")
                            Text(node.name)
                        }
                    }.buttonStyle(.bordered).tint(crimson)
                }
            }
            Button("現在の力を試す ／ 威力 \(game.damage(catalog))") {
                game.manifest()
            }.buttonStyle(.bordered).tint(crimson).disabled(game.selected.isEmpty)
        }
    }

    private func provenAbilities(_ catalog: Catalog) -> Set<String> {
        Set(catalog.trials.filter { game.records?[$0.id]?.mastered == true }.flatMap(\.rewards))
    }

    private func rewardName(_ story: Trial, catalog: Catalog) -> String {
        story.rewards.compactMap { id in catalog.nodes.first { $0.id == id }?.name }.last ?? "新しい力"
    }

    private func trialScene(_ progress: TrialProgress, catalog: Catalog) -> some View {
        let story = progress.story
        return VStack(spacing: 20) {
            Text(story.place).font(.caption).foregroundStyle(crimson)
            Text(progress.stage == .reward ? (progress.isReplay == true ? "追憶を越えた。" : "新たな系譜、解放。") : story.title)
                .font(.title2.bold()).fontDesign(.serif).multilineTextAlignment(.center)
            if progress.stage == .reward {
                if let node = catalog.nodes.first(where: { $0.id == story.rewards.last }) {
                    Text(node.reading ?? "").font(.caption).foregroundStyle(crimson)
                    Text(node.name).font(.title.bold()).fontDesign(.serif)
                    Text("「\(node.verse ?? node.detail)」").font(.subheadline).fontDesign(.serif)
                        .multilineTextAlignment(.center)
                }
                proofResult(story)
                primaryButton("この力で、次の頁へ") { game.returnToNotebook() }
                SkillConstellation(catalog: catalog, learned: game.unlocked,
                                   highlighted: progress.isReplay == true ? [] : Set(story.rewards), crimson: crimson,
                                   proven: provenAbilities(catalog))
                    .frame(height: 430).background(Color.black, in: RoundedRectangle(cornerRadius: 18))
                Text(progress.isReplay == true ? "習得した設定が、再び現実になった。" : "《\(rewardName(story, catalog: catalog))》習得").font(.title3.bold())
                Text(story.victory).font(.footnote).multilineTextAlignment(.center)
                if let resonance = game.activeResonances(catalog).first(where: {
                    !Set($0.requires).isDisjoint(with: story.rewards)
                }) {
                    Text("設定が共鳴した——《\(resonance.name)》 ×\(resonance.multiplier, specifier: "%.1f")")
                        .font(.footnote.bold()).foregroundStyle(crimson)
                }
            } else {
                TacticalEnemyView(style: story.encounter?.style ?? .open, revealed: false,
                                  armor: story.encounter?.style == .armored ? 2 : 0, crimson: crimson)
                    .frame(height: 150)
                    .scaleEffect(progress.stage == .crisis ? 1.15 : 1)
                if progress.stage == .crisis {
                    Text("今の能力では、届かない。").font(.caption.bold()).foregroundStyle(crimson)
                }
                Text(progress.stage == .approach ? story.opening : story.crisis)
                    .font(.body).multilineTextAlignment(.center).lineSpacing(5)
                if progress.stage == .approach {
                    primaryButton("今の力を、ぶつける") {
                        game.confrontTrial()
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                } else {
                    Text("ノートに、次の一行を。").font(.caption).foregroundStyle(crimson)
                    Text(story.proofTitle).font(.footnote.bold())
                    Text("勝てば習得。設定を使いこなせば、証明も刻まれる。")
                        .font(.caption).foregroundStyle(paper.opacity(0.7))
                    primaryButton(story.vow) {
                        awakeningNode = catalog.nodes.first { $0.id == story.rewards.last }
                    }
                }
                Button("一度、ノートに戻る") { game.abandonTrial() }.font(.caption).tint(crimson)
            }
        }.frame(maxWidth: .infinity)
    }

    private func battle(_ catalog: Catalog, compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            HStack {
                Text(game.trial?.story.enemy ?? "名を失った残響").font(.headline)
                Spacer()
                Text("\((game.battle?.turn ?? 0) + (game.phase == .battle ? 1 : 0))手目").font(.caption.monospaced())
            }
            ProgressView(value: Double(game.enemyHP), total: Double(game.enemyMaximum)).tint(crimson)
                .accessibilityLabel("敵の残り耐久 \(game.enemyHP) / \(game.enemyMaximum)")
            if !compact {
                TacticalEnemyView(style: game.enemyStyle, revealed: (game.battle?.revealed ?? 0) > 0,
                                  armor: game.battle?.armor ?? 0, crimson: crimson)
                    .frame(height: 110).offset(x: impact && !reduceMotion ? 8 : 0)
            }
            if game.phase == .battle {
                VStack(alignment: .leading, spacing: 5) {
                    Text("次の敵行動：\(game.intent.title)").font(.headline)
                    if game.selected.contains("eye3") {
                        Text("その次：\(game.nextIntent.title)").font(.caption)
                    }
                    Text(battleStatus).font(.caption).foregroundStyle(crimson)
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(crimson.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack {
                Text("存在 \(game.vitality)/100")
                Spacer()
                Text("技 \(game.charges)/3")
                Text("詠唱 \(game.battle?.chanting ?? 0)/3")
            }.font(.caption.monospaced()).accessibilityElement(children: .combine)
            if game.phase == .battle { proofPanel(catalog, compact: compact) }
            if game.phase == .battle, let story = game.trial?.story {
                Text(game.proofAchieved ? "証明条件成立——このまま勝利せよ" : "証明：\(story.proofTitle)")
                    .font(.caption2).foregroundStyle(game.proofAchieved ? Color.yellow : paper)
            }
            if game.phase == .battle {
                Spacer(minLength: 0)
                if game.availableArts.count > 1 {
                    Picker("使う設定", selection: Binding(get: { game.battle?.art ?? .arm }, set: { game.chooseArt($0) })) {
                        ForEach(game.availableArts, id: \.self) { art in Text(art.title).tag(art) }
                    }.pickerStyle(.segmented)
                }
                let finisher = game.finisher
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    battleButton(game.technique, catalog: catalog)
                    battleButton(finisher, catalog: catalog)
                    battleButton(.guard, catalog: catalog)
                    battleButton(.focus, catalog: catalog)
                }
                HStack {
                    Button("設定・直前の一手") { showingBattleHelp = true }
                    Spacer()
                    Menu("その他") {
                        if !persistence.isPlaytest {
                            Button("覚醒から試遊（セーブはそのまま）") { showingPlaytest = true }
                        }
                        Button("殴る ／ 威力14") { takeAction(.punch, catalog: catalog) }
                        Button("……逃げる？") { takeAction(.escape, catalog: catalog) }
                    }
                }.font(.caption).tint(crimson)
            } else {
                Text(game.phase == .victory ? "設定は、証明された。" : "次は、突破できる。")
                    .font(.title2.bold()).fontDesign(.serif)
                if game.phase == .defeat {
                    Text(game.defeatAdvice).font(.footnote)
                    if game.trial != nil {
                        primaryButton("この未来を、書き直す ／ 再戦") { game.retryTrial() }
                        Button("ノートで設定を見直す") { game.returnToNotebook() }.tint(crimson)
                    }
                }
                if game.phase == .victory || game.trial == nil {
                primaryButton(game.phase == .victory ? "次の頁へ" : "設定を見直して再挑戦") {
                    game.returnToNotebook()
                }
                }
            }
        }
    }

    private func proofPanel(_ catalog: Catalog, compact: Bool) -> some View {
        let proof = game.battle?.proof?.last
        let interrupted = game.battle?.interrupted == true
        return VStack(alignment: .leading, spacing: 4) {
            Text(proof?.title ?? (interrupted ? "詠唱断絶——言葉が、消された。" : "余白の設定が、現実を変える。"))
                .font(.subheadline.bold()).fontDesign(.serif).foregroundStyle(proof == nil ? paper : .yellow)
            if let proof {
                if !compact, let verse = catalog.nodes.first(where: { $0.id == proof.nodeID })?.verse {
                    Text("「\(verse)」").font(.caption).fontDesign(.serif)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }
                Text(proof.explanation).font(.caption)
            } else {
                Text(interrupted ? "詠唱が0に戻った。先に防御すると、次の妨害を一度だけ防げる。" : (game.trial?.story.encounter?.note ?? "予兆を読んで、次の一手を決める。"))
                    .font(.caption)
            }
            if let state = game.battle, state.turn > 0 {
                Text("直前の一手：与えた傷 \(state.lastDamage) ／ 受けた傷 \(state.lastReceived)")
                    .font(.caption2.monospaced()).foregroundStyle(paper.opacity(0.7))
            }
        }.padding(10).frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .background((proof == nil ? crimson : Color.yellow).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: proof)
    }

    private func proofResult(_ story: Trial) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.proofAchieved ? "——設定証明・完遂——" : "——生還。その先に、極致がある——")
                .font(.headline).fontDesign(.serif).foregroundStyle(game.proofAchieved ? Color.yellow : crimson)
            Text(story.proofTitle).font(.footnote)
            if let proof = game.battle?.proof?.last {
                Text(proof.explanation).font(.footnote)
            }
            HStack {
                Text("\(game.battle?.turn ?? 0)手で突破")
                Spacer()
                Text("残存存在 \(game.vitality)")
            }.font(.caption.monospaced())
            if !game.proofAchieved {
                Text("目標には、追憶戦でいつでも挑める。")
                    .font(.caption).foregroundStyle(paper.opacity(0.7))
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(crimson.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func memories(_ catalog: Catalog) -> some View {
        let stories = catalog.trials.filter { Set($0.rewards).isSubset(of: game.unlocked) }
        return VStack(alignment: .leading, spacing: 12) {
            if !stories.isEmpty {
                Button {
                    showingMemories.toggle()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("追憶戦・かつての絶望を越えろ").font(.headline).fontDesign(.serif)
                            Text("設定証明 \(stories.filter { game.records?[$0.id]?.mastered == true }.count) / \(catalog.trials.count)")
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: showingMemories ? "chevron.up" : "chevron.down")
                    }.frame(minHeight: 48)
                }.tint(crimson)
                if showingMemories {
                    Text("事件の力に、習得した別系統を重ねて挑める。目標達成と最少手数をノートに刻もう。")
                        .font(.footnote)
                    ForEach(stories) { story in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(story.enemy).font(.headline)
                            Text(story.proofTitle).font(.footnote)
                            if let record = game.records?[story.id] {
                                Text("\(record.mastered ? "設定証明済" : "証明に挑戦") ／ 最少\(record.bestTurns)手 ／ 最高存在\(record.bestVitality)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Button("この絶望を、もう一度") { game.beginReplay(story) }
                                .buttonStyle(.bordered).tint(crimson)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(crimson.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var battleStatus: String {
        guard let state = game.battle else { return "以前の戦闘を再開" }
        var parts: [String] = []
        if state.armor > 0 { parts.append("殻あり：硬直か継ぎ目を狙う") }
        if game.enemyStyle == .hidden { parts.append(state.revealed > 0 ? "看破 あと\(state.revealed)手" : game.intent == .recover ? "硬直：今だけ狙える" : "不可視：技が当たらない") }
        if game.enemyStyle == .silencer { parts.append("短い技は減衰：詠唱を解き放つ") }
        if let higher = state.ascension {
            if higher.absorbed > 0 { parts.append("喰らった力 \(higher.absorbed)") }
            if higher.silence > 0 { parts.append("静寂 あと\(higher.silence)手") }
            if higher.rewriteUsed { parts.append("未来書換え 使用済") }
        }
        if state.ward { parts.append("妨害への備え 1回") }
        if game.focused { parts.append("次の技 ×1.5") }
        return parts.isEmpty ? "予兆を読み、設定を使う。" : parts.joined(separator: " ／ ")
    }

    private func actionLabel(_ action: BattleAction, catalog: Catalog) -> (String, String) {
        switch action {
        case .devour: return ("神喰らい", "敵の一手を吸収／残数1")
        case .rend: return ("終焉を掴む手", "吸収した力で防御を貫く")
        case .rewrite: return ("世界の理を書き換える", "一戦一度／敵の一手を消す")
        case .trueName: return ("真名解放", "全防御貫通／存在+24")
        case .breakSeal: return ("黒龍・殻を砕く", game.selected.contains("arm3") ? "硬直か看破中に有効" : "黒龍は未習得")
        case .observe: return ("魔眼・見抜く", "看破3手／襲撃を見切る")
        case .chant: return ("詠唱を重ねる", "最大3段階・妨害に注意")
        case .release: return ("詠唱を解き放つ", "予測威力 \(game.predictedDamage(action, catalog: catalog))")
        case .strike: return ("技を放つ", "予測威力 \(game.predictedDamage(action, catalog: catalog))")
        case .guard: return ("防御・備える", "被害1/4／妨害を1回防ぐ")
        case .focus: return ("集中", "技残数+1／次の技×1.5")
        default: return ("殴る", "威力14")
        }
    }
    private func battleButton(_ action: BattleAction, catalog: Catalog) -> some View {
        let label = actionLabel(action, catalog: catalog)
        return Button { takeAction(action, catalog: catalog) } label: {
            VStack(spacing: 3) {
                Text(label.0).font(.subheadline.bold())
                Text(label.1).font(.caption2)
            }.frame(maxWidth: .infinity, minHeight: 52)
        }.buttonStyle(.bordered).tint(crimson).disabled(!game.canPerform(action))
            .accessibilityLabel(label.0 + "。" + label.1)
    }
    private func takeAction(_ action: BattleAction, catalog: Catalog) {
        let turn = game.battle?.turn
        game.perform(action, catalog: catalog)
        guard game.battle?.turn != turn else { return }
        UIImpactFeedbackGenerator(style: game.battle?.proof?.last != nil || [.release, .trueName, .rend, .devour, .rewrite].contains(action) || game.battle?.broken == true ? .heavy : .light).impactOccurred()
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { impact = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation { impact = false }
        }
    }


}


private struct MonsterView: View {
    let crimson: Color
    var isDefeated = false
    @State private var breathing = false

    func defeated(_ value: Bool) -> MonsterView {
        var view = self
        view.isDefeated = value
        return view
    }

    var body: some View {
        ZStack {
            Circle().fill(crimson.opacity(0.18)).frame(width: 170, height: 170).offset(x: 60, y: -20)
            ForEach(0..<7) { index in
                Ellipse().fill(Color.purple.opacity(0.45))
                    .frame(width: 50, height: 145)
                    .rotationEffect(.degrees(Double(index) * 51 + (breathing ? 12 : -12)))
            }
            Circle().fill(Color(red: 0.06, green: 0.02, blue: 0.09)).frame(width: 110, height: 110)
            HStack(spacing: 24) {
                Capsule().fill(crimson).frame(width: 21, height: 7).rotationEffect(.degrees(20))
                Capsule().fill(crimson).frame(width: 21, height: 7).rotationEffect(.degrees(-20))
            }
        }
        .scaleEffect(isDefeated ? 0.05 : breathing ? 1.04 : 0.96)
        .opacity(isDefeated ? 0 : 1)
        .animation(.easeOut(duration: 0.5), value: isDefeated)
        .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathing = true } }
        .accessibilityLabel(isDefeated ? "敵は消えた" : "赤い目をした墨の怪物")
    }
}


private struct AwakeningIntroduction: View {
    enum Beat: Int { case encounter, pressure, notebook, awakening, impact, unlock }
    let catalog: Catalog
    let crimson: Color
    let onUnlock: () -> Void
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = Beat.encounter
    @State private var approaching = false

    var body: some View {
        VStack(spacing: 20) {
            Text(title).font(.system(size: 26, weight: .black, design: .serif))
                .multilineTextAlignment(.center)
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color.black)
                if beat == .notebook {
                    VStack(spacing: 18) {
                        Image(systemName: "book.pages.fill").font(.system(size: 70))
                        Text("この包帯は、\n力を封じている。").font(.title2.bold()).fontDesign(.serif)
                        Rectangle().fill(crimson).frame(height: 2)
                        Text("——小五の夜に書いた、一行。").font(.caption)
                    }.padding(24).foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.84))
                } else if beat == .awakening {
                    Text("——封印の向こうへ——").foregroundStyle(crimson)
                } else if beat == .unlock {
                    firstBranch
                } else {
                    MonsterView(crimson: crimson).defeated(beat == .impact)
                        .scaleEffect(beat == .pressure ? (approaching ? 1.7 : 1.1) : 1)
                    if beat == .pressure {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(crimson.opacity(approaching ? 0.8 : 0.2), lineWidth: 14)
                        VStack {
                            Text("1 DAMAGE").font(.title.bold())
                            Spacer()
                            Text("存在強度 100 → 18").font(.headline.monospaced())
                        }.padding(20).foregroundStyle(crimson)
                    }
                    if beat == .impact {
                        Text("48").font(.system(size: 110, weight: .black, design: .serif))
                            .foregroundStyle(crimson).shadow(color: crimson, radius: 20)
                    }
                }
            }.frame(height: beat == .unlock ? 440 : 280).clipped()
            Text(line).font(.body).multilineTextAlignment(.center).frame(minHeight: 50)
            if beat == .encounter {
                action("殴る") { beat = .pressure }
            } else if beat == .notebook {
                Text("（……書いた通りになるなら、今しかない）")
                    .font(.caption).foregroundStyle(.secondary)
                action("……封印を、解いてみる") { beat = .awakening }

            } else if beat == .unlock {
                action("次の力を、選ぶ", perform: onContinue)
            } else {
                // Timed beats own their transition, so repeated taps cannot skip awakening.
                Text(beat == .pressure ? "——間に合え。" : " ")
                    .font(.caption).foregroundStyle(crimson).frame(height: 52)
            }
        }
        .frame(maxWidth: .infinity)
        .fullScreenCover(isPresented: Binding(
            get: { beat == .awakening },
            set: { if !$0 && beat == .awakening { beat = .notebook } }
        )) {
            if let node = catalog.nodes.first(where: { $0.id == "arm2" }) {
                AwakeningRitual(node: node, onManifest: { beat = .impact }, onCancel: { beat = .notebook })
            }
        }
        .task(id: beat) {
            do {
                switch beat {
                case .pressure:
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(reduceMotion ? nil : .easeIn(duration: 2.2)) { approaching = true }
                    try await Task.sleep(for: .seconds(2.4))
                    beat = .notebook
                case .impact:
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    try await Task.sleep(for: .seconds(1.6))
                    beat = .unlock
                case .unlock:
                    onUnlock()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                default: break
                }
            } catch { /* Leaving or resetting the introduction cancels its timeline. */ }
        }
    }

    private var title: String {
        switch beat {
        case .encounter: return "何かが、来る。"
        case .pressure: return "効かない。\nもう、目の前にいる。"
        case .notebook: return "開いたのは、あのページ。"
        case .awakening: return "——右腕が、灼ける。"
        case .impact: return "……やれやれ。"
        case .unlock: return "最初の能力を、手に入れた。"
        }
    }

    private var line: String {
        switch beat {
        case .encounter: return "教室の誰も、気づいていない。"
        case .pressure: return "背後は壁。\n握りしめたノートだけが、残っている。"
        case .notebook: return "……こんな設定が、今さら。"
        case .awakening: return "包帯の下を、黒い紋章が走る。"
        case .impact: return "闇に還れ。"
        case .unlock: return "この一撃は、始まりに過ぎない。\nノートの奥には、まだ幾つもの力が眠っている。"
        }
    }

    private var firstBranch: some View {
        SkillConstellation(catalog: catalog, learned: ["arm2"], highlighted: ["arm2"], crimson: crimson)
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.headline).padding(.vertical, 16).frame(maxWidth: .infinity)
        }.buttonStyle(.borderedProminent).tint(crimson)
    }
}


/// No timed input or mandatory wait: the player's gesture turns handwriting into power.
private struct AwakeningRitual: View {
    private enum Step { case memory, seal, awakened }
    let node: Node
    let onManifest: () -> Void
    let onCancel: () -> Void
    @State private var step = Step.memory
    @State private var pull: CGFloat = 0
    @State private var completed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        node.route == "魔眼" ? Color(red: 0.43, green: 0.63, blue: 1) :
        node.route == "詠唱" ? Color(red: 0.91, green: 0.72, blue: 0.34) :
        Color(red: 0.9, green: 0.16, blue: 0.25)
    }
    private var glyph: String { node.route == "魔眼" ? "視" : node.route == "詠唱" ? "唱" : "解" }
    private var gestureTitle: String {
        node.route == "魔眼" ? "禁じられた視界を開く" :
        node.route == "詠唱" ? "消された詠唱をなぞる" : "右腕の封印を引き裂く"
    }
    private var awakeningLine: String {
        node.route == "魔眼" ? "見えなかったはずの世界が、視える。" :
        node.route == "詠唱" ? "書いた言葉を、世界が復唱している。" : "右腕の奥で、何かが俺の名に応えた。"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Text(step == .awakened ? "記述、現実へ侵蝕。" : "忘れたふりをしていた頁。")
                        .font(.caption.monospaced())
                    Spacer()
                    Button("閉じる", action: onCancel).frame(minHeight: 44)
                }.foregroundStyle(tint)
                Text(step == .awakened ? "この力は、俺が考えた。" : "……あれは、ただの設定だった。")
                    .font(.system(.title2, design: .serif, weight: .black))
                    .multilineTextAlignment(.center)
                notebookPage
                if step == .seal {
                    Text("信じるだけじゃない。自分の手で、解け。")
                        .font(.subheadline).multilineTextAlignment(.center)
                    sealControl
                    Button(gestureTitle) { breakSeal() }
                        .buttonStyle(.bordered).tint(tint).frame(minHeight: 44)
                        .accessibilityHint("スライド操作と同じ効果で封印を解除します")
                } else if step == .memory {
                    Text("昔の自分は、本気でこの力を信じていた。\nなら今だけは、俺も信じてやる。")
                        .font(.subheadline).multilineTextAlignment(.center)
                    ritualButton("ああ。これは、俺の設定だ。") {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { step = .seal }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } else {
                    Text(awakeningLine).font(.subheadline).multilineTextAlignment(.center)
                    Text(node.reading ?? "").font(.caption).foregroundStyle(tint)
                    Text(node.name).font(.system(.largeTitle, design: .serif, weight: .black))
                        .multilineTextAlignment(.center)
                    Text(node.effect ?? node.detail).font(.footnote).foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    ritualButton("この力を、解き放つ") {
                        guard !completed else { return }
                        completed = true
                        onManifest()
                    }.disabled(completed)
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.025, green: 0.02, blue: 0.04).ignoresSafeArea())
        .foregroundStyle(.white)
        .interactiveDismissDisabled()
    }

    private var notebookPage: some View {
        VStack(spacing: 16) {
            Text(step == .awakened ? "——ノートは、嘘をつかなかった——" : "小さな字で、こう書いてある。")
                .font(.caption).foregroundStyle(step == .awakened ? tint : .black.opacity(0.6))
            ZStack {
                Circle().stroke(tint.opacity(step == .awakened ? 0.8 : 0.18), lineWidth: 2)
                Circle().trim(from: 0.08, to: 0.92).stroke(tint, style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
                    .padding(12).rotationEffect(.degrees(step == .awakened && !reduceMotion ? 70 : 0))
                Text(glyph).font(.system(size: 74, weight: .black, design: .serif))
                    .foregroundStyle(tint.opacity(step == .awakened ? 1 : 0.25))
                if step != .awakened {
                    ForEach(0..<3) { index in
                        Rectangle().fill(Color.black.opacity(0.8))
                            .frame(height: 5).rotationEffect(.degrees(-20))
                            .offset(x: pull * CGFloat(index + 1) * 8, y: CGFloat(index - 1) * 26)
                    }
                }
            }.frame(width: 150, height: 150)
                .scaleEffect(step == .awakened && !reduceMotion ? 1.08 : 1)
                .shadow(color: tint.opacity(step == .awakened ? 0.5 : 0), radius: 20)
                .accessibilityHidden(true)
            Text("「\(node.verse ?? node.detail)」")
                .font(.system(.title3, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(step == .awakened ? .white : .black)
                .shadow(color: step == .awakened ? tint : .clear, radius: 8)
            Rectangle().fill(tint.opacity(0.6)).frame(height: 1)
        }.padding(22).frame(maxWidth: .infinity)
            .background(step == .awakened ? Color(red: 0.08, green: 0.04, blue: 0.12) : Color(red: 0.95, green: 0.92, blue: 0.84),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(step == .awakened ? 1 : 0.2), lineWidth: 2))
    }

    private var sealControl: some View {
        VStack(spacing: 8) {
            Text("右へなぞる、または下のボタンで解放").font(.caption)
            GeometryReader { geometry in
                let travel = max(1, geometry.size.width - 64)
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.12))
                    Capsule().fill(tint.opacity(0.3)).frame(width: 56 + pull * travel)
                    Text("封　印　解　除").font(.caption.bold()).frame(maxWidth: .infinity)
                    Circle().fill(tint).frame(width: 48, height: 48)
                        .overlay(Image(systemName: "arrow.right").foregroundStyle(.black))
                        .offset(x: 8 + pull * travel)
                }
                .contentShape(Capsule())
                .gesture(DragGesture(minimumDistance: 8)
                    .onChanged { value in pull = min(1, max(0, value.translation.width / travel)) }
                    .onEnded { _ in
                        if pull >= 0.8 { breakSeal() }
                        else { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pull = 0 } }
                    })
            }.frame(height: 56).accessibilityHidden(true)
        }
    }
    private func breakSeal() {
        guard step == .seal else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
            pull = 1
            step = .awakened
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    private func ritualButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).padding(.vertical, 16).frame(maxWidth: .infinity)
        }.buttonStyle(.borderedProminent).tint(tint).foregroundStyle(.black)
    }
}

/// The complete playable horizon: one first ability and three evolving branches.
private struct SkillConstellation: View {
    let catalog: Catalog
    let learned: Set<String>
    let highlighted: Set<String>
    let crimson: Color
    var proven: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var inspected: Node?
    private let gold = Color(red: 0.85, green: 0.66, blue: 0.29)
    private let rows = [["arm2"], ["arm3", "eye2", "chant2"],
                        ["arm4", "eye3", "chant3"], ["arm5", "eye4", "chant4"]]

    var body: some View {
        VStack(spacing: 0) {
            let total = rows.flatMap { $0 }
            Text("覚醒 \(total.filter { learned.contains($0) }.count) / \(total.count) · 禁書ノ系譜")
                .font(.caption.monospaced().bold()).foregroundStyle(crimson).padding(.top, 14)
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack {
                    Circle().stroke(gold.opacity(0.14), lineWidth: 1)
                        .frame(width: width * 0.9, height: width * 0.9).position(x: width / 2, y: 190)
                    Circle().stroke(gold.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [2, 10]))
                        .frame(width: width * 0.76, height: width * 0.76).position(x: width / 2, y: 190)
                    ForEach(1..<4) { row in
                        ForEach(0..<3) { column in
                            let id = rows[row][column]
                            let start = point(row: row - 1, column: row == 1 ? 0 : column, width: width)
                            let end = point(row: row, column: column, width: width)
                            Path { path in
                                path.move(to: start)
                                path.addLine(to: CGPoint(x: start.x, y: (start.y + end.y) / 2))
                                path.addLine(to: CGPoint(x: end.x, y: (start.y + end.y) / 2))
                                path.addLine(to: end)
                            }.trim(from: 0, to: revealed ? 1 : 0)
                                .stroke(learned.contains(id) ? crimson : Color.white.opacity(0.23),
                                        style: StrokeStyle(lineWidth: learned.contains(id) ? 2.5 : 1, dash: learned.contains(id) ? [] : [3, 4]))
                        }
                    }
                    ForEach(0..<4) { row in
                        ForEach(Array(rows[row].enumerated()), id: \.element) { column, id in
                            let active = learned.contains(id)
                            let newly = highlighted.contains(id)
                            Button {
                                inspected = catalog.nodes.first { $0.id == id }
                            } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    Circle().fill(active ? crimson.opacity(0.22) : Color.black)
                                    Circle().stroke(active ? crimson : row == 3 ? gold.opacity(0.8) : Color.white.opacity(0.3), lineWidth: newly ? 3 : 1)
                                    Image(systemName: active ? (id.hasPrefix("arm") ? "flame.fill" : id.hasPrefix("eye") ? "eye.fill" : "waveform") : "lock.fill")
                                        .font(.system(size: newly ? 22 : 15)).foregroundStyle(active ? crimson : .gray)
                                }.frame(width: newly ? 52 : 38, height: newly ? 52 : 38)
                                    .shadow(color: newly ? crimson.opacity(0.7) : .clear, radius: revealed ? 16 : 0)
                                Text(id == "arm2" ? "漆黒拳・第一拘束解除" : catalog.nodes.first { $0.id == id }?.name ?? id)
                                    .font(.system(size: 10, weight: active ? .bold : .regular))
                                    .foregroundStyle(active ? Color.white : Color.white.opacity(0.55))
                                    .multilineTextAlignment(.center).frame(width: width / 3 - 5)
                                if newly { Text("封印解除").font(.system(size: 9, weight: .bold)).foregroundStyle(crimson) }
                                else if proven.contains(id) { Text("設定証明済").font(.system(size: 9, weight: .bold)).foregroundStyle(gold) }
                                else if row == 3 { Text("終式").font(.system(size: 9, weight: .bold)).foregroundStyle(gold) }
                            }
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(catalog.nodes.first { $0.id == id }?.name ?? id)、\(active ? "習得済み" : "未習得")。詳細を開く")
                                .position(point(row: row, column: column, width: width))
                                .opacity(row == 0 || revealed ? 1 : 0)
                        }
                    }
                }
                .scaleEffect(revealed || reduceMotion ? 1 : 1.7, anchor: .top)
            }.padding(.horizontal, 8)
            Text("龍腕ノ封縛 ／ 因果ノ魔眼 ／ 終焉ノ言霊").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).padding(.bottom, 14)
        }
        .task {
            if reduceMotion { revealed = true; return }
            do {
                try await Task.sleep(for: .milliseconds(500))
                withAnimation(.easeInOut(duration: 1.8)) { revealed = true }
            } catch { }
        }
        .sheet(item: $inspected) { node in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(learned.contains(node.id) ? "——封印解除済——" : "——未だ開かれぬ頁——")
                        .font(.caption.bold()).foregroundStyle(crimson)
                    Text(node.reading ?? "").font(.caption).foregroundStyle(.secondary)
                    Text(node.name).font(.system(size: 30, weight: .black, design: .serif))
                    Text("「\(node.verse ?? node.detail)」").font(.title3).fontDesign(.serif)
                    Divider()
                    Text("この設定が、現実になると").font(.headline)
                    Text(node.effect ?? node.detail)
                    if let story = catalog.trials.first(where: { $0.rewards.contains(node.id) }) {
                        Text("解放事件：\(story.title)").font(.subheadline.bold())
                        Text(story.place).font(.caption)
                        Text((proven.contains(node.id) ? "証明済：" : "設定証明：") + story.proofTitle).font(.footnote)
                    } else { Text("最初の覚醒で習得する、全ての起点。").font(.footnote) }
                    let children = catalog.abilities.filter { child in
                        child.requires.contains(node.id) || catalog.trials.contains { story in
                            story.requires.contains(node.id) && story.rewards.contains(child.id)
                        }
                    }
                    if !children.isEmpty {
                        Text("この先に眠る力").font(.headline)
                        ForEach(children) { child in Text("◇ \(child.name)") }
                    }
                    Button("禁書を閉じる") { inspected = nil }.buttonStyle(.borderedProminent).tint(crimson)
                }.padding(24)
            }.presentationDetents([.medium, .large])
        }
    }

    private func point(row: Int, column: Int, width: CGFloat) -> CGPoint {
        CGPoint(x: row == 0 ? width / 2 : width * CGFloat(column * 2 + 1) / 6,
                y: 48 + CGFloat(row) * 90)
    }
}


/// Three readable silhouettes, without adding art downloads or animation timelines.
private struct TacticalEnemyView: View {
    let style: EnemyStyle
    let revealed: Bool
    let armor: Int
    let crimson: Color
    var body: some View {
        ZStack {
            switch style {
            case .armored:
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(armor > 0 ? Color.gray : crimson, lineWidth: armor > 0 ? 10 : 2)
                        .frame(width: CGFloat(70 + index * 30), height: CGFloat(55 + index * 14))
                        .rotationEffect(.degrees(Double(index * 24)))
                }
                Text(armor > 0 ? "殻" : "砕").font(.title.bold()).fontDesign(.serif).foregroundStyle(crimson)
            case .hidden:
                Ellipse().stroke(crimson.opacity(revealed ? 1 : 0.25), style: StrokeStyle(lineWidth: 2, dash: revealed ? [] : [2, 8]))
                    .frame(width: 105, height: 95)
                Image(systemName: revealed ? "eye.fill" : "eye.slash").font(.system(size: 40)).foregroundStyle(crimson)
            case .silencer:
                ForEach(0..<5) { index in
                    Capsule().fill(crimson.opacity(0.3 + Double(index) * 0.12))
                        .frame(width: CGFloat(130 - index * 22), height: 5).offset(y: CGFloat(index * 17 - 34))
                }
            case .open:
                MonsterView(crimson: crimson).scaleEffect(0.6)
            }
        }.frame(maxWidth: .infinity).accessibilityHidden(true)
    }
}
