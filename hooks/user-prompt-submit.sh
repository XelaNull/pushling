#!/usr/bin/env bash
# user-prompt-submit.sh — Pushling UserPromptSubmit hook for Claude Code
#
# Fires when the human sends a message to Claude. The creature notices:
# ears perk, head turns toward "where the terminal would be."
#
# PRIVACY: Captures prompt LENGTH only. Never captures content.
#
# No stdout output. Writes to feed directory only.
# Performance: Must complete in <50ms.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pushling-hook-lib.sh"

# ── Main ───────────────────────────────────────────────────────────────

main() {
    # Prompt length from Claude Code hook environment
    # PRIVACY: We only receive length, never content
    local prompt_length="${CLAUDE_PROMPT_LENGTH:-0}"

    # Validate it's a number
    if ! [[ "$prompt_length" =~ ^[0-9]+$ ]]; then
        prompt_length=0
    fi

    # Build JSON data
    local json_data="{\"prompt_length\":${prompt_length}}"

    # Emit to feed directory + signal daemon
    pushling_emit "UserPromptSubmit" "$json_data"
}

main "$@"
