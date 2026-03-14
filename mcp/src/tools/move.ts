/**
 * pushling_move — Locomotion. Move this body.
 *
 * Claude directs the creature's movement — walking, running, jumping,
 * turning. Suspends autonomous walking but breathing/tail-sway continues.
 *
 * Returns immediately with estimated duration — does not block on completion.
 * Movement speeds: walk = 30pt/s, run = 80pt/s, sneak = 12pt/s
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";

const VALID_ACTIONS = [
  "goto",
  "walk",
  "stop",
  "jump",
  "turn",
  "retreat",
  "pace",
  "approach_edge",
  "center",
  "follow_cursor",
] as const;

const VALID_TARGETS: Record<string, string[]> = {
  goto: ["left", "right", "center", "edge_left", "edge_right"],
  walk: ["left", "right"],
  jump: ["up", "left", "right"],
  turn: ["left", "right", "around"],
  approach_edge: ["left", "right"],
};

const VALID_SPEEDS = ["walk", "run", "sneak"] as const;

// Movement speed in points per second
const SPEED_PTS: Record<string, number> = {
  walk: 30,
  run: 80,
  sneak: 12,
};

// Named position targets in points
const POSITION_TARGETS: Record<string, number> = {
  left: 100,
  right: 985,
  center: 542,
  edge_left: 15,
  edge_right: 1070,
};

// Fixed-duration actions in milliseconds
const FIXED_DURATIONS: Record<string, number> = {
  stop: 300,
  jump: 800,
  turn: 430,
  retreat: 2000,
  pace: 5000,
  follow_cursor: 0, // continuous
};

/** Actions that require a target/direction param */
const REQUIRES_TARGET = new Set(["goto", "walk", "approach_edge"]);
const REQUIRES_DIRECTION = new Set(["jump", "turn"]);

export const moveSchema = {
  name: "pushling_move",
  description:
    "Locomotion. Move this body. Walk, run, sneak, jump, turn. " +
    "Suspends autonomous walking — breathing and tail-sway continue. " +
    "After 30s with no new move command, autonomous wander resumes.",
  inputSchema: {
    type: "object" as const,
    properties: {
      action: {
        type: "string",
        enum: [...VALID_ACTIONS],
        description:
          "Movement action: goto (to a target), walk (in direction), " +
          "stop, jump, turn, retreat, pace, approach_edge, center, follow_cursor.",
      },
      target: {
        type: "string",
        description:
          "Where to go. For goto: left, right, center, edge_left, edge_right, " +
          "or a pixel position (number 0-1085). For walk/jump/turn: left, right, up, around.",
      },
      speed: {
        type: "string",
        enum: [...VALID_SPEEDS],
        description: "Movement speed: walk (default), run, or sneak.",
      },
    },
    required: ["action"],
  },
};

export async function handleMove(
  args: { action: string; target?: string; speed?: string },
  daemon: DaemonClient,
  state?: StateReader
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const { action, target, speed } = args;

  // Validate action
  if (!VALID_ACTIONS.includes(action as (typeof VALID_ACTIONS)[number])) {
    return {
      content:
        `Unknown action '${action}' for move. ` +
        `Valid: ${VALID_ACTIONS.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Validate target/direction for actions that require it
  if (REQUIRES_TARGET.has(action) && !target) {
    const validTargets = VALID_TARGETS[action] ?? [];
    return {
      content:
        `'${action}' requires a target. ` +
        `Valid: ${validTargets.join(", ")}` +
        (action === "goto" ? " or a pixel position (0-1085)." : "."),
      pendingEvents: [],
    };
  }

  if (REQUIRES_DIRECTION.has(action) && !target) {
    const validTargets = VALID_TARGETS[action] ?? [];
    return {
      content:
        `'${action}' requires a direction. ` +
        `Valid: ${validTargets.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Validate target value if action expects specific options
  if (action in VALID_TARGETS && target) {
    const validTargets = VALID_TARGETS[action]!;
    // Allow numeric targets for goto (pixel position)
    const isNumericTarget = action === "goto" && !isNaN(Number(target));
    if (!isNumericTarget && !validTargets.includes(target)) {
      return {
        content:
          `Invalid target '${target}' for ${action}. ` +
          `Valid targets: ${validTargets.join(", ")}` +
          (action === "goto" ? " or a pixel position (0-1085)." : "."),
        pendingEvents: [],
      };
    }
    // Validate numeric range for goto
    if (isNumericTarget) {
      const pos = Number(target);
      if (pos < 0 || pos > 1085) {
        return {
          content:
            `Pixel position must be between 0 and 1085. Got: ${pos}. ` +
            `The Touch Bar is 1085 points wide.`,
          pendingEvents: [],
        };
      }
    }
  }

  // Validate speed
  if (
    speed &&
    !VALID_SPEEDS.includes(speed as (typeof VALID_SPEEDS)[number])
  ) {
    return {
      content: `Invalid speed '${speed}'. Valid: ${VALID_SPEEDS.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Requires daemon
  if (!daemon.isConnected()) {
    return {
      content:
        "Your body is still — the Pushling daemon is not running. " +
        "Launch Pushling.app to inhabit your creature.",
      pendingEvents: [],
    };
  }

  try {
    const params: Record<string, unknown> = {};
    if (target !== undefined) params.target = target;
    if (speed !== undefined) params.speed = speed;

    const response = await daemon.send("move", action, params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? "Move command rejected by daemon.",
        pendingEvents,
      };
    }

    // Estimate duration based on action type and distance
    const actualSpeed = speed ?? "walk";
    const estimatedMs = estimateDuration(action, target, actualSpeed, state);

    const result: Record<string, unknown> = {
      accepted: true,
      action,
      ...(response.data ?? {}),
      speed: actualSpeed,
      estimated_duration_ms: estimatedMs,
      pending_events: pendingEvents,
    };

    if (target !== undefined) result.target = target;

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to send move command: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}

// ─── Duration estimation ────────────────────────────────────────────

function estimateDuration(
  action: string,
  target: string | undefined,
  speed: string,
  state?: StateReader
): number {
  // Fixed duration actions
  if (action in FIXED_DURATIONS) {
    return FIXED_DURATIONS[action]!;
  }

  // Center is a goto variant
  if (action === "center") {
    return estimateGotoDuration(542, speed, state);
  }

  // Approach edge
  if (action === "approach_edge") {
    const edgeTarget = target === "left" ? 15 : 1070;
    return estimateGotoDuration(edgeTarget, speed, state);
  }

  // Walk is continuous until stopped
  if (action === "walk") {
    return 0; // continuous — no fixed duration
  }

  // Goto with a target
  if (action === "goto" && target) {
    const targetPos = !isNaN(Number(target))
      ? Number(target)
      : POSITION_TARGETS[target] ?? 542;
    return estimateGotoDuration(targetPos, speed, state);
  }

  return 0;
}

function estimateGotoDuration(
  targetX: number,
  speed: string,
  state?: StateReader
): number {
  const currentX = state?.getWorld()?.creature_x ?? 542;
  const distance = Math.abs(targetX - currentX);
  const ptsPerSec = SPEED_PTS[speed] ?? 30;
  return Math.round((distance / ptsPerSec) * 1000);
}
