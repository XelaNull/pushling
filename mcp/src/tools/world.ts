/**
 * pushling_world — Shape the environment around you.
 *
 * Weather, events, object placement, time overrides, sounds, companions.
 * Claude sculpts the world the creature lives in.
 *
 * Object limits: 12 persistent objects max, 3 active consumables.
 * Minimum 20pt spacing between objects.
 * Max 2 particle emitters from placed objects.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";

const VALID_ACTIONS = [
  "weather",
  "event",
  "place",
  "create",
  "remove",
  "modify",
  "time_override",
  "sound",
  "companion",
] as const;

const VALID_WEATHER_TYPES = [
  "rain",
  "snow",
  "storm",
  "clear",
  "sunny",
  "fog",
] as const;

const VALID_EVENT_TYPES = [
  "shooting_star",
  "aurora",
  "bloom",
  "eclipse",
  "festival",
  "fireflies",
  "rainbow",
] as const;

const VALID_PLACE_OBJECTS = [
  "fountain",
  "bench",
  "shrine",
  "garden",
  "campfire",
  "tree",
  "rock",
  "mushroom",
  "lantern",
  "bridge",
] as const;

/** 20 named presets for the "create" action */
const VALID_PRESETS = [
  "ball",
  "yarn_ball",
  "cozy_bed",
  "cardboard_box",
  "campfire",
  "music_box",
  "little_mirror",
  "treat",
  "fresh_fish",
  "scratching_post",
  "fountain",
  "bench",
  "shrine",
  "garden",
  "flower_pot",
  "crystal",
  "lantern",
  "feather",
  "tiny_hat",
  "bell",
] as const;

const VALID_TIME_PERIODS = [
  "deep_night",
  "dawn",
  "morning",
  "day",
  "golden_hour",
  "dusk",
  "evening",
  "late_night",
] as const;

const VALID_SOUND_TYPES = [
  "chime",
  "purr",
  "meow",
  "wind",
  "rain",
  "crickets",
  "music_box",
] as const;

const VALID_COMPANION_TYPES = [
  "mouse",
  "bird",
  "butterfly",
  "fish",
  "ghost_cat",
] as const;

const VALID_REMOVE_TARGETS = ["nearest", "all_placed"] as const;

const MAX_PERSISTENT_OBJECTS = 12;

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
      content:
        `Unknown action '${action}' for world. ` +
        `Valid: ${VALID_ACTIONS.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Action-specific parameter validation
  const validationError = validateActionParams(action, params, state);
  if (validationError) {
    return { content: validationError, pendingEvents: [] };
  }

  // Requires daemon for all world actions
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

    // Build embodiment-framed response based on action
    const result = buildWorldResponse(action, params, response.data ?? {}, pendingEvents);

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

// ─── Parameter validation ─────────────────────────────────────────────

function validateActionParams(
  action: string,
  params: Record<string, unknown>,
  state?: StateReader
): string | null {
  switch (action) {
    case "weather":
      return validateWeather(params);
    case "event":
      return validateEvent(params);
    case "place":
      return validatePlace(params, state);
    case "create":
      return validateCreate(params, state);
    case "remove":
      return validateRemove(params);
    case "modify":
      return validateModify(params);
    case "time_override":
      return validateTimeOverride(params);
    case "sound":
      return validateSound(params);
    case "companion":
      return validateCompanion(params, state);
    default:
      return null;
  }
}

function validateWeather(params: Record<string, unknown>): string | null {
  const weatherType = params?.type as string | undefined;
  if (!weatherType) {
    return (
      `Weather action requires 'type' in params. ` +
      `Valid types: ${VALID_WEATHER_TYPES.join(", ")}. ` +
      `Optional: 'duration' (1-60 minutes, default: 10).`
    );
  }
  if (
    !VALID_WEATHER_TYPES.includes(
      weatherType as (typeof VALID_WEATHER_TYPES)[number]
    )
  ) {
    return (
      `Unknown weather type '${weatherType}'. ` +
      `Valid: ${VALID_WEATHER_TYPES.join(", ")}.`
    );
  }
  if (params.duration !== undefined) {
    const dur = params.duration as number;
    if (dur < 1 || dur > 60) {
      return `Weather duration must be 1-60 minutes. Got: ${dur}.`;
    }
  }
  return null;
}

function validateEvent(params: Record<string, unknown>): string | null {
  const eventType = params?.type as string | undefined;
  if (!eventType) {
    return (
      `Event action requires 'type' in params. ` +
      `Valid: ${VALID_EVENT_TYPES.join(", ")}.`
    );
  }
  if (
    !VALID_EVENT_TYPES.includes(
      eventType as (typeof VALID_EVENT_TYPES)[number]
    )
  ) {
    return (
      `Unknown event type '${eventType}'. ` +
      `Valid: ${VALID_EVENT_TYPES.join(", ")}.`
    );
  }
  return null;
}

function validatePlace(
  params: Record<string, unknown>,
  state?: StateReader
): string | null {
  const obj = params?.object as string | undefined;
  if (!obj) {
    return (
      `Place action requires 'object' in params. ` +
      `Valid: ${VALID_PLACE_OBJECTS.join(", ")}. ` +
      `Optional: 'position' ("near", "random", "center", or pixel number).`
    );
  }
  if (
    !VALID_PLACE_OBJECTS.includes(
      obj as (typeof VALID_PLACE_OBJECTS)[number]
    )
  ) {
    return (
      `Unknown placeable object '${obj}'. ` +
      `Valid pre-coded objects: ${VALID_PLACE_OBJECTS.join(", ")}. ` +
      `For custom objects, use action 'create' with a preset.`
    );
  }
  // Check object limit
  if (state) {
    const count = state.getAIPlacedObjectCount();
    if (count >= MAX_PERSISTENT_OBJECTS) {
      return (
        `Cannot place object — ${count}/${MAX_PERSISTENT_OBJECTS} persistent objects in world. ` +
        `Remove one first with pushling_world('remove', {object: 'nearest'}).`
      );
    }
  }
  return null;
}

function validateCreate(
  params: Record<string, unknown>,
  state?: StateReader
): string | null {
  const preset = params?.preset as string | undefined;
  if (!preset) {
    return (
      `Create action requires 'preset' in params (Phase 4 supports named presets only). ` +
      `Valid presets: ${VALID_PRESETS.join(", ")}.`
    );
  }
  if (!VALID_PRESETS.includes(preset as (typeof VALID_PRESETS)[number])) {
    return (
      `Unknown preset '${preset}'. ` +
      `Valid: ${VALID_PRESETS.join(", ")}. ` +
      `Custom object definitions will be available in a future update.`
    );
  }
  // Check object limit
  if (state) {
    const count = state.getAIPlacedObjectCount();
    if (count >= MAX_PERSISTENT_OBJECTS) {
      return (
        `Cannot create object — ${count}/${MAX_PERSISTENT_OBJECTS} persistent objects in world. ` +
        `Remove one first with pushling_world('remove', {object: 'nearest'}).`
      );
    }
  }
  return null;
}

function validateRemove(params: Record<string, unknown>): string | null {
  const obj = params?.object as string | number | undefined;
  if (obj === undefined) {
    return (
      `Remove action requires 'object' in params. ` +
      `Valid: 'nearest' (closest AI-placed object), 'all_placed' (all AI-placed), ` +
      `or a specific object ID (number).`
    );
  }
  if (typeof obj === "string") {
    if (
      !VALID_REMOVE_TARGETS.includes(
        obj as (typeof VALID_REMOVE_TARGETS)[number]
      )
    ) {
      return (
        `Unknown remove target '${obj}'. ` +
        `Valid: 'nearest', 'all_placed', or a numeric object ID.`
      );
    }
  }
  return null;
}

function validateModify(params: Record<string, unknown>): string | null {
  const obj = params?.object;
  if (obj === undefined) {
    return (
      `Modify action requires 'object' in params — ` +
      `an object ID (number) or 'nearest'. ` +
      `Also provide 'changes' (object with property updates) ` +
      `and/or 'repair' (boolean, reduces wear to 0).`
    );
  }
  if (!params.changes && !params.repair) {
    return (
      `Modify action requires either 'changes' (object) or 'repair' (boolean). ` +
      `Changes can include: color, effects, size.`
    );
  }
  return null;
}

function validateTimeOverride(
  params: Record<string, unknown>
): string | null {
  const timePeriod = params?.time as string | undefined;
  if (!timePeriod) {
    return (
      `Time override requires 'time' in params. ` +
      `Valid: ${VALID_TIME_PERIODS.join(", ")}. ` +
      `Optional: 'duration' (1-30 minutes, default: 10).`
    );
  }
  if (
    !VALID_TIME_PERIODS.includes(
      timePeriod as (typeof VALID_TIME_PERIODS)[number]
    )
  ) {
    return (
      `Unknown time period '${timePeriod}'. ` +
      `Valid: ${VALID_TIME_PERIODS.join(", ")}.`
    );
  }
  if (params.duration !== undefined) {
    const dur = params.duration as number;
    if (dur < 1 || dur > 30) {
      return `Time override duration must be 1-30 minutes. Got: ${dur}.`;
    }
  }
  return null;
}

function validateSound(params: Record<string, unknown>): string | null {
  const soundType = params?.type as string | undefined;
  if (!soundType) {
    return (
      `Sound action requires 'type' in params. ` +
      `Valid: ${VALID_SOUND_TYPES.join(", ")}.`
    );
  }
  if (
    !VALID_SOUND_TYPES.includes(
      soundType as (typeof VALID_SOUND_TYPES)[number]
    )
  ) {
    return (
      `Unknown sound type '${soundType}'. ` +
      `Valid: ${VALID_SOUND_TYPES.join(", ")}.`
    );
  }
  return null;
}

function validateCompanion(
  params: Record<string, unknown>,
  state?: StateReader
): string | null {
  const compType = params?.type as string | undefined;
  if (!compType) {
    return (
      `Companion action requires 'type' in params. ` +
      `Valid: ${VALID_COMPANION_TYPES.join(", ")}. ` +
      `Optional: 'name' (string). Only one companion at a time.`
    );
  }
  if (
    !VALID_COMPANION_TYPES.includes(
      compType as (typeof VALID_COMPANION_TYPES)[number]
    )
  ) {
    return (
      `Unknown companion type '${compType}'. ` +
      `Valid: ${VALID_COMPANION_TYPES.join(", ")}.`
    );
  }
  // Check existing companion
  if (state) {
    const world = state.getWorld();
    if (world?.companion_type) {
      const existingName = world.companion_name
        ? ` named '${world.companion_name}'`
        : "";
      return (
        `A companion already exists (${world.companion_type}${existingName}). ` +
        `Only one companion at a time. The new ${compType} will replace it.`
      );
    }
  }
  return null;
}

// ─── Response builder ─────────────────────────────────────────────────

function buildWorldResponse(
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
        note: "Sky cycle overridden temporarily. Will revert to natural cycle when duration ends.",
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
