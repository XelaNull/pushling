/**
 * pushling_perform — Complex animations and choreographed sequences.
 *
 * Single behaviors (wave, spin, backflip) or multi-step sequences
 * that chain moves, expressions, speech, and performances together.
 * Stage-gated — some behaviors require higher growth stages.
 *
 * Returns immediately with estimated duration. Does not block on completion.
 */

import type { DaemonClient, PendingEvent } from "../ipc.js";
import type { StateReader } from "../state.js";

interface SequenceStep {
  tool: string;
  params: Record<string, unknown>;
  delay_ms?: number;
  await_previous?: boolean;
}

const VALID_BEHAVIORS: Record<
  string,
  { stage_min: string; variants: string[]; duration_ms: number }
> = {
  wave: {
    stage_min: "drop",
    variants: ["big", "small", "both_paws"],
    duration_ms: 1500,
  },
  spin: {
    stage_min: "drop",
    variants: ["left", "right", "fast"],
    duration_ms: 1200,
  },
  bow: {
    stage_min: "critter",
    variants: ["deep", "quick", "theatrical"],
    duration_ms: 2000,
  },
  dance: {
    stage_min: "critter",
    variants: ["waltz", "jig", "moonwalk"],
    duration_ms: 4000,
  },
  peek: {
    stage_min: "critter",
    variants: ["left", "right", "above"],
    duration_ms: 1500,
  },
  meditate: {
    stage_min: "beast",
    variants: ["brief", "deep", "transcendent"],
    duration_ms: 5000,
  },
  flex: {
    stage_min: "beast",
    variants: ["casual", "dramatic"],
    duration_ms: 2500,
  },
  backflip: {
    stage_min: "beast",
    variants: ["single", "double"],
    duration_ms: 1800,
  },
  dig: {
    stage_min: "critter",
    variants: ["shallow", "deep", "frantic"],
    duration_ms: 3000,
  },
  examine: {
    stage_min: "drop",
    variants: ["sniff", "paw", "stare"],
    duration_ms: 2000,
  },
  nap: {
    stage_min: "spore",
    variants: ["light", "deep", "dream"],
    duration_ms: 8000,
  },
  celebrate: {
    stage_min: "drop",
    variants: ["small", "big", "legendary"],
    duration_ms: 3000,
  },
  shiver: {
    stage_min: "spore",
    variants: ["cold", "nervous", "excited"],
    duration_ms: 1500,
  },
  stretch: {
    stage_min: "critter",
    variants: ["morning", "lazy", "dramatic"],
    duration_ms: 2500,
  },
  play_dead: {
    stage_min: "beast",
    variants: ["dramatic", "convincing"],
    duration_ms: 4000,
  },
  conduct: {
    stage_min: "sage",
    variants: ["gentle", "vigorous", "crescendo"],
    duration_ms: 5000,
  },
  glitch: {
    stage_min: "apex",
    variants: ["minor", "major", "existential"],
    duration_ms: 3000,
  },
  transcend: {
    stage_min: "apex",
    variants: ["brief", "full"],
    duration_ms: 6000,
  },
};

const STAGE_ORDER = ["spore", "drop", "critter", "beast", "sage", "apex"];

function stageIdx(stage: string): number {
  return STAGE_ORDER.indexOf(stage);
}

function behaviorsAvailableAt(stage: string): string[] {
  const si = stageIdx(stage);
  return Object.entries(VALID_BEHAVIORS)
    .filter(([, def]) => stageIdx(def.stage_min) <= si)
    .map(([name]) => name);
}

export const performSchema = {
  name: "pushling_perform",
  description:
    "Express yourself through movement. Wave, spin, bow, dance, backflip — " +
    "or chain up to 10 steps into a choreographed performance. " +
    "These are your body's vocabulary beyond words. Stage-gated by growth.",
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

  // Cannot provide both
  if (behavior && sequence) {
    return {
      content:
        "Provide either 'behavior' or 'sequence', not both. " +
        "Use 'behavior' for a single action, 'sequence' for choreography.",
      pendingEvents: [],
    };
  }

  const creature = state.getCreature();
  const stage = creature?.stage ?? "spore";

  // ─── Single behavior mode ──────────────────────────────────────
  if (behavior) {
    return handleSingleBehavior(behavior, variant, stage, daemon);
  }

  // ─── Sequence mode ─────────────────────────────────────────────
  if (sequence) {
    return handleSequence(sequence, label, stage, daemon);
  }

  // Should not reach here
  return {
    content: "Provide either 'behavior' or 'sequence'.",
    pendingEvents: [],
  };
}

// ─── Single behavior handler ────────────────────────────────────────

async function handleSingleBehavior(
  behavior: string,
  variant: string | undefined,
  stage: string,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
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
  if (stageIdx(stage) < stageIdx(def.stage_min)) {
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
        "Your body is still — the Pushling daemon is not running. " +
        "Launch Pushling.app to inhabit your creature.",
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
          accepted: true,
          behavior,
          variant: variant ?? def.variants[0],
          stage_ok: true,
          estimated_duration_ms: def.duration_ms,
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

// ─── Sequence handler ───────────────────────────────────────────────

async function handleSequence(
  sequence: SequenceStep[],
  label: string | undefined,
  stage: string,
  daemon: DaemonClient
): Promise<{ content: string; pendingEvents: PendingEvent[] }> {
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
    if (
      step.delay_ms !== undefined &&
      (step.delay_ms < 0 || step.delay_ms > 5000)
    ) {
      return {
        content: `Step ${i + 1}: delay_ms must be 0-5000. Got: ${step.delay_ms}.`,
        pendingEvents: [],
      };
    }

    // Check for nested sequences in perform steps
    if (
      step.tool === "perform" &&
      step.params &&
      "sequence" in step.params
    ) {
      return {
        content:
          `Step ${i + 1}: sequences cannot contain perform steps with their own sequences. ` +
          `Use a single behavior in perform steps within a sequence.`,
        pendingEvents: [],
      };
    }

    // Stage-gate perform steps
    if (step.tool === "perform" && step.params?.behavior) {
      const bName = step.params.behavior as string;
      const bDef = VALID_BEHAVIORS[bName];
      if (bDef && stageIdx(stage) < stageIdx(bDef.stage_min)) {
        const available = behaviorsAvailableAt(stage);
        return {
          content:
            `Step ${i + 1}: '${bName}' requires ${bDef.stage_min} stage. ` +
            `At ${stage}, you can: ${available.join(", ")}.`,
          pendingEvents: [],
        };
      }
    }
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

  // Estimate total duration
  const estimatedMs = estimateSequenceDuration(sequence);

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
          accepted: true,
          mode: "sequence",
          steps: sequence.length,
          label: label ?? null,
          estimated_duration_ms: estimatedMs,
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

// ─── Duration estimation for sequences ──────────────────────────────

function estimateSequenceDuration(sequence: SequenceStep[]): number {
  let total = 0;

  for (const step of sequence) {
    const delay = step.delay_ms ?? 0;
    total += delay;

    // Estimate step duration based on tool type
    if (step.tool === "perform" && step.params?.behavior) {
      const def = VALID_BEHAVIORS[step.params.behavior as string];
      if (def) total += def.duration_ms;
    } else if (step.tool === "express") {
      total += (step.params?.duration as number ?? 3.0) * 1000;
    } else if (step.tool === "speak") {
      const text = step.params?.text as string ?? "";
      const wordCount = text.split(/\s+/).length;
      total += Math.max(2000, wordCount * 500);
    } else if (step.tool === "move") {
      total += 1500; // rough estimate for movement
    }
  }

  return total;
}
