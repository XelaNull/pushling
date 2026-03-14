/**
 * Handler functions for pushling_teach — compose, preview/refine, commit, remove, reinforce.
 *
 * Extracted from teach.ts to keep it under the 500-line limit.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";

const VALID_CATEGORIES = [
  "playful", "affectionate", "dramatic", "calm", "silly", "functional",
] as const;

const VALID_TRACKS = [
  "body", "head", "ears", "eyes", "tail", "mouth", "whiskers",
  "paw_fl", "paw_fr", "paw_bl", "paw_br",
  "particles", "aura", "speech", "sound", "movement",
] as const;

const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];
const MAX_TAUGHT = 30;

type TeachResult = { content: string; pendingEvents: PendingEvent[] };

export interface ComposeArgs {
  name?: string;
  category?: string;
  duration_s?: number;
  stage_min?: string;
  tracks?: Record<string, unknown>;
  triggers?: Record<string, unknown>;
}

export async function handleCompose(
  args: ComposeArgs,
  state: StateReader,
  daemon: DaemonClient
): Promise<TeachResult> {
  if (!args.name) {
    return { content: "compose requires a 'name' for the behavior. Choose a descriptive name like 'roll_over', 'victory_dance', 'shy_wave'.", pendingEvents: [] };
  }
  if (!args.category) {
    return { content: `compose requires a 'category'. Valid: ${VALID_CATEGORIES.join(", ")}.`, pendingEvents: [] };
  }
  if (!VALID_CATEGORIES.includes(args.category as (typeof VALID_CATEGORIES)[number])) {
    return { content: `Unknown category '${args.category}'. Valid: ${VALID_CATEGORIES.join(", ")}.`, pendingEvents: [] };
  }
  if (!args.duration_s) {
    return { content: "compose requires 'duration_s' (total duration in seconds, 0.5-15.0).", pendingEvents: [] };
  }
  if (args.duration_s < 0.5 || args.duration_s > 15.0) {
    return { content: `duration_s must be between 0.5 and 15.0 seconds. Got: ${args.duration_s}.`, pendingEvents: [] };
  }
  if (!args.tracks || Object.keys(args.tracks).length === 0) {
    return {
      content: "compose requires 'tracks' — at least one body-part track with keyframes. " +
        `Valid tracks: ${VALID_TRACKS.join(", ")}. ` +
        `Example: {"body": [{"t": 0.0, "pose": "crouch"}, {"t": 1.0, "pose": "stand"}]}`,
      pendingEvents: [],
    };
  }
  for (const trackName of Object.keys(args.tracks)) {
    if (!VALID_TRACKS.includes(trackName as (typeof VALID_TRACKS)[number])) {
      return { content: `Unknown track '${trackName}'. Valid tracks: ${VALID_TRACKS.join(", ")}.`, pendingEvents: [] };
    }
  }
  if (args.stage_min && !STAGE_ORDER.includes(args.stage_min)) {
    return { content: `Unknown stage '${args.stage_min}'. Valid: ${STAGE_ORDER.join(", ")}.`, pendingEvents: [] };
  }

  const existing = state.getTaughtBehaviors();
  if (existing.length >= MAX_TAUGHT) {
    return { content: `Cannot compose — ${existing.length}/${MAX_TAUGHT} taught behaviors. Remove one first.`, pendingEvents: [] };
  }
  const dupe = state.getTaughtBehaviorByName(args.name);
  if (dupe) {
    return { content: `A behavior named '${args.name}' already exists (created ${dupe.created_at}). Choose a different name.`, pendingEvents: [] };
  }

  try {
    const params: Record<string, unknown> = {
      name: args.name, category: args.category, duration_s: args.duration_s,
      stage_min: args.stage_min ?? "critter",
      tracks: args.tracks, triggers: args.triggers ?? { idle_weight: 0.3 },
    };
    const response = await daemon.send("teach", "compose", params);
    const pe = response.pending_events ?? [];
    if (!response.ok) return { content: response.error ?? "Compose rejected by daemon.", pendingEvents: pe };
    return {
      content: JSON.stringify({
        accepted: true, action: "compose", name: args.name, category: args.category,
        duration_s: args.duration_s, tracks_count: Object.keys(args.tracks).length,
        draft_id: response.data?.draft_id ?? null,
        note: "Draft created. Use 'preview' to see it play, 'refine' to adjust, or 'commit' to save permanently.",
        pending_events: pe,
      }, null, 2),
      pendingEvents: pe,
    };
  } catch (err) {
    return { content: `Failed to compose: ${err instanceof Error ? err.message : String(err)}`, pendingEvents: [] };
  }
}

export async function handlePreviewOrRefine(
  action: "preview" | "refine",
  args: { tracks?: Record<string, unknown> },
  daemon: DaemonClient
): Promise<TeachResult> {
  try {
    const params: Record<string, unknown> = {};
    if (args.tracks) params.tracks = args.tracks;
    const response = await daemon.send("teach", action, params);
    const pe = response.pending_events ?? [];
    if (!response.ok) return { content: response.error ?? `${action} rejected.`, pendingEvents: pe };
    return {
      content: JSON.stringify({
        accepted: true, action, ...(response.data ?? {}),
        note: action === "preview" ? "Behavior playing once. Watch the Touch Bar." : "Draft refined. Preview again or commit when satisfied.",
        pending_events: pe,
      }, null, 2),
      pendingEvents: pe,
    };
  } catch (err) {
    return { content: `Failed to ${action}: ${err instanceof Error ? err.message : String(err)}`, pendingEvents: [] };
  }
}

export async function handleCommit(
  args: { name?: string },
  state: StateReader,
  daemon: DaemonClient
): Promise<TeachResult> {
  const existing = state.getTaughtBehaviors();
  if (existing.length >= MAX_TAUGHT) {
    return { content: `Cannot commit — ${existing.length}/${MAX_TAUGHT} taught behaviors.`, pendingEvents: [] };
  }
  try {
    const params: Record<string, unknown> = {};
    if (args.name) params.name = args.name;
    const response = await daemon.send("teach", "commit", params);
    const pe = response.pending_events ?? [];
    if (!response.ok) return { content: response.error ?? "Commit rejected.", pendingEvents: pe };
    return {
      content: JSON.stringify({
        accepted: true, action: "commit", ...(response.data ?? {}),
        note: "Behavior saved permanently. The learning ceremony is playing. This trick will now appear in idle rotation.",
        pending_events: pe,
      }, null, 2),
      pendingEvents: pe,
    };
  } catch (err) {
    return { content: `Failed to commit: ${err instanceof Error ? err.message : String(err)}`, pendingEvents: [] };
  }
}

export async function handleRemove(
  args: { name?: string },
  daemon: DaemonClient
): Promise<TeachResult> {
  if (!args.name) return { content: "remove requires a 'name' — the behavior to remove.", pendingEvents: [] };
  if (!daemon.isConnected()) return { content: "Your creature cannot unlearn — the daemon is not running.", pendingEvents: [] };
  try {
    const response = await daemon.send("teach", "remove", { name: args.name });
    const pe = response.pending_events ?? [];
    if (!response.ok) return { content: response.error ?? `Remove '${args.name}' rejected.`, pendingEvents: pe };
    return {
      content: JSON.stringify({ accepted: true, action: "remove", name: args.name,
        note: `Behavior '${args.name}' has been forgotten.`, pending_events: pe }, null, 2),
      pendingEvents: pe,
    };
  } catch (err) {
    return { content: `Failed to remove: ${err instanceof Error ? err.message : String(err)}`, pendingEvents: [] };
  }
}

export async function handleReinforce(
  args: { name?: string },
  state: StateReader,
  daemon: DaemonClient
): Promise<TeachResult> {
  if (!args.name) return { content: "reinforce requires a 'name' — the behavior to strengthen (+0.15).", pendingEvents: [] };
  const behavior = state.getTaughtBehaviorByName(args.name);
  if (!behavior) {
    const names = state.getTaughtBehaviors().map((b) => b.name);
    return {
      content: `No behavior named '${args.name}'. ` +
        (names.length > 0 ? `Known: ${names.join(", ")}.` : "No behaviors taught yet."),
      pendingEvents: [],
    };
  }
  if (!daemon.isConnected()) return { content: "Your creature cannot be reinforced — the daemon is not running.", pendingEvents: [] };
  try {
    const response = await daemon.send("teach", "reinforce", { name: args.name });
    const pe = response.pending_events ?? [];
    if (!response.ok) return { content: response.error ?? `Reinforce rejected.`, pendingEvents: pe };
    return {
      content: JSON.stringify({
        accepted: true, action: "reinforce", name: args.name,
        previous_strength: behavior.strength,
        new_strength: Math.round(Math.min(1.0, behavior.strength + 0.15) * 100) / 100,
        reinforcement_count: behavior.reinforcement_count + 1,
        note: `'${args.name}' reinforced. It will appear more often in idle rotation.`,
        pending_events: pe,
      }, null, 2),
      pendingEvents: pe,
    };
  } catch (err) {
    return { content: `Failed to reinforce: ${err instanceof Error ? err.message : String(err)}`, pendingEvents: [] };
  }
}
