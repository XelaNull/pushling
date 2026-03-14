#!/usr/bin/env bash
# post-commit.sh — Pushling Git post-commit hook
#
# Captures commit data and writes a feed JSON file for the daemon to
# process. This is the creature's food supply.
#
# Installed in each tracked repo's .git/hooks/ directory.
# Can also be installed globally via core.hooksPath.
#
# Data captured:
#   - SHA, message, timestamp, repo name/path
#   - Files changed, lines added/removed
#   - Languages (from file extensions in the diff)
#   - Branch name
#   - Flags: is_merge, is_revert, is_force_push
#
# File format: JSON written to ~/.local/share/pushling/feed/{sha}.json
# File write is atomic (temp + rename).
#
# Performance: Must complete in <100ms including git commands.
# Safety: Never modifies the commit. Never fails the commit.

# Source the shared library — resolve from the hook's install location
# The lib might be at a known location, or relative to a symlink target
_resolve_lib() {
    # Try standard install location first
    local standard="${HOME}/.local/share/pushling/hooks/lib/pushling-hook-lib.sh"
    [[ -f "$standard" ]] && echo "$standard" && return 0

    # Try relative to this script (works if installed via symlink or copy)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

    # Direct sibling: hooks/lib/ when script is in hooks/
    local direct_lib="${script_dir}/lib/pushling-hook-lib.sh"
    [[ -f "$direct_lib" ]] && echo "$direct_lib" && return 0

    # If we're in .git/hooks/, the lib might be at the installed location
    local git_lib="${script_dir}/../../hooks/lib/pushling-hook-lib.sh"
    [[ -f "$git_lib" ]] && echo "$git_lib" && return 0

    # Try via PUSHLING_HOME env var
    [[ -n "${PUSHLING_HOME:-}" && -f "${PUSHLING_HOME}/hooks/lib/pushling-hook-lib.sh" ]] && \
        echo "${PUSHLING_HOME}/hooks/lib/pushling-hook-lib.sh" && return 0

    return 1
}

LIB_PATH="$(_resolve_lib)"
if [[ -n "$LIB_PATH" ]]; then
    source "$LIB_PATH"
else
    # Minimal fallback: define just enough to write the JSON file
    PUSHLING_FEED_DIR="${PUSHLING_FEED_DIR:-${HOME}/.local/share/pushling/feed}"
    PUSHLING_SOCKET="${PUSHLING_SOCKET:-/tmp/pushling.sock}"
    # Suppress stderr but don't use exec (preserves caller's stderr)
    pushling_ensure_feed_dir() { mkdir -p "$PUSHLING_FEED_DIR" 2>/dev/null || true; }
    pushling_signal() { return 0; }
    pushling_json_escape() {
        local r="$1"; r="${r//\\/\\\\}"; r="${r//\"/\\\"}"; echo -n "$r"
    }
    pushling_timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "1970-01-01T00:00:00Z"; }
fi

# ── Language Detection ─────────────────────────────────────────────────

# Maps file extension to language name
ext_to_language() {
    # Direct match first (most extensions are already lowercase)
    # Only fall back to tr for uppercase cases
    case "$1" in
        # Systems
        rs) echo "rust" ;; c) echo "c" ;; cpp|cc|cxx) echo "cpp" ;;
        h|hpp|hxx) echo "c_header" ;; go) echo "go" ;; zig) echo "zig" ;;
        # Web Frontend
        tsx) echo "tsx" ;; jsx) echo "jsx" ;; vue) echo "vue" ;;
        svelte) echo "svelte" ;; css) echo "css" ;; scss|sass) echo "scss" ;;
        html|htm) echo "html" ;; less) echo "less" ;;
        # Web Backend
        php) echo "php" ;; rb) echo "ruby" ;; erb) echo "erb" ;;
        # Script / General
        py) echo "python" ;; sh|bash|zsh) echo "shell" ;; lua) echo "lua" ;;
        pl|pm) echo "perl" ;; r) echo "r" ;;
        # JVM
        java) echo "java" ;; kt|kts) echo "kotlin" ;; scala) echo "scala" ;;
        groovy) echo "groovy" ;; clj|cljs) echo "clojure" ;;
        # Mobile (include common capitalization)
        swift|Swift) echo "swift" ;; m|mm) echo "objc" ;; dart) echo "dart" ;;
        # JS/TS
        js|mjs|cjs) echo "javascript" ;; ts|mts|cts) echo "typescript" ;;
        # Data
        sql|SQL) echo "sql" ;; ipynb) echo "jupyter" ;;
        # Config / Infra
        yaml|yml) echo "yaml" ;; toml) echo "toml" ;; json) echo "json" ;;
        xml|XML) echo "xml" ;; tf|hcl) echo "terraform" ;;
        dockerfile) echo "docker" ;; nix) echo "nix" ;;
        # Docs
        md) echo "markdown" ;; txt) echo "text" ;; rst) echo "rst" ;;
        tex) echo "latex" ;;
        # Other
        graphql|gql) echo "graphql" ;; proto) echo "protobuf" ;;
        ex|exs) echo "elixir" ;; hs) echo "haskell" ;;
        ml|mli) echo "ocaml" ;; fs|fsi|fsx) echo "fsharp" ;;
        # Blade templates
        blade.php) echo "blade" ;;
        # Uppercase variants for common types
        C) echo "c" ;; H) echo "c_header" ;; R) echo "r" ;;
        *) echo "" ;;
    esac
}

# Extract unique languages from the list of changed files.
# Uses bash built-ins only (no subprocess per file for speed).
detect_languages() {
    local files="$1"
    local seen=""

    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        # Get filename using bash built-in (no subprocess)
        local filename="${filepath##*/}"
        local ext=""

        # Check for multi-part extensions first
        case "$filename" in
            *.blade.php) ext="blade.php" ;;
            *.spec.ts|*.test.ts) ext="ts" ;;
            *.spec.js|*.test.js) ext="js" ;;
            Dockerfile*) ext="dockerfile" ;;
            *)
                ext="${filename##*.}"
                # Skip if no extension or extension is the whole filename
                [[ "$ext" == "$filename" ]] && continue
                ;;
        esac

        local lang
        lang="$(ext_to_language "$ext")"
        [[ -z "$lang" ]] && continue

        # Deduplicate
        case ",$seen," in
            *,"$lang",*) continue ;;
        esac
        seen="${seen:+$seen,}$lang"
    done <<< "$files"

    echo "$seen"
}

# ── Commit Data Extraction ─────────────────────────────────────────────

main() {
    # Get the commit SHA
    local sha
    sha=$(git rev-parse HEAD 2>/dev/null) || return 0
    local short_sha="${sha:0:8}"

    # Get commit message (first line only for the feed file)
    local message
    message=$(git log -1 --format="%s" HEAD 2>/dev/null) || message=""
    message="$(pushling_json_escape "$(echo "$message" | head -1)")"

    # Get commit timestamp
    local commit_timestamp
    commit_timestamp=$(git log -1 --format="%aI" HEAD 2>/dev/null) || \
        commit_timestamp="$(pushling_timestamp)"

    # Get repo name and path
    local repo_path
    repo_path=$(git rev-parse --show-toplevel 2>/dev/null) || repo_path="$(pwd)"
    local repo_name
    repo_name="$(basename "$repo_path")"
    repo_name="$(pushling_json_escape "$repo_name")"
    local escaped_repo_path
    escaped_repo_path="$(pushling_json_escape "$repo_path")"

    # Get branch name
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="unknown"
    branch="$(pushling_json_escape "$branch")"

    # Get diff stats using diff-tree (fast, doesn't require working tree)
    local files_changed=0
    local lines_added=0
    local lines_removed=0
    local changed_files=""

    # diff-tree with --numstat for the commit
    local numstat
    numstat=$(git diff-tree --numstat -r HEAD 2>/dev/null) || numstat=""

    if [[ -n "$numstat" ]]; then
        while IFS=$'\t' read -r added removed filepath; do
            [[ -z "$filepath" ]] && continue
            # Skip the commit hash line (first line of diff-tree output)
            [[ "$added" == "$sha" ]] && continue

            files_changed=$((files_changed + 1))

            # Binary files show "-" for added/removed
            if [[ "$added" != "-" ]]; then
                lines_added=$((lines_added + added))
            fi
            if [[ "$removed" != "-" ]]; then
                lines_removed=$((lines_removed + removed))
            fi

            changed_files="${changed_files}${filepath}
"
        done <<< "$numstat"
    fi

    # Detect languages from changed files
    local languages
    languages="$(detect_languages "$changed_files")"

    # Detect merge commit (more than one parent)
    local is_merge="false"
    local parent_count
    parent_count=$(git rev-list --parents -n 1 HEAD 2>/dev/null | wc -w) || parent_count=1
    parent_count=$((parent_count - 1))  # subtract the commit itself
    if [[ $parent_count -gt 1 ]]; then
        is_merge="true"
    fi

    # Detect revert (message starts with "Revert " or contains "This reverts commit")
    local is_revert="false"
    local full_message
    full_message=$(git log -1 --format="%B" HEAD 2>/dev/null) || full_message=""
    case "$full_message" in
        Revert\ *|revert\ *|Revert:*|revert:*)
            is_revert="true"
            ;;
        *"This reverts commit"*)
            is_revert="true"
            ;;
    esac

    # Detect force push (compare reflog — if HEAD@{1} is not an ancestor of HEAD)
    # This is heuristic and only works if the hook fires in the right context
    local is_force_push="false"
    local prev_head
    prev_head=$(git rev-parse 'HEAD@{1}' 2>/dev/null) || prev_head=""
    if [[ -n "$prev_head" && "$prev_head" != "$sha" ]]; then
        # Check if previous HEAD is an ancestor of current HEAD
        if ! git merge-base --is-ancestor "$prev_head" HEAD 2>/dev/null; then
            is_force_push="true"
        fi
    fi

    # ── Build JSON ─────────────────────────────────────────────────────

    local json_data
    json_data=$(cat << JSONEOF
{
  "type": "commit",
  "sha": "${short_sha}",
  "full_sha": "${sha}",
  "message": "${message}",
  "timestamp": "${commit_timestamp}",
  "repo_name": "${repo_name}",
  "repo_path": "${escaped_repo_path}",
  "files_changed": ${files_changed},
  "lines_added": ${lines_added},
  "lines_removed": ${lines_removed},
  "languages": "${languages}",
  "is_merge": ${is_merge},
  "is_revert": ${is_revert},
  "is_force_push": ${is_force_push},
  "branch": "${branch}"
}
JSONEOF
)

    # ── Write to Feed Directory ────────────────────────────────────────

    pushling_ensure_feed_dir || return 0

    # Atomic write: temp file then rename
    # Use SHA for filename to avoid duplicates
    local feed_file="${PUSHLING_FEED_DIR}/${short_sha}.json"
    local tmp_file="${PUSHLING_FEED_DIR}/.tmp_${short_sha}.json"

    # Compact the JSON to a single line for NDJSON compatibility
    local compact_json
    compact_json=$(echo "$json_data" | tr -d '\n' | tr -s ' ' 2>/dev/null) || compact_json="$json_data"

    echo "$compact_json" > "$tmp_file" 2>/dev/null || return 0
    mv "$tmp_file" "$feed_file" 2>/dev/null || return 0

    # Signal daemon
    pushling_signal "Commit"

    return 0
}

# Only run if executed (not sourced for testing)
main "$@"
