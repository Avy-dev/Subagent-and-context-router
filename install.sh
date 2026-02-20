#!/usr/bin/env bash
# install.sh — Unified installer for Claude Code Skills
# Usage:
#   bash install.sh                    # Install all default skills
#   bash install.sh agent-manager      # Install specific skill(s)
#   bash install.sh --uninstall        # Uninstall all skills
#   bash install.sh --uninstall agent-manager  # Uninstall specific skill
#   bash install.sh --status           # Show installation status
#   bash install.sh --update           # Pull latest and reinstall if needed
#   bash install.sh --init-project     # Copy project templates to current dir

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
RULES_DIR="$CLAUDE_DIR/rules"
COMMANDS_DIR="$CLAUDE_DIR/commands"
AGENTS_DIR="$CLAUDE_DIR/agents"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
RECEIPT_FILE="$CLAUDE_DIR/.skills-receipt.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─────────────────────────────────────────────────────────────────────────────
# JSON helpers (uses Python as portable JSON parser)
# ─────────────────────────────────────────────────────────────────────────────

json_get() {
    local file="$1" query="$2"
    python3 -c "
import json, sys
with open('$file') as f:
    data = json.load(f)
result = data
for key in '$query'.strip('.').split('.'):
    if key:
        if isinstance(result, list):
            result = result[int(key)]
        else:
            result = result.get(key)
if result is None:
    sys.exit(1)
if isinstance(result, (dict, list)):
    print(json.dumps(result))
else:
    print(result)
" 2>/dev/null
}

json_array_len() {
    local file="$1" query="$2"
    python3 -c "
import json
with open('$file') as f:
    data = json.load(f)
result = data
for key in '$query'.strip('.').split('.'):
    if key:
        result = result.get(key, [])
print(len(result) if isinstance(result, list) else 0)
" 2>/dev/null || echo "0"
}

json_array_item() {
    local file="$1" query="$2" index="$3"
    python3 -c "
import json
with open('$file') as f:
    data = json.load(f)
result = data
for key in '$query'.strip('.').split('.'):
    if key:
        result = result.get(key, [])
if isinstance(result, list) and $index < len(result):
    item = result[$index]
    if isinstance(item, dict):
        print(json.dumps(item))
    else:
        print(item)
" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Receipt management
# ─────────────────────────────────────────────────────────────────────────────

init_receipt() {
    if [ ! -f "$RECEIPT_FILE" ]; then
        echo '{
  "receipt_version": 1,
  "installed_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "source_repo": "'"$REPO_DIR"'",
  "skills": {}
}' > "$RECEIPT_FILE"
    fi
}

record_install() {
    local skill_name="$1" version="$2" skill_dir="$3"
    shift 3
    local symlinks=("$@")

    python3 << PYEOF
import json
from datetime import datetime, timezone

receipt_path = "$RECEIPT_FILE"
try:
    with open(receipt_path) as f:
        receipt = json.load(f)
except:
    receipt = {"receipt_version": 1, "skills": {}}

receipt["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
receipt["source_repo"] = "$REPO_DIR"

receipt["skills"]["$skill_name"] = {
    "version": "$version",
    "installed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source_dir": "$skill_dir",
    "symlinks": ${symlinks[@]+"$(printf '%s\n' "${symlinks[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin]))")"},
    "hooks": []
}

with open(receipt_path, 'w') as f:
    json.dump(receipt, f, indent=2)
PYEOF
}

record_hook() {
    local skill_name="$1" event="$2" command_path="$3"

    python3 << PYEOF
import json

receipt_path = "$RECEIPT_FILE"
with open(receipt_path) as f:
    receipt = json.load(f)

if "$skill_name" in receipt["skills"]:
    hooks = receipt["skills"]["$skill_name"].setdefault("hooks", [])
    hook_entry = {"event": "$event", "command": "$command_path"}
    if hook_entry not in hooks:
        hooks.append(hook_entry)

with open(receipt_path, 'w') as f:
    json.dump(receipt, f, indent=2)
PYEOF
}

get_installed_skills() {
    if [ -f "$RECEIPT_FILE" ]; then
        python3 -c "
import json
with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)
for skill in receipt.get('skills', {}).keys():
    print(skill)
" 2>/dev/null
    fi
}

is_installed() {
    local skill_name="$1"
    if [ -f "$RECEIPT_FILE" ]; then
        python3 -c "
import json, sys
with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)
sys.exit(0 if '$skill_name' in receipt.get('skills', {}) else 1)
" 2>/dev/null
    else
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Hook management (settings.json)
# ─────────────────────────────────────────────────────────────────────────────

install_hook() {
    local event="$1" command_path="$2"

    chmod +x "$command_path" 2>/dev/null || true

    python3 << PYEOF
import json, os

settings_path = os.path.expanduser("$SETTINGS_FILE")

# Read or create settings
try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.setdefault("hooks", {})
event_hooks = hooks.setdefault("$event", [])

# Check if already registered
command_path = "$command_path"
already = any(
    h.get("hooks", [{}])[0].get("command") == command_path
    for h in event_hooks if isinstance(h, dict)
)

if not already:
    event_hooks.append({
        "matcher": "",
        "hooks": [{"type": "command", "command": command_path}]
    })

    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    print("installed")
else:
    print("exists")
PYEOF
}

remove_hook() {
    local command_path="$1"

    python3 << PYEOF
import json, os

settings_path = os.path.expanduser("$SETTINGS_FILE")

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    exit(0)

hooks = settings.get("hooks", {})
modified = False

for event, event_hooks in hooks.items():
    original_len = len(event_hooks)
    hooks[event] = [
        h for h in event_hooks
        if not (isinstance(h, dict) and h.get("hooks", [{}])[0].get("command") == "$command_path")
    ]
    if len(hooks[event]) < original_len:
        modified = True

if modified:
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    print("removed")
PYEOF
}

# ─────────────────────────────────────────────────────────────────────────────
# File operations
# ─────────────────────────────────────────────────────────────────────────────

backup_if_regular_file() {
    local path="$1"
    if [ -e "$path" ] && [ ! -L "$path" ]; then
        echo -e "  ${YELLOW}Backing up:${NC} $path -> ${path}.bak"
        cp "$path" "${path}.bak"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Install a single skill
# ─────────────────────────────────────────────────────────────────────────────

install_skill() {
    local skill_name="$1"
    local skill_dir="$REPO_DIR/$skill_name"
    local manifest="$skill_dir/skill.json"

    if [ ! -f "$manifest" ]; then
        echo -e "${RED}Error:${NC} Skill '$skill_name' not found (no skill.json at $skill_dir)"
        return 1
    fi

    local version_file display_name version
    version_file=$(json_get "$manifest" "version_file")
    display_name=$(json_get "$manifest" "display_name")
    version=$(cat "$skill_dir/$version_file")

    echo -e "${BLUE}Installing${NC} $display_name v$version..."

    # Check dependencies
    local dep_count dep_name
    dep_count=$(json_array_len "$manifest" "depends_on")
    for ((i=0; i<dep_count; i++)); do
        dep_name=$(json_array_item "$manifest" "depends_on" "$i")
        if ! is_installed "$dep_name"; then
            echo -e "  ${RED}Error:${NC} Requires '$dep_name'. Install it first."
            return 1
        fi
    done

    # Check recommendations
    local rec_count rec_name
    rec_count=$(json_array_len "$manifest" "recommends")
    for ((i=0; i<rec_count; i++)); do
        rec_name=$(json_array_item "$manifest" "recommends" "$i")
        if ! is_installed "$rec_name"; then
            echo -e "  ${YELLOW}Note:${NC} Works best with '$rec_name'. Consider installing it too."
        fi
    done

    # Create directories
    mkdir -p "$RULES_DIR" "$COMMANDS_DIR" "$AGENTS_DIR"

    local symlinks=()
    local count source target

    # Symlink rules
    count=$(json_array_len "$manifest" "install.rules")
    for ((i=0; i<count; i++)); do
        source=$(json_get "$manifest" "install.rules.$i.source")
        target=$(json_get "$manifest" "install.rules.$i.target")
        backup_if_regular_file "$RULES_DIR/$target"
        ln -sf "$skill_dir/$source" "$RULES_DIR/$target"
        symlinks+=("$RULES_DIR/$target")
        echo -e "  ${GREEN}Linked:${NC} rules/$target"
    done

    # Symlink commands
    count=$(json_array_len "$manifest" "install.commands")
    for ((i=0; i<count; i++)); do
        source=$(json_get "$manifest" "install.commands.$i.source")
        target=$(json_get "$manifest" "install.commands.$i.target")
        backup_if_regular_file "$COMMANDS_DIR/$target"
        ln -sf "$skill_dir/$source" "$COMMANDS_DIR/$target"
        symlinks+=("$COMMANDS_DIR/$target")
        echo -e "  ${GREEN}Linked:${NC} commands/$target"
    done

    # Symlink agents
    count=$(json_array_len "$manifest" "install.agents")
    for ((i=0; i<count; i++)); do
        source=$(json_get "$manifest" "install.agents.$i.source")
        target=$(json_get "$manifest" "install.agents.$i.target")
        backup_if_regular_file "$AGENTS_DIR/$target"
        ln -sf "$skill_dir/$source" "$AGENTS_DIR/$target"
        symlinks+=("$AGENTS_DIR/$target")
        echo -e "  ${GREEN}Linked:${NC} agents/$target"
    done

    # Install hooks
    count=$(json_array_len "$manifest" "install.hooks")
    for ((i=0; i<count; i++)); do
        local hook_json event hook_source command_path result
        hook_json=$(json_array_item "$manifest" "install.hooks" "$i")
        event=$(echo "$hook_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['event'])")
        hook_source=$(echo "$hook_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['source'])")
        command_path="$skill_dir/$hook_source"

        result=$(install_hook "$event" "$command_path")
        if [ "$result" = "installed" ]; then
            echo -e "  ${GREEN}Hook:${NC} $event -> $hook_source"
            record_hook "$skill_name" "$event" "$command_path"
        else
            echo -e "  ${YELLOW}Hook:${NC} $event (already registered)"
        fi
    done

    # Record installation
    record_install "$skill_name" "$version" "$skill_dir" "${symlinks[@]}"

    # Post-install message
    local post_msg
    post_msg=$(json_get "$manifest" "post_install_message" 2>/dev/null || true)
    if [ -n "$post_msg" ]; then
        echo -e "  ${YELLOW}Tip:${NC} $post_msg"
    fi

    echo -e "${GREEN}$display_name v$version installed.${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Uninstall a single skill
# ─────────────────────────────────────────────────────────────────────────────

uninstall_skill() {
    local skill_name="$1"

    if ! is_installed "$skill_name"; then
        echo -e "${YELLOW}Warning:${NC} '$skill_name' is not installed."
        return 0
    fi

    local display_name version
    display_name=$(json_get "$REPO_DIR/$skill_name/skill.json" "display_name" 2>/dev/null || echo "$skill_name")
    version=$(python3 -c "
import json
with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)
print(receipt['skills']['$skill_name'].get('version', 'unknown'))
" 2>/dev/null || echo "unknown")

    echo -e "${BLUE}Uninstalling${NC} $display_name v$version..."

    # Remove symlinks
    python3 << PYEOF
import json, os

with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)

skill_data = receipt['skills'].get('$skill_name', {})

for symlink in skill_data.get('symlinks', []):
    if os.path.islink(symlink):
        os.remove(symlink)
        print(f"  Removed: {symlink}")
    elif os.path.exists(symlink):
        print(f"  Skipped: {symlink} (not a symlink)")
PYEOF

    # Remove hooks
    python3 << PYEOF
import json, os

with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)

skill_data = receipt['skills'].get('$skill_name', {})
settings_path = os.path.expanduser("$SETTINGS_FILE")

try:
    with open(settings_path) as f:
        settings = json.load(f)
except:
    settings = {}

hooks_config = settings.get("hooks", {})
modified = False

for hook in skill_data.get('hooks', []):
    command_path = hook.get('command', '')
    for event, event_hooks in hooks_config.items():
        original_len = len(event_hooks)
        hooks_config[event] = [
            h for h in event_hooks
            if not (isinstance(h, dict) and h.get("hooks", [{}])[0].get("command") == command_path)
        ]
        if len(hooks_config[event]) < original_len:
            modified = True
            print(f"  Removed: {hook.get('event')} hook")

if modified:
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
PYEOF

    # Remove from receipt
    python3 << PYEOF
import json

with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)

if '$skill_name' in receipt['skills']:
    del receipt['skills']['$skill_name']

with open('$RECEIPT_FILE', 'w') as f:
    json.dump(receipt, f, indent=2)
PYEOF

    echo -e "${GREEN}$display_name uninstalled.${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Status command
# ─────────────────────────────────────────────────────────────────────────────

show_status() {
    echo -e "${BLUE}Claude Code Skills${NC} (source: $REPO_DIR)"
    echo "════════════════════════════════════════════════════"
    echo ""

    if [ ! -f "$RECEIPT_FILE" ]; then
        echo "No skills installed."
        echo ""
        echo "Available skills:"
        for skill_dir in "$REPO_DIR"/*/; do
            if [ -f "${skill_dir}skill.json" ]; then
                local name desc
                name=$(json_get "${skill_dir}skill.json" "display_name")
                desc=$(json_get "${skill_dir}skill.json" "description")
                echo "  - $name: $desc"
            fi
        done
        return
    fi

    python3 << PYEOF
import json, os

with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)

skills = receipt.get('skills', {})

if not skills:
    print("No skills installed.")
else:
    for name, data in skills.items():
        version = data.get('version', 'unknown')
        installed_at = data.get('installed_at', 'unknown')[:10]
        symlinks = data.get('symlinks', [])
        hooks = data.get('hooks', [])

        # Count valid symlinks
        valid = sum(1 for s in symlinks if os.path.islink(s) and os.path.exists(s))
        total = len(symlinks)

        status = "ok" if valid == total else f"{valid}/{total} valid"

        # Check recommendations
        manifest_path = f"$REPO_DIR/{name}/skill.json"
        recommends = []
        if os.path.exists(manifest_path):
            with open(manifest_path) as mf:
                manifest = json.load(mf)
                recommends = manifest.get('recommends', [])

        print(f"\033[0;34m{name}\033[0m v{version} (installed {installed_at})")
        print(f"  Symlinks: {total} ({status})")
        print(f"  Hooks:    {len(hooks)}")

        for rec in recommends:
            rec_status = "installed" if rec in skills else "not installed"
            print(f"  Recommends: {rec} ({rec_status})")
        print()
PYEOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Update command
# ─────────────────────────────────────────────────────────────────────────────

do_update() {
    echo -e "${BLUE}Updating skills...${NC}"
    echo ""

    # Pull latest if git repo
    if [ -d "$REPO_DIR/.git" ]; then
        echo "Pulling latest changes..."
        if git -C "$REPO_DIR" pull --ff-only origin main 2>/dev/null; then
            echo -e "${GREEN}Updated from remote.${NC}"
        else
            echo -e "${YELLOW}Could not pull (might have local changes or no remote).${NC}"
        fi
        echo ""
    fi

    # Check each installed skill for version changes
    for skill_name in $(get_installed_skills); do
        local skill_dir="$REPO_DIR/$skill_name"
        local manifest="$skill_dir/skill.json"

        if [ ! -f "$manifest" ]; then
            echo -e "${YELLOW}Warning:${NC} $skill_name source not found at $skill_dir"
            continue
        fi

        local old_version new_version version_file
        version_file=$(json_get "$manifest" "version_file")
        new_version=$(cat "$skill_dir/$version_file")
        old_version=$(python3 -c "
import json
with open('$RECEIPT_FILE') as f:
    receipt = json.load(f)
print(receipt['skills']['$skill_name'].get('version', ''))
" 2>/dev/null)

        if [ "$old_version" != "$new_version" ]; then
            echo -e "${BLUE}Updating${NC} $skill_name: $old_version -> $new_version"
            install_skill "$skill_name"
        else
            echo -e "${GREEN}$skill_name${NC} is up to date ($new_version)"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Init project templates
# ─────────────────────────────────────────────────────────────────────────────

init_project() {
    local target_skills=("$@")

    # Default to all installed skills if none specified
    if [ ${#target_skills[@]} -eq 0 ]; then
        while IFS= read -r skill; do
            [ -n "$skill" ] && target_skills+=("$skill")
        done < <(get_installed_skills)
    fi

    if [ ${#target_skills[@]} -eq 0 ]; then
        echo -e "${YELLOW}No skills installed.${NC} Run install.sh first."
        return 1
    fi

    local project_agents=".claude/agents"
    mkdir -p "$project_agents"

    local copied=0

    for skill_name in "${target_skills[@]}"; do
        local skill_dir="$REPO_DIR/$skill_name"
        local manifest="$skill_dir/skill.json"

        if [ ! -f "$manifest" ]; then
            continue
        fi

        local count
        count=$(json_array_len "$manifest" "install.project_templates")

        for ((i=0; i<count; i++)); do
            local source target
            source=$(json_get "$manifest" "install.project_templates.$i.source")
            target=$(json_get "$manifest" "install.project_templates.$i.target")

            if [ -e "$project_agents/$target" ]; then
                echo -e "  ${YELLOW}Skipped:${NC} $target (already exists)"
            else
                cp "$skill_dir/$source" "$project_agents/$target"
                echo -e "  ${GREEN}Copied:${NC} $target"
                copied=$((copied + 1))
            fi
        done
    done

    echo ""
    echo -e "${GREEN}$copied${NC} project template(s) installed to $project_agents/"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    local action="install"
    local skills_to_process=()

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --uninstall|-u)
                action="uninstall"
                shift
                ;;
            --status|-s)
                action="status"
                shift
                ;;
            --update|-U)
                action="update"
                shift
                ;;
            --init-project|-p)
                action="init-project"
                shift
                ;;
            --help|-h)
                echo "Usage: install.sh [options] [skill-names...]"
                echo ""
                echo "Options:"
                echo "  --uninstall, -u    Uninstall skills"
                echo "  --status, -s       Show installation status"
                echo "  --update, -U       Pull latest and reinstall if needed"
                echo "  --init-project, -p Copy project templates to current dir"
                echo "  --help, -h         Show this help"
                echo ""
                echo "Examples:"
                echo "  bash install.sh                  # Install all default skills"
                echo "  bash install.sh agent-manager    # Install specific skill"
                echo "  bash install.sh --uninstall      # Uninstall all"
                echo "  bash install.sh --status         # Show what's installed"
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option:${NC} $1"
                exit 1
                ;;
            *)
                skills_to_process+=("$1")
                shift
                ;;
        esac
    done

    # Execute action
    case "$action" in
        status)
            show_status
            ;;
        update)
            do_update
            ;;
        init-project)
            init_project "${skills_to_process[@]}"
            ;;
        install)
            init_receipt

            # Default to all skills if none specified
            if [ ${#skills_to_process[@]} -eq 0 ]; then
                while IFS= read -r skill; do
                    [ -n "$skill" ] && skills_to_process+=("$skill")
                done < <(json_get "$REPO_DIR/skills.json" "default_install" | python3 -c "import json,sys; [print(s) for s in json.load(sys.stdin)]")
            fi

            for skill in "${skills_to_process[@]}"; do
                install_skill "$skill"
            done

            echo "════════════════════════════════════════════════════"
            echo -e "${GREEN}Installation complete.${NC}"
            echo "Skills are active in all new Claude Code sessions."
            ;;
        uninstall)
            if [ ! -f "$RECEIPT_FILE" ]; then
                echo "No skills installed."
                exit 0
            fi

            # Default to all installed skills if none specified
            if [ ${#skills_to_process[@]} -eq 0 ]; then
                while IFS= read -r skill; do
                    [ -n "$skill" ] && skills_to_process+=("$skill")
                done < <(get_installed_skills)
            fi

            for skill in "${skills_to_process[@]}"; do
                uninstall_skill "$skill"
            done

            # Clean up empty receipt
            local remaining
            remaining=$(get_installed_skills | wc -l | tr -d ' ')
            if [ "$remaining" -eq 0 ]; then
                rm -f "$RECEIPT_FILE"
                echo "Receipt cleaned up."
            fi

            echo "════════════════════════════════════════════════════"
            echo -e "${GREEN}Uninstallation complete.${NC}"
            echo "Note: Project-level agents in .claude/agents/ were not removed."
            ;;
    esac
}

main "$@"
