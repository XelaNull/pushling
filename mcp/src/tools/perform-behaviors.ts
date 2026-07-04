/**
 * Behavior allowlist + stage-gate helpers for pushling_perform.
 *
 * Extracted from perform.ts to keep it under the 500-line limit.
 *
 * Source of truth is the daemon, not this file — mirror, don't invent:
 *   Pushling/Sources/Pushling/IPC/PerformActionMapping.swift (map() switch:
 *   behavior -> LayerOutput + duration) and CommandRouter.swift's
 *   validActions["perform"] (canonical accepted-name list). A name added
 *   here without a matching Swift-side row/entry gets accepted by the MCP
 *   tool then rejected by the daemon with UNKNOWN_ACTION.
 */

export const VALID_BEHAVIORS: Record<
  string,
  { stage_min: string; variants: string[]; duration_ms: number }
> = {
  wave: {
    stage_min: "drop",
    variants: ["big", "small", "both_paws"],
    duration_ms: 1500,
  },
  spin: {
    stage_min: "drop",
    variants: ["left", "right", "fast"],
    duration_ms: 1200,
  },
  bow: {
    stage_min: "critter",
    variants: ["deep", "quick", "theatrical"],
    duration_ms: 2000,
  },
  dance: {
    stage_min: "critter",
    variants: ["waltz", "jig", "moonwalk"],
    duration_ms: 4000,
  },
  peek: {
    stage_min: "critter",
    variants: ["left", "right", "above"],
    duration_ms: 1500,
  },
  meditate: {
    stage_min: "beast",
    variants: ["brief", "deep", "transcendent"],
    duration_ms: 5000,
  },
  flex: {
    stage_min: "beast",
    variants: ["casual", "dramatic"],
    duration_ms: 2500,
  },
  backflip: {
    stage_min: "beast",
    variants: ["single", "double"],
    duration_ms: 1800,
  },
  dig: {
    stage_min: "critter",
    variants: ["shallow", "deep", "frantic"],
    duration_ms: 3000,
  },
  examine: {
    stage_min: "drop",
    variants: ["sniff", "paw", "stare"],
    duration_ms: 2000,
  },
  nap: {
    stage_min: "spore",
    variants: ["light", "deep", "dream"],
    duration_ms: 8000,
  },
  celebrate: {
    stage_min: "drop",
    variants: ["small", "big", "legendary"],
    duration_ms: 3000,
  },
  shiver: {
    stage_min: "spore",
    variants: ["cold", "nervous", "excited"],
    duration_ms: 1500,
  },
  stretch: {
    stage_min: "critter",
    variants: ["morning", "lazy", "dramatic"],
    duration_ms: 2500,
  },
  play_dead: {
    stage_min: "beast",
    variants: ["dramatic", "convincing"],
    duration_ms: 4000,
  },
  conduct: {
    stage_min: "sage",
    variants: ["gentle", "vigorous", "crescendo"],
    duration_ms: 5000,
  },
  glitch: {
    stage_min: "apex",
    variants: ["minor", "major", "existential"],
    duration_ms: 3000,
  },
  transcend: {
    stage_min: "apex",
    variants: ["brief", "full"],
    duration_ms: 6000,
  },

  // WO-23 — postures the daemon already accepts (CommandRouter's WO-19
  // sub-part 2 REVISE addition) but this allowlist was missing. This
  // schema's stage_min is a monotonic ">=" floor; sphinx/sprawl below are
  // non-monotonic in the daemon (exact-stage / two-of-five gates) and are
  // marked EXCEPTION — the floor is a permissive superset there, and the
  // daemon safely no-ops to `stand` for the extra stages it lets through.
  loaf: {
    // Live gate is CatBehaviors.named("loaf").minimumStage == .critter —
    // CatBehaviors is checked before PerformActionMapping in
    // ActionHandlers.handlePerform, so the mapping's own "loaf" row/6s
    // duration is shadowed; the real hold is a random 30-60s via CatBehaviors.
    stage_min: "critter",
    variants: ["classic", "tight_tuck", "sun_puddle"],
    duration_ms: 6000,
  },
  sphinx: {
    // EXCEPTION: BodyPoseTable.resolve() gates sphinx to == .beast exactly
    // (withheld again at .sage/.apex, unlike a normal floor).
    stage_min: "beast",
    variants: ["alert", "regal", "watchful"],
    duration_ms: 6000,
  },
  sprawl: {
    // EXCEPTION: BodyPoseTable.resolve() gates sprawl to .drop OR .beast
    // (withheld at .critter/.sage/.apex — idle-life-and-rest.md §2.1).
    stage_min: "drop",
    variants: ["belly_up", "full_stretch", "kicked_leg"],
    duration_ms: 6000,
  },
  curl: {
    stage_min: "spore", // no stage guard anywhere in the daemon's path
    variants: ["tight", "loose", "tail_wrap"],
    duration_ms: 6000,
  },
  groom: {
    stage_min: "spore", // no stage guard anywhere in the daemon's path
    variants: ["face", "paw", "full_body"],
    duration_ms: 4000,
  },
  knead: {
    stage_min: "spore", // no stage guard anywhere in the daemon's path
    variants: ["gentle", "rhythmic", "eager"],
    duration_ms: 6000,
  },
};

export const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];

export function stageIdx(stage: string): number {
  return STAGE_ORDER.indexOf(stage);
}

export function behaviorsAvailableAt(stage: string): string[] {
  const si = stageIdx(stage);
  return Object.entries(VALID_BEHAVIORS)
    .filter(([, def]) => stageIdx(def.stage_min) <= si)
    .map(([name]) => name);
}
