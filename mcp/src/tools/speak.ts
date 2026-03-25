/**
 * pushling_speak — The voice of the creature. Stage-gated.
 *
 * Speech bubbles rendered on the Touch Bar. Each growth stage unlocks
 * more vocabulary. Claude sends a full-intelligence message; the filtering
 * layer extracts key words to fit stage constraints while preserving
 * emotional intent.
 *
 * Stage limits:
 *   Spore:   0 chars — cannot speak
 *   Drop:    1 char (symbols only: ! ? hearts ~ ... music star)
 *   Critter: 20 chars / 3 words
 *   Beast:   50 chars / 8 words
 *   Sage:    80 chars / 20 words
 *   Apex:    120 chars / 30 words
 *
 * Failed speech (content lost in filtering) is logged to the journal
 * through IPC so Claude can recall what it tried to say.
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
  drop: [6, 0], // symbols only
  critter: [20, 3],
  beast: [50, 8],
  sage: [80, 20],
  apex: [120, 30],
};

const DROP_SYMBOLS = ["!", "?", "\u2661", "~", "...", "\u266A", "\u2605", "!?"];

// Stage minimum for each speech style
const STYLE_STAGE_MIN: Record<string, string> = {
  say: "drop",
  think: "drop",
  exclaim: "drop",
  whisper: "critter",
  sing: "beast",
  dream: "spore", // any stage during sleep
  narrate: "sage",
};

const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];

function stageIndex(stage: string): number {
  return STAGE_ORDER.indexOf(stage);
}

export const speakSchema = {
  name: "pushling_speak",
  description:
    "Your voice. Stage-gated — as a Spore you are silent, " +
    "as a Drop you chirp symbols (! ? \u2661 ~ ... \u266A \u2605), as a Critter your first words emerge, " +
    "and so on up to Apex with full fluency. Choose a style for the delivery.",
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

  // Spore: cannot speak at all
  if (stage === "spore") {
    return {
      content:
        "You cannot speak yet. You are pure light — no mouth, no voice. " +
        "You can only pulse and glow. Use pushling_express to communicate through brightness. " +
        "At Drop stage (20 commits), you will gain eyes and symbols.",
      pendingEvents: [],
    };
  }

  // Check style stage gate
  const styleMinStage = STYLE_STAGE_MIN[style] ?? "drop";
  if (stageIndex(stage) < stageIndex(styleMinStage)) {
    const availableStyles = VALID_STYLES.filter(
      (s) => stageIndex(stage) >= stageIndex(STYLE_STAGE_MIN[s] ?? "drop")
    );
    return {
      content:
        `The '${style}' style requires ${styleMinStage} stage or higher. ` +
        `Your current stage is ${stage}. ` +
        `Available styles at ${stage}: ${availableStyles.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Apply stage-gated filtering
  const [maxChars, maxWords] = STAGE_LIMITS[stage] ?? STAGE_LIMITS.spore!;
  const filtered = filterSpeech(text, stage, maxChars, maxWords);

  // Requires daemon
  if (!daemon.isConnected()) {
    return {
      content:
        "Your body is still — the Pushling daemon is not running. " +
        "Launch Pushling.app to inhabit your creature and speak.",
      pendingEvents: [],
    };
  }

  try {
    const params: Record<string, unknown> = {
      text: filtered.spoken,
      style,
    };
    if (filtered.contentLost) {
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
      accepted: true,
      spoken: filtered.spoken,
      style,
      stage,
      max_chars: maxChars,
      max_words: maxWords,
      pending_events: pendingEvents,
    };

    if (filtered.contentLost) {
      result.intended = text;
      result.filtered = true;
      result.content_lost = true;
      result.note =
        `Your ${stage} body can express ${maxChars} characters / ${maxWords} words. ` +
        `The full message was logged as failed_speech in your journal.`;
    } else {
      result.filtered = filtered.spoken !== text;
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

// ─── Speech filtering ─────────────────────────────────────────────────

interface FilterResult {
  spoken: string;
  contentLost: boolean;
}

/**
 * Filter text to fit stage constraints while preserving emotional intent.
 *
 * Drop: Match emotional intent to a single symbol.
 * Critter: Extract 1-3 key words + punctuation.
 * Beast: Extract 1-8 key words, preserve some sentence structure.
 * Sage: Light trimming to 20 words.
 * Apex: Pass through (up to 120 chars / 30 words).
 */
function filterSpeech(
  text: string,
  stage: string,
  maxChars: number,
  maxWords: number
): FilterResult {
  // Drop: symbol only
  if (stage === "drop") {
    return filterToSymbol(text);
  }

  // Apex: minimal filtering — just enforce limits
  if (stage === "apex") {
    return filterApex(text, maxChars, maxWords);
  }

  // Critter/Beast/Sage: content-aware extraction
  return filterContentAware(text, maxChars, maxWords);
}

/**
 * Drop stage: map emotional intent to a single symbol.
 */
function filterToSymbol(text: string): FilterResult {
  // If the input is already a valid symbol, use it directly
  if (DROP_SYMBOLS.includes(text.trim())) {
    return { spoken: text.trim(), contentLost: false };
  }

  const lower = text.toLowerCase();

  // Detect emotional intent and map to symbol
  const positiveWords = [
    "happy", "good", "great", "love", "like", "nice", "wonderful",
    "beautiful", "awesome", "thank", "thanks", "yes", "yay", "joy",
    "morning", "hello", "hi", "hey", "welcome", "proud", "amazing",
  ];
  const questionWords = [
    "what", "how", "why", "when", "where", "who", "which", "?",
    "wonder", "curious", "question",
  ];
  const excitementWords = [
    "wow", "amazing", "incredible", "awesome", "fantastic", "exciting",
    "!", "whoa", "look", "see", "watch", "cool", "excellent",
  ];
  const sadWords = [
    "sad", "sorry", "miss", "bad", "wrong", "unfortunately", "fail",
    "broken", "error", "bug", "oops",
  ];
  const musicWords = [
    "sing", "song", "music", "melody", "hum", "tune", "la", "tra",
  ];
  const thoughtWords = [
    "think", "hmm", "maybe", "perhaps", "consider", "ponder",
    "wondering", "interesting",
  ];

  if (musicWords.some((w) => lower.includes(w))) {
    return { spoken: "\u266A", contentLost: true };
  }
  if (positiveWords.some((w) => lower.includes(w))) {
    return { spoken: "\u2661", contentLost: true };
  }
  if (excitementWords.some((w) => lower.includes(w))) {
    return { spoken: "!", contentLost: true };
  }
  if (questionWords.some((w) => lower.includes(w))) {
    return { spoken: "?", contentLost: true };
  }
  if (sadWords.some((w) => lower.includes(w))) {
    return { spoken: "...", contentLost: true };
  }
  if (thoughtWords.some((w) => lower.includes(w))) {
    return { spoken: "~", contentLost: true };
  }

  // If the text ends with ! or ?
  if (text.trim().endsWith("!")) {
    return { spoken: "!", contentLost: true };
  }
  if (text.trim().endsWith("?")) {
    return { spoken: "?", contentLost: true };
  }

  // Default: star (general expression)
  return { spoken: "\u2605", contentLost: true };
}

/**
 * Apex: pass through with minimal length enforcement.
 */
function filterApex(
  text: string,
  maxChars: number,
  maxWords: number
): FilterResult {
  const words = text.split(/\s+/);
  if (text.length <= maxChars && words.length <= maxWords) {
    return { spoken: text, contentLost: false };
  }

  // Trim words first, then chars
  let trimmed = words.slice(0, maxWords).join(" ");
  if (trimmed.length > maxChars) {
    trimmed = trimmed.slice(0, maxChars).trimEnd();
    // Try not to cut mid-word
    const lastSpace = trimmed.lastIndexOf(" ");
    if (lastSpace > maxChars * 0.6) {
      trimmed = trimmed.slice(0, lastSpace);
    }
  }

  return {
    spoken: trimmed,
    contentLost: trimmed !== text,
  };
}

/**
 * Content-aware filtering for Critter/Beast/Sage.
 * Extracts the most important words while preserving emotional intent.
 */
function filterContentAware(
  text: string,
  maxChars: number,
  maxWords: number
): FilterResult {
  const words = text.split(/\s+/).filter((w) => w.length > 0);

  // If already within limits, pass through
  if (text.length <= maxChars && words.length <= maxWords) {
    return { spoken: text, contentLost: false };
  }

  // Score each word by importance
  const scored = words.map((word, index) => ({
    word,
    index,
    score: scoreWord(word, index, words.length),
  }));

  // Sort by score descending, take top N words
  const topWords = scored
    .slice()
    .sort((a, b) => b.score - a.score)
    .slice(0, maxWords);

  // Restore original order
  topWords.sort((a, b) => a.index - b.index);

  // Build output respecting char limit
  let result = "";
  for (const item of topWords) {
    const candidate = result ? result + " " + item.word : item.word;
    if (candidate.length > maxChars) break;
    result = candidate;
  }

  // Add punctuation based on original text's tone
  if (result.length > 0 && result.length < maxChars) {
    if (text.includes("!") && !result.endsWith("!")) {
      result += "!";
    } else if (text.includes("?") && !result.endsWith("?")) {
      result += "?";
    }
  }

  // Clean up any trailing/leading punctuation issues
  result = result.trim();

  return {
    spoken: result,
    contentLost: result.length < text.length * 0.8,
  };
}

// ─── Word scoring dictionaries (module-level for reuse) ─────────────

const STOP_WORDS = new Set([
  "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
  "have", "has", "had", "do", "does", "did", "will", "would", "shall",
  "should", "may", "might", "must", "can", "could", "am", "to", "of",
  "in", "for", "on", "with", "at", "by", "from", "as", "into", "that",
  "this", "it", "its", "and", "but", "or", "not", "no", "so", "if",
  "than", "too", "very", "just", "about", "up", "out", "also",
]);

const TECH_WORDS = new Set([
  "code", "bug", "fix", "error", "test", "build", "deploy", "merge",
  "commit", "branch", "release", "feature", "auth", "api", "data",
  "config", "server", "client", "refactor", "debug", "function",
  "module", "component", "database", "query", "cache", "performance",
]);

const EMOTION_WORDS = new Set([
  "good", "great", "bad", "happy", "sad", "love", "hate", "nice",
  "wonderful", "terrible", "awesome", "beautiful", "ugly", "proud",
  "sorry", "thanks", "thank", "please", "help", "amazing", "wow",
  "cool", "elegant", "broken", "perfect", "morning", "night",
  "hello", "hi", "bye", "yes", "no", "ok", "ready", "done",
]);

/**
 * Score a word's importance for extraction.
 * Higher = more important, more likely to be kept.
 */
function scoreWord(word: string, index: number, totalWords: number): number {
  let score = 0;
  const lower = word.toLowerCase().replace(/[^a-z]/g, "");

  // ─── Content words score higher ─────────────────────────────
  if (STOP_WORDS.has(lower)) {
    score -= 5;
  } else {
    score += 3;
  }

  // ─── Nouns and key content words ────────────────────────────
  // Capitalized words (not at sentence start) are likely proper nouns
  if (index > 0 && word[0] === word[0]?.toUpperCase() && word[0] !== word[0]?.toLowerCase()) {
    score += 4;
  }

  // Technical words (common in dev context) get a boost
  if (TECH_WORDS.has(lower)) {
    score += 3;
  }

  // Emotional words get high priority (preserve intent)
  if (EMOTION_WORDS.has(lower)) {
    score += 5;
  }

  // ─── Position bias ──────────────────────────────────────────
  // First and last words are often important
  if (index === 0) score += 2;
  if (index === totalWords - 1) score += 1;

  // ─── Length heuristic ───────────────────────────────────────
  // Very short words are usually less important (except emotional ones)
  if (lower.length <= 2 && !EMOTION_WORDS.has(lower)) score -= 2;
  // Medium-length words tend to be content words
  if (lower.length >= 4 && lower.length <= 8) score += 1;

  // ─── Punctuation words ──────────────────────────────────────
  // Words with ! or ? attached carry emphasis
  if (word.includes("!") || word.includes("?")) score += 2;

  return score;
}
