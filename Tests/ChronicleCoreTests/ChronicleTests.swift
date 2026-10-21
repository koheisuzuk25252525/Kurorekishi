import XCTest
@testable import ChronicleCore

final class ChronicleTests: XCTestCase {
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
