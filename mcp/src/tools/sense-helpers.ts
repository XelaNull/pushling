/**
 * Helper functions for pushling_sense — emergent state computation,
 * mood summaries, and circadian phase.
 *
 * Extracted from sense.ts to keep it under the 500-line limit.
 */

import type { CreatureState } from "../state.js";

/**
 * Compute the emergent emotional state from the 4 axes.
 * Based on the vision doc combination rules.
 */
export function computeEmergentState(creature: CreatureState): string {
  const sat = creature.satisfaction;
  const cur = creature.curiosity;
  const con = creature.contentment;
  const ene = creature.emotional_energy;

  // High satisfaction + contentment + mid energy = blissful
  if (sat > 70 && con > 70 && ene >= 30 && ene <= 70) return "blissful";

  // High curiosity + high energy = playful
  if (cur > 70 && ene > 70) return "playful";

  // High curiosity + low energy = studious
  if (cur > 70 && ene < 40) return "studious";

  // Low satisfaction + high energy = hangry
  if (sat < 30 && ene > 60) return "hangry";

  // High contentment + low energy = zen
  if (con > 70 && ene < 30) return "zen";

  // Low everything = exhausted
  if (sat < 30 && ene < 30 && con < 30) return "exhausted";

  // High satisfaction + high curiosity = inspired
  if (sat > 60 && cur > 60) return "inspired";

  // Mid-range everything = balanced
  if (sat >= 40 && sat <= 60 && con >= 40 && con <= 60) return "balanced";

  // High energy + low contentment = restless
  if (ene > 70 && con < 40) return "restless";

  // Default
  return "settled";
}

/**
 * Compose a natural-language mood summary.
 */
export function composeMoodSummary(
  creature: CreatureState,
  emergent: string
): string {
  const parts: string[] = [];

  // Feeding status
  const fedAgo = agoSeconds(creature.last_fed_at);
  if (fedAgo === null) {
    parts.push("never been fed");
  } else if (fedAgo < 300) {
    parts.push("freshly fed");
  } else if (fedAgo < 3600) {
    parts.push("well-fed");
  } else if (fedAgo < 14400) {
    parts.push("getting peckish");
  } else {
    parts.push("quite hungry");
  }

  // Emotional color
  if (creature.curiosity > 70) parts.push("intensely curious");
  else if (creature.curiosity > 50) parts.push("curious");

  if (creature.satisfaction > 70) parts.push("deeply satisfied");
  else if (creature.satisfaction < 30) parts.push("unsatisfied");

  if (creature.emotional_energy > 70) parts.push("buzzing with energy");
  else if (creature.emotional_energy < 30) parts.push("low on energy");

  if (creature.contentment > 70) parts.push("peacefully content");

  // Streak flavor
  if (creature.streak_days > 7) {
    parts.push(`riding a ${creature.streak_days}-day streak`);
  }

  const emergentPrefixes: Record<string, string> = {
    blissful: "Feeling blissful — ",
    playful: "Feeling playful — ",
    studious: "In a studious mood — ",
    hangry: "Getting hangry — ",
    zen: "In a zen state — ",
    exhausted: "Feeling exhausted — ",
    inspired: "Feeling inspired — ",
    restless: "Feeling restless — ",
  };

  const prefix = emergentPrefixes[emergent] ?? "";
  return prefix + parts.join(", ") + ".";
}

/**
 * Compute circadian phase from current time.
 */
export function computeCircadianPhase(): string {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 7) return "early morning awakening";
  if (hour >= 7 && hour < 9) return "morning energy";
  if (hour >= 9 && hour < 12) return "mid-morning focus";
  if (hour >= 12 && hour < 14) return "midday";
  if (hour >= 14 && hour < 16) return "mid-afternoon settling";
  if (hour >= 16 && hour < 18) return "late afternoon";
  if (hour >= 18 && hour < 20) return "evening wind-down";
  if (hour >= 20 && hour < 22) return "evening drowsiness";
  if (hour >= 22 || hour < 1) return "late night";
  return "deep night rest";
}

/**
 * Compute seconds ago from a timestamp string.
 * Returns null if timestamp is null.
 */
export function agoSeconds(timestamp: string | null): number | null {
  if (!timestamp) return null;
  return Math.floor((Date.now() - new Date(timestamp).getTime()) / 1000);
}

/**
 * Safely parse a JSON string, returning null on failure.
 */
export function safeParseJSON(data: string | null): unknown {
  if (!data) return null;
  try {
    return JSON.parse(data);
  } catch {
    return data;
  }
}
