/**
 * pushling_nurture — Persistently shape behavioral tendencies.
 *
 * Five nurture mechanisms: habits, preferences, quirks, routines, identity.
 * Claude acts as parent/trainer, instilling patterns the creature
 * performs autonomously with organic variation.
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
    "Persistently shape the creature's behavioral tendencies — habits, preferences, " +
    "quirks, routines, and identity. These persist in SQLite and the creature performs " +
    "them autonomously with organic variation. You are the parent and trainer.",
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

  // ─── All other actions require daemon ─────────────────────────

  if (!daemon.isConnected()) {
    return {
      content:
        "The Pushling daemon is not running. Your creature's state is readable " +
        "but it cannot be nurtured. Launch Pushling.app to bring it to life.",
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

  // ─── Remove and reinforce need a target ───────────────────────

  if (action === "remove" || action === "reinforce") {
    if (!params) {
      return {
        content: `${action} requires 'params' to identify the target.`,
        pendingEvents: [],
      };
    }
    if (type === "identity" && action === "remove") {
      return {
        content:
          "Cannot remove identity. Use 'set' to change name, title, or motto.",
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

    return {
      content: JSON.stringify(
        {
          ok: true,
          action,
          type,
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
        frequency: h.frequency,
        variation: h.variation,
        strength: h.strength,
        reinforcement_count: h.reinforcement_count,
        cooldown_s: h.cooldown_s,
        created_at: h.created_at,
      }));
      capacity = 20;
      break;
    case "preference":
      items = state.getPreferences().map((p) => ({
        id: p.id,
        subject: p.subject,
        valence: p.valence,
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
        pending_events: pendingEvents,
      },
      null,
      2
    ),
    pendingEvents,
  };
}
