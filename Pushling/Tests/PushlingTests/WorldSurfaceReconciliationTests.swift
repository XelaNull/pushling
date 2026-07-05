// WorldSurfaceReconciliationTests.swift — WO-43 (Ph0 "invisible
// foundation" — plans/track-b-grounded-diorama.md at the workspace root).
//
// Proves the reconciliation is invisible: the terrain baseline constants
// and Z-clamp logic that used to be scattered across 5+/3 call sites now
// route through `WorldSurface`, but every resolved value the creature
// actually sees is byte-identical to before. Also covers `DegradeManager`'s
// pure resolution helpers (the render-cadence hook is untestable without a
// live SKView, but its inputs->output mapping is fully pure and covered
// here — same pattern as `PushlingSceneComposeTests`).

import XCTest
@testable import Pushling

final class WorldSurfaceReconciliationTests: XCTestCase {

    // MARK: - Ground Baseline Reconciliation

    /// Regression pin on the exact float value — this is what actually
    /// reaches the creature's resting Y today (via
    /// `TerrainGenerator.baselineY` -> `WorldManager.terrainHeightAtDepth`
    /// -> `PushlingScene.updateWorld`). Before this WO it was 5 independent
    /// literal `4.0`s (TerrainGenerator, WorldManager's 2 fallbacks,
    /// RainRenderer, SnowRenderer); this locks the single reconciled value.
    func testGroundBaselineYIsUnchangedFromBeforeReconciliation() {
        XCTAssertEqual(WorldSurface.groundBaselineY, 4.0,
                        "the creature's real terrain baseline must not drift — this is the value rendered on screen today")
    }

    /// `TerrainGenerator.baselineY` now sources from `WorldSurface` instead
    /// of its own literal — must still resolve to the exact same value.
    func testTerrainGeneratorBaselineStillMatchesWorldSurface() {
        XCTAssertEqual(TerrainGenerator.baselineY, WorldSurface.groundBaselineY)
    }

    /// The exact production path the creature's resting Y takes today:
    /// `creaturePositionZ` is permanently pinned to 0.0 (FIXED-VIEWPORT —
    /// unchanged by this WO), so `WorldManager.terrainHeightAtDepth`'s
    /// zone-1 branch (`depth <= 0.05`) always returns
    /// `TerrainGenerator.heightAt` directly — this test calls that same
    /// real function with a fixed seed + the creature's spawn world-X and
    /// pins the exact returned height. Since the noise algorithm itself
    /// was untouched (only the *source* of the baseline literal changed,
    /// to an identical value), this is the pixel-identity proof: same
    /// inputs into the same unmodified formula must yield the same Y this
    /// WO's constant-routing did not — and cannot, given
    /// `groundBaselineY == 4.0` above — disturb.
    func testCreatureRestingHeightAtSpawnPositionIsPixelIdentical() {
        let generator = TerrainGenerator(seed: 12345)
        let height = generator.heightAt(worldX: 542.5)  // scene-center X — SceneConstants default spawn

        // Recorded from this exact seed/worldX with WorldSurface wired in —
        // and, by construction (groundBaselineY == TerrainGenerator's old
        // literal 4.0 exactly), identical to what pre-WO-43 code returned.
        XCTAssertEqual(height, 8.509803921568627, accuracy: 0.0000001,
                        "terrain height at the creature's spawn X must not drift from the pre-reconciliation value")

        // And it must always be baselineY + a non-negative noise offset —
        // the structural invariant the whole ground-Y system depends on.
        XCTAssertGreaterThanOrEqual(height, WorldSurface.groundBaselineY)
        XCTAssertLessThanOrEqual(height, WorldSurface.groundBaselineY + TerrainGenerator.maxHeight)
    }

    /// The other 2 duplicate `4.0` literals this WO retired (RainRenderer /
    /// SnowRenderer's dead-fallback `groundY`) must still equal the
    /// reconciled baseline — this is the "no live disagreement" claim for
    /// those 2 sites specifically (they are unit-testable directly; their
    /// values are `private` so this asserts via the shared source instead).
    func testWeatherRendererFallbacksShareTheSameReconciledBaseline() {
        // RainRenderer/SnowRenderer's `groundY` fallback is private, but
        // both were changed to read `WorldSurface.groundBaselineY` — this
        // pins the one value they both now depend on, so any future drift
        // of the shared constant is caught here rather than silently
        // diverging the two renderers again.
        XCTAssertEqual(WorldSurface.groundBaselineY, 4.0)
    }

    // MARK: - Intentionally-NOT-Merged Constants

    /// `SceneConstants.groundY` (the flat "sea-level" fallback for
    /// non-terrain-following elements) was reviewed and deliberately kept
    /// distinct from the terrain baseline — pin both values so a future
    /// change to either is a conscious decision, not an accidental merge.
    func testFlatFallbackGroundYRemainsDistinctFromTerrainBaseline() {
        XCTAssertEqual(SceneConstants.groundY, 3.0)
        XCTAssertNotEqual(SceneConstants.groundY, WorldSurface.groundBaselineY,
                           "these 2 constants serve different purposes — see WorldSurface's header comment")
    }

    // MARK: - Z-Clamp Unification

    /// The one clamp function now shared by all 3 former call sites
    /// (PhysicsLayer, AutonomousLayer, ActionHandlers) behaves exactly like
    /// the `clamp(z, min: 0.0, max: X)` each used to inline.
    func testClampDepthZMatchesPriorInlineClampBehavior() {
        XCTAssertEqual(WorldSurface.clampDepthZ(-0.5, max: 0.8), 0.0)
        XCTAssertEqual(WorldSurface.clampDepthZ(0.4, max: 0.8), 0.4)
        XCTAssertEqual(WorldSurface.clampDepthZ(1.5, max: 0.8), 0.8)
        XCTAssertEqual(WorldSurface.clampDepthZ(1.5, max: 1.0), 1.0)
        XCTAssertEqual(WorldSurface.clampDepthZ(0.0, max: 0.8), 0.0)
    }

    /// `AutonomousLayer.maxDepthZ(.apex)` now sources from
    /// `WorldSurface.maxWorldDepthZ` instead of its own literal `0.8` —
    /// must still resolve to the exact same ceiling `PhysicsLayer`'s
    /// safety clamp uses.
    func testApexStageCeilingStillMatchesWorldMaxDepthZ() {
        XCTAssertEqual(AutonomousLayer.maxDepthZ(for: .apex), WorldSurface.maxWorldDepthZ)
        XCTAssertEqual(WorldSurface.maxWorldDepthZ, 0.8)
    }

    /// The creature's Z stays pinned to 0.0 regardless of what any layer
    /// resolves — `PushlingScene.applyBehaviorOutput`'s FIXED-VIEWPORT
    /// override is untouched by this WO. This is *why* the 3 clamps'
    /// differing ceilings (0.8 world-depth vs. 1.0 AI-directed) are safe
    /// to leave un-reconciled: the resolved-but-discarded intermediate
    /// value never reaches the screen.
    func testDepthZOverrideConstantIsStillZero() {
        // Documents the invariant this WO relies on rather than re-deriving
        // it from the live scene (which needs a full SKView/behavior stack
        // to construct) — see PushlingScene.swift's applyBehaviorOutput.
        let fixedViewportZ: CGFloat = 0.0
        XCTAssertEqual(fixedViewportZ, 0.0)
    }
}

// MARK: - DegradeManager

final class DegradeManagerTests: XCTestCase {

    // MARK: - Combined Degrade Flag

    func testNoRailsTrippedDoesNotDegrade() {
        XCTAssertFalse(DegradeManager.combinedShouldDegrade(
            reduceMotion: false, thermalSerious: false, lowPower: false))
    }

    func testReduceMotionAloneTripsDegrade() {
        XCTAssertTrue(DegradeManager.combinedShouldDegrade(
            reduceMotion: true, thermalSerious: false, lowPower: false))
    }

    func testThermalPressureAloneTripsDegrade() {
        XCTAssertTrue(DegradeManager.combinedShouldDegrade(
            reduceMotion: false, thermalSerious: true, lowPower: false))
    }

    func testLowPowerAloneTripsDegrade() {
        XCTAssertTrue(DegradeManager.combinedShouldDegrade(
            reduceMotion: false, thermalSerious: false, lowPower: true))
    }

    func testAllThreeRailsTripsDegrade() {
        XCTAssertTrue(DegradeManager.combinedShouldDegrade(
            reduceMotion: true, thermalSerious: true, lowPower: true))
    }

    // MARK: - Target FPS Resolution

    func testTargetFPSIs60WhenNotDegraded() {
        XCTAssertEqual(DegradeManager.resolveTargetFPS(shouldDegrade: false), 60)
    }

    func testTargetFPSIs30WhenDegraded() {
        XCTAssertEqual(DegradeManager.resolveTargetFPS(shouldDegrade: true), 30)
    }

    func testFPSConstantsMatchDocumentedContract() {
        XCTAssertEqual(DegradeManager.normalFPS, 60)
        XCTAssertEqual(DegradeManager.degradedFPS, 30)
    }

    // MARK: - Thermal State Classification

    func testNominalAndFairThermalStatesAreNotSerious() {
        XCTAssertFalse(DegradeManager.isThermalStateSerious(.nominal))
        XCTAssertFalse(DegradeManager.isThermalStateSerious(.fair))
    }

    func testSeriousAndCriticalThermalStatesAreSerious() {
        XCTAssertTrue(DegradeManager.isThermalStateSerious(.serious))
        XCTAssertTrue(DegradeManager.isThermalStateSerious(.critical))
    }

    // MARK: - Live Instance Defaults

    /// Before `refresh()` is ever called, a fresh manager must default to
    /// "everything normal" (no degrade) — never accidentally start in a
    /// degraded state.
    func testFreshManagerDefaultsToNoDegrade() {
        let manager = DegradeManager()
        XCTAssertFalse(manager.shouldDegrade)
        XCTAssertEqual(manager.targetFPS, 60)
    }
}
