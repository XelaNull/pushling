/**
 * Validation logic for pushling_nurture set params.
 *
 * Extracted to keep nurture.ts under the 500-line limit.
 * Each nurture type (habit, preference, quirk, routine, identity)
 * has its own parameter shape and constraints.
 */

import type { StateReader } from "../state.js";

export const VALID_HABIT_TRIGGERS = [
  "after_commit",
  "on_idle",
  "at_time",
  "on_emotion",
  "on_weather",
  "near_object",
  "on_wake",
  "on_session",
  "on_touch",
  "periodic",
  "all_of",
  "any_of",
  "none_of",
] as const;

export const VALID_FREQUENCIES = [
  "always",
  "often",
  "sometimes",
  "rarely",
] as const;

export const VALID_VARIATIONS = [
  "strict",
  "moderate",
  "loose",
  "wild",
] as const;

export const VALID_ROUTINE_SLOTS = [
  "morning",
  "post_meal",
  "bedtime",
  "greeting",
  "farewell",
  "return",
  "milestone",
  "weather_change",
  "boredom",
  "post_feast",
] as const;

const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];

/**
 * Validate params for a nurture 'set' action.
 * Returns an error message string if invalid, or null if valid.
 */
export function validateSetParams(
  type: string,
  params: Record<string, unknown>,
  state: StateReader
): string | null {
  switch (type) {
    case "habit":
      return validateHabit(params);
    case "preference":
      return validatePreference(params);
    case "quirk":
      return validateQuirk(params);
    case "routine":
      return validateRoutine(params);
    case "identity":
      return validateIdentity(params, state);
    default:
      return null;
  }
}

function validateHabit(params: Record<string, unknown>): string | null {
  if (!params.name) {
    return "habit requires 'name' in params. Example: 'stretch_after_eating'.";
  }
  if (!params.trigger) {
    return (
      `habit requires 'trigger' in params. ` +
      `Valid triggers: ${VALID_HABIT_TRIGGERS.join(", ")}.`
    );
  }
  if (!params.action) {
    return (
      "habit requires 'action' in params — what the creature does. " +
      "Example: {behavior: 'stretch', variant: 'morning'}."
    );
  }
  if (
    params.frequency &&
    !VALID_FREQUENCIES.includes(
      params.frequency as (typeof VALID_FREQUENCIES)[number]
    )
  ) {
    return (
      `Invalid frequency '${params.frequency}'. ` +
      `Valid: ${VALID_FREQUENCIES.join(", ")}.`
    );
  }
  if (
    params.variation &&
    !VALID_VARIATIONS.includes(
      params.variation as (typeof VALID_VARIATIONS)[number]
    )
  ) {
    return (
      `Invalid variation '${params.variation}'. ` +
      `Valid: ${VALID_VARIATIONS.join(", ")}.`
    );
  }
  return null;
}

function validatePreference(params: Record<string, unknown>): string | null {
  if (!params.subject) {
    return (
      "preference requires 'subject' in params. " +
      "Example: 'rain', 'mushrooms', 'night_time'."
    );
  }
  if (params.valence === undefined) {
    return (
      "preference requires 'valence' in params. " +
      "-1.0 (strong dislike) to +1.0 (strong fascination). " +
      "Example: {subject: 'rain', valence: 0.8}."
    );
  }
  const valence = params.valence as number;
  if (valence < -1.0 || valence > 1.0) {
    return (
      `Valence must be between -1.0 and +1.0. Got: ${valence}. ` +
      `-1.0 = strong dislike, 0 = neutral, +1.0 = strong fascination.`
    );
  }
  return null;
}

function validateQuirk(params: Record<string, unknown>): string | null {
  if (!params.name) {
    return "quirk requires 'name' in params. Example: 'wink_instead_of_blink'.";
  }
  if (!params.behavior_target) {
    return (
      "quirk requires 'behavior_target' — which behavior this modifies. " +
      "Example: 'blink', 'walk', 'eat'."
    );
  }
  if (!params.modifier) {
    return (
      "quirk requires 'modifier' — what changes. " +
      "Example: 'wink left eye', 'look left before', 'sneeze after'."
    );
  }
  if (params.probability !== undefined) {
    const prob = params.probability as number;
    if (prob < 0.0 || prob > 1.0) {
      return (
        `Probability must be between 0.0 and 1.0. Got: ${prob}. ` +
        `How often the quirk triggers (0.15 = 15% of the time).`
      );
    }
  }
  return null;
}

function validateRoutine(params: Record<string, unknown>): string | null {
  if (!params.slot) {
    return (
      `routine requires 'slot' in params. ` +
      `Valid slots: ${VALID_ROUTINE_SLOTS.join(", ")}. ` +
      `One routine per slot.`
    );
  }
  if (
    !VALID_ROUTINE_SLOTS.includes(
      params.slot as (typeof VALID_ROUTINE_SLOTS)[number]
    )
  ) {
    return (
      `Unknown routine slot '${params.slot}'. ` +
      `Valid: ${VALID_ROUTINE_SLOTS.join(", ")}.`
    );
  }
  if (!params.steps || !Array.isArray(params.steps)) {
    return (
      "routine requires 'steps' — an array of ordered actions. " +
      "Example: [{action: 'stretch'}, {action: 'walk', target: 'center'}, {action: 'speak', text: 'ready'}]."
    );
  }
  return null;
}

function validateIdentity(
  params: Record<string, unknown>,
  state: StateReader
): string | null {
  if (!params.name && !params.title && !params.motto) {
    return (
      "identity requires at least one of: 'name' (max 12 chars, any stage), " +
      "'title' (max 30 chars, Beast+), 'motto' (max 50 chars, Sage+). " +
      "Example: {name: 'Zepus', title: 'The Methodical'}."
    );
  }
  if (params.name && (params.name as string).length > 12) {
    return `Name must be 12 characters or fewer. Got: ${(params.name as string).length}.`;
  }
  if (params.title && (params.title as string).length > 30) {
    return `Title must be 30 characters or fewer. Got: ${(params.title as string).length}.`;
  }
  if (params.motto && (params.motto as string).length > 50) {
    return `Motto must be 50 characters or fewer. Got: ${(params.motto as string).length}.`;
  }

  const creature = state.getCreature();
  const stage = creature?.stage ?? "spore";

  if (params.title && STAGE_ORDER.indexOf(stage) < STAGE_ORDER.indexOf("beast")) {
    return (
      `Titles require Beast stage or higher. Current stage: ${stage}. ` +
      `At Beast (500 commits), you can claim a title.`
    );
  }
  if (params.motto && STAGE_ORDER.indexOf(stage) < STAGE_ORDER.indexOf("sage")) {
    return (
      `Mottos require Sage stage or higher. Current stage: ${stage}. ` +
      `At Sage (2500 commits), you can declare a motto.`
    );
  }
  return null;
}
