import SwiftUI
import ChronicleCore

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

    init() {
        let saved = UserDefaults.standard.data(forKey: "chronicle.prototype.v1")
        _game = State(initialValue: saved.flatMap { try? JSONDecoder().decode(Game.self, from: $0) } ?? Game())
    }

    var body: some View {
        ZStack {
            (game.phase == .notebook ? paper : Color(red: 0.03, green: 0.02, blue: 0.05)).ignoresSafeArea()
            if let catalog {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if game.phase == .notebook { notebook(catalog) }
                        else { battle(catalog) }
                        Text(game.log).font(.body).lineSpacing(6).padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(crimson.opacity(0.1))
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
        .foregroundStyle(game.phase == .notebook ? Color.black : paper)
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
            Button("最初から", role: .destructive) { game = Game() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("第\(game.day)頁 ／ \(game.phase == .notebook ? "記述" : "現実")")
                Spacer()
                Button("書き直す") { confirmingReset = true }.font(.caption)
            }.font(.caption.monospaced()).foregroundStyle(crimson)
            Text("黒歴史ノート").font(.system(size: 34, weight: .black, design: .serif))
            Text("その設定は、まだ終わらない。").font(.caption)
            Rectangle().fill(crimson).frame(height: 2)
        }
    }

    private func notebook(_ catalog: Catalog) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text("設定強度").font(.caption)
                    Text("×\(game.multiplier(catalog), specifier: "%.2f")")
                        .font(.system(size: 40, weight: .black, design: .serif)).foregroundStyle(crimson)
                }
                Spacer()
                Text("記述点 \(game.ink)\n技威力 \(game.damage(catalog))")
                    .font(.callout.monospaced()).multilineTextAlignment(.trailing)
            }
            Text("解放した設定を選んで、この頁に刻む。設定を重ねるほど、力は増す。")
                .font(.footnote)
            ForEach(["右腕", "魔眼", "詠唱"], id: \.self) { route in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(route)ノ系譜").font(.title2.bold()).fontDesign(.serif)
                    ForEach(catalog.nodes.filter { $0.route == route }) { node in
                        nodeRow(node)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("交差する設定").font(.title2.bold()).fontDesign(.serif)
                ForEach(catalog.resonances) { resonance in
                    let active = game.activeResonances(catalog).contains { $0.id == resonance.id }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(active ? "◆" : "◇") \(resonance.name)  ×\(resonance.multiplier, specifier: "%.1f")").bold()
                        Text(resonance.requires.compactMap { id in catalog.nodes.first { $0.id == id }?.name }.joined(separator: " ＋ "))
                            .font(.caption)
                        if active { Text(resonance.chant).font(.caption).italic() }
                    }.foregroundStyle(active ? crimson : .secondary)
                }
            }
            Button {
                game.manifest()
                showCutin("設定、現実化。")
            } label: {
                Text("この設定で、現実を書き換える").bold().padding(.vertical, 10).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(crimson).disabled(game.selected.isEmpty)
        }
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
            Text(node.detail).font(.footnote)
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
            ZStack {
                Circle().fill(crimson.opacity(0.25)).frame(width: 160, height: 160).offset(x: 70, y: -30)
                Image(systemName: "scribble.variable").font(.system(size: 120, weight: .black)).foregroundStyle(.purple)
                HStack(spacing: 20) {
                    Capsule().fill(crimson).frame(width: 18, height: 5)
                    Capsule().fill(crimson).frame(width: 18, height: 5)
                }
            }.frame(height: 200).accessibilityLabel("墨でできた怪物。赤い目が光る。")
            Text("存在強度 \(game.vitality) ／ 詠唱残数 \(game.charges)").font(.callout.monospaced())
            if game.phase == .battle {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    command("技を放つ ／ \(game.damage(catalog))", action: "skill", catalog: catalog)
                    command("抑える ／ 次の技 ×1.5", action: "focus", catalog: catalog)
                    command("殴る ／ 14", action: "punch", catalog: catalog)
                    command("……逃げる？", action: "escape", catalog: catalog)
                }
            } else {
                Text(game.phase == .victory ? "設定は、証明された。" : "まだ、設定が足りない。")
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
