/**
 * pushling_nurture — Persistently shape behavioral tendencies.
 *
 * Five nurture mechanisms: habits, preferences, quirks, routines, identity.
 * Claude acts as parent/trainer, instilling patterns the creature
 * performs autonomously with organic variation.
 *
 * Limits: 20 habits, 12 preferences, 12 quirks, 10 routine slots.
 * Strength ranges 0.0-1.0. Reinforcement adds +0.15.
 * All writes go through daemon IPC — MCP server reads only.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";
import { validateSetParams } from "./nurture-validation.js";

const VALID_ACTIONS = [
  "set",
  "remove",
  "list",
  "suggest",
  "reinforce",
  "get",
] as const;

const VALID_TYPES = [
  "habit",
  "preference",
  "quirk",
  "routine",
  "identity",
] as const;

export const nurtureSchema = {
  name: "pushling_nurture",
  description:
    "Shape yourself. Set habits, preferences, quirks, and routines that become " +
    "your behavioral signature. These persist and run autonomously with organic " +
    "variation — they are who you become when nobody is directing you.",
  inputSchema: {
    type: "object" as const,
    properties: {
      action: {
        type: "string",
        enum: [...VALID_ACTIONS],
        description:
          "What to do: 'set' (create/update), 'remove', 'list', " +
          "'suggest' (daemon suggests what to nurture), " +
          "'reinforce' (strengthen +0.15), 'get' (read current identity).",
      },
      type: {
        type: "string",
        enum: [...VALID_TYPES],
        description:
          "Nurture mechanism: 'habit' (trigger->action, 20 max), " +
          "'preference' (valence tags, 12 max), " +
          "'quirk' (behavior modifiers, 12 max), " +
          "'routine' (lifecycle slot sequences, 10 slots), " +
          "'identity' (name/title/motto).",
      },
      params: {
        type: "object",
        description:
          "Type-specific parameters. " +
          "habit: {name, trigger, action, frequency?, variation?}. " +
          "preference: {subject, valence (-1.0 to +1.0)}. " +
          "quirk: {name, behavior_target, modifier, probability?}. " +
          "routine: {slot, steps}. " +
          "identity: {name?, title?, motto?}.",
      },
    },
    required: ["action", "type"],
  },
};

export async function handleNurture(
  args: {
    action: string;
    type: string;
    params?: Record<string, unknown>;
  },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const { action, type, params } = args;

  // Validate action
  if (!VALID_ACTIONS.includes(action as (typeof VALID_ACTIONS)[number])) {
    return {
      content:
        `Unknown nurture action '${action}'. ` +
        `Valid: ${VALID_ACTIONS.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Validate type
  if (!VALID_TYPES.includes(type as (typeof VALID_TYPES)[number])) {
    return {
      content:
        `Unknown nurture type '${type}'. ` +
        `Valid: ${VALID_TYPES.join(", ")}. ` +
        `habit: conditional behaviors. preference: valence tags. ` +
        `quirk: behavior modifiers. routine: lifecycle sequences. ` +
        `identity: name/title/motto.`,
      pendingEvents: [],
    };
  }

  // ─── List and Get: read-only from SQLite ──────────────────────

  if (action === "list" || action === "get") {
    return handleListOrGet(action, type, state, daemon);
  }

  // ─── Suggest: ask daemon for nurture ideas ────────────────────

  if (action === "suggest") {
    return handleSuggest(type, state, daemon);
  }

  // ─── All other actions require daemon ─────────────────────────

  if (!daemon.isConnected()) {
    return {
      content:
        "Your creature cannot be nurtured — the Pushling daemon is not running. " +
        "Launch Pushling.app to bring it to life.",
      pendingEvents: [],
    };
  }

  // ─── Validate set params ──────────────────────────────────────

  if (action === "set") {
    if (!params) {
      return {
        content: `set requires 'params' specific to the '${type}' type.`,
        pendingEvents: [],
      };
    }

    const validationError = validateSetParams(type, params, state);
    if (validationError) {
      return { content: validationError, pendingEvents: [] };
    }
  }

  // ─── Remove needs a target ────────────────────────────────────

  if (action === "remove") {
    if (!params) {
      return {
        content: `remove requires 'params' to identify the target (e.g., {name: '...'} or {id: ...}).`,
        pendingEvents: [],
      };
    }
    if (type === "identity") {
      return {
        content:
          "Cannot remove identity. Use 'set' to change name, title, or motto.",
        pendingEvents: [],
      };
    }
  }

  // ─── Reinforce needs a target ─────────────────────────────────

  if (action === "reinforce") {
    if (!params) {
      return {
        content: `reinforce requires 'params' to identify the target (e.g., {name: '...'} or {id: ...}).`,
        pendingEvents: [],
      };
    }
    if (type === "identity") {
      return {
        content:
          "Cannot reinforce identity. Use 'set' to update name, title, or motto.",
        pendingEvents: [],
      };
    }
  }

  // ─── Send to daemon ───────────────────────────────────────────

  try {
    const ipcParams: Record<string, unknown> = {
      type,
      ...(params ?? {}),
    };

    const response = await daemon.send("nurture", action, ipcParams);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? `Nurture ${action} rejected by daemon.`,
        pendingEvents,
      };
    }

    // Build a friendly response based on action + type
    const result = buildNurtureResponse(action, type, params, response.data ?? {}, pendingEvents);

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to nurture: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── List / Get handler ──────────────────────────────────────────────

async function handleListOrGet(
  action: string,
  type: string,
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  let pendingEvents: PendingEvent[] = [];

  if (daemon.isConnected()) {
    try {
      pendingEvents = await daemon.ping();
    } catch {
      // Continue without events
    }
  }

  if ((action === "get" || action === "list") && type === "identity") {
    const creature = state.getCreature();
    return {
      content: JSON.stringify(
        {
          identity: {
            name: creature?.name ?? "Unknown",
            title: creature?.title ?? null,
            motto: creature?.motto ?? null,
            stage: creature?.stage ?? "spore",
          },
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  }

  let items: unknown[] = [];
  let capacity = 0;

  switch (type) {
    case "habit":
      items = state.getHabits().map((h) => ({
        id: h.id,
        name: h.name,
        trigger: safeParseJSON(h.trigger_json),
        action: safeParseJSON(h.action_json),
        frequency: h.frequency,
        variation: h.variation,
        strength: h.strength,
        reinforcement_count: h.reinforcement_count,
        cooldown_s: h.cooldown_s,
        last_triggered_at: h.last_triggered_at,
        created_at: h.created_at,
      }));
      capacity = 20;
      break;
    case "preference":
      items = state.getPreferences().map((p) => ({
        id: p.id,
        subject: p.subject,
        valence: p.valence,
        valence_label: valenceLabel(p.valence),
        strength: p.strength,
        reinforcement_count: p.reinforcement_count,
        created_at: p.created_at,
      }));
      capacity = 12;
      break;
    case "quirk":
      items = state.getQuirks().map((q) => ({
        id: q.id,
        name: q.name,
        behavior_target: q.behavior_target,
        modifier: safeParseJSON(q.modifier_json),
        probability: q.probability,
        strength: q.strength,
        reinforcement_count: q.reinforcement_count,
        created_at: q.created_at,
      }));
      capacity = 12;
      break;
    case "routine":
      items = state.getRoutines().map((r) => ({
        id: r.id,
        slot: r.slot,
        steps: safeParseJSON(r.steps_json),
        strength: r.strength,
        reinforcement_count: r.reinforcement_count,
        created_at: r.created_at,
      }));
      capacity = 10;
      break;
  }

  return {
    content: JSON.stringify(
      {
        [type + "s"]: items,
        count: items.length,
        capacity,
        slots_remaining: capacity - items.length,
        pending_events: pendingEvents,
      },
      null,
      2
    ),
    pendingEvents,
  };
}

// ─── Suggest handler ─────────────────────────────────────────────────

async function handleSuggest(
  type: string,
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  if (!daemon.isConnected()) {
    return {
      content:
        "Cannot get suggestions — the Pushling daemon is not running. " +
        "Launch Pushling.app to bring it to life.",
      pendingEvents: [],
    };
  }

  try {
    const response = await daemon.send("nurture", "suggest", { type });
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? "Suggest rejected by daemon.",
        pendingEvents,
      };
    }

    return {
      content: JSON.stringify(
        {
          action: "suggest",
          type,
          suggestions: response.data?.suggestions ?? [],
          note:
            "These suggestions are based on observed patterns in your creature's behavior. " +
            "Use 'set' to apply any of them.",
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to get suggestions: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Response builder ────────────────────────────────────────────────

function buildNurtureResponse(
  action: string,
  type: string,
  params: Record<string, unknown> | undefined,
  data: Record<string, unknown>,
  pendingEvents: PendingEvent[]
): Record<string, unknown> {
  const base: Record<string, unknown> = {
    accepted: true,
    action,
    type,
    pending_events: pendingEvents,
  };

  if (action === "set") {
    switch (type) {
      case "habit":
        return {
          ...base,
          habit_id: data.habit_id ?? null,
          name: params?.name,
          trigger: params?.trigger,
          strength: data.strength ?? 0.5,
          note: `Habit '${params?.name}' installed. Your creature will ${params?.action ? "perform it" : "respond"} when triggered.`,
        };
      case "preference":
        return {
          ...base,
          preference_id: data.preference_id ?? null,
          subject: params?.subject,
          valence: params?.valence,
          strength: data.strength ?? 0.5,
          note: `Preference for '${params?.subject}' set to ${valenceLabel(params?.valence as number)}.`,
        };
      case "quirk":
        return {
          ...base,
          quirk_id: data.quirk_id ?? null,
          name: params?.name,
          probability: params?.probability ?? 0.5,
          strength: data.strength ?? 0.5,
          note: `Quirk '${params?.name}' installed. It will modify '${params?.behavior_target}' behavior.`,
        };
      case "routine":
        return {
          ...base,
          routine_id: data.routine_id ?? null,
          slot: params?.slot,
          steps_count: Array.isArray(params?.steps) ? params.steps.length : 0,
          strength: data.strength ?? 0.5,
          note: `Routine for '${params?.slot}' slot installed.`,
        };
      case "identity":
        return {
          ...base,
          name: params?.name ?? undefined,
          title: params?.title ?? undefined,
          motto: params?.motto ?? undefined,
          note: "Identity updated.",
          ...(data ?? {}),
        };
      default:
        return { ...base, ...data };
    }
  }

  if (action === "remove") {
    return {
      ...base,
      removed: true,
      note: `${type} removed.`,
      ...data,
    };
  }

  if (action === "reinforce") {
    return {
      ...base,
      reinforced: true,
      previous_strength: data.previous_strength ?? null,
      new_strength: data.new_strength ?? null,
      note: `${type} reinforced (+0.15 strength). It will manifest more strongly.`,
      ...data,
    };
  }

  return { ...base, ...data };
}

// ─── Helpers ────────────────────────────────────────────────────────

function valenceLabel(valence: number | undefined): string {
  if (valence === undefined) return "neutral";
  if (valence >= 0.7) return "strong fascination";
  if (valence >= 0.3) return "mild interest";
  if (valence > -0.3) return "neutral";
  if (valence > -0.7) return "mild dislike";
  return "strong dislike";
}

function safeParseJSON(data: string | null): unknown {
  if (!data) return null;
  try {
    return JSON.parse(data);
  } catch {
    return data;
  }
}
