# Skills Registry

Custom skills installed for Claude Code. Each skill lives in its own subdirectory of this directory and is symlinked into `~/.claude/` via its `install.sh`.

## Installed Skills

### AgentManager (v2.0.1)
- **Directory:** `agent-manager/`
- **Purpose:** Automatic task dispatch to specialized sub-agents. Every user message is classified by intent and routed to the best agent — UI work goes to the UI specialist, git operations go to github-sync, code audits go to the bug finder. Ships agent definitions alongside routing logic.
- **Components:**
  - `agent-managing.md` — Always-on rule (loaded into every conversation via `~/.claude/rules/`)
  - `agent-manager.md` — Manual `/agent-manager` command (via `~/.claude/commands/`)
  - `VERSION` — Version tracking
  - `install.sh` — Installer (supports `--uninstall` and `--init-project`)
  - `agents/user/` — User-level agent definitions (symlinked to `~/.claude/agents/`):
    - `feature-planner.md` — Feature scoping and planning specialist
    - `github-sync.md` — Git/GitHub operations specialist
    - `local-dev-runner.md` — Build, test, and environment operations
  - `agents/project-templates/` — Project-level agent templates (copied on demand):
    - `bug-finder-refiner.md` — Code quality auditor (memory: project)
    - `ui-specialist.md` — UI/UX engineer (memory: project)
- **Usage:**
  - Automatic: Just describe your task — routing happens transparently
  - Manual: `/agent-manager <agent-name> <task>` to force-dispatch (case-insensitive)
  - Status: `/agent-manager status` to see tracked modifications
  - Version: `/agent-manager version`
- **Install:**
  - `bash install.sh` — Install rule, command, and user-level agents
  - `bash install.sh --init-project` — Copy project templates into `.claude/agents/`
  - `bash install.sh --uninstall` — Remove all installed symlinks
- **Integration:** Tracks modifications in project-level `context-plane-state.json` under the `agent_manager_tracking` key. Suggests `/context-plane review` after 10+ modifications since last review.

### ContextPlane (v1.0.0)
- **Directory:** `context-plane/`
- **Purpose:** Autonomous memory lifecycle management and session persistence. Reviews, prunes, moves, and pins entries across CLAUDE.md and auto-memory files. Includes a session-resume rule that persists working context across conversations and self-compacts to stay under size limits.
- **Components:**
  - `session-resume.md` — Always-on rule (loaded into every conversation via `~/.claude/rules/`)
  - `context-plane.md` — Dispatcher command (via `~/.claude/commands/`)
  - `checkpoint.md` — Capture session context before it's lost
  - `review-memory.md` — Autonomous review with proposal + approval
  - `prune-memory.md` — Automated pruning with approval
  - `move-memory.md` — Move sections between memory files
  - `overflow.md` — Move detailed MEMORY.md sections to topic files
  - `pin.md` — Pin entries to protect from pruning
  - `restore.md` — List and restore pre-modification snapshots
  - `VERSION` — Version tracking
  - `install.sh` — Installer (supports `--uninstall`)
- **Usage:** `/context-plane <subcommand> [arguments]`
- **Install:**
  - `bash context-plane/install.sh` — Install rule and all commands
  - `bash context-plane/install.sh --uninstall` — Remove all installed symlinks
- **Integration:** AgentManager tracks modifications in `context-plane-state.json` and suggests `/context-plane review` after 10+ changes.
