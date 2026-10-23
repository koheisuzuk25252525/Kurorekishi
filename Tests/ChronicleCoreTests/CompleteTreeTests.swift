import Foundation
import XCTest
@testable import ChronicleCore

final class CompleteTreeTests: XCTestCase {
    func at(_ id: String, catalog: Catalog) throws -> Game {
        var game = Game(); game.completeIntroduction()
        for story in catalog.trials {
            XCTAssertTrue(game.canBegin(story), story.id)
            game.beginTrial(story); game.confrontTrial(); game.awakenTrial()
            if story.id == id { return game }
            winBattle(&game, catalog: catalog)
            XCTAssertEqual(game.phase, .victory, story.id)
            game.returnToNotebook()
        }
        throw CocoaError(.fileNoSuchFile)
    }
    func testCompleteCatalogHasTenDocumentedAbilitiesAndNinePlayableTrials() throws {
        let c = try Catalog.load()
        XCTAssertEqual(c.abilities.count, 10)
        XCTAssertEqual(Set(c.nodes.map(\.id)).count, c.nodes.count)
        var unlocked: Set<String> = ["arm1", "arm2"]
        for story in c.trials {
            XCTAssertNotNil(story.encounter)
            XCTAssertFalse(story.encounter!.pattern.isEmpty)
            XCTAssertTrue(Set(story.requires).isSubset(of: unlocked))
            unlocked.formUnion(story.rewards)
        }
        XCTAssertEqual(unlocked, Set(c.nodes.map(\.id)))
        for node in c.abilities {
            XCTAssertFalse(try XCTUnwrap(node.reading).isEmpty)
            XCTAssertFalse(try XCTUnwrap(node.effect).isEmpty)
            XCTAssertFalse(try XCTUnwrap(node.verse).isEmpty)
        }
    }
    func testDevourAbsorbsAttackAndAddsStoredPowerToNextSkill() throws {
        let c = try Catalog.load()
        var g = try at("devour", catalog: c)
        g.perform(.focus, catalog: c)
        XCTAssertEqual(g.technique, .devour)
        let vitality = g.vitality
        g.perform(.devour, catalog: c)
        XCTAssertEqual(g.vitality, vitality)
        XCTAssertEqual(g.battle?.ascension?.absorbed, 40)
        XCTAssertEqual(g.battle?.lastReceived, 0)
        XCTAssertEqual(g.technique, .breakSeal)
        let expected = g.predictedDamage(.breakSeal, catalog: c)
        g.perform(.breakSeal, catalog: c)
        XCTAssertGreaterThanOrEqual(expected, 40)
        XCTAssertEqual(g.battle?.lastDamage, expected)
        XCTAssertEqual(g.battle?.armor, 0)
        XCTAssertEqual(g.battle?.ascension?.absorbed, 0)
    }
    func testLastArmConsumesAbsorbedForceAndErasesDefense() throws {
        let c = try Catalog.load()
        var g = try at("lastarm", catalog: c)
        XCTAssertFalse(g.canPerform(.rend))
        g.perform(.focus, catalog: c); g.perform(.devour, catalog: c)
        XCTAssertEqual(g.technique, .rend)
        XCTAssertEqual(g.battle?.ascension?.absorbed, 44)
        let hit = g.predictedDamage(.rend, catalog: c)
        XCTAssertGreaterThan(hit, 132)
        g.perform(.rend, catalog: c)
        XCTAssertEqual(g.battle?.lastDamage, hit)
        XCTAssertEqual(g.battle?.armor, 0)
        XCTAssertEqual(g.battle?.ascension?.absorbed, 0)
        XCTAssertFalse(g.canPerform(.rend))
    }
    func testCausalEyeSeesAndDodgesHeavyStrike() throws {
        let c = try Catalog.load()
        var g = try at("causality", catalog: c)
        XCTAssertEqual(g.nextIntent, .slam)
        g.perform(.focus, catalog: c)
        XCTAssertEqual(g.intent, .slam)
        g.perform(.observe, catalog: c)
        XCTAssertEqual(g.battle?.lastReceived, 0)
        XCTAssertEqual(g.battle?.revealed, 3)
    }
    func testWorldEyeCancelsOneDangerousTurnOnly() throws {
        let c = try Catalog.load()
        var g = try at("worldeye", catalog: c)
        XCTAssertFalse(g.canPerform(.rewrite))
        g.perform(.focus, catalog: c)
        XCTAssertEqual(g.technique, .rewrite)
        g.perform(.rewrite, catalog: c)
        XCTAssertEqual(g.battle?.lastReceived, 0)
        XCTAssertTrue(g.battle?.ascension?.rewriteUsed == true)
        XCTAssertEqual(g.battle?.revealed, 3)
        XCTAssertFalse(g.canPerform(.rewrite))
        let saved = g
        g.perform(.rewrite, catalog: c)
        XCTAssertEqual(g, saved)
    }
    func testEndChantSuppressesTwoEnemyActions() throws {
        let c = try Catalog.load()
        var g = try at("silence", catalog: c)
        for action in [BattleAction.guard, .chant, .chant] { g.perform(action, catalog: c) }
        let vitality = g.vitality
        g.perform(.release, catalog: c)
        XCTAssertEqual(g.phase, .battle)
        XCTAssertEqual(g.vitality, vitality)
        XCTAssertEqual(g.battle?.ascension?.silence, 1)
        XCTAssertEqual(g.intent, .recover)
        g.perform(.chant, catalog: c)
        XCTAssertEqual(g.vitality, vitality)
        XCTAssertEqual(g.battle?.ascension?.silence, 0)
        XCTAssertEqual(g.battle?.chanting, 1)
    }
    func testTrueNameRequiresThreeVersesAndRestoresExistence() throws {
        let c = try Catalog.load()
        var g = try at("truename", catalog: c)
        XCTAssertFalse(g.canPerform(.trueName))
        for action in [BattleAction.guard, .guard, .chant, .guard, .chant, .chant] {
            g.perform(action, catalog: c)
        }
        XCTAssertEqual(g.phase, .battle)
        XCTAssertEqual(g.battle?.chanting, 3)
        XCTAssertEqual(g.finisher, .trueName)
        let vitality = g.vitality
        g.perform(.trueName, catalog: c)
        XCTAssertEqual(g.vitality, min(100, vitality + 24))
        XCTAssertEqual(g.battle?.chanting, 0)
        XCTAssertEqual(g.battle?.armor, 0)
        XCTAssertFalse(g.canPerform(.trueName))
        g.perform(.chant, catalog: c); g.perform(.release, catalog: c)
        XCTAssertEqual(g.phase, .victory)
    }
    func testNewStatePersistsAndPreviousTacticalSavesDecode() throws {
        let c = try Catalog.load()
        var g = try at("lastarm", catalog: c)
        g.perform(.focus, catalog: c); g.perform(.devour, catalog: c)
        var restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(restored, g)
        g.perform(.rend, catalog: c); restored.perform(.rend, catalog: c)
        XCTAssertEqual(restored, g)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(g)) as? [String: Any])
        var battle = try XCTUnwrap(object["battle"] as? [String: Any])
        battle.removeValue(forKey: "ascension")
        object["battle"] = battle
        let old = try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.battle?.ascension)
        XCTAssertEqual(old.enemyHP, g.enemyHP)
        XCTAssertEqual(old.charges, g.charges)
    }
}
