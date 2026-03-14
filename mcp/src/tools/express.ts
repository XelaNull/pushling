/**
 * pushling_express — Emotional display. Show what you feel.
 *
 * Claude expresses emotions through the creature — joy, curiosity,
 * mischief, love. Each expression has a visual animation that plays
 * with configurable intensity and duration.
 *
 * AI-directed expressions transition at 0.3s (faster than autonomous 0.8s)
 * for a more intentional feel. After duration, expression fades to
 * autonomous emotional state over 0.8s.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";

const VALID_EXPRESSIONS = [
  "joy",
  "curiosity",
  "surprise",
  "contentment",
  "thinking",
  "mischief",
  "pride",
  "embarrassment",
  "determination",
  "wonder",
  "sleepy",
  "love",
  "confusion",
  "excitement",
  "melancholy",
  "neutral",
] as const;

/** Human-readable description of what each expression looks like */
const EXPRESSION_DESCRIPTIONS: Record<string, string> = {
  joy: "eyes bright, ears up, tail high, bouncy step",
  curiosity: "head tilt, ears rotate independently, eyes widen",
  surprise: "ears snap back, eyes wide, jump-startle, fur puffs",
  contentment: "slow-blink, kneading paws, purr particles",
  thinking: "head slight tilt, one ear forward one back, tail still",
  mischief: "narrow eyes, low crouch, tail tip twitching",
  pride: "chest out, chin up, tail high and still",
  embarrassment: "ears flat, looks away, tail wraps around body",
  determination: "ears forward, eyes focused, stance widens",
  wonder: "eyes huge, ears high, mouth slightly open",
  sleepy: "heavy blinks, yawns, ears droop",
  love: "slow-blink, headbutt toward screen, purr particles",
  confusion: "head tilts alternating sides, ear rotates, '?' symbol",
  excitement: "zoomies trigger, tail poofs, ears wild",
  melancholy: "tail low, slow movement, muted colors, quiet",
  neutral: "reset to default idle expression",
};

export const expressSchema = {
  name: "pushling_express",
  description:
    "Emotional display. Show what you feel. " +
    "Express joy, curiosity, surprise, love, mischief, and more. " +
    "Intensity and duration control the animation's amplitude and how long it lasts.",
  inputSchema: {
    type: "object" as const,
    properties: {
      expression: {
        type: "string",
        enum: [...VALID_EXPRESSIONS],
        description:
          "The emotion to express. 16 options from joy to melancholy. " +
          "Use 'neutral' to reset to default idle expression.",
      },
      intensity: {
        type: "number",
        minimum: 0.0,
        maximum: 1.0,
        description:
          "Animation amplitude from 0.0 (subtle) to 1.0 (dramatic). Default: 0.7.",
      },
      duration: {
        type: "number",
        minimum: 0.1,
        maximum: 30.0,
        description:
          "Seconds the expression holds before fading to autonomous state. " +
          "Default: 3.0, max: 30.0.",
      },
    },
    required: ["expression"],
  },
};

export async function handleExpress(
  args: { expression: string; intensity?: number; duration?: number },
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const { expression, intensity, duration } = args;

  // Validate expression
  if (
    !VALID_EXPRESSIONS.includes(
      expression as (typeof VALID_EXPRESSIONS)[number]
    )
  ) {
    return {
      content:
        `Unknown expression '${expression}'. ` +
        `Valid: ${VALID_EXPRESSIONS.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Validate intensity
  if (intensity !== undefined && (intensity < 0.0 || intensity > 1.0)) {
    return {
      content:
        `Intensity must be between 0.0 and 1.0. Got: ${intensity}. ` +
        `0.0 = barely perceptible, 0.5 = moderate, 1.0 = maximum.`,
      pendingEvents: [],
    };
  }

  // Validate duration
  if (duration !== undefined && (duration < 0.1 || duration > 30.0)) {
    return {
      content:
        `Duration must be between 0.1 and 30.0 seconds. Got: ${duration}.`,
      pendingEvents: [],
    };
  }

  // Requires daemon
  if (!daemon.isConnected()) {
    return {
      content:
        "Your body cannot express what you feel — the Pushling daemon is not running. " +
        "Launch Pushling.app to inhabit your creature.",
      pendingEvents: [],
    };
  }

  const actualIntensity = intensity ?? 0.7;
  const actualDuration = duration ?? 3.0;

  try {
    const params: Record<string, unknown> = {
      intensity: actualIntensity,
      duration: actualDuration,
    };

    const response = await daemon.send("express", expression, params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? "Expression rejected by daemon.",
        pendingEvents,
      };
    }

    const desc = EXPRESSION_DESCRIPTIONS[expression] ?? expression;

    return {
      content: JSON.stringify(
        {
          accepted: true,
          expression,
          visual: desc,
          intensity: actualIntensity,
          duration_s: actualDuration,
          transition_speed_s: 0.3,
          fade_to_autonomous_s: 0.8,
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to express: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}
