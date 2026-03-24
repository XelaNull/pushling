/**
 * pushling_sense — Feel yourself, your surroundings, and what's happening.
 *
 * Proprioception, not status polling. Claude asks "how do I feel?" and
 * "what's around me?" through the creature's senses.
 *
 * Each aspect returns embodiment-framed data ("you feel...", "your body is...")
 * rather than raw status numbers.
 */

import type { StateReader, CreatureState, WorldState } from "../state.js";
import type { DaemonClient, PendingEvent } from "../ipc.js";
import {
  computeEmergentState,
  composeMoodSummary,
  computeCircadianPhase,
  agoSeconds,
  safeParseJSON,
} from "./sense-helpers.js";

const VALID_ASPECTS = [
  "self", "body", "surroundings", "visual",
  "events", "developer", "evolve", "version", "full",
] as const;

type Aspect = (typeof VALID_ASPECTS)[number];

const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];
const STAGE_INDEX: Record<string, number> = {};
STAGE_ORDER.forEach((s, i) => { STAGE_INDEX[s] = i; });

export const senseSchema = {
  name: "pushling_sense",
  description:
    "Feel yourself, your surroundings, and what's happening. " +
    "Proprioception — sense your emotional state, body, environment, and recent events. " +
    "Omit aspect for a full reading of everything.",
  inputSchema: {
    type: "object" as const,
    properties: {
      aspect: {
        type: "string",
        enum: [...VALID_ASPECTS],
        description:
          "What to sense. 'self' = emotions, 'body' = physical form, " +
          "'surroundings' = weather/terrain/objects, 'visual' = screenshot, " +
          "'events' = recent happenings, 'developer' = human activity, " +
          "'evolve' = check evolution eligibility, 'full' = everything (default).",
      },
    },
  },
};

export async function handleSense(
  args: { aspect?: string },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const aspect = (args.aspect ?? "full") as string;

  if (!VALID_ASPECTS.includes(aspect as Aspect)) {
    return {
      content: `Unknown aspect '${aspect}'. Valid: ${VALID_ASPECTS.join(", ")} (or omit for full).`,
      pendingEvents: [],
    };
  }

  const creature = state.getCreature();
  const world = state.getWorld();
  let pendingEvents: PendingEvent[] = [];

  if (daemon.isConnected()) {
    try { pendingEvents = await daemon.ping(); } catch { /* continue */ }
  }

  if (!creature) {
    return {
      content: JSON.stringify({
        error: "No creature exists yet. The Pushling daemon has not been launched. " +
          "Launch Pushling.app to begin the hatching ceremony.",
        pending_events: pendingEvents,
      }, null, 2),
      pendingEvents,
    };
  }

  const response: Record<string, unknown> = {};

  if (aspect === "self" || aspect === "full") {
    response.self = buildSelf(creature);
  }
  if (aspect === "body" || aspect === "full") {
    response.body = buildBody(creature, state);
  }
  if (aspect === "surroundings" || aspect === "full") {
    response.surroundings = buildSurroundings(world, creature, state);
  }
  if (aspect === "visual") {
    if (!daemon.isConnected()) {
      return { content: "Cannot capture a visual — the Pushling daemon is not running.", pendingEvents };
    }
    try {
      const r = await daemon.send("sense", "visual");
      pendingEvents = r.pending_events ?? [];
      response.visual = r.data;
    } catch (err) {
      response.visual = { error: `Failed to capture visual: ${err instanceof Error ? err.message : String(err)}` };
    }
  }
  if (aspect === "events" || aspect === "full") {
    response.events = buildEvents(state);
  }
  if (aspect === "developer" || aspect === "full") {
    response.developer = buildDeveloper(creature, state);
  }
  if (aspect === "evolve") {
    const evolve = await buildEvolve(creature, daemon);
    if (evolve._pendingEvents) {
      pendingEvents = evolve._pendingEvents as PendingEvent[];
      delete evolve._pendingEvents;
    }
    response.evolve = evolve;
  }
  if (aspect === "version" || aspect === "full") {
    response.version = {
      app: "0.1.0.1",
      mcp: "0.1.0.1",
      engine: "SpriteKit 60fps",
      platform: "macOS Touch Bar"
    };
  }

  response.pending_events = pendingEvents;
  return { content: JSON.stringify(response, null, 2), pendingEvents };
}

// ─── Aspect builders ──────────────────────────────────────────────────

function buildSelf(creature: CreatureState): Record<string, unknown> {
  const emergent = computeEmergentState(creature);
  return {
    aspect: "self",
    emotional_state: {
      satisfaction: creature.satisfaction,
      curiosity: creature.curiosity,
      contentment: creature.contentment,
      energy: creature.emotional_energy,
    },
    emergent_state: emergent,
    mood_summary: composeMoodSummary(creature, emergent),
    circadian_phase: computeCircadianPhase(),
    last_fed_ago_s: agoSeconds(creature.last_fed_at),
    streak_days: creature.streak_days,
  };
}

function buildBody(creature: CreatureState, state: StateReader): Record<string, unknown> {
  const si = STAGE_INDEX[creature.stage] ?? 0;
  const tricks = state.getTaughtBehaviors();
  const progressPercent = creature.xp_to_next_stage > 0
    ? Math.round((creature.xp / creature.xp_to_next_stage) * 1000) / 10
    : 100;

  return {
    aspect: "body",
    stage: creature.stage,
    stage_index: si,
    name: creature.name,
    appearance: {
      base_color_hue: creature.base_color_hue,
      eye_shape: creature.eye_shape,
      body_proportion: creature.body_proportion,
      tail_shape: creature.tail_shape,
      fur_pattern: creature.fur_pattern,
    },
    personality: {
      energy: creature.energy_axis,
      verbosity: creature.verbosity_axis,
      focus: creature.focus_axis,
      discipline: creature.discipline_axis,
      specialty: creature.specialty,
    },
    growth: {
      total_commits_eaten: creature.commits_eaten,
      xp: creature.xp,
      xp_to_next_stage: creature.xp_to_next_stage,
      progress_percent: progressPercent,
      commits_remaining: Math.max(0, creature.xp_to_next_stage - creature.xp),
    },
    title: creature.title,
    motto: creature.motto,
    tricks_learned: tricks.map((t) => t.name),
    hatched: creature.hatched === 1,
  };
}

function buildSurroundings(
  world: WorldState | null,
  creature: CreatureState,
  state: StateReader
): Record<string, unknown> {
  const now = new Date();
  const creatureX = world?.creature_x ?? 542.5;
  const nearbyObjects = state.getObjectsNear(creatureX, 60);
  const repos = state.getRepos();

  let weatherDurationMin: number | null = null;
  if (world?.weather_changed_at) {
    weatherDurationMin = Math.floor(
      (now.getTime() - new Date(world.weather_changed_at).getTime()) / 60000
    );
  }

  const landmarks = repos
    .map((r) => ({
      repo: r.name, type: r.landmark_type,
      distance_pt: Math.abs(r.world_x_position - creatureX),
      direction: r.world_x_position > creatureX ? "right" as const : "left" as const,
    }))
    .sort((a, b) => a.distance_pt - b.distance_pt);

  return {
    aspect: "surroundings",
    time: {
      wall_clock: `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`,
      sky_period: world?.time_override ?? world?.time_period ?? "day",
    },
    weather: { state: world?.weather ?? "clear", duration_minutes: weatherDurationMin },
    terrain: {
      biome: world?.biome ?? "plains",
      creature_x: creatureX,
      creature_facing: world?.creature_facing ?? "right",
      nearby_objects: nearbyObjects.map((o) => ({
        id: o.id, name: o.name ?? o.base_shape, type: o.base_shape,
        distance_pt: Math.round(Math.abs(o.position_x - creatureX)),
        direction: o.position_x > creatureX ? "right" : "left",
        interaction: o.interaction,
      })),
    },
    landmarks: {
      nearest: landmarks[0] ?? null,
      visible: landmarks.slice(0, 5).map((l) => `${l.repo} (${l.type})`),
    },
    companion: world?.companion_type
      ? { type: world.companion_type, name: world.companion_name }
      : null,
  };
}

function buildEvents(state: StateReader): Record<string, unknown> {
  const journal = state.getJournal(undefined, 20);
  const now = Date.now();
  return {
    aspect: "events",
    recent: journal.map((e) => ({
      type: e.type, summary: e.summary,
      ago_s: Math.floor((now - new Date(e.timestamp).getTime()) / 1000),
      timestamp: e.timestamp,
      data: safeParseJSON(e.data),
    })),
    count: journal.length,
  };
}

function buildDeveloper(creature: CreatureState, state: StateReader): Record<string, unknown> {
  return {
    aspect: "developer",
    activity: {
      last_commit_ago_s: agoSeconds(creature.last_fed_at),
      last_touch_ago_s: agoSeconds(creature.last_touched_at),
      session_active: creature.last_session_at !== null,
      commits_today: state.getCommitsToday(),
      repos_active_today: state.getReposActiveToday(),
    },
    streak_days: creature.streak_days,
    total_touches: creature.touch_count,
  };
}

async function buildEvolve(
  creature: CreatureState,
  daemon: DaemonClient
): Promise<Record<string, unknown>> {
  const si = STAGE_INDEX[creature.stage] ?? 0;

  if (creature.stage === "apex") {
    return { aspect: "evolve", ready: false, current_stage: "apex",
      message: "You have reached Apex — the final form. You are complete." };
  }

  const ready = creature.xp >= creature.xp_to_next_stage;
  const nextStage = STAGE_ORDER[si + 1] ?? "apex";
  const remaining = Math.max(0, creature.xp_to_next_stage - creature.xp);
  const pct = creature.xp_to_next_stage > 0
    ? Math.round((creature.xp / creature.xp_to_next_stage) * 1000) / 10 : 100;

  if (!ready) {
    return { aspect: "evolve", ready: false, current_stage: creature.stage,
      next_stage: nextStage, xp: creature.xp, threshold: creature.xp_to_next_stage,
      progress_percent: pct, commits_remaining: remaining,
      message: `${remaining} more XP until ${nextStage}. Keep feeding me.` };
  }

  if (!daemon.isConnected()) {
    return { aspect: "evolve", ready: true, current_stage: creature.stage,
      next_stage: nextStage,
      note: "Evolution is ready but the daemon is not running. Launch Pushling.app." };
  }

  try {
    const r = await daemon.send("sense", "evolve");
    return { aspect: "evolve", ready: true, evolving_from: creature.stage,
      evolving_to: nextStage, ceremony_started: r.ok,
      message: "The evolution ceremony has begun. Use pushling_sense('body') in 6 seconds to discover your new form.",
      _pendingEvents: r.pending_events ?? [] };
  } catch (err) {
    return { aspect: "evolve", ready: true, current_stage: creature.stage,
      next_stage: nextStage,
      error: `Failed to trigger ceremony: ${err instanceof Error ? err.message : String(err)}` };
  }
}
