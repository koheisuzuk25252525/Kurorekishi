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

    init() {
        let saved = UserDefaults.standard.data(forKey: "chronicle.prototype.v1")
        _game = State(initialValue: saved.flatMap { try? JSONDecoder().decode(Game.self, from: $0) } ?? Game())
    }

    var body: some View {
        ZStack {
            (isPaper ? paper : Color(red: 0.03, green: 0.02, blue: 0.05)).ignoresSafeArea()
            if let catalog {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if !introductionComplete { introduction(catalog) }
                        else if let progress = game.trial, progress.stage != .combat { trialScene(progress, catalog: catalog) }
                        else if game.phase == .notebook { notebook(catalog) }
                        else { battle(catalog) }
                        if introductionComplete && game.phase != .notebook && game.trial?.stage != .reward {
                        Text(game.log).font(.footnote).lineSpacing(4).padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(crimson.opacity(0.1))
                        }
                    }.padding(20)
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
            do { catalog = try Catalog.load() }
            catch { self.error = "設定データを読み込めませんでした：\(error.localizedDescription)" }
        }
        .onChange(of: game) { _, value in
            if let data = try? JSONEncoder().encode(value) {
                UserDefaults.standard.set(data, forKey: "chronicle.prototype.v1")
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
                Text("すべての系譜が、あなたの力になった。").font(.headline)
            }
            Text("あなたの系譜").font(.title2.bold()).fontDesign(.serif)
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

    private func battle(_ catalog: Catalog) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text(game.trial?.story.enemy ?? "名を失った残響").font(.headline)
                Spacer()
                Text("\(game.enemyHP) / \(game.enemyMaximum)").monospacedDigit()
            }
            ProgressView(value: Double(game.enemyHP), total: Double(game.enemyMaximum)).tint(crimson)
            monster.defeated(game.phase == .victory).frame(height: 200)
                .offset(x: impact ? 12 : 0)
            Text("存在強度 \(game.vitality) ／ 詠唱残数 \(game.charges)").font(.callout.monospaced())
            if game.phase == .battle {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    command("技を放つ ／ \(game.damage(catalog))", action: "skill", catalog: catalog)
                    command("抑える ／ 次の技 ×1.5", action: "focus", catalog: catalog)
                    command("殴る ／ 14", action: "punch", catalog: catalog)
                    command("……逃げる？", action: "escape", catalog: catalog)
                }
            } else {
                Text(game.phase == .victory ? "次の力が、待っている。" : "まだ、設定が足りない。")
                    .font(.title2).fontDesign(.serif)
                Button(game.phase == .victory ? "次の頁へ ／ 新しい設定を解放" : "ノートへ戻って再挑戦") {
                    game.returnToNotebook()
                }.buttonStyle(.borderedProminent).tint(crimson)
            }
        }
    }

    private func command(_ title: String, action: String, catalog: Catalog) -> some View {
        Button {
            if action == "skill", game.charges > 0 {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showCutin(game.trial.map { rewardName($0.story, catalog: catalog) } ?? game.activeResonances(catalog).first?.name ?? "漆黒拳")
            }
            game.act(action, catalog: catalog)
            withAnimation(.spring(response: 0.15, dampingFraction: 0.2)) { impact = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation { impact = false }
            }
        } label: {
            Text(title).font(.footnote.bold()).frame(maxWidth: .infinity, minHeight: 48)
        }.buttonStyle(.bordered).tint(crimson)
            .disabled(action == "skill" && game.charges == 0)
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
    private let rows = [["arm2"], ["arm3", "eye2", "chant2"],
                        ["arm4", "eye3", "chant3"], ["arm5", "eye4", "chant4"]]

    var body: some View {
        VStack(spacing: 0) {
            let total = rows.flatMap { $0 }
            Text("習得 \(total.filter { learned.contains($0) }.count) / \(total.count)")
                .font(.caption.monospaced().bold()).foregroundStyle(crimson).padding(.top, 14)
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack {
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
                            VStack(spacing: 5) {
                                ZStack {
                                    Circle().fill(active ? crimson.opacity(0.22) : Color.black)
                                    Circle().stroke(active ? crimson : Color.white.opacity(0.3), lineWidth: newly ? 3 : 1)
                                    Image(systemName: active ? (id.hasPrefix("arm") ? "flame.fill" : id.hasPrefix("eye") ? "eye.fill" : "waveform") : "lock.fill")
                                        .font(.system(size: newly ? 22 : 15)).foregroundStyle(active ? crimson : .gray)
                                }.frame(width: newly ? 52 : 38, height: newly ? 52 : 38)
                                    .shadow(color: newly ? crimson.opacity(0.7) : .clear, radius: revealed ? 16 : 0)
                                Text(id == "arm2" ? "漆黒拳・第一拘束解除" : catalog.nodes.first { $0.id == id }?.name ?? id)
                                    .font(.system(size: 10, weight: active ? .bold : .regular))
                                    .foregroundStyle(active ? Color.white : Color.white.opacity(0.55))
                                    .multilineTextAlignment(.center).frame(width: width / 3 - 5)
                                if newly { Text("習得").font(.system(size: 9, weight: .bold)).foregroundStyle(crimson) }
                            }.position(point(row: row, column: column, width: width))
                                .opacity(row == 0 || revealed ? 1 : 0)
                        }
                    }
                }
                .scaleEffect(revealed || reduceMotion ? 1 : 1.7, anchor: .top)
            }.padding(.horizontal, 8)
            Text("右腕  ／  魔眼  ／  詠唱").font(.caption).foregroundStyle(.white.opacity(0.6)).padding(.bottom, 14)
        }
        .task {
            if reduceMotion { revealed = true; return }
            do {
                try await Task.sleep(for: .milliseconds(500))
                withAnimation(.easeInOut(duration: 1.8)) { revealed = true }
            } catch { }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("全10能力の系譜。光る点は習得済み、鍵は未習得。右腕、魔眼、詠唱へ枝分かれしている")
    }

    private func point(row: Int, column: Int, width: CGFloat) -> CGPoint {
        CGPoint(x: row == 0 ? width / 2 : width * CGFloat(column * 2 + 1) / 6,
                y: 48 + CGFloat(row) * 90)
    }
}
