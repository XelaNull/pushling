// WorldSurface.swift — Single source of truth for the terrain ground
// baseline and the depth-Z clamp (WO-43, Ph0 "invisible foundation" —
// plans/track-b-grounded-diorama.md at the workspace root).
//
// Before this file, the terrain baseline Y was independently defined (as
// the literal `4.0`) in TerrainGenerator, WorldManager's fallback, and
// both weather renderers — a de-dup hazard, not a live disagreement: they
// all already agreed at 4.0, and that value is exactly what reaches the
// creature's resting Y today via TerrainGenerator.heightAt /
// WorldManager.terrainHeightAtDepth. Similarly the depth-Z clamp
// (`clamp(z, min: 0.0, max: X)`) was inlined independently in 3 places.
// This file gives both ONE home. See WorldSurfaceReconciliationTests for
// the pixel-identity proof that no resolved value changed.
//
// Two constants this file deliberately does NOT absorb (considered and
// rejected — see the WO-43 report): `SceneConstants.groundY` (3.0, a flat
// "sea-level" fallback used by non-terrain-following elements — thrown
// toys, companions, world-object bob baseline, physics jump floor,
// hatch placement) and `LandmarkSystem.baselineY` (6.0, a fixed height on
// the mid-parallax layer's own scroll-scaled coordinate space). Neither
// feeds the creature's resolved ground Y; force-merging them would be a
// genuine behavior change to unrelated visuals, not a de-dup.

import CoreGraphics

/// Owns the terrain heightmap's baseline Y and the depth-Z clamp shared
/// across the Behavior and World subsystems.
enum WorldSurface {

    /// The terrain heightmap's baseline Y — the bottom of the rolling-hills
    /// range that `TerrainGenerator.heightAt` builds on top of. This is the
    /// value that actually reaches the creature's resting Y today (via
    /// `TerrainGenerator.baselineY` → `WorldManager.terrainHeightAtDepth`),
    /// unchanged from before this WO.
    static let groundBaselineY: CGFloat = 4.0

    /// The world's absolute maximum depth-Z (0.0 = foreground, this = the
    /// deepest a fully-grown creature is ever allowed to wander). Shared by
    /// `PhysicsLayer`'s safety clamp and `AutonomousLayer.maxDepthZ`'s Apex
    /// (fully-grown) ceiling — both already used the literal `0.8`.
    static let maxWorldDepthZ: CGFloat = 0.8

    /// Clamps a depth-Z value to `[0.0, upperBound]`. The 3 call sites that
    /// used to inline `clamp(z, min: 0.0, max: X)` now share this single
    /// function. Note they do NOT all share the same `upperBound` today
    /// (`PhysicsLayer`/`AutonomousLayer` cap at `maxWorldDepthZ` or a
    /// smaller stage-gated value; the AI-directed `pushling_move` IPC
    /// handler caps at `1.0`) — that ceiling mismatch is a real, pre-existing
    /// inconsistency, flagged in the WO-43 report rather than silently
    /// changed, since depth-Z is currently pinned to 0.0 downstream
    /// (`PushlingScene.applyBehaviorOutput`'s FIXED-VIEWPORT override) and
    /// picking a ceiling now would be a design decision, not a de-dup.
    static func clampDepthZ(_ z: CGFloat, max upperBound: CGFloat) -> CGFloat {
        clamp(z, min: 0.0, max: upperBound)
    }
}
