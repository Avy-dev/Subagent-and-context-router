#!/usr/bin/env bash
# install.sh — Install context-plane skill: memory management commands and session-resume rule.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_DIR="$HOME/.claude/rules"
COMMANDS_DIR="$HOME/.claude/commands"

# List of command files (everything except session-resume.md, VERSION, and install.sh)
COMMAND_FILES=(
    context-plane.md
    checkpoint.md
    review-memory.md
    prune-memory.md
    move-memory.md
    overflow.md
    pin.md
    restore.md
)

# --- Uninstall mode ---
if [ "${1:-}" = "--uninstall" ]; then
    rm -f "$RULES_DIR/session-resume.md"
    echo "Removed: $RULES_DIR/session-resume.md"
    for cmd in "${COMMAND_FILES[@]}"; do
        if [ -L "$COMMANDS_DIR/$cmd" ] && [[ "$(readlink "$COMMANDS_DIR/$cmd")" == "$SCRIPT_DIR/"* ]]; then
            rm -f "$COMMANDS_DIR/$cmd"
            echo "Removed: $COMMANDS_DIR/$cmd"
        elif [ -L "$COMMANDS_DIR/$cmd" ]; then
            echo "Skipped: $COMMANDS_DIR/$cmd (symlink points elsewhere)"
        fi
    done
    echo "ContextPlane v$(cat "$SCRIPT_DIR/VERSION") uninstalled."
    exit 0
fi

# --- Verify source files exist ---
for f in "$SCRIPT_DIR/session-resume.md" "$SCRIPT_DIR/VERSION"; do
    [ -f "$f" ] || { echo "Error: $(basename "$f") not found in $SCRIPT_DIR"; exit 1; }
done
for cmd in "${COMMAND_FILES[@]}"; do
    [ -f "$SCRIPT_DIR/$cmd" ] || { echo "Error: $cmd not found in $SCRIPT_DIR"; exit 1; }
done

# --- Create target directories ---
mkdir -p "$RULES_DIR"
mkdir -p "$COMMANDS_DIR"

# --- Backup existing regular files (not symlinks) before overwriting ---
if [ -e "$RULES_DIR/session-resume.md" ] && [ ! -L "$RULES_DIR/session-resume.md" ]; then
    echo "Warning: $RULES_DIR/session-resume.md exists as a regular file. Backing up to ${RULES_DIR}/session-resume.md.bak"
    cp "$RULES_DIR/session-resume.md" "$RULES_DIR/session-resume.md.bak"
fi
for cmd in "${COMMAND_FILES[@]}"; do
    if [ -e "$COMMANDS_DIR/$cmd" ] && [ ! -L "$COMMANDS_DIR/$cmd" ]; then
        echo "Warning: $COMMANDS_DIR/$cmd exists as a regular file. Backing up to ${COMMANDS_DIR}/${cmd}.bak"
        cp "$COMMANDS_DIR/$cmd" "$COMMANDS_DIR/${cmd}.bak"
    fi
done

# --- Symlink always-on rule ---
ln -sf "$SCRIPT_DIR/session-resume.md" "$RULES_DIR/session-resume.md"
echo "Linked: $RULES_DIR/session-resume.md"

# --- Symlink commands ---
echo ""
echo "Installing commands..."
CMD_COUNT=0
for cmd in "${COMMAND_FILES[@]}"; do
    ln -sf "$SCRIPT_DIR/$cmd" "$COMMANDS_DIR/$cmd"
    echo "  Linked: $COMMANDS_DIR/$cmd"
    CMD_COUNT=$((CMD_COUNT + 1))
done

# --- Summary ---
echo ""
echo "ContextPlane v$(cat "$SCRIPT_DIR/VERSION") installed successfully."
echo "  Rule:     ~/.claude/rules/session-resume.md     (always-on)"
echo "  Commands: $CMD_COUNT command(s) in ~/.claude/commands/"
echo ""
echo "Available commands:"
echo "  /context-plane review    — Autonomous review with proposal + approval"
echo "  /context-plane prune     — Automated pruning with approval"
echo "  /context-plane move      — Move sections between memory files"
echo "  /context-plane checkpoint — Capture session context"
echo "  /context-plane overflow  — Move detailed MEMORY.md sections to topic files"
echo "  /context-plane restore   — List and restore pre-modification snapshots"
echo "  /context-plane pin       — Pin entries to protect from pruning"
