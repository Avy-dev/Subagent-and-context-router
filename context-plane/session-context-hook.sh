#!/bin/bash
# session-context-hook.sh — Stop hook for session-context.md reminders
# Checks existence and freshness of session-context.md and outputs reminders.

# Derive project key from PWD (same escaping Claude Code uses)
PROJECT_KEY=$(echo "$PWD" | sed 's|/|-|g')
SESSION_FILE="$HOME/.claude/projects/${PROJECT_KEY}/memory/session-context.md"

# macOS is case-insensitive; find the actual directory if exact match fails
if [ ! -f "$SESSION_FILE" ] && [[ "$(uname)" == "Darwin" ]]; then
    # Try case-insensitive match
    FOUND_DIR=$(find "$HOME/.claude/projects" -maxdepth 1 -iname "${PROJECT_KEY}" -type d 2>/dev/null | head -1)
    if [ -n "$FOUND_DIR" ]; then
        SESSION_FILE="${FOUND_DIR}/memory/session-context.md"
    fi
fi

if [ ! -f "$SESSION_FILE" ]; then
    echo "session-context.md missing -- create after significant work"
    exit 0
fi

# Check if the file hasn't been modified in the last 30 minutes
if command -v stat >/dev/null 2>&1; then
    # macOS stat syntax
    if [[ "$(uname)" == "Darwin" ]]; then
        last_modified=$(stat -f %m "$SESSION_FILE" 2>/dev/null)
    else
        last_modified=$(stat -c %Y "$SESSION_FILE" 2>/dev/null)
    fi

    now=$(date +%s)
    if [ -n "$last_modified" ]; then
        age=$(( now - last_modified ))
        # 30 minutes = 1800 seconds
        if [ "$age" -gt 1800 ]; then
            echo "Consider updating session-context.md (last modified $(( age / 60 )) minutes ago)"
        fi
    fi
fi

exit 0
