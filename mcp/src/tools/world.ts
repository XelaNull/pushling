/**
 * pushling_world — Shape the environment around you.
 *
 * Weather, events, object placement, time overrides, sounds, companions.
 * Claude sculpts the world the creature lives in.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";

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
          "create: {preset?} or {base, color?, effects?, physics?, interaction?}. " +
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
  daemon: DaemonClient
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
  switch (action) {
    case "weather": {
      const weatherType = params?.type as string | undefined;
      if (
        weatherType &&
        !VALID_WEATHER_TYPES.includes(
          weatherType as (typeof VALID_WEATHER_TYPES)[number]
        )
      ) {
        return {
          content:
            `Unknown weather type '${weatherType}'. ` +
            `Valid: ${VALID_WEATHER_TYPES.join(", ")}.`,
          pendingEvents: [],
        };
      }
      if (!weatherType) {
        return {
          content:
            `Weather action requires a 'type' in params. ` +
            `Valid types: ${VALID_WEATHER_TYPES.join(", ")}. ` +
            `Optional: 'duration' (1-60 minutes).`,
          pendingEvents: [],
        };
      }
      break;
    }
    case "event": {
      const eventType = params?.type as string | undefined;
      if (
        eventType &&
        !VALID_EVENT_TYPES.includes(
          eventType as (typeof VALID_EVENT_TYPES)[number]
        )
      ) {
        return {
          content:
            `Unknown event type '${eventType}'. ` +
            `Valid: ${VALID_EVENT_TYPES.join(", ")}.`,
          pendingEvents: [],
        };
      }
      if (!eventType) {
        return {
          content:
            `Event action requires a 'type' in params. ` +
            `Valid: ${VALID_EVENT_TYPES.join(", ")}.`,
          pendingEvents: [],
        };
      }
      break;
    }
    case "place": {
      const obj = params?.object as string | undefined;
      if (
        obj &&
        !VALID_PLACE_OBJECTS.includes(
          obj as (typeof VALID_PLACE_OBJECTS)[number]
        )
      ) {
        return {
          content:
            `Unknown placeable object '${obj}'. ` +
            `Valid pre-coded objects: ${VALID_PLACE_OBJECTS.join(", ")}. ` +
            `For custom objects, use action 'create' instead.`,
          pendingEvents: [],
        };
      }
      if (!obj) {
        return {
          content:
            `Place action requires an 'object' in params. ` +
            `Valid: ${VALID_PLACE_OBJECTS.join(", ")}. ` +
            `Optional: 'position' ("near", "random", "center").`,
          pendingEvents: [],
        };
      }
      break;
    }
    case "time_override": {
      const timePeriod = params?.time as string | undefined;
      if (
        timePeriod &&
        !VALID_TIME_PERIODS.includes(
          timePeriod as (typeof VALID_TIME_PERIODS)[number]
        )
      ) {
        return {
          content:
            `Unknown time period '${timePeriod}'. ` +
            `Valid: ${VALID_TIME_PERIODS.join(", ")}.`,
          pendingEvents: [],
        };
      }
      if (!timePeriod) {
        return {
          content:
            `Time override requires a 'time' in params. ` +
            `Valid: ${VALID_TIME_PERIODS.join(", ")}. ` +
            `Optional: 'duration' (1-30 minutes).`,
          pendingEvents: [],
        };
      }
      break;
    }
    case "sound": {
      const soundType = params?.type as string | undefined;
      if (
        soundType &&
        !VALID_SOUND_TYPES.includes(
          soundType as (typeof VALID_SOUND_TYPES)[number]
        )
      ) {
        return {
          content:
            `Unknown sound type '${soundType}'. ` +
            `Valid: ${VALID_SOUND_TYPES.join(", ")}.`,
          pendingEvents: [],
        };
      }
      if (!soundType) {
        return {
          content:
            `Sound action requires a 'type' in params. ` +
            `Valid: ${VALID_SOUND_TYPES.join(", ")}.`,
          pendingEvents: [],
        };
      }
      break;
    }
    case "companion": {
      const compType = params?.type as string | undefined;
      if (
        compType &&
        !VALID_COMPANION_TYPES.includes(
          compType as (typeof VALID_COMPANION_TYPES)[number]
        )
      ) {
        return {
          content:
            `Unknown companion type '${compType}'. ` +
            `Valid: ${VALID_COMPANION_TYPES.join(", ")}.`,
          pendingEvents: [],
        };
      }
      if (!compType) {
        return {
          content:
            `Companion action requires a 'type' in params. ` +
            `Valid: ${VALID_COMPANION_TYPES.join(", ")}. ` +
            `Optional: 'name' (string).`,
          pendingEvents: [],
        };
      }
      break;
    }
  }

  // Requires daemon for all world actions
  if (!daemon.isConnected()) {
    return {
      content:
        "The Pushling daemon is not running. Your creature's state is readable " +
        "but it cannot act. Launch Pushling.app to bring it to life.",
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

    return {
      content: JSON.stringify(
        {
          ok: true,
          action,
          params,
          pending_events: pendingEvents,
        },
        null,
        2
      ),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to change world: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}
