import Foundation
import XCTest
@testable import ChronicleCore

final class LegendProofTests: XCTestCase {
    private func start(_ id: String, catalog: Catalog) throws -> Game {
        var game = Game(); game.completeIntroduction()
        for story in catalog.trials {
            game.beginTrial(story); game.confrontTrial(); game.awakenTrial()
            if story.id == id { return game }
            winBattle(&game, catalog: catalog)
            XCTAssertEqual(game.phase, .victory)
            game.returnToNotebook()
        }
        throw CocoaError(.fileNoSuchFile)
    }

    func testAllNineProofsRequireRealCombatAndAreReachable() throws {
        let catalog = try Catalog.load()
        let plans: [(String, [BattleAction])] = [
            ("dragon", [.focus, .guard, .breakSeal]),
            ("eye", [.focus, .observe]),
            ("word", [.guard, .chant, .chant, .release]),
            ("devour", [.focus, .devour, .breakSeal]),
            ("causality", [.focus, .observe]),
            ("silence", [.guard, .chant, .chant, .release]),
            ("lastarm", [.focus, .devour, .rend]),
            ("worldeye", [.focus, .rewrite]),
            ("truename", [.guard, .guard, .chant, .guard, .chant, .chant, .trueName, .chant, .release])
        ]
        for (id, actions) in plans {
            var game = try start(id, catalog: catalog)
            XCTAssertFalse(game.proofAchieved, id)
            for action in actions {
                XCTAssertTrue(game.canPerform(action), "\(id): \(action)")
                game.perform(action, catalog: catalog)
            }
            XCTAssertTrue(game.proofAchieved, id)
            winBattle(&game, catalog: catalog)
            XCTAssertEqual(game.phase, .victory, id)
            let record = try XCTUnwrap(game.records?[id])
            XCTAssertTrue(record.mastered, id)
            XCTAssertEqual(record.victories, 1)
            XCTAssertEqual(record.bestTurns, game.battle?.turn)
            XCTAssertEqual(record.bestVitality, game.vitality)
            print("PROOF \(id): turns=\(record.bestTurns), vitality=\(record.bestVitality)")
        }
    }

    func testVictoryWithoutProofStillUnlocksAndReplayCanImproveRecord() throws {
        let catalog = try Catalog.load()
        var game = try start("eye", catalog: catalog)
        for action in [BattleAction.observe, .guard, .strike, .strike] {
            game.perform(action, catalog: catalog)
        }
        XCTAssertEqual(game.phase, .victory)
        XCTAssertTrue(game.unlocked.contains("eye2"))
        XCTAssertEqual(game.records?["eye"]?.mastered, false)
        let first = try XCTUnwrap(game.records?["eye"])
        game.returnToNotebook()
        let snapshot = game
        let story = try XCTUnwrap(catalog.trials.first { $0.id == "eye" })
        XCTAssertFalse(game.canBegin(story))
        XCTAssertTrue(game.canReplay(story))
        game.beginReplay(story)
        XCTAssertEqual(game.trial?.isReplay, true)
        XCTAssertEqual(game.phase, .battle)
        for action in [BattleAction.focus, .observe, .strike] { game.perform(action, catalog: catalog) }
        XCTAssertEqual(game.phase, .victory)
        XCTAssertTrue(game.records?["eye"]?.mastered == true)
        XCTAssertEqual(game.records?["eye"]?.victories, 2)
        XCTAssertLessThan(game.records!["eye"]!.bestTurns, first.bestTurns)
        XCTAssertGreaterThanOrEqual(game.records!["eye"]!.bestVitality, first.bestVitality)
        let once = game
        game.perform(.strike, catalog: catalog)
        XCTAssertEqual(game, once)
        game.returnToNotebook()
        XCTAssertEqual(game.ink, snapshot.ink)
        XCTAssertEqual(game.day, snapshot.day)
        XCTAssertEqual(game.unlocked, snapshot.unlocked)
        XCTAssertEqual(game.selected, snapshot.selected)
        let best = game.records!["eye"]!
        game.beginReplay(story)
        for action in [BattleAction.observe, .guard, .strike, .strike] { game.perform(action, catalog: catalog) }
        XCTAssertEqual(game.phase, .victory)
        XCTAssertFalse(game.proofAchieved)
        XCTAssertTrue(game.records!["eye"]!.mastered)
        XCTAssertEqual(game.records!["eye"]!.bestTurns, best.bestTurns)
        XCTAssertEqual(game.records!["eye"]!.bestVitality, best.bestVitality)
    }

    func testProofIsNotGrantedForWrongTimingOrUnusedPreparation() throws {
        let c = try Catalog.load()
        var armor = try start("dragon", catalog: c)
        armor.perform(.breakSeal, catalog: c)
        XCTAssertFalse(armor.proofAchieved)
        XCTAssertNil(armor.battle?.proof?.last)
        var eye = try start("eye", catalog: c)
        eye.perform(.observe, catalog: c) // Approach, not a lunge.
        XCTAssertFalse(eye.proofAchieved)
        var word = try start("word", catalog: c)
        word.perform(.guard, catalog: c)
        XCTAssertFalse(word.battle?.proof?.feats.contains(.protectedVerse) ?? false)
        word.perform(.chant, catalog: c); word.perform(.release, catalog: c)
        XCTAssertFalse(word.battle?.proof?.feats.contains(.invocation) ?? false)
        XCTAssertFalse(word.proofAchieved)
    }

    func testDefeatDoesNotBankProofAndRetryResetsAllCombatResources() throws {
        let c = try Catalog.load()
        var g = try start("eye", catalog: c)
        let selection = g.trial!.previousSelection
        g.perform(.focus, catalog: c); g.perform(.observe, catalog: c)
        XCTAssertTrue(g.proofAchieved)
        for _ in 0..<30 where g.phase == .battle { g.perform(.focus, catalog: c) }
        XCTAssertEqual(g.phase, .defeat)
        XCTAssertNil(g.records?["eye"])
        XCTAssertFalse(g.unlocked.contains("eye2"))
        let ink = g.ink
        g.retryTrial()
        XCTAssertEqual(g.phase, .battle)
        XCTAssertEqual(g.trial?.previousSelection, selection)
        XCTAssertEqual(g.battle?.turn, 0)
        XCTAssertNil(g.battle?.proof)
        XCTAssertFalse(g.proofAchieved)
        XCTAssertEqual(g.enemyHP, g.enemyMaximum)
        XCTAssertEqual(g.vitality, 72)
        XCTAssertEqual(g.charges, 3)
        XCTAssertFalse(g.focused)
        XCTAssertEqual(g.ink, ink)
        let active = g
        g.retryTrial() // Cannot heal an active battle.
        XCTAssertEqual(g, active)
    }

    func testReplayUsesCurrentAbilitiesAndRestoresOriginalSelection() throws {
        let c = try Catalog.load()
        var g = try start("eye", catalog: c)
        winBattle(&g, catalog: c); g.returnToNotebook()
        let node = try XCTUnwrap(c.nodes.first { $0.id == "arm3" })
        g.toggle(node)
        let selection = g.selected
        let dragon = try XCTUnwrap(c.trials.first { $0.id == "dragon" })
        g.beginReplay(dragon)
        XCTAssertTrue(g.selected.contains("arm3")) // Required episode ability is lent back.
        XCTAssertTrue(g.selected.contains("eye2")) // Cross-route combination is available.
        g.perform(.observe, catalog: c); g.perform(.breakSeal, catalog: c)
        XCTAssertEqual(g.battle?.proof?.last, .seam)
        XCTAssertTrue(g.battle?.proof?.feats.contains(.rupture) == true)
        winBattle(&g, catalog: c)
        XCTAssertEqual(g.phase, .victory)
        g.returnToNotebook()
        XCTAssertEqual(g.selected, selection)
    }

    func testFailedReplayRetriesWithoutGrantingNewRewardsOrLosingHistory() throws {
        let c = try Catalog.load()
        var g = try start("dragon", catalog: c)
        winBattle(&g, catalog: c); g.returnToNotebook()
        let old = g
        g.beginReplay(c.trials[0])
        for _ in 0..<30 where g.phase == .battle { g.perform(.focus, catalog: c) }
        XCTAssertEqual(g.phase, .defeat)
        XCTAssertEqual(g.records, old.records)
        g.retryTrial()
        XCTAssertTrue(g.trial?.isReplay == true)
        winBattle(&g, catalog: c)
        XCTAssertEqual(g.phase, .victory)
        g.returnToNotebook()
        XCTAssertEqual(g.day, old.day)
        XCTAssertEqual(g.ink, old.ink)
        XCTAssertEqual(g.selected, old.selected)
        XCTAssertEqual(g.records?["dragon"]?.victories, 2)
    }

    func testKillingBlowDoesNotClaimToHaveSilencedAnEnemyAction() throws {
        let c = try Catalog.load()
        var g = try start("silence", catalog: c)
        for action in [BattleAction.guard, .focus, .chant, .guard, .chant, .release] {
            g.perform(action, catalog: c)
        }
        XCTAssertEqual(g.phase, .victory)
        XCTAssertFalse(g.proofAchieved)
        XCTAssertFalse(g.battle?.proof?.feats.contains(.silence) ?? false)
        XCTAssertEqual(g.battle?.proof?.last, .invocation)
    }

    func testReplayCannotStartLockedTrialsOrInterruptAnotherScene() throws {
        let c = try Catalog.load()
        var g = Game(); g.completeIntroduction()
        let before = g
        g.beginReplay(c.trials[0]); XCTAssertEqual(g, before)
        g.beginTrial(c.trials[0])
        let scene = g
        g.beginReplay(c.trials[0]); XCTAssertEqual(g, scene)
    }

    func testProofAndReplayPersistAcrossRelaunchAndOldSavesStillLoad() throws {
        let c = try Catalog.load()
        var g = try start("word", catalog: c)
        for action in [BattleAction.guard, .chant, .chant, .release] { g.perform(action, catalog: c) }
        g.returnToNotebook()
        g.beginReplay(try XCTUnwrap(c.trials.first { $0.id == "word" }))
        for action in [BattleAction.guard, .chant, .chant] { g.perform(action, catalog: c) }
        var restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(restored, g)
        restored.perform(.release, catalog: c); g.perform(.release, catalog: c)
        XCTAssertEqual(restored, g)
        XCTAssertEqual(restored.records?["word"]?.victories, 2)

        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(g)) as? [String: Any])
        old.removeValue(forKey: "records")
        var battle = old["battle"] as! [String: Any]; battle.removeValue(forKey: "proof"); old["battle"] = battle
        var trial = old["trial"] as! [String: Any]; trial.removeValue(forKey: "isReplay"); old["trial"] = trial
        let decoded = try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(decoded.records)
        XCTAssertNil(decoded.battle?.proof)
        XCTAssertNil(decoded.trial?.isReplay)
        XCTAssertEqual(decoded.unlocked, g.unlocked)
        XCTAssertEqual(decoded.enemyHP, g.enemyHP)
    }
}
