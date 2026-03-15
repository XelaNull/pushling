#!/bin/bash
# find-unwired-code.sh — Detect unwired code patterns in the Pushling codebase
# Searches for properties stored but never read, functions defined but never called,
# parameters accepted but ignored, stubs, TODOs, and empty implementations.
#
# Usage: ./scripts/find-unwired-code.sh [--verbose]

set -uo pipefail

SRC="Pushling/Sources/Pushling"
VERBOSE="${1:-}"
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

FINDINGS=0
CRITICAL=0
MEDIUM=0
LOW=0

# Portable grep -c wrapper (never fails on zero matches)
gcount() {
    local result
    result=$(grep -r --include='*.swift' "$1" "$2" 2>/dev/null | wc -l | tr -d '[:space:]')
    echo "${result:-0}"
}

# Grep with filter
gcount_filter() {
    local pattern="$1"
    local path="$2"
    local filter="$3"
    local result
    result=$(grep -r --include='*.swift' "$pattern" "$path" 2>/dev/null | grep -v "$filter" | wc -l | tr -d '[:space:]')
    echo "${result:-0}"
}

finding() {
    local severity="$1"
    local category="$2"
    local detail="$3"
    FINDINGS=$((FINDINGS + 1))
    case "$severity" in
        CRITICAL) CRITICAL=$((CRITICAL + 1)); color="$RED" ;;
        MEDIUM)   MEDIUM=$((MEDIUM + 1));     color="$YELLOW" ;;
        LOW)      LOW=$((LOW + 1));           color="$CYAN" ;;
        *)        color="$NC" ;;
    esac
    echo -e "${color}[$severity]${NC} ${BOLD}$category${NC}"
    echo "  $detail"
    echo ""
}

header() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

echo -e "${BOLD}Pushling Unwired Code Detector${NC}"
echo "Scanning $SRC ..."
echo ""

# ─────────────────────────────────────────────
header "1. Object Physics Properties — Stored But Never Read"
# ─────────────────────────────────────────────

for prop in weight bounciness rollable pushable carryable; do
    total=$(gcount "\.$prop" "$SRC")
    reads=$(gcount_filter "\.$prop" "$SRC" "struct\|let.*:\|var.*:\|init(")
    if [ "$total" -gt 0 ] && [ "$reads" -lt 2 ]; then
        finding "CRITICAL" "ObjectPhysics.$prop — stored but never read" \
            "Appears $total times total, meaningful reads: $reads"
    elif [ "$total" -gt 0 ]; then
        echo -e "  ${GREEN}OK${NC} ObjectPhysics.$prop ($total refs, $reads reads)"
    fi
done

# ─────────────────────────────────────────────
header "2. Object Layer — Stored But Never Used for Rendering"
# ─────────────────────────────────────────────

layer_stores=$(gcount "\.layer" "$SRC/World")
layer_switch_file="$SRC/World/WorldObjectRenderer.swift"
if [ -f "$layer_switch_file" ]; then
    layer_switch=$(grep -E 'case "far"|case "mid"|switch.*\.layer' "$layer_switch_file" 2>/dev/null | wc -l | tr -d '[:space:]')
    layer_switch="${layer_switch:-0}"
else
    layer_switch=0
fi
if [ "$layer_stores" -gt 0 ] && [ "$layer_switch" -eq 0 ]; then
    finding "CRITICAL" "Object layer property stored but never used for parallax rendering" \
        "layer field referenced $layer_stores times in World/, but renderer never switches on it"
else
    echo -e "  ${GREEN}OK${NC} Object layer wired ($layer_switch switch refs)"
fi

# ─────────────────────────────────────────────
header "3. consumesObject Flag — Never Checked"
# ─────────────────────────────────────────────

consumes_total=$(gcount "consumesObject" "$SRC")
consumes_checked=$(gcount "if.*consumesObject\|consumesObject ==" "$SRC")
if [ "$consumes_total" -gt 0 ] && [ "$consumes_checked" -eq 0 ]; then
    finding "CRITICAL" "consumesObject flag set ($consumes_total refs) but never checked" \
        "Eating sets consumesObject=true but completeInteraction() never reads it"
else
    echo -e "  ${GREEN}OK${NC} consumesObject checked ($consumes_checked refs)"
fi

# ─────────────────────────────────────────────
header "4. Per-Object wearRate — Ignored by Wear System"
# ─────────────────────────────────────────────

wear_defined=$(gcount "wearRate" "$SRC/World/WorldObjectRenderer.swift" || echo 0)
wear_consumed=$(gcount_filter "definition\.wearRate\|\.wearRate" "$SRC" "let\|var\|struct\|init\|WorldObjectRenderer")
if [ "$wear_defined" -gt 0 ] && [ "$wear_consumed" -eq 0 ]; then
    finding "MEDIUM" "Per-object wearRate defined ($wear_defined refs) but never consumed" \
        "ObjectWearSystem uses hardcoded rates by interaction type instead"
else
    echo -e "  ${GREEN}OK${NC} wearRate consumed ($wear_consumed refs)"
fi

# ─────────────────────────────────────────────
header "5. EyeController.look_at — Stub Check"
# ─────────────────────────────────────────────

look_at_todo=$(gcount "look_at.*TODO\|TODO.*look_at" "$SRC/Creature" || echo 0)
if [ "$look_at_todo" -gt 0 ]; then
    finding "LOW" "EyeController.look_at is stubbed (TODO marker present)" \
        "Uses fixed offset instead of real target coordinates"
else
    echo -e "  ${GREEN}OK${NC} look_at appears fully implemented"
fi

# ─────────────────────────────────────────────
header "6. Badge Ceremony — Empty Callback"
# ─────────────────────────────────────────────

badge_callback=$(gcount "onBadgeEarned" "$SRC")
badge_todo=$(gcount "badge.*ceremony\|badge.*animation" "$SRC" || echo 0)
badge_impl=$(gcount_filter "badge.*ceremony\|badge.*animation" "$SRC" "//\|TODO")
if [ "$badge_callback" -gt 0 ] && [ "$badge_impl" -eq 0 ]; then
    finding "LOW" "Badge ceremony callback exists but no animation implemented" \
        "onBadgeEarned wired ($badge_callback refs), ceremony code: $badge_impl"
else
    echo -e "  ${GREEN}OK${NC} Badge ceremony implemented ($badge_impl refs)"
fi

# ─────────────────────────────────────────────
header "7. Database Columns — Schema Only"
# ─────────────────────────────────────────────

for field in repo_name landmark_type; do
    schema=$(gcount "$field" "$SRC/State" || echo 0)
    usage=$(gcount_filter "$field" "$SRC" "State/\|Schema\|Migration\|CREATE\|ALTER")
    if [ "$schema" -gt 0 ] && [ "$usage" -eq 0 ]; then
        finding "LOW" "DB column '$field' exists in schema but never written/read" \
            "Schema: $schema refs, usage outside schema: $usage"
    else
        echo -e "  ${GREEN}OK${NC} Column '$field' used ($usage refs outside schema)"
    fi
done

# ─────────────────────────────────────────────
header "8. TODO / FIXME / PLACEHOLDER Markers"
# ─────────────────────────────────────────────

todo_output=$(grep -rn --include='*.swift' \
    'TODO\|FIXME\|PLACEHOLDER\|NOT_IMPLEMENTED' "$SRC" 2>/dev/null || true)
todo_count=$(echo "$todo_output" | grep -c '' 2>/dev/null || echo 0)

# Handle empty output
if [ -z "$todo_output" ]; then
    todo_count=0
fi

if [ "$todo_count" -gt 0 ]; then
    finding "MEDIUM" "$todo_count TODO/FIXME/PLACEHOLDER markers" \
        "Each may indicate unwired functionality"
    if [ "$VERBOSE" = "--verbose" ]; then
        echo "$todo_output"
    else
        echo "$todo_output" | head -10
        if [ "$todo_count" -gt 10 ]; then
            echo "  ... ($((todo_count - 10)) more, use --verbose)"
        fi
    fi
    echo ""
fi

# ─────────────────────────────────────────────
header "9. Functions Defined But Never Called"
# ─────────────────────────────────────────────

for func in performBadgeCeremony applyMutationVisuals displayBadge triggerCeremony applyDepthScale; do
    defined=$(gcount "func $func" "$SRC")
    called=$(gcount_filter "\.$func(\|$func(" "$SRC" "func $func")
    if [ "$defined" -gt 0 ] && [ "$called" -eq 0 ]; then
        finding "MEDIUM" "Function '$func()' defined but never called" \
            "Defined $defined time(s), called from 0 sites"
    fi
done

# ─────────────────────────────────────────────
header "10. Potential Unused Struct Properties (Heuristic)"
# ─────────────────────────────────────────────

if [ "$VERBOSE" = "--verbose" ]; then
    echo "  Scanning for struct properties that may be write-only..."
    # Look for let properties in World/ structs and check if accessed
    grep -rn --include='*.swift' 'let [a-z][a-zA-Z]*:' "$SRC/World/" 2>/dev/null | \
        sed -n 's/.*let \([a-zA-Z]*\):.*/\1/p' | sort -u | while read -r prop; do
        if [ ${#prop} -gt 3 ]; then
            access=$(gcount_filter "\.$prop" "$SRC" "let\|var\|struct\|init\|//")
            if [ "$access" -eq 0 ]; then
                echo -e "  ${YELLOW}SUSPECT${NC} World/ property '$prop' — defined but 0 access sites"
            fi
        fi
    done
    echo ""
fi

# ─────────────────────────────────────────────
header "SUMMARY"
# ─────────────────────────────────────────────

echo -e "${BOLD}Total findings: $FINDINGS${NC}"
echo -e "  ${RED}CRITICAL: $CRITICAL${NC}  (built + stored + never connected)"
echo -e "  ${YELLOW}MEDIUM:   $MEDIUM${NC}  (stubs or partial wiring)"
echo -e "  ${CYAN}LOW:      $LOW${NC}  (minor gaps)"
echo ""

if [ $CRITICAL -gt 0 ]; then
    echo -e "${RED}${BOLD}$CRITICAL critical system(s) have full infrastructure (struct, DB column,${NC}"
    echo -e "${RED}${BOLD}IPC parameter, SQLite persistence) but zero connection to rendering or behavior.${NC}"
    echo ""
fi

echo -e "${BOLD}Known unwired systems (audit 2026-03-15):${NC}"
cat << 'KNOWN'
  1. Object physics (weight/bounciness/rollable/pushable/carryable)
     Stored in SQLite & WorldObjectDefinition, never affects interaction
  2. Object layer (far/mid/fore)
     Stored in SQLite, never used for parallax layer assignment
  3. consumesObject flag
     Set true for eating, but completeInteraction() never checks it
  4. Per-object wearRate
     Stored per-instance, ObjectWearSystem uses hardcoded rates
  5. EyeController.look_at
     Stub with fixed offset, no real target coordinate passing
  6. Badge ceremony animation
     onBadgeEarned callback body is TODO
  7. DB columns: repo_name, landmark_type
     Schema defined, never written or read
KNOWN

echo ""
echo "Run: ./scripts/find-unwired-code.sh --verbose  (for full details)"
