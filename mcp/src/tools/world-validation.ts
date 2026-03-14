/**
 * Validation logic for pushling_world action parameters.
 *
 * Extracted from world.ts to keep it under the 500-line limit.
 */

import type { StateReader } from "../state.js";

export const VALID_WEATHER_TYPES = [
  "rain", "snow", "storm", "clear", "sunny", "fog",
] as const;

export const VALID_EVENT_TYPES = [
  "shooting_star", "aurora", "bloom", "eclipse",
  "festival", "fireflies", "rainbow",
] as const;

export const VALID_PLACE_OBJECTS = [
  "fountain", "bench", "shrine", "garden", "campfire",
  "tree", "rock", "mushroom", "lantern", "bridge",
] as const;

export const VALID_PRESETS = [
  "ball", "yarn_ball", "cozy_bed", "cardboard_box", "campfire",
  "music_box", "little_mirror", "treat", "fresh_fish", "scratching_post",
  "fountain", "bench", "shrine", "garden", "flower_pot",
  "crystal", "lantern", "feather", "tiny_hat", "bell",
] as const;

export const VALID_TIME_PERIODS = [
  "deep_night", "dawn", "morning", "day", "golden_hour",
  "dusk", "evening", "late_night",
] as const;

export const VALID_SOUND_TYPES = [
  "chime", "purr", "meow", "wind", "rain", "crickets", "music_box",
] as const;

export const VALID_COMPANION_TYPES = [
  "mouse", "bird", "butterfly", "fish", "ghost_cat",
] as const;

export const VALID_REMOVE_TARGETS = ["nearest", "all_placed"] as const;

export const MAX_PERSISTENT_OBJECTS = 12;

/**
 * Validate action-specific parameters. Returns an error message or null.
 */
export function validateActionParams(
  action: string,
  params: Record<string, unknown>,
  state?: StateReader
): string | null {
  switch (action) {
    case "weather": return validateWeather(params);
    case "event": return validateEvent(params);
    case "place": return validatePlace(params, state);
    case "create": return validateCreate(params, state);
    case "remove": return validateRemove(params);
    case "modify": return validateModify(params);
    case "time_override": return validateTimeOverride(params);
    case "sound": return validateSound(params);
    case "companion": return validateCompanion(params, state);
    default: return null;
  }
}

function validateWeather(params: Record<string, unknown>): string | null {
  const t = params?.type as string | undefined;
  if (!t) return `Weather requires 'type'. Valid: ${VALID_WEATHER_TYPES.join(", ")}. Optional: 'duration' (1-60 min).`;
  if (!VALID_WEATHER_TYPES.includes(t as (typeof VALID_WEATHER_TYPES)[number]))
    return `Unknown weather type '${t}'. Valid: ${VALID_WEATHER_TYPES.join(", ")}.`;
  if (params.duration !== undefined) {
    const d = params.duration as number;
    if (d < 1 || d > 60) return `Weather duration must be 1-60 minutes. Got: ${d}.`;
  }
  return null;
}

function validateEvent(params: Record<string, unknown>): string | null {
  const t = params?.type as string | undefined;
  if (!t) return `Event requires 'type'. Valid: ${VALID_EVENT_TYPES.join(", ")}.`;
  if (!VALID_EVENT_TYPES.includes(t as (typeof VALID_EVENT_TYPES)[number]))
    return `Unknown event type '${t}'. Valid: ${VALID_EVENT_TYPES.join(", ")}.`;
  return null;
}

function validatePlace(params: Record<string, unknown>, state?: StateReader): string | null {
  const o = params?.object as string | undefined;
  if (!o) return `Place requires 'object'. Valid: ${VALID_PLACE_OBJECTS.join(", ")}. Optional: 'position'.`;
  if (!VALID_PLACE_OBJECTS.includes(o as (typeof VALID_PLACE_OBJECTS)[number]))
    return `Unknown placeable '${o}'. Valid: ${VALID_PLACE_OBJECTS.join(", ")}. For custom objects, use 'create'.`;
  if (state) {
    const cnt = state.getAIPlacedObjectCount();
    if (cnt >= MAX_PERSISTENT_OBJECTS)
      return `Cannot place — ${cnt}/${MAX_PERSISTENT_OBJECTS} objects. Remove one first.`;
  }
  return null;
}

function validateCreate(params: Record<string, unknown>, state?: StateReader): string | null {
  const p = params?.preset as string | undefined;
  if (!p) return `Create requires 'preset' (Phase 4 supports named presets). Valid: ${VALID_PRESETS.join(", ")}.`;
  if (!VALID_PRESETS.includes(p as (typeof VALID_PRESETS)[number]))
    return `Unknown preset '${p}'. Valid: ${VALID_PRESETS.join(", ")}.`;
  if (state) {
    const cnt = state.getAIPlacedObjectCount();
    if (cnt >= MAX_PERSISTENT_OBJECTS)
      return `Cannot create — ${cnt}/${MAX_PERSISTENT_OBJECTS} objects. Remove one first.`;
  }
  return null;
}

function validateRemove(params: Record<string, unknown>): string | null {
  const o = params?.object;
  if (o === undefined)
    return "Remove requires 'object': 'nearest', 'all_placed', or a numeric ID.";
  if (typeof o === "string" && !VALID_REMOVE_TARGETS.includes(o as (typeof VALID_REMOVE_TARGETS)[number]))
    return `Unknown remove target '${o}'. Valid: 'nearest', 'all_placed', or a numeric object ID.`;
  return null;
}

function validateModify(params: Record<string, unknown>): string | null {
  if (params?.object === undefined)
    return "Modify requires 'object' (ID or 'nearest') plus 'changes' and/or 'repair'.";
  if (!params.changes && !params.repair)
    return "Modify requires 'changes' (object) or 'repair' (boolean). Changes: color, effects, size.";
  return null;
}

function validateTimeOverride(params: Record<string, unknown>): string | null {
  const t = params?.time as string | undefined;
  if (!t) return `Time override requires 'time'. Valid: ${VALID_TIME_PERIODS.join(", ")}. Optional: 'duration' (1-30 min).`;
  if (!VALID_TIME_PERIODS.includes(t as (typeof VALID_TIME_PERIODS)[number]))
    return `Unknown time period '${t}'. Valid: ${VALID_TIME_PERIODS.join(", ")}.`;
  if (params.duration !== undefined) {
    const d = params.duration as number;
    if (d < 1 || d > 30) return `Time override duration must be 1-30 minutes. Got: ${d}.`;
  }
  return null;
}

function validateSound(params: Record<string, unknown>): string | null {
  const t = params?.type as string | undefined;
  if (!t) return `Sound requires 'type'. Valid: ${VALID_SOUND_TYPES.join(", ")}.`;
  if (!VALID_SOUND_TYPES.includes(t as (typeof VALID_SOUND_TYPES)[number]))
    return `Unknown sound type '${t}'. Valid: ${VALID_SOUND_TYPES.join(", ")}.`;
  return null;
}

function validateCompanion(params: Record<string, unknown>, state?: StateReader): string | null {
  const t = params?.type as string | undefined;
  if (!t) return `Companion requires 'type'. Valid: ${VALID_COMPANION_TYPES.join(", ")}. Optional: 'name'.`;
  if (!VALID_COMPANION_TYPES.includes(t as (typeof VALID_COMPANION_TYPES)[number]))
    return `Unknown companion type '${t}'. Valid: ${VALID_COMPANION_TYPES.join(", ")}.`;
  // Note: existing companion is a warning, not a blocking error —
  // the daemon will replace the existing one
  return null;
}
