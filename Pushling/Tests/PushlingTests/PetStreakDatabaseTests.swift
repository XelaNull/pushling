// PetStreakDatabaseTests.swift — Regression test for WO-35.
//
// PetStreak.saveToDatabase() used to bind `lastInteractionDate as Any`.
// Boxing a nil Optional<String> via `as Any` produces a non-nil Any that
// WRAPS nil, which DatabaseManager.bindArguments' `case nil:` cannot
// match — it falls through to the default branch and binds the literal
// STRING "nil" instead of a real SQL NULL. This mirrors WO-13's fix for
// commit.branch in GameCoordinator+Loading.swift, applied here to
// creature.streak_last_date.
//
// A fresh creature row (as seeded by Migration's v1 seedCreature()) has
// streak_last_date = NULL and streak_days = 0, and a freshly-constructed
// PetStreak loads that as `lastInteractionDate == nil`. Neither
// recordInteraction() nor midnightCheck() ever calls saveToDatabase()
// while still nil (both only save once a date has been set/confirmed),
// so this test drives saveToDatabase() directly — it is `func`, not
// `private func`, specifically so this regression can pin the nil-bind
// path itself.

import XCTest
@testable import Pushling

final class PetStreakDatabaseTests: XCTestCase {

    private var tempDBPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir
            .appendingPathComponent("pushling-test-\(UUID().uuidString).db")
            .path
        try DatabaseManager.shared.open(at: tempDBPath)
    }

    override func tearDownWithError() throws {
        DatabaseManager.shared.close()
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempDBPath = nil
        try super.tearDownWithError()
    }

    /// Pins the fix at PetStreak.swift's saveToDatabase(): a fresh
    /// PetStreak (no prior interaction, `lastInteractionDate == nil`)
    /// must persist `streak_last_date` as a real SQL NULL, never the
    /// literal string "nil" produced by the old `as Any` boxing bug.
    func testFreshStreakSavesNilLastInteractionDateAsRealSQLNullNotStringNil() throws {
        let streak = PetStreak(db: DatabaseManager.shared)
        XCTAssertNil(
            streak.lastInteractionDate,
            "a fresh PetStreak backed by the migration-seeded creature row "
                + "should load streak_last_date as nil"
        )

        // Drive the async write directly — this is the only route to
        // exercise saveToDatabase() while lastInteractionDate is still nil.
        streak.saveToDatabase()

        // The write is dispatched on DatabaseManager's serial write queue.
        // Enqueue a no-op behind it and wait for its completion to make
        // sure the streak save has actually landed before querying back.
        let drained = expectation(description: "write queue drained")
        DatabaseManager.shared.performWriteAsync({ }, completion: { _ in
            drained.fulfill()
        })
        wait(for: [drained], timeout: 2.0)

        let storedType = try DatabaseManager.shared.queryScalarText(
            "SELECT typeof(streak_last_date) FROM creature WHERE id = 1;"
        )
        XCTAssertEqual(
            storedType, "null",
            "streak_last_date must be bound as a real SQL NULL, not a string"
        )

        let storedText = try DatabaseManager.shared.queryScalarText(
            "SELECT streak_last_date FROM creature WHERE id = 1;"
        )
        XCTAssertNil(
            storedText,
            "streak_last_date must read back as nil, never the literal "
                + "string \"nil\""
        )
    }

    /// Sanity check on the same path: a non-nil date still round-trips
    /// correctly through the fixed argument array (no regression on the
    /// happy path while fixing the nil case).
    func testStreakSavesNonNilLastInteractionDateAsText() throws {
        let streak = PetStreak(db: DatabaseManager.shared)
        streak.recordInteraction()

        let drained = expectation(description: "write queue drained")
        DatabaseManager.shared.performWriteAsync({ }, completion: { _ in
            drained.fulfill()
        })
        wait(for: [drained], timeout: 2.0)

        let storedType = try DatabaseManager.shared.queryScalarText(
            "SELECT typeof(streak_last_date) FROM creature WHERE id = 1;"
        )
        XCTAssertEqual(storedType, "text")

        let storedText = try DatabaseManager.shared.queryScalarText(
            "SELECT streak_last_date FROM creature WHERE id = 1;"
        )
        XCTAssertEqual(storedText, PetStreak.todayString())
    }
}
