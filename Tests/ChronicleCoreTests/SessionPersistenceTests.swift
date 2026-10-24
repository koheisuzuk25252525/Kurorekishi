import Foundation
import XCTest
@testable import ChronicleCore

final class SessionPersistenceTests: XCTestCase {
    func testPlaytestStartsFreshAndCannotOverwriteSavedGameOrIntroduction() throws {
        let suite = "chronicle.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let regular = SessionPersistence(defaults: defaults)
        var original = Game(); original.completeIntroduction()
        let catalog = try Catalog.load()
        original.beginTrial(catalog.trials[0]); original.confrontTrial(); original.awakenTrial()
        original.perform(.focus, catalog: catalog)
        regular.save(original); regular.saveIntroduction(true)
        let originalBytes = defaults.data(forKey: "chronicle.prototype.v1")

        let playtest = SessionPersistence(isPlaytest: true, defaults: defaults)
        XCTAssertEqual(playtest.loadGame(), Game())
        XCTAssertFalse(playtest.loadIntroduction())
        var practice = playtest.loadGame()
        practice.completeIntroduction()
        practice.beginTrial(catalog.trials[1]); practice.confrontTrial(); practice.awakenTrial()
        playtest.save(practice); playtest.saveIntroduction(true)
        playtest.save(Game()); playtest.saveIntroduction(false) // Reset inside the demo too.

        XCTAssertEqual(defaults.data(forKey: "chronicle.prototype.v1"), originalBytes)
        XCTAssertEqual(regular.loadGame(), original)
        XCTAssertTrue(regular.loadIntroduction())
        XCTAssertEqual(playtest.loadGame(), Game()) // Each new practice session starts at the awakening.
    }

    func testPlaytestLeavesAnUnusedInstallationUntouched() throws {
        let suite = "chronicle.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let playtest = SessionPersistence(isPlaytest: true, defaults: defaults)
        var game = Game(); game.completeIntroduction()
        playtest.save(game); playtest.saveIntroduction(true)
        XCTAssertNil(defaults.object(forKey: "chronicle.prototype.v1"))
        XCTAssertNil(defaults.object(forKey: "chronicle.introduction.v4"))
    }

    func testNormalSessionReadsExistingKeysAndPersistsNewProgress() throws {
        let suite = "chronicle.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var game = Game(); game.completeIntroduction()
        defaults.set(try JSONEncoder().encode(game), forKey: "chronicle.prototype.v1")
        defaults.set(true, forKey: "chronicle.introduction.v4")
        let store = SessionPersistence(defaults: defaults)
        XCTAssertEqual(store.loadGame(), game)
        XCTAssertTrue(store.loadIntroduction())
        game.beginTrial(try Catalog.load().trials[0])
        store.save(game)
        XCTAssertEqual(store.loadGame(), game)
        store.save(Game()); store.saveIntroduction(false)
        XCTAssertEqual(store.loadGame(), Game())
        XCTAssertFalse(store.loadIntroduction())
    }
}
