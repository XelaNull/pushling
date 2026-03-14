/**
 * pushling_speak — The voice of the creature. Stage-gated.
 *
 * Speech bubbles rendered on the Touch Bar. Each growth stage unlocks
 * more vocabulary. A Spore cannot speak at all. An Apex has full fluency.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";

const VALID_STYLES = [
  "say",
  "think",
  "exclaim",
  "whisper",
  "sing",
  "dream",
  "narrate",
] as const;

// Stage gates: [maxChars, maxWords]
const STAGE_LIMITS: Record<string, [number, number]> = {
  spore: [0, 0],
  drop: [1, 0], // Only symbols: ! ? ♡ ~ ... ♪ ★
  critter: [20, 3],
  beast: [50, 8],
  sage: [80, 20],
  apex: [120, 30],
};

const DROP_SYMBOLS = ["!", "?", "♡", "~", "...", "♪", "★"];

export const speakSchema = {
  name: "pushling_speak",
  description:
    "The voice of the creature. Stage-gated — Spore cannot speak, " +
    "Drop can only use symbols (! ? ♡ ~ ... ♪ ★), Critter gets 3 words, " +
    "and so on up to Apex with full fluency. Choose a style for the speech bubble.",
  inputSchema: {
    type: "object" as const,
    properties: {
      text: {
        type: "string",
        description:
          "What to say. Will be filtered to fit the creature's current " +
          "stage limits. At Drop stage, only symbols are allowed.",
      },
      style: {
        type: "string",
        enum: [...VALID_STYLES],
        description:
          "Speech style: 'say' (normal), 'think' (thought bubble), " +
          "'exclaim' (bold), 'whisper' (quiet), 'sing' (musical), " +
          "'dream' (sleep only), 'narrate' (environmental, Sage+ only). " +
          "Default: 'say'.",
      },
    },
    required: ["text"],
  },
};

export async function handleSpeak(
  args: { text: string; style?: string },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const { text, style: rawStyle } = args;
  const style = rawStyle ?? "say";

  // Validate style
  if (!VALID_STYLES.includes(style as (typeof VALID_STYLES)[number])) {
    return {
      content:
        `Unknown style '${style}'. ` +
        `Valid: ${VALID_STYLES.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Check creature stage for gating
  const creature = state.getCreature();
  const stage = creature?.stage ?? "spore";
  const limits = STAGE_LIMITS[stage] ?? STAGE_LIMITS.spore;

  // Spore: cannot speak at all
  if (stage === "spore") {
    return {
      content:
        "You cannot speak yet. You are pure light — no mouth, no voice. " +
        "You can only pulse and glow. At Drop stage (20 commits), " +
        "you will gain eyes and symbols.",
      pendingEvents: [],
    };
  }

  // Drop: only symbols
  if (stage === "drop") {
    if (!DROP_SYMBOLS.includes(text)) {
      return {
        content:
          `At Drop stage, you can only express single symbols: ${DROP_SYMBOLS.join(" ")}. ` +
          `You tried to say "${text}" but your body can only produce symbols right now. ` +
          `At Critter stage (100 commits), you will gain your first words.`,
        pendingEvents: [],
      };
    }
  }

  // Narrate requires Sage+
  if (style === "narrate" && stage !== "sage" && stage !== "apex") {
    return {
      content:
        `The 'narrate' style requires Sage stage or higher. ` +
        `Your current stage is ${stage}. At Sage (2500 commits), ` +
        `you will unlock environmental narration.`,
      pendingEvents: [],
    };
  }

  // Validate text length for stage
  const [maxChars, maxWords] = limits;
  const wordCount = text.split(/\s+/).length;
  const truncatedText =
    text.length > maxChars ? text.slice(0, maxChars) : text;
  const wasFiltered = text.length > maxChars || wordCount > maxWords;

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
      text: truncatedText,
      style,
    };
    if (wasFiltered) {
      params.intended_text = text;
    }

    const response = await daemon.send("speak", style, params);
    const pendingEvents = response.pending_events ?? [];

    if (!response.ok) {
      return {
        content: response.error ?? "Speech rejected by daemon.",
        pendingEvents,
      };
    }

    const result: Record<string, unknown> = {
      ok: true,
      rendered: truncatedText,
      style,
      pending_events: pendingEvents,
    };

    if (wasFiltered) {
      result.intended = text;
      result.note = `Your ${stage} body can express ${maxChars} characters / ${maxWords} words. The full message was logged as failed_speech.`;
    }

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  } catch (err) {
    return {
      content: `Failed to speak: ${err instanceof Error ? err.message : String(err)}`,
      pendingEvents: [],
    };
  }
}
