// ClipTable.swift — WO-27 sub-part 1: the bodyState -> clip lookup.
// Mirrors BodyPoseTable.swift's structure and "unknown = fall back to
// neutral" philosophy, per the Orchestrator-signed WO-27 plan §2: reuse
// BodyPoseTable's 111->22-core alias collapse UNCHANGED (no second alias
// mechanism), then map the resulting core string -> a clip name -> a
// ClipDefinition. BodyPoseTable itself is not modified by this file.
//
// Sub-part 1 scope: this table + its resolver exist and are unit-tested,
// but nothing in CreatureNode's render path calls `clip(for:stage:)` yet
// — that wiring is sub-part 2. Zero visible render change.

import CoreGraphics

// MARK: - Clip Anchors (WO-37's eventual export target)

/// Per-frame anchor points the REAL bake pipeline will export (master
/// plan §3 step 2: tail-base for L2's SegmentedTailController, head for
/// L3's eye/mouth/whisker overlays, groundContact for gait/foot-slide
/// fixes). Every field optional and the whole struct is nil-able at the
/// clip level (`ClipDefinition.anchors`) because NO anchor data exists
/// anywhere yet — confirmed by reading scratch/cat-demo/render_all.py in
/// full: it renders PNGs only, zero JSON/bone-position export. This
/// struct exists now so sub-part 2+ has a defined target shape to fill
/// in later, not because any producer populates it today.
struct ClipAnchors {
    var tailBase: CGPoint?
    var head: CGPoint?
    var groundContact: CGPoint?
}

// MARK: - Clip Definition

/// One playable clip: an ordered sequence of frame-resource names (matching
/// SpriteFrameLoader's cache keys, NOT file extensions or paths), a
/// playback rate, whether it loops, and per-frame anchors (index -> anchor,
/// sparse — absent indices simply have no anchor data yet).
struct ClipDefinition {
    let frames: [String]
    let fps: Double
    let loop: Bool
    let anchors: [Int: ClipAnchors]?
}

// MARK: - Clip Table

enum ClipTable {

    /// Beast's scaffolding clips — the ONLY stage with rendered frames
    /// today. Stored at Beast's NATIVE 36x40px (18x20pt @2x — confirmed by
    /// the demo's own `demo-report.json` px_sizes note), not the demo
    /// scaffolding's own 8x-upscaled 288x320 touchbar_*.png convention:
    /// SKSpriteNode's `.size` already controls display size regardless of
    /// texture pixel dimensions, so storing at 288x320 would only cost
    /// 64x the decoded texture memory (~360KB/frame vs ~5.6KB/frame) for
    /// an identical on-screen result once `.filteringMode = .nearest`
    /// reconstructs the crisp edges either way — WO-27 sub-part 2 (this
    /// pass) regenerated all 8 frames at native res once this was caught,
    /// to respect the SpriteKit <1MB texture-memory budget as more clips/
    /// stages accumulate. Frame names match exactly what's committed into
    /// `Pushling/Resources/sprites/` (unique flat filenames — build.sh's
    /// resource-copy step has no subdirectory support).
    ///
    /// Only clips with ACTUAL rendered frames are listed. The source
    /// model (`scratch/cat-demo/clips.txt`) also has `Jump_Loop`, `Run`,
    /// `Headbutt`, `Death`, `Idle_Eating` — none of those were ever
    /// rendered to PNG (confirmed against `demo-report.json`'s `renders`
    /// list), so they have no entry here; anything that would resolve to
    /// them instead falls back to `"Idle"` in `clip(for:stage:)`.
    private static let beastClips: [String: ClipDefinition] = [
        "Idle": ClipDefinition(
            frames: ["beast_idle_00"],
            fps: 8, loop: true, anchors: nil
        ),
        "Walk": ClipDefinition(
            // 6 frames, sliced from the model's own Walk clip (frames
            // 0,2,4,6,8,10 of its 24-frame stride) — same selection
            // postprocess.sh's walk_strip_touchbar.png already used;
            // regenerated as individual native-resolution PNGs directly
            // from the fullsize renders here rather than sliced from that
            // pre-assembled (and 8x-upscaled) strip.
            frames: ["beast_walk_00", "beast_walk_01", "beast_walk_02",
                     "beast_walk_03", "beast_walk_04", "beast_walk_05"],
            fps: 10, loop: true, anchors: nil
        ),
        "Jump_Start": ClipDefinition(
            // Single frame (the model's own frame 6, "deepest crouch
            // before takeoff") — a static wind-up pose, not a sustained
            // loop; also doubles as the "crouch" bodyState stand-in below
            // (nearest-visual-match aliasing, same philosophy as
            // BodyPoseTable's own §2b).
            frames: ["beast_jumpstart_00"],
            fps: 8, loop: false, anchors: nil
        ),
    ]

    /// Per-stage clip tables. Only Beast is populated — Critter/Sage/Apex
    /// are architecturally eligible (`SpriteBodyMode.isEligible`) but have
    /// no rendered frames yet; that's a DATA gap (each needs its own
    /// 36x40-equivalent-for-its-own-size renders), not a code gap.
    private static let clipsByStage: [GrowthStage: [String: ClipDefinition]] = [
        .beast: beastClips,
    ]

    /// core bodyState string -> clip name, per the WO-27 plan §2 table.
    /// Deliberately narrow — only what the scaffolding has frames for;
    /// everything else falls back to `"Idle"` in `clip(for:stage:)`,
    /// matching BodyPoseTable's own "unknown state = neutral" rule at the
    /// clip level.
    ///
    /// **Flagged finding, not a bug introduced here:** `BodyPoseTable.
    /// resolve()` already collapses `"walk"`/`"walk_rhythm"` to `"stand"`
    /// (BodyPoseTable.swift:179-180) — correct for the VECTOR path, where
    /// gait is walkSpeed/PawController-driven, not bodyState-driven. Since
    /// `clip(for:stage:)` below calls `resolve()` FIRST (per the signed
    /// plan — no second alias mechanism), this table's `"walk"`/
    /// `"walk_rhythm"` KEYS ARE CURRENTLY UNREACHABLE: `resolve()` will
    /// never hand back either string, only `"stand"`. Kept here anyway
    /// (documentation + forward-compatibility, not dead-code-removed)
    /// because the REAL fix isn't "change the alias table" — master plan
    /// §4 already specifies the actual mechanism: "distance-driven gait
    /// phase (phase = distance/stride) selects walk frames," a signal
    /// that rides ALONGSIDE bodyState (checking `walkSpeed > 0`), not
    /// through it. That's sub-part 2+'s wiring, not this table's job.
    private static let coreStateToClipName: [String: String] = [
        "stand": "Idle",
        "walk": "Walk",
        "walk_rhythm": "Walk",
        "crouch": "Jump_Start",
        "jump": "Jump_Start",
    ]

    /// Resolves a raw bodyState string to a playable clip for the given
    /// stage. Reuses `BodyPoseTable.resolve()` UNCHANGED to collapse the
    /// 111-string vocabulary to one of its 22 core strings first, then
    /// maps core -> clip name -> `ClipDefinition`, falling back to
    /// `"Idle"` at each stage (an unmapped core string, or a mapped clip
    /// name with no frames at this stage yet).
    ///
    /// Returns `nil` only when the stage itself has no scaffolding at all
    /// (Critter/Sage/Apex today) — callers should treat `nil` as "nothing
    /// to play yet," not as an error.
    static func clip(for bodyState: String, stage: GrowthStage) -> ClipDefinition? {
        guard let stageClips = clipsByStage[stage] else { return nil }

        let coreState = BodyPoseTable.resolve(bodyState, stage: stage)
        let clipName = coreStateToClipName[coreState] ?? "Idle"
        return stageClips[clipName] ?? stageClips["Idle"]
    }

    /// WO-27 sub-part 2 — direct "Walk" lookup, deliberately bypassing
    /// `BodyPoseTable.resolve()` entirely. This is the resolution to the
    /// flagged finding above: gait is selected by a `walkSpeed` signal
    /// riding ALONGSIDE bodyState (master plan §4's "distance-driven gait
    /// phase"), not through the bodyState alias table — so this accessor
    /// never touches `coreStateToClipName`'s unreachable `"walk"` row at
    /// all; it goes straight at the stage's own `"Walk"` entry. Returns
    /// `nil` when the stage has no scaffolding OR no `"Walk"` clip yet —
    /// callers (`CreatureNode.updateBreathing()`) must fall back to
    /// `clip(for:stage:)` in that case, matching the "nil = nothing to
    /// play yet" contract `clip(for:stage:)` already uses.
    static func walkClip(for stage: GrowthStage) -> ClipDefinition? {
        clipsByStage[stage]?["Walk"]
    }
}

// MARK: - Sprite Overlay Anchors (WO-27 sub-part 2, §4)

/// Where the L2 (tail) / L3 (eyes/mouth/whiskers, via `headNode`) overlays
/// should sit relative to pelvis-space (0,0) when a sprite body is active.
/// HARDCODED PER-STAGE APPROXIMATIONS, not real per-frame anchor data —
/// WO-37 is the eventual real exporter (see `ClipAnchors` above); the
/// values below were eyeballed directly against the actual committed
/// `beast_idle_00.png` pixels (head silhouette center ~65% across / ~58%
/// up from the bottom of the 18x20pt frame; tail-base center ~25% across
/// / ~52% up), not guessed blind. Expected to look approximate on this
/// placeholder frame (the master plan's own "chimera-face risk on a voxel
/// cat" tolerance) — revisit once WO-37 exports real per-frame anchors.
struct SpriteOverlayAnchors {
    let headOffset: CGPoint
    let tailOffset: CGPoint
}

extension ClipTable {
    private static let overlayAnchorsByStage: [GrowthStage: SpriteOverlayAnchors] = [
        .beast: SpriteOverlayAnchors(
            headOffset: CGPoint(x: 3.0, y: 1.5),
            tailOffset: CGPoint(x: -4.5, y: 0.5)
        ),
    ]

    /// Returns `nil` for any stage without an approximation yet (matches
    /// `clipsByStage`'s Beast-only coverage today).
    static func overlayAnchors(for stage: GrowthStage) -> SpriteOverlayAnchors? {
        overlayAnchorsByStage[stage]
    }
}
