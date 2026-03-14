#!/usr/bin/env bash
# subagent-start.sh — Pushling SubagentStart hook for Claude Code
#
# Fires when Claude spawns subagent(s). The diamond splits into N smaller
# diamonds. Creature's eyes widen, head tracks between them.
#
# No stdout output. Writes to feed directory only.
# Performance: Must complete in <50ms.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pushling-hook-lib.sh"

# ── Main ───────────────────────────────────────────────────────────────

main() {
    # Subagent count from Claude Code hook environment
    local subagent_count="${CLAUDE_SUBAGENT_COUNT:-1}"

    # Validate it's a number
    if ! [[ "$subagent_count" =~ ^[0-9]+$ ]]; then
        subagent_count=1
    fi

    # Cap at 5 for diamond rendering budget
    if [[ $subagent_count -gt 5 ]]; then
        subagent_count=5
    fi

    # Build JSON data
    local json_data="{\"subagent_count\":${subagent_count}}"

    # Emit to feed directory + signal daemon
    pushling_emit "SubagentStart" "$json_data"
}

main "$@"
