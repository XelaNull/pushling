/**
 * pushling_recall — Access memories. What do you remember?
 *
 * Query the creature's journal for past events — commits eaten,
 * touch interactions, conversations, milestones, dreams, relationships.
 * Each memory is framed as proprioceptive recall — "I remember..."
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
  relationship: [
    "touch",
    "ai_speech",
    "ai_move",
    "ai_express",
    "ai_perform",
    "session",
  ],
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

  const now = Date.now();

  // Special case: commits — use the commits table directly for richer data
  if (what === "commits") {
    const commits = state.getRecentCommits(count);
    const result = {
      filter: "commits",
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
        is_merge: c.is_merge === 1,
        is_revert: c.is_revert === 1,
        eaten_at: c.eaten_at,
        ago_s: Math.floor(
          (now - new Date(c.eaten_at).getTime()) / 1000
        ),
      })),
      count: commits.length,
      pending_events: pendingEvents,
    };

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  }

  // Special case: relationship — build a computed summary
  if (what === "relationship") {
    return buildRelationshipSummary(state, pendingEvents);
  }

  // Special case: failed_speech — include intended vs spoken
  if (what === "failed_speech") {
    const entries = state.getJournal("failed_speech", count);
    const result = {
      filter: "failed_speech",
      memories: entries.map((e) => {
        const data = safeParseJSON(e.data);
        return {
          summary: e.summary,
          intended: data?.intended ?? null,
          spoken: data?.spoken ?? null,
          style: data?.style ?? null,
          stage: data?.stage ?? null,
          ago_s: Math.floor(
            (now - new Date(e.timestamp).getTime()) / 1000
          ),
          timestamp: e.timestamp,
        };
      }),
      count: entries.length,
      message:
        entries.length === 0
          ? "No failed speech attempts found. Either your stage allows full expression, or you have not yet tried to speak."
          : `${entries.length} messages your body could not fully express.`,
      pending_events: pendingEvents,
    };

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  }

  // Special case: dreams — default to fewer
  if (what === "dreams") {
    const dreamCount = Math.min(count, args.count ?? 10);
    const entries = state.getJournal("dream", dreamCount);
    const result = {
      filter: "dreams",
      memories: entries.map((e) => ({
        summary: e.summary,
        ago_s: Math.floor(
          (now - new Date(e.timestamp).getTime()) / 1000
        ),
        timestamp: e.timestamp,
        data: safeParseJSON(e.data),
      })),
      count: entries.length,
      pending_events: pendingEvents,
    };

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  }

  // Special case: milestones — include milestone table data
  if (what === "milestones") {
    const milestones = state.getMilestones();
    const journalEntries = getMultiTypeJournal(state, FILTER_TO_TYPES.milestones!, count);

    const result = {
      filter: "milestones",
      achievements: milestones.slice(0, count).map((m) => ({
        id: m.id,
        category: m.category,
        earned_at: m.earned_at,
        ago_s: m.earned_at
          ? Math.floor(
              (now - new Date(m.earned_at).getTime()) / 1000
            )
          : null,
        data: safeParseJSON(m.data_json),
      })),
      journal_memories: journalEntries.map((e) => ({
        type: e.type,
        summary: e.summary,
        ago_s: Math.floor(
          (now - new Date(e.timestamp).getTime()) / 1000
        ),
        timestamp: e.timestamp,
        data: safeParseJSON(e.data),
      })),
      count: milestones.length,
      pending_events: pendingEvents,
    };

    return {
      content: JSON.stringify(result, null, 2),
      pendingEvents,
    };
  }

  // General journal query (recent, touches, conversations)
  const types = FILTER_TO_TYPES[what];
  let entries;
  if (types && types.length === 1) {
    entries = state.getJournal(types[0], count);
  } else if (types && types.length > 1) {
    entries = getMultiTypeJournal(state, types, count);
  } else {
    entries = state.getJournal(undefined, count);
  }

  const result = {
    filter: what,
    memories: entries.map((e) => ({
      type: e.type,
      summary: e.summary,
      ago_s: Math.floor(
        (now - new Date(e.timestamp).getTime()) / 1000
      ),
      timestamp: e.timestamp,
      data: safeParseJSON(e.data),
    })),
    count: entries.length,
    pending_events: pendingEvents,
  };

  return {
    content: JSON.stringify(result, null, 2),
    pendingEvents,
  };
}

// ─── Relationship summary ─────────────────────────────────────────────

function buildRelationshipSummary(
  state: StateReader,
  pendingEvents: PendingEvent[]
): { content: string; pendingEvents: PendingEvent[] } {
  const creature = state.getCreature();
  const recentTouches = state.getJournal("touch", 50);
  const recentSessions = state.getJournal("session", 20);
  const recentConversations = state.getJournal("ai_speech", 20);
  const totalCommits = creature?.commits_eaten ?? 0;

  // Compute trust level from interaction frequency
  const touchCount = creature?.touch_count ?? 0;
  let trustLevel: string;
  if (touchCount === 0) {
    trustLevel = "stranger";
  } else if (touchCount < 10) {
    trustLevel = "acquaintance";
  } else if (touchCount < 50) {
    trustLevel = "companion";
  } else if (touchCount < 200) {
    trustLevel = "trusted friend";
  } else {
    trustLevel = "bonded";
  }

  // Compute favorite interaction
  const interactionCounts: Record<string, number> = {};
  for (const t of recentTouches) {
    const data = safeParseJSON(t.data);
    const gesture = (data?.gesture as string) ?? "tap";
    interactionCounts[gesture] = (interactionCounts[gesture] ?? 0) + 1;
  }
  let favoriteInteraction = "none yet";
  let maxCount = 0;
  for (const [gesture, cnt] of Object.entries(interactionCounts)) {
    if (cnt > maxCount) {
      maxCount = cnt;
      favoriteInteraction = gesture;
    }
  }

  // Longest session
  let longestSessionS = 0;
  for (const s of recentSessions) {
    const data = safeParseJSON(s.data);
    const dur = (data?.duration_s as number) ?? 0;
    if (dur > longestSessionS) longestSessionS = dur;
  }

  const result = {
    filter: "relationship",
    relationship: {
      creature_name: creature?.name ?? "Unknown",
      stage: creature?.stage ?? "spore",
      trust_level: trustLevel,
      total_touches: touchCount,
      total_commits_fed: totalCommits,
      streak_days: creature?.streak_days ?? 0,
      favorite_interaction: favoriteInteraction,
      longest_session_s: longestSessionS,
      last_fed_at: creature?.last_fed_at ?? null,
      last_touched_at: creature?.last_touched_at ?? null,
      last_session_at: creature?.last_session_at ?? null,
      recent_conversations: recentConversations.slice(0, 5).map((e) => ({
        summary: e.summary,
        timestamp: e.timestamp,
      })),
      session_count: recentSessions.length,
    },
    pending_events: pendingEvents,
  };

  return {
    content: JSON.stringify(result, null, 2),
    pendingEvents,
  };
}

// ─── Helpers ──────────────────────────────────────────────────────────

function getMultiTypeJournal(
  state: StateReader,
  types: string[],
  count: number
): { id: number; type: string; summary: string; timestamp: string; data: string | null }[] {
  const allEntries = types.flatMap((t) => state.getJournal(t, count));
  allEntries.sort(
    (a, b) =>
      new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
  );
  return allEntries.slice(0, count);
}

function safeParseJSON(data: string | null): Record<string, unknown> | null {
  if (!data) return null;
  try {
    return JSON.parse(data) as Record<string, unknown>;
  } catch {
    return null;
  }
}
