#!/usr/bin/env bash
# post-tool-use.sh — Pushling PostToolUse hook for Claude Code
#
# Fires after Claude uses a tool (Bash, Edit, Read, Write, Grep, etc.).
# Writes tool_use event with tool name, success/failure, duration.
#
# Batching: If 3+ tools fire within 10 seconds, coalesce into a single
# "tool_burst" event instead of individual events. Uses a state file
# in the feed directory to track recent tool events.
#
# No stdout output. Writes to feed directory only.
# Performance: Must complete in <50ms.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pushling-hook-lib.sh"

# ── Batching State ─────────────────────────────────────────────────────

PUSHLING_TOOL_BURST_FILE="${PUSHLING_FEED_DIR}/.tool_burst_state"
PUSHLING_BURST_WINDOW=10  # seconds
PUSHLING_BURST_THRESHOLD=3  # tools within window to trigger burst mode

# Check if we should batch this event
check_burst_mode() {
    pushling_ensure_feed_dir

    local now_epoch
    now_epoch=$(date +%s 2>/dev/null) || now_epoch=0

    # Read the burst state file: format is "count epoch_of_first"
    local burst_count=0
    local burst_start=0

    if [[ -f "$PUSHLING_TOOL_BURST_FILE" ]]; then
        local state_line
        state_line=$(cat "$PUSHLING_TOOL_BURST_FILE" 2>/dev/null) || state_line=""
        if [[ -n "$state_line" ]]; then
            burst_count="${state_line%% *}"
            burst_start="${state_line##* }"
        fi
    fi

    # Check if we're still within the burst window
    local elapsed=$((now_epoch - burst_start))
    if [[ $elapsed -gt $PUSHLING_BURST_WINDOW || $burst_start -eq 0 ]]; then
        # Window expired — start a new window
        burst_count=1
        burst_start=$now_epoch
    else
        # Within window — increment
        burst_count=$((burst_count + 1))
    fi

    # Update state file
    echo "${burst_count} ${burst_start}" > "$PUSHLING_TOOL_BURST_FILE" 2>/dev/null

    # Return: 0 if should emit individual, 1 if should batch
    if [[ $burst_count -ge $PUSHLING_BURST_THRESHOLD ]]; then
        # In burst mode — only emit on threshold crossings (3, 6, 9, etc.)
        # to avoid flooding feed directory
        if [[ $((burst_count % PUSHLING_BURST_THRESHOLD)) -eq 0 ]]; then
            echo "$burst_count"
            return 1
        fi
        # Suppress individual event during burst
        return 2
    fi

    echo "$burst_count"
    return 0
}

# ── Main ───────────────────────────────────────────────────────────────

main() {
    # Tool data from Claude Code hook environment
    local tool_name="${CLAUDE_TOOL_NAME:-unknown}"
    local tool_success="${CLAUDE_TOOL_SUCCESS:-true}"
    local tool_duration_ms="${CLAUDE_TOOL_DURATION_MS:-0}"

    # Normalize success to JSON boolean
    case "$tool_success" in
        true|1|yes|True|TRUE) tool_success="true" ;;
        *) tool_success="false" ;;
    esac

    # Check burst mode
    local burst_count
    burst_count=$(check_burst_mode)
    local burst_status=$?

    if [[ $burst_status -eq 1 ]]; then
        # Emit a burst event instead
        local escaped_tool
        escaped_tool="$(pushling_json_escape "$tool_name")"
        pushling_emit "PostToolUse" "{\"tool\":\"${escaped_tool}\",\"success\":${tool_success},\"duration_ms\":${tool_duration_ms},\"burst\":true,\"burst_count\":${burst_count}}"
    elif [[ $burst_status -eq 0 ]]; then
        # Normal individual event
        local escaped_tool
        escaped_tool="$(pushling_json_escape "$tool_name")"
        pushling_emit "PostToolUse" "{\"tool\":\"${escaped_tool}\",\"success\":${tool_success},\"duration_ms\":${tool_duration_ms}}"
    fi
    # burst_status 2 = suppressed during burst, no emit

    return 0
}

main "$@"
