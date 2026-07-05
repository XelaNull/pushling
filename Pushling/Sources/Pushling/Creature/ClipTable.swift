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
//
// Model bake pass (post sub-part-2): the human picked model ① — the
// "jonasdichelle" realistic calico — as the Beast sprite body. Its baked
// output (bake_all.sh's `out/compare/jonasdichelle/beast/`) replaces the
// placeholder scaffolding frames below: real fps/loop/frame-counts and
// per-frame anchors transcribed verbatim from
// `.../generated/ClipTableGenerated_jonasdichelle.swift` (a data source
// to copy from, not a second table — this file's types/structure are
// unchanged). Model ①'s clip inventory per its own `bake-manifest.json`
// (`clip_resolution`): `idle` (SYNTHESIZED from the rest pose — no
// idle-like action exists in the source .blend), `walk` (real action),
// `run` (real action). NO `jump`/`sit`/`sleep` — the manifest's own
// `todos` list confirms none of those actions exist in this model
// ("missing — not fatal"). `coreStateToClipName` below documents how
// bodyStates that would have wanted a jump/crouch pose fall back.
//
// The committed PNGs in `Resources/sprites/` were hflip'd (`sips --flip
// horizontal`, in place) before this pass landed — model ①'s raw bake
// renders head-LEFT; the engine convention (matching `Direction.right`'s
// unflipped `xScale = 1.0`) is head-RIGHT, the same fix sub-part 2 applied
// to the placeholder frames (see that commit's message). All anchor
// CGPoints below and in `overlayAnchorsByStage` are transcribed AFTER
// that mirror, not from the raw bake — see each anchor block's own doc
// comment for the mirror math.
import CoreGraphics

// MARK: - Clip Anchors (WO-37's eventual export target)

/// Per-frame anchor points the bake pipeline exports (master plan §3 step
/// 2: tail-base for L2's SegmentedTailController, head for L3's eye/
/// mouth/whisker overlays, groundContact for gait/foot-slide fixes).
/// Model ①'s bake pass populates these for real, transcribed verbatim
/// from `ClipTableGenerated_jonasdichelle.swift` (itself generated from
/// each frame's own `anchors/*.json`) — TARGET-PIXEL, TOP-LEFT origin,
/// per that generator's own header comment (`y_spritekit = frameHeight -
/// y` for any consumer that wants SpriteKit-space). Nothing in
/// CreatureNode reads `ClipDefinition.anchors` yet — the render path
/// still only consumes the separate, coarser `overlayAnchors(for:)`
/// approximation below — so these per-frame values are forward-looking
/// data, not (yet) load-bearing.
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

    /// Beast's clips — the ONLY stage with rendered frames today. Model
    /// ①'s bake confirmed native 36x40px (18x20pt @2x, matching
    /// `StageConfiguration.all[.beast].size` exactly — SKSpriteNode's
    /// `.size` already controls display size regardless of texture pixel
    /// dimensions, so native res keeps decoded texture memory tiny
    /// (~1.3KB/frame) well inside the SpriteKit <1MB budget as more
    /// clips/stages accumulate) once `.filteringMode = .nearest`
    /// reconstructs crisp edges. Frame names match exactly what's
    /// committed into `Pushling/Resources/sprites/` (unique flat
    /// filenames — build.sh's resource-copy step has no subdirectory
    /// support), renamed from the bake's own `beast_jonasdichelle_<clip>_
    /// <NN>` stems to the loader's plain `beast_<clip>_<NN>` convention
    /// (SpriteFrameLoader has no model-name concept — one baked model is
    /// live per stage at a time).
    ///
    /// Only clips with ACTUAL rendered frames are listed, matching this
    /// file's original scaffolding-era philosophy. Model ①'s own
    /// `bake-manifest.json` confirms `sit`/`sleep`/`jump` have no source
    /// action at all (synthesized nowhere, not just unrendered) — so
    /// there is no `Jump_Start`/`Sit`/`Sleep` entry here anymore; anything
    /// that would resolve to one instead falls back to `"Idle"` in
    /// `clip(for:stage:)`, per `coreStateToClipName` below.
    private static let beastClips: [String: ClipDefinition] = [
        "Idle": ClipDefinition(
            // Single frame — model ① has no idle-like action; the bake
            // pipeline synthesized this frame from the model's rest pose
            // (`bake-manifest.json`'s `clip_resolution.idle.matched_by ==
            // "SYNTHESIZED (rest pose)"`), not sliced from a real clip.
            //
            // Anchors below are MIRRORED (x' = 36 - x, y unchanged) from
            // the bake's raw export — the raw bake is head-LEFT; the
            // committed PNGs were hflip'd to head-RIGHT (same fix
            // sub-part 2 applied to the placeholder frames — see
            // `overlayAnchorsByStage`'s doc comment below for the mirror
            // derivation and why it's a pure x-negation in point-space).
            frames: ["beast_idle_00"],
            fps: 8, loop: true,
            anchors: [
                0: ClipAnchors(tailBase: CGPoint(x: 16.183, y: 16.202),
                                head: CGPoint(x: 29.013, y: 17.121),
                                groundContact: CGPoint(x: 16.163, y: 25.231)),
            ]
        ),
        "Walk": ClipDefinition(
            // 6 frames — model ①'s own real "Walk" action, frame range
            // [1,28] per bake-manifest.json's clip_resolution.walk.
            // Anchors mirrored to match the hflip'd PNGs (see Idle above).
            frames: ["beast_walk_00", "beast_walk_01", "beast_walk_02",
                     "beast_walk_03", "beast_walk_04", "beast_walk_05"],
            fps: 10, loop: true,
            anchors: [
                0: ClipAnchors(tailBase: CGPoint(x: 13.584, y: 18.156),
                                head: CGPoint(x: 27.687, y: 20.452),
                                groundContact: CGPoint(x: 20.192, y: 29.886)),
                1: ClipAnchors(tailBase: CGPoint(x: 13.621, y: 17.861),
                                head: CGPoint(x: 27.779, y: 20.773),
                                groundContact: CGPoint(x: 27.618, y: 29.662)),
                2: ClipAnchors(tailBase: CGPoint(x: 13.711, y: 17.926),
                                head: CGPoint(x: 27.807, y: 20.889),
                                groundContact: CGPoint(x: 25.062, y: 29.662)),
                3: ClipAnchors(tailBase: CGPoint(x: 14.107, y: 18.089),
                                head: CGPoint(x: 27.74, y: 20.63),
                                groundContact: CGPoint(x: 22.511, y: 29.662)),
                4: ClipAnchors(tailBase: CGPoint(x: 14.405, y: 17.561),
                                head: CGPoint(x: 27.769, y: 20.734),
                                groundContact: CGPoint(x: 27.748, y: 29.696)),
                5: ClipAnchors(tailBase: CGPoint(x: 14.096, y: 17.785),
                                head: CGPoint(x: 27.822, y: 20.958),
                                groundContact: CGPoint(x: 24.581, y: 29.728)),
            ]
        ),
        "Run": ClipDefinition(
            // 4 frames — model ①'s own real "run" action, frame range
            // [1,15] per bake-manifest.json's clip_resolution.run. Not
            // mapped from any bodyState/gait signal today (no run-speed
            // tier exists yet in the locomotion layer) — listed because
            // real frames exist for it, same "only list what has frames"
            // rule as Idle/Walk. Reachable only via a future direct
            // accessor mirroring `walkClip(for:)`, not built here. Anchors
            // mirrored to match the hflip'd PNGs (see Idle above).
            frames: ["beast_run_00", "beast_run_01", "beast_run_02", "beast_run_03"],
            fps: 12, loop: true,
            anchors: [
                0: ClipAnchors(tailBase: CGPoint(x: 14.048, y: 16.312),
                                head: CGPoint(x: 28.737, y: 17.012),
                                groundContact: CGPoint(x: 30.125, y: 27.531)),
                1: ClipAnchors(tailBase: CGPoint(x: 15.026, y: 17.486),
                                head: CGPoint(x: 29.011, y: 17.315),
                                groundContact: CGPoint(x: 27.834, y: 30.048)),
                2: ClipAnchors(tailBase: CGPoint(x: 16.274, y: 15.688),
                                head: CGPoint(x: 29.619, y: 17.361),
                                groundContact: CGPoint(x: 19.114, y: 26.399)),
                3: ClipAnchors(tailBase: CGPoint(x: 16.183, y: 16.202),
                                head: CGPoint(x: 29.013, y: 17.121),
                                groundContact: CGPoint(x: 16.163, y: 25.231)),
            ]
        ),
    ]

    /// Per-stage clip tables. Only Beast is populated — Critter/Sage/Apex
    /// are architecturally eligible (`SpriteBodyMode.isEligible`) but have
    /// no rendered frames yet; that's a DATA gap (each needs its own bake
    /// pass at its own native resolution), not a code gap.
    private static let clipsByStage: [GrowthStage: [String: ClipDefinition]] = [
        .beast: beastClips,
    ]

    /// core bodyState string -> clip name, per the WO-27 plan §2 table.
    /// Deliberately narrow — only what Beast has frames for; everything
    /// else falls back to `"Idle"` in `clip(for:stage:)`, matching
    /// BodyPoseTable's own "unknown state = neutral" rule at the clip
    /// level.
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
    /// through it — see `walkClip(for:)` below, which is how sub-part 2
    /// actually reaches "Walk".
    ///
    /// **Jump/crouch fallback (model ① has neither):** the scaffolding-era
    /// table mapped `"crouch"`/`"jump"` to a dedicated `"Jump_Start"`
    /// wind-up clip. Model ①'s bake has no jump-like action at all
    /// (`bake-manifest.json`'s `clip_resolution.jump.matched_by == null`,
    /// "missing — not fatal") — there is nothing to alias to, so both
    /// core states now map straight to `"Idle"` rather than crashing or
    /// rendering nothing. This is a real, visible regression versus the
    /// scaffolding placeholder (a crouch/jump pose now looks identical to
    /// standing in sprite mode) — flagged for review, not silently
    /// dropped; fixing it needs a real jump/crouch bake pass for model ①
    /// (or an accepted "no jump pose at Beast" ruling), not a code change
    /// here.
    private static let coreStateToClipName: [String: String] = [
        "stand": "Idle",
        "walk": "Walk",
        "walk_rhythm": "Walk",
        "crouch": "Idle",
        "jump": "Idle",
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
/// A single representative approximation per stage, not full per-frame
/// data (that finer-grained data lives in `ClipDefinition.anchors` above,
/// unconsumed today) — matches `CreatureNode.addBodyParts`' own usage,
/// which reads this once per `configureForStage` call, not once per
/// frame.
struct SpriteOverlayAnchors {
    let headOffset: CGPoint
    let tailOffset: CGPoint
}

extension ClipTable {
    /// Beast's values are model ①'s REAL exported anchors (idle clip's
    /// only frame — the representative pick, since idle is Beast's rest
    /// state), converted from the anchor JSON's target-pixel/top-left
    /// space into this struct's pelvis-relative point space, THEN
    /// mirrored to match the hflip'd PNGs actually committed to
    /// `Resources/sprites/` (the raw bake is head-LEFT; sub-part 2's own
    /// precedent for the placeholder frames was to hflip the art to
    /// head-RIGHT, matching `Direction.right`'s unflipped `xScale = 1.0`
    /// — this pass applies the identical fix rather than a runtime facing
    /// override, keeping the convention global).
    ///
    /// Derivation: `pt = (px * pointsPerPixel) - halfWidth` for x (sprite
    /// spans `-halfWidth...+halfWidth` centered at the pelvis origin) and
    /// `pt = halfHeight - (py * pointsPerPixel)` for y (image y grows
    /// downward, SpriteKit y grows up), using Beast's own
    /// `StageConfiguration.size` (18x20pt) against the frame's 36x40px —
    /// `pointsPerPixel = 0.5` either axis. Because an hflip is `px' = 36 -
    /// px` with y untouched, and the x-conversion above is affine through
    /// the frame's midline, mirroring reduces to a pure negation in
    /// point-space (`x_pt' = -x_pt`, y unchanged) — confirmed algebraically
    /// (`-9 + (36-px)*0.5 == -(-9 + px*0.5)`), not just eyeballed. Raw-bake
    /// idle anchors: `head` px (6.987, 17.121) -> pt (-5.51, 1.44) ->
    /// mirrored pt (5.51, 1.44); `tailBase` px (19.817, 16.202) -> pt
    /// (0.91, 1.90) -> mirrored pt (-0.91, 1.90). Verified visually too —
    /// viewing an upscaled `beast_idle_00.png` post-hflip shows the head
    /// mass on the right, tail extending left, matching these signs.
    ///
    /// **Tail/fur tradeoff (accepted, not fixed here):** model ①'s
    /// `bake-manifest.json` reports `tail_separable: false` /
    /// `has_particle_fur: true` — the tail is baked into the body's
    /// particle-fur mesh, not a separable object, so the L2 procedural
    /// tail overlay (`tailBase`) will render alongside/on top of the
    /// baked fur-tail already painted into the sprite texture. A known,
    /// human-accepted tradeoff of this bake, not something `tailOffset`
    /// below can correct.
    private static let overlayAnchorsByStage: [GrowthStage: SpriteOverlayAnchors] = [
        .beast: SpriteOverlayAnchors(
            headOffset: CGPoint(x: 5.51, y: 1.44),
            tailOffset: CGPoint(x: -0.91, y: 1.90)
        ),
    ]

    /// Returns `nil` for any stage without an approximation yet (matches
    /// `clipsByStage`'s Beast-only coverage today).
    static func overlayAnchors(for stage: GrowthStage) -> SpriteOverlayAnchors? {
        overlayAnchorsByStage[stage]
    }
}
