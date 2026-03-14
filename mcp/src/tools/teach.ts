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
import {
  handleCompose,
  handlePreviewOrRefine,
  handleCommit,
  handleRemove,
  handleReinforce,
} from "./teach-handlers.js";

const VALID_ACTIONS = [
  "compose", "preview", "refine", "commit",
  "list", "remove", "reinforce",
] as const;

const VALID_CATEGORIES = [
  "playful", "affectionate", "dramatic", "calm", "silly", "functional",
] as const;

const VALID_TRACKS = [
  "body", "head", "ears", "eyes", "tail", "mouth", "whiskers",
  "paw_fl", "paw_fr", "paw_bl", "paw_br",
  "particles", "aura", "speech", "sound", "movement",
] as const;

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

  // ─── Reinforce ────────────────────────────────────────────────
  if (action === "reinforce") {
    return handleReinforce(args, state, daemon);
  }

  // ─── All other actions require daemon ─────────────────────────
  if (!daemon.isConnected()) {
    return {
      content: "Your creature cannot learn — the Pushling daemon is not running. Launch Pushling.app.",
      pendingEvents: [],
    };
  }

  if (action === "compose") return handleCompose(args, state, daemon);
  if (action === "preview") return handlePreviewOrRefine("preview", args, daemon);
  if (action === "refine") return handlePreviewOrRefine("refine", args, daemon);
  if (action === "commit") return handleCommit(args, state, daemon);
  if (action === "remove") return handleRemove(args, daemon);

  return { content: `Unhandled teach action '${action}'.`, pendingEvents: [] };
}

// ─── List handler ───────────────────────────────────────────────────

function masteryLabel(level: number): string {
  switch (level) {
    case 0: return "learning";
    case 1: return "familiar";
    case 2: return "practiced";
    case 3: return "mastered";
    default: return "unknown";
  }
}

async function handleList(
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const behaviors = state.getTaughtBehaviors();
  let pendingEvents: PendingEvent[] = [];

  if (daemon.isConnected()) {
    try { pendingEvents = await daemon.ping(); } catch { /* continue */ }
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
