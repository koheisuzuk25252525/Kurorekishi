import Foundation
import XCTest
@testable import ChronicleCore

final class TacticalCombatTests: XCTestCase {
    func start(_ id: String, catalog: Catalog) throws -> Game {
        var g = Game(); g.completeIntroduction()
        let story = try XCTUnwrap(catalog.trials.first { $0.id == id })
        g.beginTrial(story); g.confrontTrial(); g.awakenTrial()
        return g
    }
    func testThreeDistinctStrategiesAndDecisionCounts() throws {
        let c = try Catalog.load()
        let strategies: [(String, [BattleAction])] = [
            ("dragon", [.focus, .guard, .breakSeal, .strike, .guard, .strike]),
            ("eye", [.observe, .guard, .strike, .strike]),
            ("word", [.guard, .chant, .chant, .release])
        ]
        for (id, actions) in strategies {
            var g = try start(id, catalog: c)
            for action in actions {
                XCTAssertTrue(g.canPerform(action), "\(id) \(action)")
                g.perform(action, catalog: c)
            }
            XCTAssertEqual(g.phase, .victory, id)
            XCTAssertEqual(g.battle?.turn, actions.count)
            print("TACTICS \(id): turns=\(g.battle!.turn), vitality=\(g.vitality), actions=\(actions.map(\.rawValue).joined(separator: ","))")
        }
    }
    func testRepeatingAttackAndRefillingIsNotAWinningPolicy() throws {
        let c = try Catalog.load()
        for id in ["dragon", "eye", "word"] {
            var g = try start(id, catalog: c)
            for _ in 0..<30 {
                guard g.phase == .battle else { break }
                g.act(g.charges > 0 ? "skill" : "focus", catalog: c)
            }
            XCTAssertEqual(g.phase, .defeat, id)
            XCTAssertFalse(g.defeatAdvice.isEmpty)
        }
    }
    func testDragonNeedsAnOpeningButEyeCreatesAnotherRoute() throws {
        let c = try Catalog.load()
        var g = try start("dragon", catalog: c)
        g.perform(.breakSeal, catalog: c) // shell closed
        XCTAssertEqual(g.battle?.armor, 2)
        XCTAssertEqual(g.battle?.lastDamage, 1)
        g.perform(.guard, catalog: c) // absorb slam
        g.perform(.breakSeal, catalog: c) // recovery
        XCTAssertEqual(g.battle?.armor, 0)
        XCTAssertTrue(g.battle?.broken == true)

        var combined = Game(); combined.completeIntroduction()
        for id in ["eye1", "eye2"] { combined.unlock(c.nodes.first { $0.id == id }!) }
        combined.beginTrial(c.trials.first { $0.id == "dragon" }!)
        combined.confrontTrial(); combined.awakenTrial()
        combined.perform(.observe, catalog: c)
        XCTAssertEqual(combined.intent, .slam)
        combined.perform(.breakSeal, catalog: c) // risky: exploit seam during slam
        XCTAssertEqual(combined.battle?.armor, 0)
        XCTAssertEqual(combined.vitality, 36)
        combined.perform(.strike, catalog: c)
        XCTAssertEqual(combined.phase, .victory)
        XCTAssertEqual(combined.battle?.turn, 3) // faster than safe six-turn route
    }
    func testHiddenEnemyRequiresTargetingAndObservationCanDodge() throws {
        let c = try Catalog.load()
        var g = try start("eye", catalog: c)
        g.perform(.strike, catalog: c)
        XCTAssertEqual(g.enemyHP, g.enemyMaximum)
        XCTAssertEqual(g.battle?.lastDamage, 0)
        XCTAssertEqual(g.intent, .lunge)
        g.perform(.observe, catalog: c)
        XCTAssertEqual(g.battle?.lastReceived, 0)
        XCTAssertEqual(g.battle?.revealed, 3)
        XCTAssertGreaterThan(g.predictedDamage(.strike, catalog: c), 0)
        g.perform(.focus, catalog: c)
        g.perform(.focus, catalog: c)
        g.perform(.guard, catalog: c)
        XCTAssertEqual(g.battle?.revealed, 0)
        XCTAssertEqual(g.intent, .recover)
        g.perform(.focus, catalog: c)
        XCTAssertEqual(g.predictedDamage(.strike, catalog: c), 0)
    }
    func testChantCanBeInterruptedAndGuardPreservesIt() throws {
        let c = try Catalog.load()
        var reckless = try start("word", catalog: c)
        reckless.perform(.chant, catalog: c)
        XCTAssertEqual(reckless.battle?.chanting, 0)
        XCTAssertTrue(reckless.battle?.interrupted == true)
        for _ in 0..<3 { reckless.perform(.chant, catalog: c) }
        XCTAssertEqual(reckless.phase, .defeat)

        var prepared = try start("word", catalog: c)
        prepared.perform(.guard, catalog: c)
        prepared.perform(.chant, catalog: c)
        prepared.perform(.chant, catalog: c)
        XCTAssertEqual(prepared.battle?.chanting, 2)
        XCTAssertFalse(prepared.battle!.ward)
        XCTAssertEqual(prepared.intent, .slam)
        XCTAssertEqual(prepared.predictedDamage(.release, catalog: c), 180)
        prepared.perform(.release, catalog: c)
        XCTAssertEqual(prepared.phase, .victory)
    }
    func testNewAbilityButtonAloneIsNotAnAutomaticWin() throws {
        let c = try Catalog.load()
        for (id, action) in [("dragon", BattleAction.breakSeal), ("eye", .observe), ("word", .chant)] {
            var g = try start(id, catalog: c)
            for _ in 0..<20 { g.perform(action, catalog: c) }
            XCTAssertNotEqual(g.phase, .victory, id)
            XCTAssertFalse(Set(g.trial!.story.rewards).isSubset(of: g.unlocked))
        }
    }
    func testChantHasASecondSlowerWinningReleaseWindow() throws {
        let c = try Catalog.load()
        var g = try start("word", catalog: c)
        // Release one phrase before the interruption instead of protecting two.
        for action in [BattleAction.guard, .chant, .release, .guard, .chant, .release] {
            g.perform(action, catalog: c)
        }
        XCTAssertEqual(g.phase, .victory)
        XCTAssertEqual(g.battle?.turn, 6)
        XCTAssertEqual(g.vitality, 41)
    }

    func testInvalidActionsDoNotConsumeTurnsAndArtSwitchIsFree() throws {
        let c = try Catalog.load()
        var g = try start("dragon", catalog: c)
        let before = g
        for action in [BattleAction.observe, .chant, .release] {
            g.perform(action, catalog: c)
            XCTAssertEqual(g, before)
        }
        g.chooseArt(.eye)
        XCTAssertEqual(g, before)
        for _ in 0..<3 { g.perform(.strike, catalog: c) }
        let exhausted = g
        g.perform(.strike, catalog: c)
        XCTAssertEqual(g, exhausted)
        g.perform(.focus, catalog: c)
        XCTAssertEqual(g.charges, 1)
    }
    func testRepresentativeFailureDoesNotGrantAbilityAndRetryRestoresSelection() throws {
        let c = try Catalog.load()
        for id in ["dragon", "eye", "word"] {
            var g = try start(id, catalog: c)
            let oldSelection = g.trial!.previousSelection
            let rewards = g.trial!.story.rewards
            for _ in 0..<30 {
                if g.phase != .battle { break }
                g.perform(g.charges > 0 ? .strike : .focus, catalog: c)
            }
            XCTAssertEqual(g.phase, .defeat)
            XCTAssertFalse(Set(rewards).isSubset(of: g.unlocked))
            g.returnToNotebook()
            XCTAssertEqual(g.selected, oldSelection)
            XCTAssertNil(g.battle)
            XCTAssertNil(g.trial)
            XCTAssertTrue(g.canBegin(c.trials.first { $0.id == id }!))
        }
    }
    func testTacticalSaveRoundTripContinuesExactlyIncludingWardAndIntent() throws {
        let c = try Catalog.load()
        var g = try start("word", catalog: c)
        g.perform(.guard, catalog: c); g.perform(.chant, catalog: c)
        var restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(restored, g)
        for action in [BattleAction.chant, .release] {
            g.perform(action, catalog: c); restored.perform(action, catalog: c)
            XCTAssertEqual(restored, g)
        }
        XCTAssertEqual(restored.trial?.stage, .reward)
        let once = restored
        restored.perform(.release, catalog: c)
        XCTAssertEqual(restored, once)
    }
    func testRealMainSaveMigratesWithoutChangingExistingProgress() throws {
        let c = try Catalog.load()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "legacy-trial-combat", withExtension: "json"))
        var old = try JSONDecoder().decode(Game.self, from: Data(contentsOf: url))
        XCTAssertNil(old.battle)
        XCTAssertNil(old.trial?.story.encounter)
        XCTAssertEqual(old.enemyHP, 66)
        XCTAssertEqual(old.vitality, 54)
        XCTAssertEqual(old.charges, 2)
        let selection = old.selected
        var direct = old
        direct.act("skill", catalog: c)
        XCTAssertEqual(direct.phase, .victory)
        old.resumeBattle()
        XCTAssertEqual(old.enemyStyle, .open) // Don't inject new defenses into an existing fight.
        XCTAssertEqual(old.enemyHP, 66)
        XCTAssertEqual(old.vitality, 54)
        XCTAssertEqual(old.charges, 2)
        XCTAssertEqual(old.selected, selection)
        winBattle(&old, catalog: c)
        XCTAssertEqual(old.phase, .victory)
        XCTAssertTrue(old.unlocked.contains("arm3"))
    }
}
