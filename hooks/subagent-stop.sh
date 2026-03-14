#!/usr/bin/env bash
# subagent-stop.sh — Pushling SubagentStop hook for Claude Code
#
# Fires when subagent(s) complete. Small diamonds reconverge into the
# main diamond. Brief flash. Creature nods approvingly.
#
# No stdout output. Writes to feed directory only.
# Performance: Must complete in <50ms.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pushling-hook-lib.sh"

# ── Main ───────────────────────────────────────────────────────────────

main() {
    # Remaining subagent count from Claude Code hook environment
    local subagent_count="${CLAUDE_SUBAGENT_COUNT:-0}"
    local remaining="${CLAUDE_SUBAGENT_REMAINING:-0}"

    # Validate they're numbers
    if ! [[ "$subagent_count" =~ ^[0-9]+$ ]]; then
        subagent_count=0
    fi
    if ! [[ "$remaining" =~ ^[0-9]+$ ]]; then
        remaining=0
    fi

    # Build JSON data
    local json_data="{\"subagent_count\":${subagent_count},\"remaining\":${remaining}}"

    # Emit to feed directory + signal daemon
    pushling_emit "SubagentStop" "$json_data"
}

main "$@"
