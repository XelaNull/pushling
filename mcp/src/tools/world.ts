/**
 * pushling_world — Shape the environment around you.
 *
 * Weather, events, object placement, time overrides, sounds, companions.
 * Claude sculpts the world the creature lives in.
 *
 * Object limits: 12 persistent objects max.
 * Minimum 20pt spacing between objects.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";
import {
  validateActionParams,
  VALID_PRESETS,
} from "./world-validation.js";

const VALID_ACTIONS = [
  "weather", "event", "place", "create", "remove",
  "modify", "time_override", "sound", "companion",
] as const;

export const worldSchema = {
  name: "pushling_world",
  description:
    "Shape the environment around you. Change weather, trigger visual events, " +
    "place objects, override the sky cycle, play ambient sounds, or introduce companions. " +
    "The world responds to your touch.",
  inputSchema: {
    type: "object" as const,
    properties: {
      action: {
        type: "string",
        enum: [...VALID_ACTIONS],
        description:
          "What to do: weather, event, place, create, remove, modify, " +
          "time_override, sound, companion.",
      },
      params: {
        type: "object",
        description:
          "Action-specific parameters. " +
          "weather: {type, duration?}. " +
          "event: {type}. " +
          "place: {object, position?}. " +
          "create: {preset}. " +
          "remove: {object: 'nearest'|'all_placed'|id}. " +
          "modify: {object: id, changes?, repair?}. " +
          "time_override: {time, duration?}. " +
          "sound: {type}. " +
          "companion: {type, name?}.",
      },
    },
    required: ["action", "params"],
  },
};

export async function handleWorld(
  args: { action: string; params: Record<string, unknown> },
  daemon: DaemonClient,
  state?: StateReader
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const { action, params } = args;

  // Validate action
  if (!VALID_ACTIONS.includes(action as (typeof VALID_ACTIONS)[number])) {
    return {
      content: `Unknown action '${action}' for world. Valid: ${VALID_ACTIONS.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Validate action-specific params
  const validationError = validateActionParams(action, params, state);
  if (validationError) {
    return { content: validationError, pendingEvents: [] };
  }

  // Requires daemon
  if (!daemon.isConnected()) {
    return {
      content:
        "The world is frozen — the Pushling daemon is not running. " +
        "Launch Pushling.app to shape the world around your creature.",
      pendingEvents: [],
    };
  }

  try {
    const response = await daemon.send("world", action, params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? `World ${action} rejected by daemon.`,
        pendingEvents,
      };
    }

    const result = buildResponse(action, params, response.data ?? {}, pendingEvents);
    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to change world: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Response builder ─────────────────────────────────────────────────

function buildResponse(
  action: string,
  params: Record<string, unknown>,
  data: Record<string, unknown>,
  pendingEvents: PendingEvent[]
): Record<string, unknown> {
  const base: Record<string, unknown> = {
    accepted: true,
    action,
    pending_events: pendingEvents,
  };

  switch (action) {
    case "weather":
      return {
        ...base,
        weather: params.type,
        duration_min: params.duration ?? 10,
        previous: data.previous ?? null,
      };
    case "event":
      return {
        ...base,
        event_type: params.type,
        note: "Visual spectacle triggered. It will play once and end naturally.",
      };
    case "place":
      return {
        ...base,
        object: params.object,
        position: data.position ?? params.position ?? "near creature",
        object_id: data.object_id ?? null,
      };
    case "create":
      return {
        ...base,
        preset: params.preset,
        object_id: data.object_id ?? null,
        position: data.position ?? null,
      };
    case "remove":
      return {
        ...base,
        target: params.object,
        removed_count: data.removed_count ?? 1,
        note: "Removed objects are preserved on the legacy shelf, not deleted.",
      };
    case "modify":
      return {
        ...base,
        target: params.object,
        changes_applied: data.changes_applied ?? params.changes ?? null,
        repaired: params.repair ? true : undefined,
      };
    case "time_override":
      return {
        ...base,
        time: params.time,
        duration_min: params.duration ?? 10,
        previous: data.previous ?? null,
        note: "Sky cycle overridden temporarily. Will revert when duration ends.",
      };
    case "sound":
      return {
        ...base,
        sound: params.type,
        note: "Ambient sound queued.",
      };
    case "companion":
      return {
        ...base,
        companion_type: params.type,
        companion_name: data.name ?? params.name ?? null,
        companion_id: data.companion_id ?? null,
      };
    default:
      return { ...base, ...data };
  }
}
