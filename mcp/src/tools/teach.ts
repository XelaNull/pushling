/**
 * pushling_teach — Teach the creature new tricks.
 *
 * Choreograph multi-track body-part animations that persist in SQLite
 * and play autonomously during idle rotation, in response to triggers,
 * and even in dreams. Compose-Preview-Refine-Commit workflow.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";

const VALID_ACTIONS = [
  "compose",
  "preview",
  "refine",
  "commit",
  "list",
  "remove",
  "reinforce",
] as const;

const VALID_CATEGORIES = [
  "playful",
  "affectionate",
  "dramatic",
  "calm",
  "silly",
  "functional",
] as const;

const VALID_TRACKS = [
  "body",
  "head",
  "ears",
  "eyes",
  "tail",
  "mouth",
  "whiskers",
  "paw_fl",
  "paw_fr",
  "paw_bl",
  "paw_br",
  "particles",
  "aura",
  "speech",
  "sound",
  "movement",
] as const;

export const teachSchema = {
  name: "pushling_teach",
  description:
    "Teach the creature new tricks. Choreograph multi-track body-part animations " +
    "using the Compose-Preview-Refine-Commit workflow. Taught behaviors persist " +
    "and play autonomously during idle, in response to triggers, and in dreams. " +
    "Max 30 taught behaviors.",
  inputSchema: {
    type: "object" as const,
    properties: {
      action: {
        type: "string",
        enum: [...VALID_ACTIONS],
        description:
          "Workflow step: 'compose' (define a new trick), 'preview' (play it once), " +
          "'refine' (modify the working draft), 'commit' (save permanently), " +
          "'list' (show all taught behaviors), 'remove' (delete one), " +
          "'reinforce' (strengthen an existing behavior +0.15).",
      },
      name: {
        type: "string",
        description:
          "Name of the behavior. Required for compose, remove, reinforce. " +
          "Used as identifier — must be unique.",
      },
      category: {
        type: "string",
        enum: [...VALID_CATEGORIES],
        description:
          "Category: playful, affectionate, dramatic, calm, silly, functional. " +
          "Required for compose.",
      },
      duration_s: {
        type: "number",
        minimum: 0.5,
        maximum: 15.0,
        description:
          "Total duration of the behavior in seconds. Required for compose.",
      },
      stage_min: {
        type: "string",
        enum: ["spore", "drop", "critter", "beast", "sage", "apex"],
        description:
          "Minimum stage required to perform this behavior. Default: 'critter'.",
      },
      tracks: {
        type: "object",
        description:
          "Multi-track choreography. Keys are track names: body, head, ears, " +
          "eyes, tail, mouth, whiskers, paw_fl/fr/bl/br, particles, aura, " +
          "speech, sound, movement. Values are arrays of keyframes: " +
          "[{t: 0.0, pose/state/action: '...'}]. " +
          "Omitted tracks inherit autonomous behavior (breathing never stops).",
      },
      triggers: {
        type: "object",
        description:
          "When this behavior should play autonomously. Fields: " +
          "idle_weight (0.0-1.0), on_touch (boolean), " +
          "emotional_conditions ({emotion: {min?, max?}}).",
      },
    },
    required: ["action"],
  },
};

export async function handleTeach(
  args: {
    action: string;
    name?: string;
    category?: string;
    duration_s?: number;
    stage_min?: string;
    tracks?: Record<string, unknown>;
    triggers?: Record<string, unknown>;
  },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const { action } = args;

  // Validate action
  if (!VALID_ACTIONS.includes(action as (typeof VALID_ACTIONS)[number])) {
    return {
      content:
        `Unknown teach action '${action}'. ` +
        `Valid: ${VALID_ACTIONS.join(", ")}. ` +
        `Workflow: compose → preview → refine (optional) → commit.`,
      pendingEvents: [],
    };
  }

  // ─── List: read-only from SQLite ──────────────────────────────

  if (action === "list") {
    const behaviors = state.getTaughtBehaviors();
    let pendingEvents: PendingEvent[] = [];

    if (daemon.isConnected()) {
      try {
        pendingEvents = await daemon.ping();
      } catch {
        // Continue without events
      }
    }

    return {
      content: JSON.stringify(
        {
          taught_behaviors: behaviors.map((b) => ({
            name: b.name,
            category: b.category,
            stage_min: b.stage_min,
            duration_s: b.duration_s,
            mastery_level: b.mastery_level,
            performance_count: b.performance_count,
            strength: b.strength,
            source: b.source,
            created_at: b.created_at,
            last_performed_at: b.last_performed_at,
          })),
          count: behaviors.length,
          capacity: 30,
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  }

  // ─── All other actions require daemon ─────────────────────────

  if (!daemon.isConnected()) {
    return {
      content:
        "The Pushling daemon is not running. Your creature's state is readable " +
        "but it cannot learn. Launch Pushling.app to bring it to life.",
      pendingEvents: [],
    };
  }

  // Validate required fields for compose
  if (action === "compose") {
    if (!args.name) {
      return {
        content:
          "compose requires a 'name' for the behavior. " +
          "Choose a descriptive name like 'roll_over', 'victory_dance', 'shy_wave'.",
        pendingEvents: [],
      };
    }
    if (!args.category) {
      return {
        content:
          `compose requires a 'category'. ` +
          `Valid: ${VALID_CATEGORIES.join(", ")}.`,
        pendingEvents: [],
      };
    }
    if (
      !VALID_CATEGORIES.includes(
        args.category as (typeof VALID_CATEGORIES)[number]
      )
    ) {
      return {
        content:
          `Unknown category '${args.category}'. ` +
          `Valid: ${VALID_CATEGORIES.join(", ")}.`,
        pendingEvents: [],
      };
    }
    if (!args.duration_s) {
      return {
        content:
          "compose requires 'duration_s' (total duration in seconds, 0.5-15.0).",
        pendingEvents: [],
      };
    }
    if (!args.tracks || Object.keys(args.tracks).length === 0) {
      return {
        content:
          "compose requires 'tracks' — at least one body-part track with keyframes. " +
          `Valid tracks: ${VALID_TRACKS.join(", ")}. ` +
          `Example: {"body": [{"t": 0.0, "pose": "crouch"}, {"t": 1.0, "pose": "stand"}]}`,
        pendingEvents: [],
      };
    }

    // Validate track names
    for (const trackName of Object.keys(args.tracks)) {
      if (!VALID_TRACKS.includes(trackName as (typeof VALID_TRACKS)[number])) {
        return {
          content:
            `Unknown track '${trackName}'. ` +
            `Valid tracks: ${VALID_TRACKS.join(", ")}. ` +
            `Omitted tracks inherit autonomous behavior (breathing never stops).`,
          pendingEvents: [],
        };
      }
    }
  }

  // Validate name for remove and reinforce
  if ((action === "remove" || action === "reinforce") && !args.name) {
    return {
      content: `${action} requires a 'name' — the behavior to ${action}.`,
      pendingEvents: [],
    };
  }

  try {
    const params: Record<string, unknown> = { ...args };
    delete params.action;

    const response = await daemon.send("teach", action, params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? `Teach ${action} rejected by daemon.`,
        pendingEvents,
      };
    }

    return {
      content: JSON.stringify(
        {
          ok: true,
          action,
          ...(response.data ?? {}),
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to teach: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}
