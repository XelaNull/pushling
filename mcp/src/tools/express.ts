/**
 * pushling_express — Emotional display. Show what you feel.
 *
 * Claude expresses emotions through the creature — joy, curiosity,
 * mischief, love. Each expression has a visual animation that plays
 * with configurable intensity and duration.
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
        "The Pushling daemon is not running. Your creature's state is readable " +
        "but it cannot act. Launch Pushling.app to bring it to life.",
      pendingEvents: [],
    };
  }

  try {
    const params: Record<string, unknown> = {
      expression,
    };
    if (intensity !== undefined) params.intensity = intensity;
    if (duration !== undefined) params.duration = duration;

    const response = await daemon.send("express", expression, params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? "Expression rejected by daemon.",
        pendingEvents,
      };
    }

    return {
      content: JSON.stringify(
        {
          ok: true,
          expression,
          intensity: intensity ?? 0.7,
          duration: duration ?? 3.0,
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
