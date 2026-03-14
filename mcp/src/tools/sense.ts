/**
 * pushling_sense — Feel yourself, your surroundings, and what's happening.
 *
 * Proprioception, not status polling. Claude asks "how do I feel?" and
 * "what's around me?" through the creature's senses.
 */

import type { StateReader } from "../state.js";
import type { DaemonClient, PendingEvent } from "../ipc.js";

const VALID_ASPECTS = [
  "self",
  "body",
  "surroundings",
  "visual",
  "events",
  "developer",
  "evolve",
  "full",
] as const;

type Aspect = (typeof VALID_ASPECTS)[number];

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

  // Validate aspect
  if (!VALID_ASPECTS.includes(aspect as Aspect)) {
    return {
      content: `Unknown aspect '${aspect}'. Valid: ${VALID_ASPECTS.join(", ")} (or omit for full).`,
      pendingEvents: [],
    };
  }

  // Try to read from SQLite first
  const creature = state.getCreature();
  const world = state.getWorld();
  let pendingEvents: PendingEvent[] = [];

  // If daemon is connected, drain events
  if (daemon.isConnected()) {
    try {
      pendingEvents = await daemon.ping();
    } catch {
      // Daemon went away — continue with SQLite data
    }
  }

  // If no database exists yet, return placeholder
  if (!creature) {
    return {
      content: JSON.stringify(
        {
          error:
            "No creature exists yet. The Pushling daemon has not been launched. " +
            "Launch Pushling.app to begin the hatching ceremony.",
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  }

  // Build response based on aspect
  const response: Record<string, unknown> = {};

  if (aspect === "self" || aspect === "full") {
    response.self = {
      satisfaction: creature.satisfaction,
      curiosity: creature.curiosity,
      contentment: creature.contentment,
      energy: creature.emotional_energy,
    };
  }

  if (aspect === "body" || aspect === "full") {
    response.body = {
      stage: creature.stage,
      name: creature.name,
      commits_eaten: creature.commits_eaten,
      xp: creature.xp,
      xp_to_next_stage: creature.xp_to_next_stage,
      personality: {
        energy: creature.energy_axis,
        verbosity: creature.verbosity_axis,
        focus: creature.focus_axis,
        discipline: creature.discipline_axis,
      },
      specialty: creature.specialty,
      appearance: {
        base_color_hue: creature.base_color_hue,
        body_proportion: creature.body_proportion,
        fur_pattern: creature.fur_pattern,
        tail_shape: creature.tail_shape,
        eye_shape: creature.eye_shape,
      },
      title: creature.title,
      motto: creature.motto,
      hatched: creature.hatched === 1,
    };
  }

  if (aspect === "surroundings" || aspect === "full") {
    response.surroundings = {
      weather: world?.weather ?? "clear",
      biome: world?.biome ?? "plains",
      time: world?.time_period ?? "day",
      time_override: world?.time_override ?? null,
      creature_x: world?.creature_x ?? 542.5,
      creature_facing: world?.creature_facing ?? "right",
      companion: world?.companion_type
        ? {
            type: world.companion_type,
            name: world.companion_name,
          }
        : null,
      objects: state.getWorldObjects(true).map((o) => ({
        id: o.id,
        name: o.name,
        base_shape: o.base_shape,
        position_x: o.position_x,
        layer: o.layer,
        interaction: o.interaction,
        wear: o.wear,
        source: o.source,
      })),
    };
  }

  if (aspect === "visual") {
    // Visual requires daemon — request a screenshot via IPC
    if (!daemon.isConnected()) {
      return {
        content:
          "Cannot capture a visual — the Pushling daemon is not running. " +
          "Launch Pushling.app to see through your creature's eyes.",
        pendingEvents,
      };
    }
    try {
      const ipcResponse = await daemon.send("sense", "visual");
      pendingEvents = ipcResponse.pending_events ?? [];
      response.visual = ipcResponse.data;
    } catch (err) {
      response.visual = {
        error: `Failed to capture visual: ${err instanceof Error ? err.message : String(err)}`,
      };
    }
  }

  if (aspect === "events" || aspect === "full") {
    const journal = state.getJournal(undefined, 10);
    response.events = journal.map((e) => ({
      type: e.type,
      summary: e.summary,
      timestamp: e.timestamp,
      data: e.data ? JSON.parse(e.data) : null,
    }));
  }

  if (aspect === "developer" || aspect === "full") {
    response.developer = {
      last_commit_ago_s: creature.last_fed_at
        ? Math.floor(
            (Date.now() - new Date(creature.last_fed_at).getTime()) / 1000
          )
        : null,
      last_touch_ago_s: creature.last_touched_at
        ? Math.floor(
            (Date.now() - new Date(creature.last_touched_at).getTime()) / 1000
          )
        : null,
      last_session_ago_s: creature.last_session_at
        ? Math.floor(
            (Date.now() - new Date(creature.last_session_at).getTime()) / 1000
          )
        : null,
      streak_days: creature.streak_days,
      touch_count: creature.touch_count,
    };
  }

  if (aspect === "evolve") {
    // Evolution check requires daemon for ceremony trigger
    if (!daemon.isConnected()) {
      response.evolve = {
        stage: creature.stage,
        xp: creature.xp,
        xp_to_next_stage: creature.xp_to_next_stage,
        ready: creature.xp >= creature.xp_to_next_stage,
        note: "Daemon not running — cannot trigger evolution ceremony. Launch Pushling.app.",
      };
    } else {
      try {
        const ipcResponse = await daemon.send("sense", "evolve");
        pendingEvents = ipcResponse.pending_events ?? [];
        response.evolve = ipcResponse.data;
      } catch (err) {
        response.evolve = {
          stage: creature.stage,
          xp: creature.xp,
          xp_to_next_stage: creature.xp_to_next_stage,
          error: `Failed to check evolution: ${err instanceof Error ? err.message : String(err)}`,
        };
      }
    }
  }

  response.pending_events = pendingEvents;

  return {
    content: JSON.stringify(response, null, 2),
    pendingEvents,
  };
}
