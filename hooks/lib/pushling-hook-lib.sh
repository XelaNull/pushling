#!/usr/bin/env bash
# pushling-hook-lib.sh — Shared library for all Pushling hooks
#
# Sourced by every hook script. Provides:
#   - pushling_emit(hook_type, json_data)  — writes JSON to feed dir + signals socket
#   - pushling_signal(hook_type)           — fire-and-forget signal to daemon socket
#   - pushling_timestamp()                 — ISO 8601 UTC timestamp
#   - pushling_timestamp_ms()              — millisecond-precision epoch for filenames
#   - pushling_json_escape(string)         — escapes a string for JSON embedding
#   - pushling_ensure_feed_dir()           — creates feed directory if needed
#
# Safety contract:
#   - NEVER exits non-zero (trapped)
#   - NEVER prints to stdout (except session-start, which sets PUSHLING_ALLOW_STDOUT=1)
#   - NEVER prints to stderr
#   - All socket operations timeout in <50ms
#   - All file operations are atomic (write temp, rename)
#   - Total execution budget: <100ms
#
# Compatibility: bash 3.2+ (macOS default), no bashisms beyond what 3.2 supports

# ── Global Error Trap ──────────────────────────────────────────────────
# Catch everything. Never fail. Never output.
set -o pipefail 2>/dev/null || true

_pushling_cleanup() {
    # Remove any leftover temp files
    [[ -n "${_PUSHLING_TMPFILE:-}" && -f "${_PUSHLING_TMPFILE}" ]] && rm -f "${_PUSHLING_TMPFILE}" 2>/dev/null
    return 0
}

trap '_pushling_cleanup' EXIT
trap 'return 0 2>/dev/null || exit 0' ERR

# Redirect stderr to /dev/null for the entire sourcing script unless debugging
if [[ -z "${PUSHLING_DEBUG:-}" ]]; then
    exec 2>/dev/null
fi

# ── Constants ──────────────────────────────────────────────────────────

PUSHLING_FEED_DIR="${PUSHLING_FEED_DIR:-${HOME}/.local/share/pushling/feed}"
PUSHLING_SOCKET="${PUSHLING_SOCKET:-/tmp/pushling.sock}"
PUSHLING_STATE_DB="${PUSHLING_STATE_DB:-${HOME}/.local/share/pushling/state.db}"
PUSHLING_HEARTBEAT="${PUSHLING_HEARTBEAT:-/tmp/pushling.heartbeat}"

# Signal timeout in seconds (0.05 = 50ms)
PUSHLING_SIGNAL_TIMEOUT="${PUSHLING_SIGNAL_TIMEOUT:-0.05}"

# ── Utility Functions ──────────────────────────────────────────────────

# Returns ISO 8601 UTC timestamp
pushling_timestamp() {
    if date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null; then
        return 0
    fi
    # Fallback: just output something reasonable
    echo "1970-01-01T00:00:00Z"
}

# Returns millisecond-precision epoch for unique filenames
pushling_timestamp_ms() {
    # macOS date doesn't support %N, use python or perl for ms precision
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null && return 0
    fi
    if command -v perl >/dev/null 2>&1; then
        perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000' 2>/dev/null && return 0
    fi
    # Fallback: second precision with a random suffix for uniqueness
    echo "$(date +%s)$(( RANDOM % 1000 ))"
}

# Escapes a string for safe embedding in JSON values.
# Handles: backslash, double-quote, newline, tab, carriage return
pushling_json_escape() {
    local input="$1"
    # Replace backslashes first, then quotes, then control characters
    # Use simple per-line sed (macOS BSD sed compatible)
    local result
    result="$input"
    result="${result//\\/\\\\}"    # backslash
    result="${result//\"/\\\"}"    # double quote
    result="${result//$'\t'/\\t}"  # tab
    result="${result//$'\r'/\\r}"  # carriage return
    # Newlines: convert to \n
    result="${result//$'\n'/\\n}"  # newline
    echo -n "$result"
}

# Truncates a string to max length, appending "..." if truncated
pushling_truncate() {
    local input="$1"
    local max_len="${2:-200}"
    if [[ ${#input} -gt $max_len ]]; then
        echo "${input:0:$((max_len - 3))}..."
    else
        echo "$input"
    fi
}

# ── Feed Directory ─────────────────────────────────────────────────────

pushling_ensure_feed_dir() {
    [[ -d "$PUSHLING_FEED_DIR" ]] && return 0
    mkdir -p "$PUSHLING_FEED_DIR" 2>/dev/null || return 0
}

# ── Socket Signaling ──────────────────────────────────────────────────

# Sends a fire-and-forget signal to the daemon socket.
# Uses /dev/tcp if available, falls back to nc or socat.
# Never blocks more than 50ms.
pushling_signal() {
    local hook_type="${1:-unknown}"
    local signal_json="{\"type\":\"hook_signal\",\"hook\":\"${hook_type}\"}"

    # Skip if socket doesn't exist
    [[ -S "$PUSHLING_SOCKET" ]] || return 0

    # Try nc (netcat) with timeout — most reliable on macOS
    if command -v nc >/dev/null 2>&1; then
        echo "$signal_json" | nc -U -w 1 "$PUSHLING_SOCKET" >/dev/null 2>&1 &
        local nc_pid=$!
        # Kill after timeout if still running
        (
            sleep "${PUSHLING_SIGNAL_TIMEOUT}" 2>/dev/null
            kill "$nc_pid" 2>/dev/null
        ) &
        return 0
    fi

    # Try socat as fallback
    if command -v socat >/dev/null 2>&1; then
        echo "$signal_json" | timeout "${PUSHLING_SIGNAL_TIMEOUT}" socat - "UNIX-CONNECT:${PUSHLING_SOCKET}" >/dev/null 2>&1 &
        return 0
    fi

    # No transport available — silent success
    return 0
}

# ── JSON File Writing ──────────────────────────────────────────────────

# Writes a hook event JSON file to the feed directory and signals the daemon.
#
# Usage: pushling_emit "HookType" '{"key":"value"}'
#
# The JSON file format:
# {
#   "type": "hook",
#   "hook": "HookType",
#   "timestamp": "2026-03-14T10:30:00Z",
#   "data": { ... }
# }
pushling_emit() {
    local hook_type="$1"
    local json_data="${2:-{\}}"
    local timestamp
    local timestamp_ms
    local filename

    timestamp="$(pushling_timestamp)"
    timestamp_ms="$(pushling_timestamp_ms)"
    filename="${timestamp_ms}_${hook_type}.json"

    pushling_ensure_feed_dir || return 0

    # Build the complete JSON envelope
    local full_json="{\"type\":\"hook\",\"hook\":\"${hook_type}\",\"timestamp\":\"${timestamp}\",\"data\":${json_data}}"

    # Atomic write: temp file then rename
    _PUSHLING_TMPFILE="${PUSHLING_FEED_DIR}/.tmp_${filename}"
    echo "$full_json" > "$_PUSHLING_TMPFILE" 2>/dev/null || return 0
    mv "$_PUSHLING_TMPFILE" "${PUSHLING_FEED_DIR}/${filename}" 2>/dev/null || return 0
    _PUSHLING_TMPFILE=""

    # Signal daemon (fire and forget)
    pushling_signal "$hook_type"

    return 0
}

# ── SQLite Read Helpers ────────────────────────────────────────────────

# Checks if the Pushling state database exists and is readable
pushling_db_exists() {
    [[ -f "$PUSHLING_STATE_DB" && -r "$PUSHLING_STATE_DB" ]]
}

# Queries the SQLite database in read-only mode.
# Returns the result of the query. Returns empty string on failure.
#
# Usage: result=$(pushling_db_query "SELECT name FROM creature WHERE id=1")
pushling_db_query() {
    local sql="$1"
    local mode="${2:--readonly}"

    if ! pushling_db_exists; then
        echo ""
        return 0
    fi

    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo ""
        return 0
    fi

    sqlite3 "$mode" "$PUSHLING_STATE_DB" "$sql" 2>/dev/null || echo ""
}

# Queries a single value from the creature table.
# Usage: stage=$(pushling_creature_field "stage")
pushling_creature_field() {
    local field="$1"
    pushling_db_query "SELECT ${field} FROM creature WHERE id=1;"
}

# ── Daemon Status ──────────────────────────────────────────────────────

# Returns 0 if the daemon appears to be running (heartbeat file is fresh)
pushling_daemon_running() {
    [[ -S "$PUSHLING_SOCKET" ]] && return 0
    [[ -f "$PUSHLING_HEARTBEAT" ]] && return 0
    return 1
}
