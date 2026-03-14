/**
 * pushling_teach — Teach the creature new tricks.
 *
 * Choreograph multi-track body-part animations that persist in SQLite
 * and play autonomously during idle rotation, in response to triggers,
 * and even in dreams. Compose-Preview-Refine-Commit workflow.
 *
 * Max 30 taught behaviors. Mastery grows through performance count.
 * Strength decays over time if not reinforced or performed.
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

const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];

const MAX_TAUGHT = 30;

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
        `Workflow: compose -> preview -> refine (optional) -> commit.`,
      pendingEvents: [],
    };
  }

  // ─── List: read-only from SQLite ──────────────────────────────

  if (action === "list") {
    return handleList(state, daemon);
  }

  // ─── Reinforce: strengthen an existing behavior ────────────────

  if (action === "reinforce") {
    return handleReinforce(args, state, daemon);
  }

  // ─── All other actions require daemon ─────────────────────────

  if (!daemon.isConnected()) {
    return {
      content:
        "Your creature cannot learn — the Pushling daemon is not running. " +
        "Launch Pushling.app to bring it to life.",
      pendingEvents: [],
    };
  }

  // ─── Compose ──────────────────────────────────────────────────

  if (action === "compose") {
    return handleCompose(args, state, daemon);
  }

  // ─── Preview ──────────────────────────────────────────────────

  if (action === "preview") {
    return handlePreviewOrRefine("preview", args, daemon);
  }

  // ─── Refine ───────────────────────────────────────────────────

  if (action === "refine") {
    return handlePreviewOrRefine("refine", args, daemon);
  }

  // ─── Commit ───────────────────────────────────────────────────

  if (action === "commit") {
    return handleCommit(args, state, daemon);
  }

  // ─── Remove ───────────────────────────────────────────────────

  if (action === "remove") {
    return handleRemove(args, daemon);
  }

  return {
    content: `Unhandled teach action '${action}'.`,
    pendingEvents: [],
  };
}

// ─── List handler ───────────────────────────────────────────────────

async function handleList(
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
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
          mastery_label: masteryLabel(b.mastery_level),
          performance_count: b.performance_count,
          strength: b.strength,
          source: b.source,
          created_at: b.created_at,
          last_performed_at: b.last_performed_at,
        })),
        count: behaviors.length,
        capacity: MAX_TAUGHT,
        slots_remaining: MAX_TAUGHT - behaviors.length,
        pending_events: pendingEvents,
      },
      null,
      2
    ),
    pendingEvents,
  };
}

// ─── Compose handler ────────────────────────────────────────────────

async function handleCompose(
  args: {
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
  // Validate required fields
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
  if (args.duration_s < 0.5 || args.duration_s > 15.0) {
    return {
      content: `duration_s must be between 0.5 and 15.0 seconds. Got: ${args.duration_s}.`,
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
    if (
      !VALID_TRACKS.includes(trackName as (typeof VALID_TRACKS)[number])
    ) {
      return {
        content:
          `Unknown track '${trackName}'. ` +
          `Valid tracks: ${VALID_TRACKS.join(", ")}. ` +
          `Omitted tracks inherit autonomous behavior (breathing never stops).`,
        pendingEvents: [],
      };
    }
  }

  // Validate stage_min
  if (args.stage_min && !STAGE_ORDER.includes(args.stage_min)) {
    return {
      content:
        `Unknown stage '${args.stage_min}'. ` +
        `Valid: ${STAGE_ORDER.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Check capacity
  const existing = state.getTaughtBehaviors();
  if (existing.length >= MAX_TAUGHT) {
    return {
      content:
        `Cannot compose — ${existing.length}/${MAX_TAUGHT} taught behaviors. ` +
        `Remove one first with pushling_teach({action: 'remove', name: '...'}).`,
      pendingEvents: [],
    };
  }

  // Check duplicate name
  const dupe = state.getTaughtBehaviorByName(args.name);
  if (dupe) {
    return {
      content:
        `A behavior named '${args.name}' already exists (created ${dupe.created_at}). ` +
        `Choose a different name, or remove the existing one first.`,
      pendingEvents: [],
    };
  }

  // Send to daemon
  try {
    const params: Record<string, unknown> = {
      name: args.name,
      category: args.category,
      duration_s: args.duration_s,
      stage_min: args.stage_min ?? "critter",
      tracks: args.tracks,
      triggers: args.triggers ?? { idle_weight: 0.3 },
    };

    const response = await daemon.send("teach", "compose", params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? "Compose rejected by daemon.",
        pendingEvents,
      };
    }

    return {
      content: JSON.stringify(
        {
          accepted: true,
          action: "compose",
          name: args.name,
          category: args.category,
          duration_s: args.duration_s,
          tracks_count: Object.keys(args.tracks).length,
          draft_id: response.data?.draft_id ?? null,
          note:
            "Draft created. Use 'preview' to see it play, " +
            "'refine' to adjust, or 'commit' to save permanently.",
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to compose: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Preview / Refine handler ───────────────────────────────────────

async function handlePreviewOrRefine(
  action: "preview" | "refine",
  args: { tracks?: Record<string, unknown> },
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  try {
    const params: Record<string, unknown> = {};
    if (args.tracks) params.tracks = args.tracks;

    const response = await daemon.send("teach", action, params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? `${action} rejected by daemon.`,
        pendingEvents,
      };
    }

    return {
      content: JSON.stringify(
        {
          accepted: true,
          action,
          ...(response.data ?? {}),
          note:
            action === "preview"
              ? "Behavior playing once. Watch the Touch Bar to see it."
              : "Draft refined. Preview again or commit when satisfied.",
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to ${action}: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Commit handler ─────────────────────────────────────────────────

async function handleCommit(
  args: { name?: string },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  // Check capacity before committing
  const existing = state.getTaughtBehaviors();
  if (existing.length >= MAX_TAUGHT) {
    return {
      content:
        `Cannot commit — ${existing.length}/${MAX_TAUGHT} taught behaviors. ` +
        `Remove one first.`,
      pendingEvents: [],
    };
  }

  try {
    const params: Record<string, unknown> = {};
    if (args.name) params.name = args.name;

    const response = await daemon.send("teach", "commit", params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? "Commit rejected by daemon.",
        pendingEvents,
      };
    }

    return {
      content: JSON.stringify(
        {
          accepted: true,
          action: "commit",
          ...(response.data ?? {}),
          note:
            "Behavior saved permanently. The learning ceremony is playing. " +
            "This trick will now appear in your creature's idle rotation " +
            "and respond to its triggers.",
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to commit: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Remove handler ─────────────────────────────────────────────────

async function handleRemove(
  args: { name?: string },
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  if (!args.name) {
    return {
      content: "remove requires a 'name' — the behavior to remove.",
      pendingEvents: [],
    };
  }

  if (!daemon.isConnected()) {
    return {
      content:
        "Your creature cannot unlearn — the Pushling daemon is not running.",
      pendingEvents: [],
    };
  }

  try {
    const response = await daemon.send("teach", "remove", {
      name: args.name,
    });
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? `Remove '${args.name}' rejected by daemon.`,
        pendingEvents,
      };
    }

    return {
      content: JSON.stringify(
        {
          accepted: true,
          action: "remove",
          name: args.name,
          note: `Behavior '${args.name}' has been forgotten.`,
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to remove: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Reinforce handler ──────────────────────────────────────────────

async function handleReinforce(
  args: { name?: string },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  if (!args.name) {
    return {
      content: "reinforce requires a 'name' — the behavior to strengthen (+0.15).",
      pendingEvents: [],
    };
  }

  // Verify behavior exists
  const behavior = state.getTaughtBehaviorByName(args.name);
  if (!behavior) {
    const allBehaviors = state.getTaughtBehaviors();
    const names = allBehaviors.map((b) => b.name);
    return {
      content:
        `No behavior named '${args.name}'. ` +
        (names.length > 0
          ? `Known behaviors: ${names.join(", ")}.`
          : `No behaviors taught yet. Use 'compose' to create one.`),
      pendingEvents: [],
    };
  }

  if (!daemon.isConnected()) {
    return {
      content:
        "Your creature cannot be reinforced — the Pushling daemon is not running.",
      pendingEvents: [],
    };
  }

  try {
    const response = await daemon.send("teach", "reinforce", {
      name: args.name,
    });
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? `Reinforce '${args.name}' rejected by daemon.`,
        pendingEvents,
      };
    }

    const newStrength = Math.min(1.0, behavior.strength + 0.15);

    return {
      content: JSON.stringify(
        {
          accepted: true,
          action: "reinforce",
          name: args.name,
          previous_strength: behavior.strength,
          new_strength: Math.round(newStrength * 100) / 100,
          reinforcement_count: behavior.reinforcement_count + 1,
          note: `'${args.name}' reinforced. It will appear more often in idle rotation.`,
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to reinforce: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Helpers ────────────────────────────────────────────────────────

function masteryLabel(level: number): string {
  switch (level) {
    case 0:
      return "learning";
    case 1:
      return "familiar";
    case 2:
      return "practiced";
    case 3:
      return "mastered";
    default:
      return "unknown";
  }
}
