#!/usr/bin/env bash
# post-compact.sh — Pushling PostCompact hook for Claude Code
#
# Fires when Claude's context window is compacted. The creature shares
# the disorientation: shakes head, dazed expression, blinks rapidly.
# "...what was I thinking about?"
#
# No stdout output. Writes to feed directory only.
# Performance: Must complete in <50ms.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pushling-hook-lib.sh"

# ── Main ───────────────────────────────────────────────────────────────

main() {
    # Minimal data — just the event signal
    # The daemon handles the daze animation
    local json_data="{}"

    # Emit to feed directory + signal daemon
    pushling_emit "PostCompact" "$json_data"
}

main "$@"
