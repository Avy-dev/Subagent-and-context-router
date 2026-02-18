#!/usr/bin/env bash
# install.sh — Install agent-manager skill: routing rules, command, and agent definitions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_DIR="$HOME/.claude/rules"
COMMANDS_DIR="$HOME/.claude/commands"
AGENTS_DIR="$HOME/.claude/agents"

# --- Uninstall mode ---
if [ "${1:-}" = "--uninstall" ]; then
    rm -f "$RULES_DIR/agent-managing.md"
    rm -f "$COMMANDS_DIR/agent-manager.md"
    # Only remove agent symlinks that point back to our skill
    if [ -d "$AGENTS_DIR" ]; then
        for f in "$AGENTS_DIR"/*.md; do
            [ -e "$f" ] || continue
            if [ -L "$f" ] && [[ "$(readlink "$f")" == "$SCRIPT_DIR/agents/user/"* ]]; then
                rm -f "$f"
                echo "Removed: $f"
            fi
        done
    fi
    echo "AgentManager v$(cat "$SCRIPT_DIR/VERSION") uninstalled."
    exit 0
fi

# --- Init project templates ---
if [ "${1:-}" = "--init-project" ]; then
    PROJECT_AGENTS=".claude/agents"
    mkdir -p "$PROJECT_AGENTS"
    COPIED=0
    for t in "$SCRIPT_DIR/agents/project-templates/"*.md; do
        [ -f "$t" ] || continue
        name="$(basename "$t")"
        if [ -e "$PROJECT_AGENTS/$name" ]; then
            echo "Skipped: $PROJECT_AGENTS/$name already exists"
        else
            cp "$t" "$PROJECT_AGENTS/$name"
            echo "Copied: $PROJECT_AGENTS/$name"
            COPIED=$((COPIED + 1))
        fi
    done
    echo ""
    echo "$COPIED project agent template(s) installed to $PROJECT_AGENTS/"
    exit 0
fi

# --- Verify source files exist ---
for f in "$SCRIPT_DIR/agent-managing.md" "$SCRIPT_DIR/agent-manager.md" "$SCRIPT_DIR/VERSION"; do
    [ -f "$f" ] || { echo "Error: $(basename "$f") not found in $SCRIPT_DIR"; exit 1; }
done

# --- Create target directories ---
mkdir -p "$RULES_DIR"
mkdir -p "$COMMANDS_DIR"
mkdir -p "$AGENTS_DIR"

# --- Backup existing regular files (not symlinks) before overwriting ---
for f in "$RULES_DIR/agent-managing.md" "$COMMANDS_DIR/agent-manager.md"; do
    if [ -e "$f" ] && [ ! -L "$f" ]; then
        echo "Warning: $f exists as a regular file. Backing up to ${f}.bak"
        cp "$f" "${f}.bak"
    fi
done

# --- Symlink always-on routing rule ---
ln -sf "$SCRIPT_DIR/agent-managing.md" "$RULES_DIR/agent-managing.md"
echo "Linked: $RULES_DIR/agent-managing.md"

# --- Symlink manual command ---
ln -sf "$SCRIPT_DIR/agent-manager.md" "$COMMANDS_DIR/agent-manager.md"
echo "Linked: $COMMANDS_DIR/agent-manager.md"

# --- Install user-level agent definitions ---
echo ""
echo "Installing agent definitions..."
AGENT_COUNT=0
for agent_file in "$SCRIPT_DIR/agents/user/"*.md; do
    [ -f "$agent_file" ] || continue
    agent_name="$(basename "$agent_file")"
    target="$AGENTS_DIR/$agent_name"

    # Backup existing regular files
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "  Warning: $target exists as regular file. Backing up to ${target}.bak"
        cp "$target" "${target}.bak"
    fi

    ln -sf "$agent_file" "$target"
    echo "  Linked: $AGENTS_DIR/$agent_name"
    AGENT_COUNT=$((AGENT_COUNT + 1))
done

# --- Summary ---
echo ""
echo "AgentManager v$(cat "$SCRIPT_DIR/VERSION") installed successfully."
echo "  Rule:    ~/.claude/rules/agent-managing.md    (always-on)"
echo "  Command: ~/.claude/commands/agent-manager.md  (/agent-manager)"
echo "  Agents:  $AGENT_COUNT user-level agent(s) in ~/.claude/agents/"

# --- Mention project templates ---
if [ -d "$SCRIPT_DIR/agents/project-templates" ]; then
    TEMPLATE_COUNT=0
    for t in "$SCRIPT_DIR/agents/project-templates/"*.md; do
        [ -f "$t" ] && TEMPLATE_COUNT=$((TEMPLATE_COUNT + 1))
    done
    if [ "$TEMPLATE_COUNT" -gt 0 ]; then
        echo ""
        echo "Project-level agent templates available ($TEMPLATE_COUNT):"
        for t in "$SCRIPT_DIR/agents/project-templates/"*.md; do
            [ -f "$t" ] && echo "  - $(basename "$t")"
        done
        echo ""
        echo "To install project agents into your current project, run:"
        echo "  bash $SCRIPT_DIR/install.sh --init-project"
    fi
fi
