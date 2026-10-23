import XCTest
@testable import ChronicleCore

final class ChronicleTests: XCTestCase {
    func testAllStoryTrialsReachTheirRewardAndCannotRepeat() throws {
        let catalog = try Catalog.load()
        var game = Game()
        game.completeIntroduction()
        for story in catalog.trials {
            XCTAssertTrue(game.canBegin(story), story.id)
            game.beginTrial(story)
            XCTAssertEqual(game.trial?.stage, .approach)
            game.awakenTrial() // No skipping the crisis.
            XCTAssertEqual(game.phase, .notebook)
            game.confrontTrial()
            game.awakenTrial()
            XCTAssertEqual(game.phase, .battle)
            XCTAssertFalse(Set(story.rewards).isSubset(of: game.unlocked))
            winBattle(&game, catalog: catalog)
            XCTAssertEqual(game.phase, .victory, story.id)
            XCTAssertEqual(game.trial?.stage, .reward)
            XCTAssertTrue(Set(story.rewards).isSubset(of: game.unlocked))
            let won = game
            game.act("skill", catalog: catalog)
            XCTAssertEqual(game, won)
            game.returnToNotebook()
            XCTAssertFalse(game.canBegin(story))
        }
        XCTAssertEqual(game.unlocked.count, catalog.nodes.count)
    }

    func testEachBranchIsPlayableWithoutOtherBranches() throws {
        let catalog = try Catalog.load()
        for route in ["右腕", "魔眼", "詠唱"] {
            var game = Game()
            game.completeIntroduction()
            let branch = catalog.trials.filter { story in
                catalog.nodes.first { $0.id == story.rewards.last }?.route == route
            }
            for story in branch {
                XCTAssertTrue(game.canBegin(story))
                game.beginTrial(story)
                game.confrontTrial()
                game.awakenTrial()
                winBattle(&game, catalog: catalog)
                XCTAssertEqual(game.phase, .victory, story.id)
                game.returnToNotebook()
            }
        }
    }

    func testDefeatDoesNotGrantTrialPowerAndAllowsRetry() throws {
        let catalog = try Catalog.load()
        var game = Game()
        game.completeIntroduction()
        let previous = game.selected
        let story = catalog.trials[0]
        game.beginTrial(story)
        game.confrontTrial()
        game.awakenTrial()
        for _ in 0..<8 { game.act("focus", catalog: catalog) }
        XCTAssertEqual(game.phase, .defeat)
        XCTAssertFalse(game.unlocked.contains("arm3"))
        game.returnToNotebook()
        XCTAssertEqual(game.selected, previous)
        XCTAssertNil(game.trial)
        XCTAssertTrue(game.canBegin(story))
    }

    func testTrialSaveResumesAndOldSaveWithoutTrialStillDecodes() throws {
        let catalog = try Catalog.load()
        var game = Game()
        game.completeIntroduction()
        XCTAssertFalse(game.canBegin(catalog.trials.first { $0.id == "lastarm" }!))
        game.beginTrial(catalog.trials[0])
        game.confrontTrial()
        let data = try JSONEncoder().encode(game)
        var restored = try JSONDecoder().decode(Game.self, from: data)
        XCTAssertEqual(restored, game)
        restored.awakenTrial()
        XCTAssertEqual(restored.phase, .battle)
        let combatSave = try JSONEncoder().encode(restored)
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: combatSave), restored)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Game())) as? [String: Any])
        old.removeValue(forKey: "trial")
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: old)), Game())
    }

    func testIntroductionRewardsAllowEitherFirstEvolution() throws {
        let catalog = try Catalog.load()
        var game = Game()
        game.completeIntroduction()
        XCTAssertEqual(game.selected, ["arm1", "arm2"])
        XCTAssertEqual(game.damage(catalog), 48)
        let dragon = try XCTUnwrap(catalog.nodes.first { $0.id == "arm3" })
        XCTAssertTrue(game.canUnlock(dragon))
        var eyeGame = game
        for id in ["eye1", "eye2"] {
            eyeGame.unlock(try XCTUnwrap(catalog.nodes.first { $0.id == id }))
        }
        XCTAssertTrue(eyeGame.selected.contains("eye2"))
        XCTAssertEqual(eyeGame.activeResonances(catalog).map(\.id), ["sealeye"])
        let snapshot = eyeGame
        eyeGame.completeIntroduction()
        XCTAssertEqual(eyeGame, snapshot)
    }

    func testIntroductionPreservesExistingProgress() throws {
        var game = Game()
        game.unlock(try Catalog.load().nodes[0])
        let previous = game
        game.completeIntroduction()
        XCTAssertEqual(game, previous)
    }

    func testPrerequisitesAndBudget() throws {
        let catalog = try Catalog.load()
        var game = Game()
        let root = try XCTUnwrap(catalog.nodes.first { $0.id == "arm1" })
        let next = try XCTUnwrap(catalog.nodes.first { $0.id == "arm2" })
        game.unlock(next)
        XCTAssertTrue(game.unlocked.isEmpty)
        game.unlock(root)
        game.unlock(root)
        XCTAssertEqual(game.ink, 2)
        XCTAssertFalse(game.canUnlock(next))
    }

    func testCrossRouteResonanceUsesSelectedSettings() throws {
        let catalog = try Catalog.load()
        var game = Game()
        for id in ["arm1", "eye1", "chant1"] {
            game.unlock(try XCTUnwrap(catalog.nodes.first { $0.id == id }))
        }
        game.manifest()
        for _ in 0..<3 { game.act("skill", catalog: catalog) }
        XCTAssertEqual(game.phase, .victory)
        XCTAssertEqual(game.ink, 4)
        game.returnToNotebook()
        let eye = try XCTUnwrap(catalog.nodes.first { $0.id == "eye2" })
        game.unlock(eye)
        XCTAssertEqual(game.activeResonances(catalog).map(\.id), ["sealeye"])
        XCTAssertEqual(game.multiplier(catalog), 3.25, accuracy: 0.001)
        game.toggle(eye)
        XCTAssertTrue(game.activeResonances(catalog).isEmpty)
        XCTAssertEqual(game.multiplier(catalog), 1.75, accuracy: 0.001)
    }

    func testCombatAndRewardAreBoundToPhase() throws {
        let catalog = try Catalog.load()
        var game = Game()
        game.manifest()
        XCTAssertEqual(game.phase, .notebook)
        game.unlock(catalog.nodes[0])
        game.manifest()
        let hp = game.vitality
        game.act("escape", catalog: catalog)
        XCTAssertEqual(game.vitality, hp)
        game.act("focus", catalog: catalog)
        XCTAssertEqual(game.damage(catalog), 45)
        game.act("skill", catalog: catalog)
        XCTAssertFalse(game.focused)
        game.act("skill", catalog: catalog)
        XCTAssertEqual(game.phase, .victory)
        let earned = game.ink
        game.act("skill", catalog: catalog)
        XCTAssertEqual(game.ink, earned)
        let restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(restored, game)
    }
}


/// A readable decision policy, NOT a bypass: all actions run through the public rules.
/// Regression scenarios still require every trial to finish, persist and grant its reward.
func winBattle(_ game: inout Game, catalog: Catalog) {
    for _ in 0..<40 {
        guard game.phase == .battle else { return }
        let state = game.battle
        let action: BattleAction
        switch game.enemyStyle {
        case .armored:
            if game.intent == .slam { action = .guard }
            else if (state?.armor ?? 0) > 0 {
                action = game.intent == .recover && game.charges > 0 ? .breakSeal : .focus
            } else { action = game.charges > 0 ? .strike : .focus }
        case .hidden:
            if (state?.revealed ?? 0) == 0 { action = .observe }
            else if game.intent == .lunge { action = .guard }
            else { action = game.charges > 0 ? .strike : .focus }
        case .silencer:
            if (state?.chanting ?? 0) >= 2 && game.charges > 0 { action = .release }
            else if game.intent == .interrupt && state?.ward != true { action = .guard }
            else { action = .chant }
        case .open: action = game.charges > 0 ? .strike : .focus
        }
        game.perform(action, catalog: catalog)
    }
}
