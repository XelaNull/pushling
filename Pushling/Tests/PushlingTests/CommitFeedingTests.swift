// CommitFeedingTests.swift — WO-13 (+ REVISE): commit-ingestion bug fix
// coverage, including the crash-reprocess idempotency regression Mack's
// review required.
//
// Full GameCoordinator instantiation is impractical here (it needs a live
// SpriteKit scene). Most tests below exercise the fix at the level WO-10's
// diagnosis used instead: the exact SQL write statements now issued by
// GameCoordinator+Loading.swift's persistXPAndStage() against a real temp
// SQLite file (schema + migrations, via the same DatabaseManager.open()
// path production uses), and XPCalculator directly. The reprocess test
// below calls the REAL production code directly — GameCoordinator's
// `static func persistCommitAtomically(...db:)` was factored out
// specifically so its exact transaction/idempotency logic is testable
// without a GameCoordinator instance (the instance method is a thin
// wrapper that forwards to it).

import XCTest
@testable import Pushling

final class CommitFeedingTests: XCTestCase {

    private var tempPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempPath = NSTemporaryDirectory()
            + "pushling-test-\(UUID().uuidString).db"
        if DatabaseManager.shared.isOpen {
            DatabaseManager.shared.close()
        }
        try DatabaseManager.shared.open(at: tempPath)
    }

    override func tearDownWithError() throws {
        DatabaseManager.shared.close()
        try? FileManager.default.removeItem(atPath: tempPath)
        try super.tearDownWithError()
    }

    private func sampleCommit(totalLines: Int = 40,
                               message: String = "refactor: extract auth middleware",
                               filesChanged: Int = 4,
                               branch: String? = "main") -> CommitData {
        // 40 lines -> split evenly for a representative added/removed mix.
        CommitData(
            message: message, sha: "a1b2c3d4", repoName: "api-server",
            filesChanged: filesChanged,
            linesAdded: totalLines - totalLines / 2,
            linesRemoved: totalLines / 2,
            languages: ["php", "blade"], isMerge: false, isRevert: false,
            isForcePush: false, tags: [], branch: branch, timestamp: Date()
        )
    }

    // MARK: - Fix 1: commits_eaten increments

    /// Mirrors GameCoordinator+Loading.swift's persistXPAndStage(), which
    /// now carries a commits_eaten term (previously only xp/stage — the
    /// root cause of commits_eaten never incrementing).
    func testCommitsEatenIncrementsViaPersistStatement() throws {
        let db = DatabaseManager.shared

        let before = try db.queryScalarInt(
            "SELECT commits_eaten FROM creature WHERE id = 1")
        XCTAssertEqual(before, 0, "fresh creature row should start at 0")

        // Simulate 3 commits' worth of the persistXPAndStage() write.
        for i in 1...3 {
            try db.execute(
                "UPDATE creature SET xp = ?, stage = ?, commits_eaten = ? "
                + "WHERE id = 1",
                arguments: [i * 5, "critter", i]
            )
        }

        let after = try db.queryScalarInt(
            "SELECT commits_eaten FROM creature WHERE id = 1")
        XCTAssertEqual(after, 3,
            "commits_eaten must increment per commit, not stay pinned at 0")
    }

    // MARK: - Fix 2: commits detail table gets populated

    /// Mirrors the INSERT half of GameCoordinator+Loading.swift's
    /// persistCommitAtomically(), which is new — previously nothing ever
    /// wrote to the `commits` table (grep INSERT INTO commits was zero
    /// hits pre-fix), leaving CreationHandlers.swift's
    /// `SELECT COUNT(*) FROM commits` permanently 0.
    func testCommitsTableInsertPopulatesRow() throws {
        let db = DatabaseManager.shared
        let commit = sampleCommit()
        let xpAwarded = 7
        let commitType = CommitType.normal
        let now = ISO8601DateFormatter().string(from: Date())

        let countBefore = try db.queryScalarInt("SELECT COUNT(*) FROM commits")
        XCTAssertEqual(countBefore, 0)

        try db.execute(
            """
            INSERT OR IGNORE INTO commits (
                sha, message, repo_name, files_changed, lines_added,
                lines_removed, languages, is_merge, is_revert,
                is_force_push, branch, xp_awarded, commit_type, eaten_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                commit.sha, commit.message, commit.repoName,
                commit.filesChanged, commit.linesAdded, commit.linesRemoved,
                commit.languages.joined(separator: ","),
                commit.isMerge, commit.isRevert, commit.isForcePush,
                commit.branch, xpAwarded, commitType.rawValue, now
            ]
        )

        let countAfter = try db.queryScalarInt("SELECT COUNT(*) FROM commits")
        XCTAssertEqual(countAfter, 1,
            "the commits detail table must gain a row per commit")

        // This is the exact query CreationHandlers.swift:68 runs for
        // recall's "relationship" filter (total_commits_eaten) — now live.
        let recallCount = try db.queryScalarInt("SELECT COUNT(*) FROM commits")
        XCTAssertEqual(recallCount, 1)

        let rows = try db.query(
            "SELECT sha, repo_name, xp_awarded, commit_type, eaten_at, branch "
            + "FROM commits WHERE sha = ?", arguments: [commit.sha])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?["sha"] as? String, "a1b2c3d4")
        XCTAssertEqual(rows.first?["repo_name"] as? String, "api-server")
        XCTAssertEqual(rows.first?["xp_awarded"] as? Int, 7)
        XCTAssertEqual(rows.first?["commit_type"] as? String, "normal")
        XCTAssertNotNil(rows.first?["eaten_at"])
        XCTAssertEqual(rows.first?["branch"] as? String, "main")
    }

    /// A nil CommitData.branch (the real-world case today — GameCoordinator
    /// always constructs CommitData with `branch: nil`) must bind as a real
    /// SQL NULL, not the literal text "nil". Passing an Optional through
    /// `as Any` boxes it into a non-nil Any wrapping a nil, which
    /// bindArguments' `switch arg { case nil: ... }` cannot match — it
    /// falls to the default branch and stringifies. persistCommitAtomically
    /// passes `commit.branch` directly (no `as Any`) to avoid this.
    func testCommitsTableStoresNilBranchAsRealSQLNullNotStringNil() throws {
        let db = DatabaseManager.shared
        let commit = sampleCommit(branch: nil)

        try db.execute(
            """
            INSERT OR IGNORE INTO commits (
                sha, message, repo_name, files_changed, lines_added,
                lines_removed, languages, is_merge, is_revert,
                is_force_push, branch, xp_awarded, commit_type, eaten_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                commit.sha, commit.message, commit.repoName,
                commit.filesChanged, commit.linesAdded, commit.linesRemoved,
                commit.languages.joined(separator: ","),
                commit.isMerge, commit.isRevert, commit.isForcePush,
                commit.branch, 1, "normal",
                ISO8601DateFormatter().string(from: Date())
            ]
        )

        let rows = try db.query(
            "SELECT branch FROM commits WHERE sha = ?",
            arguments: [commit.sha])
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.first?["branch"] is NSNull,
            "nil branch must persist as SQL NULL, not the string \"nil\"")
    }

    /// The `commits` recall filter (CreationHandlers.swift) and
    /// `senseDeveloper` (SenseHandlers.swift) both query the real
    /// `eaten_at` column, not the `timestamp` column that both call sites
    /// referenced pre-fix (the commits table has never had a `timestamp`
    /// column — a second, adjacent dead-column bug this WO also fixed
    /// since it directly blocks the table this WO populates).
    func testCommitsTableHasNoTimestampColumnOnlyEatenAt() throws {
        let db = DatabaseManager.shared
        XCTAssertThrowsError(
            try db.query("SELECT timestamp FROM commits")
        )
        XCTAssertNoThrow(
            try db.query("SELECT eaten_at FROM commits")
        )
    }

    // MARK: - Fix 3: XP routed through XPCalculator, not the old bypass

    /// The XP-delta callout the review gate requires: quantifies exactly
    /// how much more (or less) XP a commit awards post-fix vs. the old
    /// inline bypass formula documented as the shipped defect in
    /// docs/SYSTEMS/commit-feeding-xp.md.
    func testXPDeltaOldFormulaVsXPCalculator() {
        // A 40-line, >20-char-message, 4-file commit — the same shape as
        // the worked example in commit-feeding-xp.md and in this file's
        // sampleCommit().
        let commit = sampleCommit(totalLines: 40, filesChanged: 4)
        let rateLimitFactor = 1.0 // first commit in the last 60s

        // --- OLD (buggy, shipped) formula, reproduced verbatim from the
        // pre-fix GameCoordinator.swift wireFeedProcessor() for comparison
        // only — this is what commits actually earned before this fix. ---
        let oldBaseXP = max(1, min(5, commit.totalLines / 20)) + 1
        let oldFinalXP = max(1, Int(Double(oldBaseXP) * rateLimitFactor))

        // --- NEW: canon XPCalculator, no prior commit (no fallow bonus),
        // no commit-day streak (streakDays: 0, see WO-13 report on why). ---
        let newResult = XPCalculator.calculate(
            commit: commit, streakDays: 0, lastCommitTime: nil,
            rateLimitFactor: rateLimitFactor
        )

        // Old formula for 40 lines: min(5, 40/20)=2, +1 = 3, *1.0 = 3
        XCTAssertEqual(oldFinalXP, 3)
        // New formula: base(1) + lines(min(5,40/20)=2) + message(2, >20
        // chars, not lazy) + breadth(1, 4 files >= 3) = 6, *1.0 = 6
        XCTAssertEqual(newResult.xp, 6)

        // The callout: this commit now earns strictly more XP than before,
        // because the old path omitted the message and breadth bonuses
        // entirely — this is canon-compliance (matching the documented
        // formula), not balance drift, but it is a real player-visible
        // increase and must be surfaced, per the WO-13 review gate.
        XCTAssertGreaterThan(newResult.xp, oldFinalXP)
        XCTAssertEqual(newResult.xp - oldFinalXP, 3,
            "a 40-line, long-message, 4-file commit should now award "
            + "3 more XP than the old bypass formula (6 vs 3)")
    }

    /// A minimal commit (short lines, lazy message, 1 file) shows the
    /// *other* direction of the delta: the old bypass's `max(1, min(5,
    /// totalLines/20)) + 1` structure floors at 2 (the "+1" sits outside
    /// the max-with-1 clamp), while XPCalculator's documented floor is 1
    /// (docs/SYSTEMS/commit-feeding-xp.md: "yields a minimum of 2 (vs.
    /// XPCalculator's minimum of 1)"). So for the smallest, laziest
    /// commits, the canon-correct formula now awards LESS XP than the old
    /// bug did — the opposite direction from the richer-commit case above,
    /// and part of the same required delta callout.
    func testXPDeltaMinimalLazyCommitAwardsLessThanOldFloor() {
        let commit = sampleCommit(totalLines: 4, message: "fix", filesChanged: 1)
        let rateLimitFactor = 1.0

        let oldBaseXP = max(1, min(5, commit.totalLines / 20)) + 1
        let oldFinalXP = max(1, Int(Double(oldBaseXP) * rateLimitFactor))

        let newResult = XPCalculator.calculate(
            commit: commit, streakDays: 0, lastCommitTime: nil,
            rateLimitFactor: rateLimitFactor
        )

        // Old: min(5,4/20)=0, max(1,0)=1, +1 = 2, *1.0 = 2
        XCTAssertEqual(oldFinalXP, 2)
        // New: base(1) + lines(0) + message(0, "fix" is lazy/short) +
        // breadth(0, 1 file) = 1, *1.0 = 1
        XCTAssertEqual(newResult.xp, 1)
        XCTAssertLessThan(newResult.xp, oldFinalXP,
            "a trivial lazy-message commit now earns 1 XP, one less than "
            + "the old formula's structural floor of 2")
    }

    /// Demonstrates the fallow multiplier now actually applies (previously
    /// the "reward the return" design principle never reached production —
    /// the inline formula had no lastCommitTime input at all).
    func testXPFallowMultiplierAppliesWhenWired() {
        let commit = sampleCommit(totalLines: 40, filesChanged: 4)

        let noPriorCommit = XPCalculator.calculate(
            commit: commit, streakDays: 0, lastCommitTime: nil,
            rateLimitFactor: 1.0
        )
        let returnAfterADay = XPCalculator.calculate(
            commit: commit, streakDays: 0,
            lastCommitTime: Date().addingTimeInterval(-25 * 3600),
            rateLimitFactor: 1.0
        )

        XCTAssertEqual(noPriorCommit.fallowMultiplier, 1.0)
        XCTAssertEqual(returnAfterADay.fallowMultiplier, 2.0)
        XCTAssertGreaterThan(returnAfterADay.xp, noPriorCommit.xp,
            "a return commit after 24h+ idle must earn more XP now that "
            + "last_fed_at is actually persisted and read back")
    }

    // MARK: - WO-13 REVISE: crash-reprocess idempotency regression

    /// Mack's required regression: this is the exact incident class WO-9
    /// exposed at ~10k-event scale — a crash between the award closure
    /// completing and the feed file moving to processed/ means the feed
    /// processor reprocesses the same commit event on restart. This test
    /// runs the SAME commit through `GameCoordinator.persistCommitAtomically`
    /// (the real production entry point, not a re-derived copy — see the
    /// static/db-parameterized split in GameCoordinator+Loading.swift)
    /// TWICE and asserts the second pass is a true no-op: commits_eaten
    /// and xp each increment EXACTLY ONCE, and the `commits` table ends
    /// with exactly one row for that sha.
    func testReprocessedCommitDoesNotDoubleCountXPOrCommitsEaten() throws {
        let db = DatabaseManager.shared
        let commit = sampleCommit(totalLines: 40, filesChanged: 4)
        let xpAwarded = 6 // matches testXPDeltaOldFormulaVsXPCalculator

        // --- Pass 1: the original, never-before-seen commit event. ---
        // Mirrors GameCoordinator.wireFeedProcessor's caller-side pattern:
        // compute tentative post-award values against the CURRENT
        // (pre-award) in-memory state, then only apply them if the atomic
        // persist confirms this sha is new.
        var totalXP = 0
        var totalCommitsEaten = 0

        let tentativeXP1 = totalXP + xpAwarded
        let tentativeCommitsEaten1 = totalCommitsEaten + 1
        let wasNew1 = GameCoordinator.persistCommitAtomically(
            commit, xpAwarded: xpAwarded, commitType: .normal,
            newXP: tentativeXP1, newCommitsEaten: tentativeCommitsEaten1,
            newStage: "critter", db: db
        )
        XCTAssertTrue(wasNew1, "the first time a sha is seen, it must be "
            + "treated as newly recorded")
        if wasNew1 {
            totalXP = tentativeXP1
            totalCommitsEaten = tentativeCommitsEaten1
        }

        XCTAssertEqual(totalXP, 6)
        XCTAssertEqual(totalCommitsEaten, 1)
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT xp FROM creature WHERE id = 1"), 6)
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT commits_eaten FROM creature WHERE id = 1"), 1)
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT COUNT(*) FROM commits WHERE sha = ?",
            arguments: [commit.sha]), 1)

        // --- Pass 2: the SAME feed file is reprocessed after a simulated
        // crash-then-restart (same CommitData, same sha; a freshly
        // relaunched GameCoordinator would have reloaded totalXP/
        // totalCommitsEaten from the DB values pass 1 just wrote, so the
        // tentative values are computed from that same post-pass-1 state,
        // exactly like a real restart would). ---
        let tentativeXP2 = totalXP + xpAwarded
        let tentativeCommitsEaten2 = totalCommitsEaten + 1
        let wasNew2 = GameCoordinator.persistCommitAtomically(
            commit, xpAwarded: xpAwarded, commitType: .normal,
            newXP: tentativeXP2, newCommitsEaten: tentativeCommitsEaten2,
            newStage: "critter", db: db
        )
        XCTAssertFalse(wasNew2, "a reprocessed duplicate sha must be "
            + "detected and the award skipped")
        if wasNew2 {
            totalXP = tentativeXP2
            totalCommitsEaten = tentativeCommitsEaten2
        }

        // The incident-class assertion: EXACTLY ONCE, not twice.
        XCTAssertEqual(totalXP, 6,
            "xp must not double-count on a reprocessed commit")
        XCTAssertEqual(totalCommitsEaten, 1,
            "commits_eaten must not double-count on a reprocessed commit")
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT xp FROM creature WHERE id = 1"), 6,
            "persisted xp must reflect exactly one award, not two")
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT commits_eaten FROM creature WHERE id = 1"), 1,
            "persisted commits_eaten must reflect exactly one award, not two")
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT COUNT(*) FROM commits WHERE sha = ?",
            arguments: [commit.sha]), 1,
            "the commits table must still have exactly one row for this sha")
        XCTAssertEqual(try db.queryScalarInt("SELECT COUNT(*) FROM commits"),
            1, "no phantom second row anywhere in the table")
    }

    /// Fix 2's atomicity guarantee: last_fed_at is stamped in the SAME
    /// transaction as the award, so it only advances on a genuinely new
    /// commit — a reprocessed duplicate must not re-stamp it (which would
    /// corrupt the next real commit's fallow-bonus read by making an old
    /// commit look freshly eaten).
    func testReprocessedCommitDoesNotRestampLastFedAt() throws {
        let db = DatabaseManager.shared
        let commit = sampleCommit()

        _ = GameCoordinator.persistCommitAtomically(
            commit, xpAwarded: 6, commitType: .normal,
            newXP: 6, newCommitsEaten: 1, newStage: "critter", db: db
        )
        let firstFedAt = try db.queryScalarText(
            "SELECT last_fed_at FROM creature WHERE id = 1")
        XCTAssertNotNil(firstFedAt)

        // Reprocess after a small delay so a re-stamp (if the bug were
        // present) would be detectably different.
        Thread.sleep(forTimeInterval: 1.1)

        let wasNew = GameCoordinator.persistCommitAtomically(
            commit, xpAwarded: 6, commitType: .normal,
            newXP: 12, newCommitsEaten: 2, newStage: "critter", db: db
        )
        XCTAssertFalse(wasNew)

        let secondFedAt = try db.queryScalarText(
            "SELECT last_fed_at FROM creature WHERE id = 1")
        XCTAssertEqual(firstFedAt, secondFedAt,
            "last_fed_at must not advance on a reprocessed duplicate")
    }

    // MARK: - WO-13 REVISE (Mack HIGH fix A): failure-path idempotency

    /// The bug Mack's fix-A review reopened: `wasNewlyRecorded` used to be
    /// set to `true` right after the `INSERT OR IGNORE`'s `changes()`
    /// check — BEFORE the award UPDATE ran. If that UPDATE then threw,
    /// `inTransaction` rolled back both statements, but the function still
    /// returned `true`, so the caller would apply an award for a commit
    /// that was never actually persisted — and since the INSERT itself
    /// rolled back too, the same sha would look "new" again on the very
    /// next attempt, reopening the double-count defect on the error path.
    ///
    /// To inject a real, deterministic failure of the award UPDATE without
    /// mocking `DatabaseManager` (there's no protocol seam for it, and
    /// adding one purely for this one test would be more architecture than
    /// the fix warrants), this test passes a `newStage` value that violates
    /// the real `creature.stage` CHECK constraint
    /// (`CHECK (stage IN ('egg','drop','critter','beast','sage','apex'))`,
    /// `Schema.swift`). That makes `UPDATE creature SET ... stage = ?
    /// ...` throw for real, inside the real transaction, exercising the
    /// exact failure shape (a throw from the award UPDATE after a
    /// successful INSERT) the bug was about — no test double needed.
    func testFailedAwardUpdateRollsBackInsertAndReturnsFalse() throws {
        let db = DatabaseManager.shared
        let commit = sampleCommit()

        let wasNew = GameCoordinator.persistCommitAtomically(
            commit, xpAwarded: 6, commitType: .normal,
            newXP: 6, newCommitsEaten: 1,
            newStage: "not_a_real_stage", // violates the CHECK constraint
            db: db
        )

        XCTAssertFalse(wasNew,
            "a thrown award UPDATE must report failure, not success")

        // The whole transaction (INSERT + UPDATE) must have rolled back —
        // not just the UPDATE. If the INSERT alone had survived, this sha
        // would look "already recorded" on the next real attempt and
        // silently eat that future award too.
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT COUNT(*) FROM commits WHERE sha = ?",
            arguments: [commit.sha]), 0,
            "no partial commits row must survive a rolled-back award")
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT xp FROM creature WHERE id = 1"), 0,
            "xp must remain untouched — the fresh creature row's default")
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT commits_eaten FROM creature WHERE id = 1"), 0,
            "commits_eaten must remain untouched")
        XCTAssertNil(try db.queryScalarText(
            "SELECT last_fed_at FROM creature WHERE id = 1"),
            "last_fed_at must not be stamped by a rolled-back award")

        // A subsequent, correctly-formed retry of the SAME sha must be
        // treated as new (the earlier attempt truly rolled back, it did
        // not "use up" the sha).
        let retryWasNew = GameCoordinator.persistCommitAtomically(
            commit, xpAwarded: 6, commitType: .normal,
            newXP: 6, newCommitsEaten: 1, newStage: "critter", db: db
        )
        XCTAssertTrue(retryWasNew,
            "a retry after a rolled-back failure must not be mistaken "
            + "for a duplicate — the sha was never actually committed")
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT xp FROM creature WHERE id = 1"), 6)
        XCTAssertEqual(try db.queryScalarInt(
            "SELECT commits_eaten FROM creature WHERE id = 1"), 1)
    }

    // NOTE on a concurrent double-fire test: HookEventProcessor serializes
    // all feed-file processing onto its own single `processingQueue`
    // (Feed/HookEventProcessor.swift), and — after REVISE-3's revert of
    // the off-main "fix B" — the entire award sequence (compute tentative
    // -> persistCommitAtomically -> apply in-memory) runs synchronously on
    // main, on the same thread as every other mutator of totalXP/
    // totalCommitsEaten/creatureStage (treat-feeding, debug menu, hatching,
    // evolution). There is no async gap anywhere in this path anymore, so
    // there is no new concurrency shape for a test to exercise beyond
    // SQLite's own `UNIQUE(sha)` guarantee (already covered by the
    // reprocess test above, sequentially). A true concurrency test (firing
    // `persistCommitAtomically` for the SAME sha from N threads
    // simultaneously via `DispatchQueue.concurrentPerform`) is feasible
    // against the static, db-parameterized entry point, but would only be
    // testing SQLite's own constraint enforcement, not anything WO-13
    // added — not worth adding. (A prior revision of this WO briefly moved
    // the write off-main and needed exactly this kind of test to cover the
    // new concurrency shape that introduced; that machinery was reverted
    // per the Orchestrator's REVISE-3 ruling — see WO-40 for the deferred,
    // more careful off-main version.)
}
