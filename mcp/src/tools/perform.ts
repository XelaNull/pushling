/**
 * pushling_perform — Complex animations and choreographed sequences.
 *
 * Single behaviors (wave, spin, backflip) or multi-step sequences
 * that chain moves, expressions, speech, and performances together.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";

interface SequenceStep {
  tool: string;
  params: Record<string, unknown>;
  delay_ms?: number;
  await_previous?: boolean;
}

const VALID_BEHAVIORS: Record<string, { stage_min: string; variants: string[] }> = {
  wave:      { stage_min: "drop",    variants: ["big", "small", "both_paws"] },
  spin:      { stage_min: "drop",    variants: ["left", "right", "fast"] },
  bow:       { stage_min: "critter", variants: ["deep", "quick", "theatrical"] },
  dance:     { stage_min: "critter", variants: ["waltz", "jig", "moonwalk"] },
  peek:      { stage_min: "critter", variants: ["left", "right", "above"] },
  meditate:  { stage_min: "beast",   variants: ["brief", "deep", "transcendent"] },
  flex:      { stage_min: "beast",   variants: ["casual", "dramatic"] },
  backflip:  { stage_min: "beast",   variants: ["single", "double"] },
  dig:       { stage_min: "critter", variants: ["shallow", "deep", "frantic"] },
  examine:   { stage_min: "drop",    variants: ["sniff", "paw", "stare"] },
  nap:       { stage_min: "spore",   variants: ["light", "deep", "dream"] },
  celebrate: { stage_min: "drop",    variants: ["small", "big", "legendary"] },
  shiver:    { stage_min: "spore",   variants: ["cold", "nervous", "excited"] },
  stretch:   { stage_min: "critter", variants: ["morning", "lazy", "dramatic"] },
  play_dead: { stage_min: "beast",   variants: ["dramatic", "convincing"] },
  conduct:   { stage_min: "sage",    variants: ["gentle", "vigorous", "crescendo"] },
  glitch:    { stage_min: "apex",    variants: ["minor", "major", "existential"] },
  transcend: { stage_min: "apex",    variants: ["brief", "full"] },
};

const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];

function stageIndex(stage: string): number {
  return STAGE_ORDER.indexOf(stage);
}

function behaviorsAvailableAt(stage: string): string[] {
  const si = stageIndex(stage);
  return Object.entries(VALID_BEHAVIORS)
    .filter(([, def]) => stageIndex(def.stage_min) <= si)
    .map(([name]) => name);
}

export const performSchema = {
  name: "pushling_perform",
  description:
    "Complex animations and choreographed sequences. Do something expressive. " +
    "Use a single behavior (wave, spin, backflip, dance) or chain up to 10 steps " +
    "into a choreographed sequence. Stage-gated — some behaviors require higher stages.",
  inputSchema: {
    type: "object" as const,
    properties: {
      behavior: {
        type: "string",
        enum: Object.keys(VALID_BEHAVIORS),
        description:
          "Single behavior to perform. Stage-gated. " +
          "Omit if using sequence mode.",
      },
      variant: {
        type: "string",
        description:
          "Variant of the behavior (e.g., 'big' for wave, 'moonwalk' for dance). " +
          "Each behavior has 2-3 variants. Optional.",
      },
      sequence: {
        type: "array",
        items: {
          type: "object",
          properties: {
            tool: {
              type: "string",
              enum: ["move", "express", "speak", "perform"],
              description: "Which tool to invoke in this step.",
            },
            params: {
              type: "object",
              description: "Parameters for the tool.",
            },
            delay_ms: {
              type: "number",
              minimum: 0,
              maximum: 5000,
              description:
                "Wait before executing this step (0-5000ms). Default: 0.",
            },
            await_previous: {
              type: "boolean",
              description:
                "Wait for previous step's animation to complete before starting delay.",
            },
          },
          required: ["tool", "params"],
        },
        description:
          "Sequence mode: chain up to 10 steps into a performance. " +
          "Each step invokes move, express, speak, or perform. " +
          "Omit if using single behavior mode.",
      },
      label: {
        type: "string",
        description:
          "Optional name for a sequence performance, logged in journal.",
      },
    },
  },
};

export async function handlePerform(
  args: {
    behavior?: string;
    variant?: string;
    sequence?: SequenceStep[];
    label?: string;
  },
  state: StateReader,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
  const { behavior, variant, sequence, label } = args;

  // Must provide either behavior or sequence
  if (!behavior && !sequence) {
    return {
      content:
        "Provide either 'behavior' for a single performance or 'sequence' " +
        "for a choreographed multi-step performance. " +
        `Available behaviors: ${Object.keys(VALID_BEHAVIORS).join(", ")}.`,
      pendingEvents: [],
    };
  }

  const creature = state.getCreature();
  const stage = creature?.stage ?? "spore";

  // ─── Single behavior mode ──────────────────────────────────────
  if (behavior) {
    const def = VALID_BEHAVIORS[behavior];
    if (!def) {
      return {
        content:
          `Unknown behavior '${behavior}'. ` +
          `Valid: ${Object.keys(VALID_BEHAVIORS).join(", ")}.`,
        pendingEvents: [],
      };
    }

    // Stage gate
    if (stageIndex(stage) < stageIndex(def.stage_min)) {
      const available = behaviorsAvailableAt(stage);
      return {
        content:
          `Your body can't do that yet. '${behavior}' requires ${def.stage_min} stage. ` +
          `At ${stage}, you can: ${available.join(", ")}.`,
        pendingEvents: [],
      };
    }

    // Validate variant
    if (variant && !def.variants.includes(variant)) {
      return {
        content:
          `Unknown variant '${variant}' for ${behavior}. ` +
          `Valid variants: ${def.variants.join(", ")}.`,
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
      const params: Record<string, unknown> = { behavior };
      if (variant) params.variant = variant;

      const response = await daemon.send("perform", behavior, params);
      const pendingEvents = response.pending_events ?? [];

      if (!response.ok) {
        return {
          content: response.error ?? "Performance rejected by daemon.",
          pendingEvents,
        };
      }

      return {
        content: JSON.stringify(
          {
            ok: true,
            behavior,
            variant: variant ?? null,
            pending_events: pendingEvents,
          },
          null,
          2
        ),
        pendingEvents,
      };
    } catch (err) {
      return {
        content: `Failed to perform: ${err instanceof Error ? err.message : String(err)}`,
        pendingEvents: [],
      };
    }
  }

  // ─── Sequence mode ─────────────────────────────────────────────
  if (sequence) {
    // Validate sequence length
    if (sequence.length === 0) {
      return {
        content: "Sequence cannot be empty. Provide 1-10 steps.",
        pendingEvents: [],
      };
    }
    if (sequence.length > 10) {
      return {
        content:
          `Sequence too long: ${sequence.length} steps. Maximum is 10. ` +
          `Trim some steps or break into multiple performances.`,
        pendingEvents: [],
      };
    }

    // Validate each step
    const validTools = ["move", "express", "speak", "perform"];
    for (let i = 0; i < sequence.length; i++) {
      const step = sequence[i]!;
      if (!validTools.includes(step.tool)) {
        return {
          content:
            `Step ${i + 1}: invalid tool '${step.tool}'. ` +
            `Valid tools in sequences: ${validTools.join(", ")}. ` +
            `Note: 'perform' in sequence mode cannot nest another sequence.`,
          pendingEvents: [],
        };
      }
      if (step.delay_ms !== undefined && (step.delay_ms < 0 || step.delay_ms > 5000)) {
        return {
          content: `Step ${i + 1}: delay_ms must be 0-5000. Got: ${step.delay_ms}.`,
          pendingEvents: [],
        };
      }
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
      const params: Record<string, unknown> = { sequence };
      if (label) params.label = label;

      const response = await daemon.send("perform", "sequence", params);
      const pendingEvents = response.pending_events ?? [];

      if (!response.ok) {
        return {
          content: response.error ?? "Sequence rejected by daemon.",
          pendingEvents,
        };
      }

      return {
        content: JSON.stringify(
          {
            ok: true,
            mode: "sequence",
            steps: sequence.length,
            label: label ?? null,
            pending_events: pendingEvents,
          },
          null,
          2
        ),
        pendingEvents,
      };
    } catch (err) {
      return {
        content: `Failed to perform sequence: ${err instanceof Error ? err.message : String(err)}`,
        pendingEvents: [],
      };
    }
  }

  // Should not reach here
  return {
    content: "Provide either 'behavior' or 'sequence'.",
    pendingEvents: [],
  };
}
