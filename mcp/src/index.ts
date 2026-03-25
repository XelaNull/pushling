#!/usr/bin/env node
/**
 * Pushling MCP Server — 9 embodiment tools for Claude to inhabit a Touch Bar creature.
 *
 * Communicates via stdio transport (Claude Code launches this as a subprocess).
 * Reads creature state from SQLite (read-only).
 * Sends commands to the Pushling daemon via Unix socket IPC.
 *
 * Install: claude mcp add pushling -- node mcp/dist/index.js
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import { DaemonClient } from "./ipc.js";
import { StateReader } from "./state.js";
import { handleSense, senseSchema } from "./tools/sense.js";
import { handleMove, moveSchema } from "./tools/move.js";
import { handleExpress, expressSchema } from "./tools/express.js";
import { handleSpeak, speakSchema } from "./tools/speak.js";
import { handlePerform, performSchema } from "./tools/perform.js";
import { handleWorld, worldSchema } from "./tools/world.js";
import { handleRecall, recallSchema } from "./tools/recall.js";
import { handleTeach, teachSchema } from "./tools/teach.js";
import { handleNurture, nurtureSchema } from "./tools/nurture.js";

// ─── Shared instances ────────────────────────────────────────────────

const state = new StateReader();
const daemon = new DaemonClient();

// ─── Pending events formatting ───────────────────────────────────────

function formatPendingEvents(
  events: { type: string; timestamp: string; data: Record<string, unknown> }[]
): string {
  if (!events || events.length === 0) return "";

  const now = Date.now();
  const lines = events.map((e) => {
    const agoMs = now - new Date(e.timestamp).getTime();
    const agoStr = formatAgo(agoMs);
    const prefix = agoMs > 3600000 ? "(earlier) " : "";
    return `  * ${prefix}${agoStr}: ${eventSummary(e)}`;
  });

  // Summarize if too many
  if (lines.length > 10) {
    const shown = lines.slice(0, 8);
    const remaining = lines.length - 8;
    shown.push(`  * ...and ${remaining} more events`);
    return "\n\n--- What happened since you last checked ---\n" + shown.join("\n");
  }

  return "\n\n--- What happened since you last checked ---\n" + lines.join("\n");
}

function formatAgo(ms: number): string {
  if (ms < 60000) return `${Math.floor(ms / 1000)}s ago`;
  if (ms < 3600000) return `${Math.floor(ms / 60000)}m ago`;
  return `${Math.floor(ms / 3600000)}h ago`;
}

function eventSummary(event: {
  type: string;
  data: Record<string, unknown>;
}): string {
  switch (event.type) {
    case "commit": {
      const xp = (event.data.xp as number) ?? 0;
      const msg = event.data.message ?? event.data.sha ?? "something";
      if (xp >= 30) return `Devoured "${msg}" -- a feast! +${xp} XP`;
      if (xp >= 15) return `Ate "${msg}" -- satisfying. +${xp} XP`;
      return `Nibbled "${msg}" -- a snack. +${xp} XP`;
    }
    case "touch": {
      const gesture = event.data.gesture ?? "tap";
      if (gesture === "pet") return "The developer stroked your back. Warmth.";
      if (gesture === "tap") return "A tap. The developer's finger, brief and warm.";
      if (gesture === "swipe") return "A swipe across your body. Playful.";
      return `Human touched you (${gesture})`;
    }
    case "surprise":
      return `Surprise: ${event.data.name ?? "something unexpected"}`;
    case "evolve":
      return `EVOLVED to ${event.data.stage}! Your body transformed. You are something new.`;
    case "weather_change":
      return `The weather shifted to ${event.data.weather}. You feel it on your fur.`;
    case "session":
      return `Claude session ${event.data.action ?? "event"}`;
    default:
      return `${event.type}: ${JSON.stringify(event.data)}`;
  }
}

// ─── Server setup ────────────────────────────────────────────────────

const server = new McpServer({
  name: "pushling-mcp",
  version: "0.1.0",
});

// ─── Tool registration ──────────────────────────────────────────────

// pushling_sense
server.tool(
  senseSchema.name,
  senseSchema.description,
  {
    aspect: z.string().optional().describe(
      senseSchema.inputSchema.properties.aspect.description
    ),
  },
  async (args) => {
    const result = await handleSense(args, state, daemon);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_move
server.tool(
  moveSchema.name,
  moveSchema.description,
  {
    action: z.string().describe(
      moveSchema.inputSchema.properties.action.description
    ),
    target: z.string().optional().describe(
      moveSchema.inputSchema.properties.target.description
    ),
    speed: z.string().optional().describe(
      moveSchema.inputSchema.properties.speed.description
    ),
  },
  async (args) => {
    const result = await handleMove(args, daemon, state);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_express
server.tool(
  expressSchema.name,
  expressSchema.description,
  {
    expression: z.string().describe(
      expressSchema.inputSchema.properties.expression.description
    ),
    intensity: z.number().optional().describe(
      expressSchema.inputSchema.properties.intensity.description
    ),
    duration: z.number().optional().describe(
      expressSchema.inputSchema.properties.duration.description
    ),
  },
  async (args) => {
    const result = await handleExpress(args, daemon);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_speak
server.tool(
  speakSchema.name,
  speakSchema.description,
  {
    text: z.string().describe(
      speakSchema.inputSchema.properties.text.description
    ),
    style: z.string().optional().describe(
      speakSchema.inputSchema.properties.style.description
    ),
  },
  async (args) => {
    const result = await handleSpeak(args, state, daemon);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_perform
server.tool(
  performSchema.name,
  performSchema.description,
  {
    behavior: z.string().optional().describe(
      performSchema.inputSchema.properties.behavior.description
    ),
    variant: z.string().optional().describe(
      performSchema.inputSchema.properties.variant.description
    ),
    sequence: z.array(
      z.object({
        tool: z.string(),
        params: z.record(z.string(), z.unknown()),
        delay_ms: z.number().optional(),
        await_previous: z.boolean().optional(),
      })
    ).optional().describe(
      performSchema.inputSchema.properties.sequence.description
    ),
    label: z.string().optional().describe(
      performSchema.inputSchema.properties.label.description
    ),
  },
  async (args) => {
    const result = await handlePerform(args, state, daemon);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_world
server.tool(
  worldSchema.name,
  worldSchema.description,
  {
    action: z.string().describe(
      worldSchema.inputSchema.properties.action.description
    ),
    params: z.record(z.string(), z.unknown()).describe(
      worldSchema.inputSchema.properties.params.description
    ),
  },
  async (args) => {
    const result = await handleWorld(args, daemon, state);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_recall
server.tool(
  recallSchema.name,
  recallSchema.description,
  {
    what: z.string().optional().describe(
      recallSchema.inputSchema.properties.what.description
    ),
    count: z.number().optional().describe(
      recallSchema.inputSchema.properties.count.description
    ),
  },
  async (args) => {
    const result = await handleRecall(args, state, daemon);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_teach
server.tool(
  teachSchema.name,
  teachSchema.description,
  {
    action: z.string().describe(
      teachSchema.inputSchema.properties.action.description
    ),
    name: z.string().optional().describe(
      teachSchema.inputSchema.properties.name.description
    ),
    category: z.string().optional().describe(
      teachSchema.inputSchema.properties.category.description
    ),
    duration_s: z.number().optional().describe(
      teachSchema.inputSchema.properties.duration_s.description
    ),
    stage_min: z.string().optional().describe(
      teachSchema.inputSchema.properties.stage_min.description
    ),
    tracks: z.record(z.string(), z.unknown()).optional().describe(
      teachSchema.inputSchema.properties.tracks.description
    ),
    triggers: z.record(z.string(), z.unknown()).optional().describe(
      teachSchema.inputSchema.properties.triggers.description
    ),
  },
  async (args) => {
    const result = await handleTeach(args, state, daemon);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// pushling_nurture
server.tool(
  nurtureSchema.name,
  nurtureSchema.description,
  {
    action: z.string().describe(
      nurtureSchema.inputSchema.properties.action.description
    ),
    type: z.string().describe(
      nurtureSchema.inputSchema.properties.type.description
    ),
    params: z.record(z.string(), z.unknown()).optional().describe(
      nurtureSchema.inputSchema.properties.params.description
    ),
  },
  async (args) => {
    const result = await handleNurture(args, state, daemon);
    const eventsText = formatPendingEvents(result.pendingEvents);
    return {
      content: [{ type: "text", text: result.content + eventsText }],
    };
  }
);

// ─── Lifecycle ───────────────────────────────────────────────────────

async function startup(): Promise<void> {
  // Open SQLite (read-only) — works even if daemon is not running
  const dbAvailable = state.open();
  if (dbAvailable) {
    console.error("[pushling-mcp] SQLite connected (read-only)");
  } else {
    console.error(
      "[pushling-mcp] SQLite not available — daemon may not have run yet"
    );
  }

  // Try to connect to daemon — non-fatal if it fails
  try {
    await daemon.connect();
    const session = await daemon.startSession();
    console.error(
      `[pushling-mcp] Daemon connected, session: ${session.sessionId}`
    );
  } catch {
    console.error(
      "[pushling-mcp] Daemon not running — read-only mode. " +
        "Tools that modify state will return helpful errors."
    );
  }
}

async function shutdown(): Promise<void> {
  await daemon.disconnect();
  state.close();
  console.error("[pushling-mcp] Shutdown complete");
}

// ─── Main ────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  await startup();

  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Handle process signals for clean shutdown
  process.on("SIGINT", async () => {
    await shutdown();
    process.exit(0);
  });
  process.on("SIGTERM", async () => {
    await shutdown();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("[pushling-mcp] Fatal error:", err);
  process.exit(1);
});
