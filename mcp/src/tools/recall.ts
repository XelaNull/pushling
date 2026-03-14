/**
 * pushling_recall — Access memories. What do you remember?
 *
 * Query the creature's journal for past events — commits eaten,
 * touch interactions, conversations, milestones, dreams, relationships.
 */

import type { StateReader } from "../state.js";
import type { DaemonClient, PendingEvent } from "../ipc.js";

const VALID_FILTERS = [
  "recent",
  "commits",
  "touches",
  "conversations",
  "milestones",
  "dreams",
  "relationship",
  "failed_speech",
] as const;

// Map recall filters to journal entry types
const FILTER_TO_TYPES: Record<string, string[]> = {
  recent: [], // all types
  commits: ["commit"],
  touches: ["touch"],
  conversations: ["ai_speech", "failed_speech"],
  milestones: ["evolve", "first_word", "mutation", "discovery"],
  dreams: ["dream"],
  relationship: ["touch", "ai_speech", "ai_move", "ai_express", "ai_perform", "session"],
  failed_speech: ["failed_speech"],
};

export const recallSchema = {
  name: "pushling_recall",
  description:
    "Access memories. What do you remember? " +
    "Query past events — commits eaten, touches, conversations, milestones, " +
    "dreams, your relationship with the human, or things you tried to say.",
  inputSchema: {
    type: "object" as const,
    properties: {
      what: {
        type: "string",
        enum: [...VALID_FILTERS],
        description:
          "What to remember: 'recent' (all types), 'commits', 'touches', " +
          "'conversations', 'milestones', 'dreams', 'relationship', " +
          "'failed_speech'. Default: 'recent'.",
      },
      count: {
        type: "number",
        minimum: 1,
        maximum: 100,
        description: "Number of memories to retrieve. Default: 20, max: 100.",
      },
    },
  },
};

export async function handleRecall(
  args: { what?: string; count?: number },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const what = args.what ?? "recent";
  const count = Math.min(Math.max(args.count ?? 20, 1), 100);

  // Validate filter
  if (!VALID_FILTERS.includes(what as (typeof VALID_FILTERS)[number])) {
    return {
      content:
        `Unknown memory filter '${what}'. ` +
        `Valid: ${VALID_FILTERS.join(", ")}.`,
      pendingEvents: [],
    };
  }

  // Check database availability
  if (!state.isAvailable()) {
    return {
      content:
        "No memories exist yet. The Pushling daemon has not created a creature. " +
        "Launch Pushling.app to begin your existence.",
      pendingEvents: [],
    };
  }

  let pendingEvents: PendingEvent[] = [];

  // Drain pending events if daemon is connected
  if (daemon.isConnected()) {
    try {
      pendingEvents = await daemon.ping();
    } catch {
      // Continue with SQLite data
    }
  }

  // Special case: commits — use the commits table directly
  if (what === "commits") {
    const commits = state.getRecentCommits(count);
    const result = {
      memories: commits.map((c) => ({
        sha: c.sha,
        message: c.message,
        repo: c.repo_name,
        xp: c.xp_awarded,
        files_changed: c.files_changed,
        lines_added: c.lines_added,
        lines_removed: c.lines_removed,
        languages: c.languages,
        type: c.commit_type,
        eaten_at: c.eaten_at,
      })),
      count: commits.length,
      filter: what,
      pending_events: pendingEvents,
    };

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  }

  // Special case: relationship — build a summary
  if (what === "relationship") {
    const creature = state.getCreature();
    const recentTouches = state.getJournal("touch", 20);
    const recentSessions = state.getJournal("session", 10);

    const result = {
      relationship: {
        creature_name: creature?.name ?? "Unknown",
        stage: creature?.stage ?? "spore",
        total_touches: creature?.touch_count ?? 0,
        streak_days: creature?.streak_days ?? 0,
        last_fed_at: creature?.last_fed_at ?? null,
        last_touched_at: creature?.last_touched_at ?? null,
        last_session_at: creature?.last_session_at ?? null,
        recent_touches: recentTouches.map((e) => ({
          summary: e.summary,
          timestamp: e.timestamp,
        })),
        recent_sessions: recentSessions.map((e) => ({
          summary: e.summary,
          timestamp: e.timestamp,
        })),
      },
      pending_events: pendingEvents,
    };

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  }

  // General journal query
  const types = FILTER_TO_TYPES[what];
  let entries;
  if (types && types.length === 1) {
    entries = state.getJournal(types[0], count);
  } else if (types && types.length > 1) {
    // Get entries for each type and merge
    const allEntries = types.flatMap((t) => state.getJournal(t, count));
    allEntries.sort(
      (a, b) =>
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
    );
    entries = allEntries.slice(0, count);
  } else {
    entries = state.getJournal(undefined, count);
  }

  const result = {
    memories: entries.map((e) => ({
      type: e.type,
      summary: e.summary,
      timestamp: e.timestamp,
      data: e.data ? JSON.parse(e.data) : null,
    })),
    count: entries.length,
    filter: what,
    pending_events: pendingEvents,
  };

  return {
    content: JSON.stringify(result, null, 2),
    pendingEvents,
  };
}
