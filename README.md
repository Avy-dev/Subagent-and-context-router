# Claude Code Skills

Custom skills that extend [Claude Code](https://claude.ai/code) with specialized agents, commands, and always-on rules.

## Quick Start

```bash
# Clone and install
git clone https://github.com/USER/claude-code-skills.git ~/.claude/skills
bash ~/.claude/skills/install.sh

# Or one-liner (update REPO_URL in remote-install.sh first)
curl -fsSL https://raw.githubusercontent.com/USER/claude-code-skills/main/remote-install.sh | bash
```

## What's Included

### AgentManager (v2.0.1)

Automatic task dispatch to specialized sub-agents. Every user message is classified by intent and routed to the best agent.

| Agent | Triggers | Purpose |
|-------|----------|---------|
| `github-sync` | push, PR, commit, branch | Git/GitHub operations |
| `feature-planner` | plan, scope, brainstorm | Feature design and planning |
| `local-dev-runner` | run tests, build, install | Build, test, dev server ops |
| `ui-specialist` | modal, CSS, layout | UI/UX work (project-level) |
| `bug-finder-refiner` | audit, sweep, review | Code quality (project-level) |

### ContextPlane (v1.0.0)

Autonomous memory lifecycle management. Keeps your CLAUDE.md, MEMORY.md, and session context clean and organized.

| Command | Purpose |
|---------|---------|
| `/context-plane checkpoint` | Capture and persist session context |
| `/context-plane review` | Autonomous memory review with approval |
| `/context-plane prune` | Automated pruning with approval |
| `/context-plane move` | Move sections between memory files |
| `/context-plane overflow` | Move detailed sections to topic files |
| `/context-plane pin` | Pin entries to protect from pruning |
| `/context-plane restore` | Restore pre-modification snapshots |

## Commands

```bash
# Show what's installed
bash ~/.claude/skills/install.sh --status

# Update to latest
bash ~/.claude/skills/install.sh --update

# Uninstall everything
bash ~/.claude/skills/install.sh --uninstall

# Install project-level agents to current project
bash ~/.claude/skills/install.sh --init-project

# Install a specific skill only
bash ~/.claude/skills/install.sh agent-manager
```

## How It Works

Skills are installed via symlinks to `~/.claude/`:

```
~/.claude/
├── rules/           # Always-on rules (loaded every conversation)
├── commands/        # Slash commands (/context-plane, etc.)
├── agents/          # User-level agent definitions
└── .skills-receipt.json  # Tracks installed skills
```

Symlinks mean edits to the source repo propagate immediately. Run `--update` only when new files are added or versions change.

## Project-Level Agents

Some agents (like `ui-specialist` and `bug-finder-refiner`) are project-level — they're copied to `.claude/agents/` in your project and can be customized:

```bash
cd your-project
bash ~/.claude/skills/install.sh --init-project
```

## Architecture

```
Skills/
├── install.sh              # Unified installer
├── skills.json             # Repo manifest
├── agent-manager/
│   ├── skill.json          # Skill manifest
│   ├── install.sh          # Standalone installer (still works)
│   ├── agent-managing.md   # Always-on routing rule
│   ├── agent-manager.md    # /agent-manager command
│   └── agents/
│       ├── user/           # User-level (symlinked)
│       └── project-templates/  # Project-level (copied)
└── context-plane/
    ├── skill.json          # Skill manifest
    ├── install.sh          # Standalone installer
    ├── session-resume.md   # Always-on session rule
    └── *.md                # Commands
```

## Creating Your Own Skills

1. Create a directory with `skill.json`:

```json
{
  "name": "my-skill",
  "display_name": "My Skill",
  "description": "What it does",
  "version_file": "VERSION",
  "depends_on": [],
  "recommends": [],
  "install": {
    "rules": [],
    "commands": [
      { "source": "my-command.md", "target": "my-command.md" }
    ],
    "agents": [],
    "hooks": [],
    "project_templates": []
  }
}
```

2. Add `VERSION` file with semver string
3. Add your `.md` files
4. Add to `skills.json` in repo root
5. Run `install.sh`

## License

MIT
