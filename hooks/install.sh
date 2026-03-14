#!/usr/bin/env bash
# install.sh — Register all Pushling hooks with Claude Code and Git
#
# What this does:
#   1. Copies hook lib to ~/.local/share/pushling/hooks/lib/
#   2. Registers Claude Code hooks via claude code hooks configuration
#   3. Optionally installs git post-commit hook to specified repos
#   4. Creates feed directory if it doesn't exist
#
# Usage:
#   ./install.sh                  # Install Claude Code hooks only
#   ./install.sh --git            # Also install git hook globally
#   ./install.sh --git-repo PATH  # Install git hook to a specific repo
#   ./install.sh --uninstall      # Remove all hooks
#
# Claude Code hooks are registered using the claude CLI or by writing
# to the hooks configuration file.

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUSHLING_DATA_DIR="${HOME}/.local/share/pushling"
PUSHLING_HOOKS_INSTALL_DIR="${PUSHLING_DATA_DIR}/hooks"
PUSHLING_FEED_DIR="${PUSHLING_DATA_DIR}/feed"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Helpers ────────────────────────────────────────────────────────────

info()  { echo -e "${BLUE}[pushling]${NC} $*"; }
ok()    { echo -e "${GREEN}[pushling]${NC} $*"; }
warn()  { echo -e "${YELLOW}[pushling]${NC} $*"; }
error() { echo -e "${RED}[pushling]${NC} $*" >&2; }

# ── Directory Setup ────────────────────────────────────────────────────

setup_directories() {
    info "Creating Pushling directories..."

    mkdir -p "$PUSHLING_DATA_DIR"
    mkdir -p "$PUSHLING_FEED_DIR"
    mkdir -p "${PUSHLING_FEED_DIR}/processed"
    mkdir -p "${PUSHLING_DATA_DIR}/backups"
    mkdir -p "${PUSHLING_HOOKS_INSTALL_DIR}/lib"

    ok "Directories ready at ${PUSHLING_DATA_DIR}"
}

# ── Copy Hook Scripts ──────────────────────────────────────────────────

install_hook_scripts() {
    info "Installing hook scripts..."

    # Copy shared library
    cp "${HOOKS_DIR}/lib/pushling-hook-lib.sh" "${PUSHLING_HOOKS_INSTALL_DIR}/lib/"
    chmod +x "${PUSHLING_HOOKS_INSTALL_DIR}/lib/pushling-hook-lib.sh"

    # Copy all hook scripts
    local hooks=(
        "session-start.sh"
        "session-end.sh"
        "post-tool-use.sh"
        "user-prompt-submit.sh"
        "subagent-start.sh"
        "subagent-stop.sh"
        "post-compact.sh"
        "post-commit.sh"
    )

    for hook in "${hooks[@]}"; do
        if [[ -f "${HOOKS_DIR}/${hook}" ]]; then
            cp "${HOOKS_DIR}/${hook}" "${PUSHLING_HOOKS_INSTALL_DIR}/${hook}"
            chmod +x "${PUSHLING_HOOKS_INSTALL_DIR}/${hook}"
            ok "  Installed ${hook}"
        else
            warn "  Missing ${hook} — skipped"
        fi
    done

    ok "Hook scripts installed to ${PUSHLING_HOOKS_INSTALL_DIR}"
}

# ── Claude Code Hook Registration ─────────────────────────────────────

register_claude_hooks() {
    info "Registering hooks with Claude Code..."

    # Claude Code hooks are registered via the settings file
    # Location: ~/.claude/settings.json (or similar)
    local claude_settings_dir="${HOME}/.claude"
    local claude_hooks_file="${claude_settings_dir}/hooks.json"

    # Build the hooks configuration
    local hooks_json
    hooks_json=$(cat << HOOKSJSON
{
  "hooks": {
    "SessionStart": {
      "command": "${PUSHLING_HOOKS_INSTALL_DIR}/session-start.sh",
      "timeout_ms": 100,
      "capture_stdout": true
    },
    "SessionEnd": {
      "command": "${PUSHLING_HOOKS_INSTALL_DIR}/session-end.sh",
      "timeout_ms": 50,
      "capture_stdout": false
    },
    "PostToolUse": {
      "command": "${PUSHLING_HOOKS_INSTALL_DIR}/post-tool-use.sh",
      "timeout_ms": 50,
      "capture_stdout": false
    },
    "UserPromptSubmit": {
      "command": "${PUSHLING_HOOKS_INSTALL_DIR}/user-prompt-submit.sh",
      "timeout_ms": 50,
      "capture_stdout": false
    },
    "SubagentStart": {
      "command": "${PUSHLING_HOOKS_INSTALL_DIR}/subagent-start.sh",
      "timeout_ms": 50,
      "capture_stdout": false
    },
    "SubagentStop": {
      "command": "${PUSHLING_HOOKS_INSTALL_DIR}/subagent-stop.sh",
      "timeout_ms": 50,
      "capture_stdout": false
    },
    "PostCompact": {
      "command": "${PUSHLING_HOOKS_INSTALL_DIR}/post-compact.sh",
      "timeout_ms": 50,
      "capture_stdout": false
    }
  }
}
HOOKSJSON
)

    # Write hooks configuration
    mkdir -p "$claude_settings_dir"

    if [[ -f "$claude_hooks_file" ]]; then
        warn "Existing hooks.json found — backing up to hooks.json.bak"
        cp "$claude_hooks_file" "${claude_hooks_file}.bak"
    fi

    echo "$hooks_json" > "$claude_hooks_file"
    ok "Claude Code hooks registered at ${claude_hooks_file}"

    echo ""
    info "To verify registration, run: cat ${claude_hooks_file}"
    info "Hooks will activate on next Claude Code session start."
}

# ── Git Post-Commit Hook ──────────────────────────────────────────────

install_git_hook_global() {
    info "Installing global git post-commit hook..."

    # Set git core.hooksPath to a directory containing our hooks
    local git_hooks_dir="${PUSHLING_DATA_DIR}/git-hooks"
    mkdir -p "$git_hooks_dir"

    # Create the post-commit hook as a wrapper
    cat > "${git_hooks_dir}/post-commit" << GITEOF
#!/usr/bin/env bash
# Pushling post-commit hook (global)
# Feeds commit data to the Pushling daemon.
# Also chains to any repo-local post-commit hook.

# Run pushling hook
"${PUSHLING_HOOKS_INSTALL_DIR}/post-commit.sh" &

# Chain to repo-local hook if it exists
# (When using core.hooksPath, local hooks are bypassed — we restore them here)
GIT_DIR="\$(git rev-parse --git-dir 2>/dev/null)"
LOCAL_HOOK="\${GIT_DIR}/hooks.local/post-commit"
if [[ -x "\$LOCAL_HOOK" ]]; then
    "\$LOCAL_HOOK"
fi

wait
GITEOF
    chmod +x "${git_hooks_dir}/post-commit"

    # Check if core.hooksPath is already set
    local current_hooks_path
    current_hooks_path=$(git config --global core.hooksPath 2>/dev/null) || current_hooks_path=""

    if [[ -n "$current_hooks_path" && "$current_hooks_path" != "$git_hooks_dir" ]]; then
        warn "core.hooksPath is already set to: ${current_hooks_path}"
        warn "Setting it to ${git_hooks_dir} will override this."
        read -p "Continue? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 0
    fi

    git config --global core.hooksPath "$git_hooks_dir"
    ok "Global git hooks installed at ${git_hooks_dir}"
    ok "All repos will now feed commits to Pushling."
}

install_git_hook_repo() {
    local repo_path="$1"

    # Resolve to absolute path
    repo_path="$(cd "$repo_path" 2>/dev/null && pwd)" || {
        error "Cannot access repo at: $1"
        return 1
    }

    # Verify it's a git repo
    if [[ ! -d "${repo_path}/.git" ]]; then
        error "Not a git repository: ${repo_path}"
        return 1
    fi

    local hooks_dir="${repo_path}/.git/hooks"
    local hook_file="${hooks_dir}/post-commit"

    # Check for existing hook
    if [[ -f "$hook_file" ]]; then
        warn "Existing post-commit hook found in ${repo_path}"
        warn "It will be preserved as post-commit.pre-pushling"
        cp "$hook_file" "${hook_file}.pre-pushling"
    fi

    # Write the hook
    cat > "$hook_file" << REPOEOF
#!/usr/bin/env bash
# Pushling post-commit hook
# Feeds commit data to the Pushling daemon.

"${PUSHLING_HOOKS_INSTALL_DIR}/post-commit.sh" &

# Run the previous hook if it was preserved
if [[ -x "${hook_file}.pre-pushling" ]]; then
    "${hook_file}.pre-pushling"
fi

wait
REPOEOF
    chmod +x "$hook_file"

    ok "Git hook installed for $(basename "$repo_path") at ${hook_file}"
}

# ── Uninstall ──────────────────────────────────────────────────────────

uninstall() {
    info "Uninstalling Pushling hooks..."

    # Remove Claude Code hooks
    local claude_hooks_file="${HOME}/.claude/hooks.json"
    if [[ -f "$claude_hooks_file" ]]; then
        # Restore backup if it exists
        if [[ -f "${claude_hooks_file}.bak" ]]; then
            mv "${claude_hooks_file}.bak" "$claude_hooks_file"
            ok "Restored previous hooks.json from backup"
        else
            rm -f "$claude_hooks_file"
            ok "Removed Claude Code hooks configuration"
        fi
    fi

    # Remove global git hooks if ours
    local current_hooks_path
    current_hooks_path=$(git config --global core.hooksPath 2>/dev/null) || current_hooks_path=""
    if [[ "$current_hooks_path" == "${PUSHLING_DATA_DIR}/git-hooks" ]]; then
        git config --global --unset core.hooksPath
        ok "Removed global git hooks path"
    fi

    # Remove installed hook scripts
    if [[ -d "$PUSHLING_HOOKS_INSTALL_DIR" ]]; then
        rm -rf "$PUSHLING_HOOKS_INSTALL_DIR"
        ok "Removed hook scripts from ${PUSHLING_HOOKS_INSTALL_DIR}"
    fi

    ok "Pushling hooks uninstalled."
    info "Note: Feed directory and state database were NOT removed."
    info "To fully remove: rm -rf ${PUSHLING_DATA_DIR}"
}

# ── Main ───────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║   Pushling Hook Installer             ║"
    echo "  ║   Feed your creature. It's hungry.    ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo ""

    case "${1:-}" in
        --uninstall|-u)
            uninstall
            ;;
        --git)
            setup_directories
            install_hook_scripts
            register_claude_hooks
            install_git_hook_global
            ;;
        --git-repo)
            if [[ -z "${2:-}" ]]; then
                error "Usage: install.sh --git-repo /path/to/repo"
                exit 1
            fi
            setup_directories
            install_hook_scripts
            register_claude_hooks
            install_git_hook_repo "$2"
            ;;
        --help|-h)
            echo "Usage:"
            echo "  install.sh              Install Claude Code hooks"
            echo "  install.sh --git        Also install global git hook"
            echo "  install.sh --git-repo P Install git hook to repo at path P"
            echo "  install.sh --uninstall  Remove all Pushling hooks"
            echo "  install.sh --help       Show this help"
            ;;
        *)
            setup_directories
            install_hook_scripts
            register_claude_hooks
            echo ""
            info "Git post-commit hook NOT installed."
            info "To install globally: $0 --git"
            info "To install per-repo: $0 --git-repo /path/to/repo"
            ;;
    esac

    echo ""
    ok "Done! Your creature awaits."
}

main "$@"
