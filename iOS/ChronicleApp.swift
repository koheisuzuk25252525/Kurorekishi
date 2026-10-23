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
    @State private var cutin: String?
    @State private var confirmingReset = false
    @AppStorage("chronicle.introduction.v4") private var introductionComplete = false
    @State private var showingTree = false
    @State private var impact = false
    @State private var showingBattleHelp = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        let saved = UserDefaults.standard.data(forKey: "chronicle.prototype.v1")
        _game = State(initialValue: saved.flatMap { try? JSONDecoder().decode(Game.self, from: $0) } ?? Game())
    }

    var body: some View {
        ZStack {
            (isPaper ? paper : Color(red: 0.03, green: 0.02, blue: 0.05)).ignoresSafeArea()
            if let catalog {
                if isCombatScreen {
                    GeometryReader { geometry in
                        if dynamicTypeSize.isAccessibilitySize {
                            ScrollView { battle(catalog, compact: true) }.padding(16)
                        } else {
                            battle(catalog, compact: geometry.size.height < 650)
                                .padding(16).frame(maxHeight: .infinity)
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
            if let cutin {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Text(cutin.contains("眼") ? "視" : cutin.contains("詠") || cutin.contains("真名") ? "言" : "龍").font(.system(size: 250, weight: .black, design: .serif))
                        .foregroundStyle(crimson.opacity(0.3))
                    VStack(spacing: 30) {
                        Text("——書いた通りに").font(.title3)
                        Text(cutin).font(.system(size: 32, weight: .black, design: .serif))
                            .multilineTextAlignment(.center).foregroundStyle(crimson)
                        Text("——現実になる").font(.title3)
                    }.padding()
                }.foregroundStyle(.white).allowsHitTesting(true)
            }
        }
        .foregroundStyle(isPaper ? Color.black : paper)
        .task {
            do { catalog = try Catalog.load(); game.resumeBattle() }
            catch { self.error = "設定データを読み込めませんでした：\(error.localizedDescription)" }
        }
        .onChange(of: game) { _, value in
            if let data = try? JSONEncoder().encode(value) {
                UserDefaults.standard.set(data, forKey: "chronicle.prototype.v1")
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
            Text("力は、まだ始まったばかりだ。").font(.title2.bold()).fontDesign(.serif)
            Text("次の頁は、新しい力を要求している。").font(.footnote)
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
            SkillConstellation(catalog: catalog, learned: game.unlocked, highlighted: [], crimson: crimson)
                .frame(height: 430).background(Color.black, in: RoundedRectangle(cornerRadius: 18))
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

    private func rewardName(_ story: Trial, catalog: Catalog) -> String {
        story.rewards.compactMap { id in catalog.nodes.first { $0.id == id }?.name }.last ?? "新しい力"
    }

    private func trialScene(_ progress: TrialProgress, catalog: Catalog) -> some View {
        let story = progress.story
        return VStack(spacing: 20) {
            Text(story.place).font(.caption).foregroundStyle(crimson)
            Text(progress.stage == .reward ? "新たな系譜、解放。" : story.title)
                .font(.title2.bold()).fontDesign(.serif).multilineTextAlignment(.center)
            if progress.stage == .reward {
                SkillConstellation(catalog: catalog, learned: game.unlocked,
                                   highlighted: Set(story.rewards), crimson: crimson)
                    .frame(height: 430).background(Color.black, in: RoundedRectangle(cornerRadius: 18))
                Text("《\(rewardName(story, catalog: catalog))》習得").font(.title3.bold())
                Text(story.victory).font(.footnote).multilineTextAlignment(.center)
                if let resonance = game.activeResonances(catalog).first(where: {
                    !Set($0.requires).isDisjoint(with: story.rewards)
                }) {
                    Text("設定が共鳴した——《\(resonance.name)》 ×\(resonance.multiplier, specifier: "%.1f")")
                        .font(.footnote.bold()).foregroundStyle(crimson)
                }
                primaryButton("さらに先の頁へ") { game.returnToNotebook() }
            } else {
                monster.frame(height: 190)
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
                    primaryButton(story.vow) {
                        game.awakenTrial()
                        showCutin(rewardName(story, catalog: catalog))
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
            Text(game.log).font(.footnote).lineLimit(compact ? 2 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(game.log)
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
                        Button("殴る ／ 威力14") { takeAction(.punch, catalog: catalog) }
                        Button("……逃げる？") { takeAction(.escape, catalog: catalog) }
                    }
                }.font(.caption).tint(crimson)
            } else {
                Text(game.phase == .victory ? "設定は、証明された。" : "次は、突破できる。")
                    .font(.title2.bold()).fontDesign(.serif)
                if game.phase == .defeat { Text(game.defeatAdvice).font(.footnote) }
                primaryButton(game.phase == .victory ? "次の頁へ" : "設定を見直して再挑戦") {
                    game.returnToNotebook()
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
        UIImpactFeedbackGenerator(style: [.release, .trueName, .rend, .devour, .rewrite].contains(action) || game.battle?.broken == true ? .heavy : .light).impactOccurred()
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { impact = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation { impact = false }
        }
    }

    private func showCutin(_ title: String) {
        cutin = title
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            cutin = nil
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
    enum Beat: Int { case encounter, pressure, notebook, awakening, ready, impact, unlock }
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
                } else if beat == .awakening || beat == .ready {
                    awakeningArt
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
            } else if beat == .ready {
                action("漆黒拳を放つ") { beat = .impact }
            } else if beat == .unlock {
                action("次の力を、選ぶ", perform: onContinue)
            } else {
                // Timed beats own their transition, so repeated taps cannot skip awakening.
                Text(beat == .pressure ? "——間に合え。" : " ")
                    .font(.caption).foregroundStyle(crimson).frame(height: 52)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: beat) {
            do {
                switch beat {
                case .pressure:
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(reduceMotion ? nil : .easeIn(duration: 2.2)) { approaching = true }
                    try await Task.sleep(for: .seconds(2.4))
                    beat = .notebook
                case .awakening:
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    try await Task.sleep(for: .seconds(2.6))
                    beat = .ready
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
        case .ready: return "本当に、宿った。"
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
        case .ready: return "（……ずっと、待ってた）"
        case .impact: return "闇に還れ。"
        case .unlock: return "この一撃は、始まりに過ぎない。\nノートの奥には、まだ幾つもの力が眠っている。"
        }
    }

    private var awakeningArt: some View {
        ZStack {
            ForEach(0..<9) { index in
                Rectangle().fill(crimson.opacity(0.3))
                    .frame(width: 2, height: 260)
                    .rotationEffect(.degrees(Double(index) * 40))
            }
            // A forearm and unravelling seals, rather than a text-only reward.
            RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.12, green: 0.06, blue: 0.1))
                .frame(width: 64, height: 180).rotationEffect(.degrees(25))
                .overlay {
                    ForEach(0..<5) { index in
                        Rectangle().fill(beat == .ready ? crimson : .white.opacity(0.7))
                            .frame(width: beat == .ready ? 110 : 76, height: 5)
                            .rotationEffect(.degrees(beat == .ready ? Double(index * 17) : 25))
                            .offset(x: beat == .ready ? CGFloat(index * 10 - 20) : 0,
                                    y: CGFloat(index * 23 - 48))
                    }
                }
            Text("解").font(.system(size: 100, weight: .black, design: .serif))
                .foregroundStyle(crimson).shadow(color: crimson.opacity(0.7), radius: 18)
        }.animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: beat)
        .accessibilityLabel("前腕の包帯がほどけ、黒い紋章が現れる")
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


/// The complete playable horizon: one first ability and three evolving branches.
private struct SkillConstellation: View {
    let catalog: Catalog
    let learned: Set<String>
    let highlighted: Set<String>
    let crimson: Color
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
