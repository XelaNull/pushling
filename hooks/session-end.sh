#!/usr/bin/env bash
# session-end.sh — Pushling SessionEnd hook for Claude Code
#
# Signals the daemon that a Claude Code session has ended.
# Triggers farewell animation: diamond dissolves, creature waves.
#
# Determines session duration and end reason from environment.
# No stdout output. Writes to feed directory only.
#
# Performance: Must complete in <50ms.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pushling-hook-lib.sh"

# ── Determine Reason ───────────────────────────────────────────────────

# Claude Code hook data comes via environment variables
# SESSION_DURATION_MS and SESSION_EXIT_REASON if available
determine_reason() {
    local reason="${CLAUDE_SESSION_EXIT_REASON:-clean}"

    # Normalize reason values
    case "$reason" in
        clean|normal|exit)
            echo "clean"
            ;;
        timeout|idle)
            echo "timeout"
            ;;
        error|crash|abort|sigterm|sigkill)
            echo "error"
            ;;
        *)
            echo "clean"
            ;;
    esac
}

# ── Main ───────────────────────────────────────────────────────────────

main() {
    local reason
    reason="$(determine_reason)"

    # Session duration: from env var or estimate from session start file
    local duration_s="${CLAUDE_SESSION_DURATION_S:-0}"

    # If we have milliseconds, convert
    if [[ -n "${CLAUDE_SESSION_DURATION_MS:-}" ]]; then
        duration_s=$(( CLAUDE_SESSION_DURATION_MS / 1000 ))
    fi

    local session_id="${CLAUDE_SESSION_ID:-$(uuidgen 2>/dev/null || echo "unknown")}"

    # Build JSON data
    local json_data="{\"session_id\":\"${session_id}\",\"duration_s\":${duration_s},\"reason\":\"${reason}\"}"

    # Emit to feed directory + signal daemon
    pushling_emit "SessionEnd" "$json_data"
}

main "$@"
