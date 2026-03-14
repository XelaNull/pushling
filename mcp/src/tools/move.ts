/**
 * pushling_move — Locomotion. Move this body.
 *
 * Claude directs the creature's movement — walking, running, jumping,
 * turning. Suspends autonomous walking but breathing/tail-sway continues.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";

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
          "or a pixel position (number). For walk/jump/turn: left, right, up, around.",
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
  daemon: DaemonClient
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

  // Validate target if action requires one
  if (action in VALID_TARGETS && target) {
    const validTargets = VALID_TARGETS[action]!;
    // Allow numeric targets for goto (pixel position)
    const isNumericTarget = action === "goto" && !isNaN(Number(target));
    if (!isNumericTarget && !validTargets.includes(target)) {
      return {
        content:
          `Invalid target '${target}' for ${action}. ` +
          `Valid targets: ${validTargets.join(", ")}` +
          (action === "goto" ? " or a pixel position (number)." : "."),
        pendingEvents: [],
      };
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
        "The Pushling daemon is not running. Your creature's state is readable " +
        "but it cannot act. Launch Pushling.app to bring it to life.",
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

    return {
      content: JSON.stringify(
        {
          ok: true,
          action,
          target: target ?? null,
          speed: speed ?? "walk",
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to send move command: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}
