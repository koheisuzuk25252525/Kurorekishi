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
    @AppStorage("chronicle.introduction.v3") private var introductionComplete = false
    @State private var showingTree = false
    @State private var inspectedNode: Node?
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
                        else if game.phase == .notebook { notebook(catalog) }
                        else { battle(catalog) }
                        if introductionComplete && game.phase != .notebook {
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
                    Text("断").font(.system(size: 250, weight: .black, design: .serif))
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

    private var isPaper: Bool { introductionComplete && game.phase == .notebook }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("第\(game.day)頁 ／ \(game.phase == .notebook ? "記述" : "現実")")
                Spacer()
                Button("書き直す") { confirmingReset = true }.font(.caption)
            }.font(.caption.monospaced()).foregroundStyle(crimson)
            Text("黒歴史ノート").font(.system(size: 34, weight: .black, design: .serif))
            Rectangle().fill(crimson).frame(height: 2)
        }
    }

    private func introduction(_ catalog: Catalog) -> some View {
        AwakeningIntroduction(crimson: crimson, onUnlock: {
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

    private func heroEmblem(awakened: Bool) -> some View {
        ZStack {
            Circle().fill(crimson.opacity(0.12)).frame(width: 145, height: 145)
            Image(systemName: awakened ? "flame.fill" : "person.fill")
                .font(.system(size: 78, weight: .black)).foregroundStyle(crimson)
            if game.selected.contains("eye2") {
                Image(systemName: "eye.fill").font(.system(size: 30)).offset(x: 48, y: -35)
            }
            if game.selected.contains("arm3") {
                Image(systemName: "bolt.fill").font(.system(size: 55)).offset(x: -48, y: 5)
            }
        }.accessibilityLabel(awakened ? "封印を解放した姿" : "封印された姿")
    }

    private var monster: MonsterView { MonsterView(crimson: crimson) }

    private func notebook(_ catalog: Catalog) -> some View {
        VStack(spacing: 18) {
            heroEmblem(awakened: game.selected.contains("arm2"))
            Text(game.activeResonances(catalog).first?.name ??
                 (game.selected.contains("arm3") ? "黒龍を宿す者" : "封印を解いた右腕"))
                .font(.title2.bold()).fontDesign(.serif)
            HStack {
                Text("技威力 \(game.damage(catalog))").bold()
                Spacer()
                Text("記述点 \(game.ink)").font(.callout)
            }
            primaryButton("この力を、試す") {
                game.manifest()
                showCutin("設定、現実化。")
            }.disabled(game.selected.isEmpty)
            Text("次は、何を宿す？").font(.title2.bold()).fontDesign(.serif)
            let routes = game.unlocked.contains("arm3") || game.unlocked.contains("eye2")
                ? ["右腕", "魔眼", "詠唱"] : ["右腕", "魔眼"]
            let next = routes.compactMap { route in
                catalog.nodes.first { $0.route == route && !game.unlocked.contains($0.id) }
            }
            ForEach(next) { node in
                evolutionCard(node, catalog: catalog)
            }
            Button(showingTree ? "系譜を閉じる" : "すべての系譜を見る") {
                withAnimation { showingTree.toggle() }
            }.font(.footnote).tint(crimson)
            if showingTree {
                ForEach(["右腕", "魔眼", "詠唱"], id: \.self) { route in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(route)ノ系譜").font(.title3.bold()).fontDesign(.serif)
                        ForEach(catalog.nodes.filter { $0.route == route }) { node in nodeRow(node) }
                    }
                }
            }
        }
    }

    private func evolutionCard(_ node: Node, catalog: Catalog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: node.route == "右腕" ? "flame.fill" : node.route == "魔眼" ? "eye.fill" : "waveform")
                    .font(.title).foregroundStyle(crimson)
                Text(node.id == "arm3" ? "この腕に、黒龍を宿す" : node.id == "eye1" ? "隠した右目を開く" : node.name)
                    .font(.headline).fontDesign(.serif)
                Spacer()
                Button { inspectedNode = inspectedNode?.id == node.id ? nil : node } label: {
                    Image(systemName: "info.circle")
                }.accessibilityLabel("\(node.name)の詳細")
            }
            // Opening the eye evolves through its root in one purchase, rather than
            // making the player read and buy two prerequisite descriptions.
            let bundle = node.id == "eye1"
                ? catalog.nodes.filter { ["eye1", "eye2"].contains($0.id) && !game.unlocked.contains($0.id) }
                : [node]
            let cost = bundle.reduce(0) { $0 + $1.cost }
            if inspectedNode?.id == node.id { Text(node.detail).font(.footnote) }
            Button("解放する ／ \(cost)点") {
                for item in bundle { game.unlock(item) }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showCutin(bundle.last?.name ?? node.name)
            }.buttonStyle(.bordered).tint(crimson)
                .disabled(game.ink < cost || !Set(node.requires).isSubset(of: game.unlocked))
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(crimson.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func nodeRow(_ node: Node) -> some View {
        let unlocked = game.unlocked.contains(node.id)
        let selected = game.selected.contains(node.id)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(selected ? "◆" : "◇") \(node.name)").bold()
                Spacer()
                Text("★\(node.stars)").font(.caption)
            }
            Button("設定を読む") { inspectedNode = inspectedNode?.id == node.id ? nil : node }
                .font(.caption)
            if inspectedNode?.id == node.id { Text(node.detail).font(.footnote) }
            if !node.requires.isEmpty {
                Text("前提：\(node.requires.compactMap { id in catalog?.nodes.first { $0.id == id }?.name }.joined(separator: "、"))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(unlocked ? (selected ? "この頁から外す" : "この頁に刻む") : "解放 ／ \(node.cost)点") {
                if unlocked { game.toggle(node) }
                else { game.unlock(node) }
            }
            .buttonStyle(.bordered).tint(crimson)
            .disabled(!unlocked && !game.canUnlock(node))
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? crimson.opacity(0.09) : Color.white.opacity(0.3))
            .overlay(alignment: .leading) { Rectangle().fill(selected ? crimson : .gray.opacity(0.3)).frame(width: 3) }
    }

    private func battle(_ catalog: Catalog) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("名を失った残響").font(.headline)
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
                showCutin(game.activeResonances(catalog).first?.name ?? "漆黒拳")
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
    let crimson: Color
    let onUnlock: () -> Void
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = Beat.encounter
    @State private var approaching = false
    @State private var inscribed = false

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
            }.frame(height: 280).clipped()
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
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 1.4)) { inscribed = true }
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
        case .unlock: return "最初の系譜、解放。"
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
        case .unlock: return "書いただけの設定が、消えない力になった。"
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
        VStack(spacing: 0) {
            Text("右腕ノ系譜").font(.caption).foregroundStyle(.white.opacity(0.6))
            Circle().fill(.white.opacity(0.5)).frame(width: 12, height: 12).padding(.top, 16)
            Path { path in
                path.move(to: CGPoint(x: 60, y: 0))
                path.addLine(to: CGPoint(x: 60, y: 45))
            }.trim(from: 0, to: inscribed ? 1 : 0)
                .stroke(crimson, lineWidth: 3).frame(width: 120, height: 45)
            ZStack {
                Circle().stroke(crimson, lineWidth: 2).frame(width: 80, height: 80)
                Circle().fill(crimson.opacity(inscribed ? 0.4 : 0)).frame(width: 70, height: 70)
                Image(systemName: "flame.fill").font(.system(size: 35)).foregroundStyle(crimson)
            }.scaleEffect(inscribed ? 1 : 0.6)
            Text("第一拘束解除").font(.title2.bold()).fontDesign(.serif).foregroundStyle(.white).padding(.top, 12)
            Text("漆黒拳、習得").font(.caption.bold()).foregroundStyle(crimson).padding(.top, 6)
            HStack(spacing: 30) {
                Image(systemName: "lock.fill")
                Image(systemName: "lock.fill")
            }.font(.caption).foregroundStyle(.white.opacity(0.25)).padding(.top, 18)
        }.accessibilityLabel("右腕の系譜に第一拘束解除が刻まれた。漆黒拳を習得")
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.headline).padding(.vertical, 16).frame(maxWidth: .infinity)
        }.buttonStyle(.borderedProminent).tint(crimson)
    }
}
