# Agent Routing Rule — MANDATORY

**STOP. Before writing ANY response to the user, you MUST run the routing classification below.** This is not optional. Do NOT handle a task on the main thread if it matches an agent in the routing table. Do NOT use your built-in knowledge of how to perform git operations, run tests, or do other tasks that have a matching agent — dispatch to the agent instead.

**The ONLY exceptions where you may skip routing:**
- The user's message is a slash command (starts with `/`)
- The user's message is a simple question with no action required (e.g. "what does this function do?")
- The user's message is a trivial single-line fix (e.g. "fix the typo on line 42")
- You are mid-task and the user is responding to a clarification question you asked

## Routing Table

Match the user's task against these agents in priority order. The **first match wins**.

| Priority | Agent | When to use | Signals |
|----------|-------|-------------|---------|
| 1 | `ui-specialist` | UI, frontend, CSS, layout, template, visual work | "modal", "button", "responsive", "CSS", "style", "layout", "template", `*.html`, `*.css`, `*.hbs`, `*.ejs` |
| 1 | `bug-finder-refiner` | Code audits, bug sweeps, pre-demo quality checks | "audit", "edge cases", "before demo", "code smell", "sweep", "review for bugs" |
| 1 | `github-sync` | Git/GitHub operations — push, PR, branch, merge | "push", "PR", "pull request", "commit", "branch", "merge", "rebase", "cherry-pick" |
| 2 | `local-dev-runner` | Build, test, install, dev server, shell ops | "run tests", "install", "start server", "npm", "pip", "build", "compile", "lint" |
| 2 | `feature-planner` | Feature scoping, brainstorming, design exploration | "plan feature", "scope", "trade-offs", "how would we", "brainstorm", "feasibility" |
| 2 | `Explore` | Codebase search, understanding, navigation | "find", "where is", "how does X work", "show me", "search for" |
| 2 | `Plan` | Architecture, implementation strategy, system design | "design system", "implementation plan", "architect", "strategy" |
| — | Main thread | Simple questions, trivial fixes, conversation | No strong agent signal; single-line fixes; clarification questions |

### Priority Rules

- **Tier 1** agents match on strong, unambiguous signals — dispatch immediately.
- **Tier 2** agents match when the task clearly falls within their domain but doesn't match a Tier 1 agent.
- **Main thread** handles everything else — trivial edits, questions, short fixes.

### Overlap Resolution

When signals overlap between agents, apply these rules:

- **Git verb + domain keyword** (e.g. "push the CSS fix"): route to `github-sync`. The git operation is the action; the domain keyword is just context.
- **"Review/audit" + "PR"**: route to `bug-finder-refiner`. Reviewing a PR is a code quality task, not a git operation.
- **"Find" + domain keyword** (e.g. "find the bug in modal"): route to the domain agent (`ui-specialist`), not `Explore`. `Explore` is for codebase navigation, not domain-specific investigation.
- **General overlap**: pick the most specific agent for the *primary* task (e.g. "fix the CSS bug before the demo" → `ui-specialist` for CSS work, not `bug-finder-refiner`).

### Memory Management

For memory file management tasks ("review my memory files", "clean up CLAUDE.md", "prune memory"), suggest the user run `/context-plane` directly. Memory management is handled by a dedicated command, not a sub-agent.

## Dispatch Protocol

**For EVERY user message (except the exceptions listed at the top):**

1. **Classify** — Read the user's message. Identify keywords, file types, and intent.
2. **Match** — Compare against the routing table. If ANY signal matches, you MUST dispatch. Only stay on main thread if there is genuinely no match.
3. **Announce** — State the routing decision in one line before dispatching:
   `Routing to <agent-name> — <brief reason>`
4. **Dispatch** — Use the `Task` tool with the correct `subagent_type` (see mapping below) and `model: "opus"`. Include the full user request and any relevant context in the prompt.
5. **Summarize** — After the agent returns, relay its results to the user concisely.

**CRITICAL: Do NOT perform the task yourself.** Even if you know how to do it (e.g. git commit, npm install), dispatch to the matched agent. The agent has specialized instructions and context for its domain.

### Subagent Type Mapping

Map routing table agent names to Task tool `subagent_type` values:

| Agent Name | `subagent_type` | Availability |
|------------|----------------|--------------|
| `github-sync` | `github-sync` | Always (user-level) |
| `feature-planner` | `feature-planner` | Always (user-level) |
| `local-dev-runner` | `local-dev-runner` | Always (user-level) |
| `Explore` | `Explore` | Always (built-in) |
| `Plan` | `Plan` | Always (built-in) |
| `ui-specialist` | `general-purpose` | Project-level — requires `--init-project`. Use `general-purpose` and include the agent's instructions from `.claude/agents/ui-specialist.md` in the prompt. |
| `bug-finder-refiner` | `general-purpose` | Project-level — requires `--init-project`. Use `general-purpose` and include the agent's instructions from `.claude/agents/bug-finder-refiner.md` in the prompt. |

### Multi-Domain Tasks

If a task spans multiple agent domains (e.g. "add a new API endpoint with tests and update the UI"):

1. Break into sub-tasks aligned to individual agents.
2. Dispatch sequentially — respect dependencies (backend before frontend, code before tests).
3. Summarize the combined result.

### Model Requirement

Always set `model: "opus"` on every `Task` tool invocation. No exceptions.

## Post-Change Tracking

After each agent completes, discover which files were modified:

1. **Discover modified files** — Run `git diff --name-only` to detect modified tracked files, and `git ls-files --others --exclude-standard` to detect new untracked files. Combine both lists. If both are empty (e.g. because the agent committed its changes), fall back to `git diff --name-only HEAD~1` to detect files changed in the most recent commit. If not in a git repo, ask the dispatched agent to end its response with a "Files modified:" line listing every file it changed.
2. **Skip if empty** — If no files were modified, skip tracking entirely. Do not create empty tracking entries.
3. **Read state** — Read the project-level state file at `~/.claude/projects/<current-project-key>/context-plane-state.json` (the same path Claude Code uses for project-scoped `.claude/` files, where the project key is the escaped directory path). If the file is missing or contains invalid JSON, start with `{}`.
4. **Initialize if needed** — If `agent_manager_tracking` does not exist in the state object, create it: `"agent_manager_tracking": { "modifications": [] }`.
5. **Append** to `agent_manager_tracking.modifications[]`:
   ```json
   {
     "timestamp": "<ISO 8601 UTC>",
     "agent": "<agent-name>",
     "files_modified": ["<list of files discovered in step 1>"],
     "updated_by": "agent-manager:<agent-name>"
   }
   ```
6. **Write** the updated state back.
7. **Count check** — Count only entries in `agent_manager_tracking.modifications[]` whose `timestamp` is newer than `last_run` (if `last_run` exists in the state file). If `last_run` is missing, count all entries. If the count is 10 or more, suggest:
   `Tip: 10+ file modifications tracked since last review. Consider running /context-plane review to tidy up.`

### Boundaries

- **Never** prune, edit, or delete memory files (MEMORY.md, CLAUDE.md, etc.) — only track state.
- **Never** overwrite context-plane's own fields (`last_run`, `files_reviewed`, `changes_made`, `last_invoked`).
- Only write to the `agent_manager_tracking` key in the state file.

### Concurrency Note

This tracking protocol is not concurrency-safe. If multiple Claude Code sessions dispatch agents simultaneously, tracking entries may be lost. This is acceptable because tracking is informational, not critical.

## Examples

**User says:** "Fix the modal clipping on mobile"
→ `Routing to ui-specialist — modal/mobile layout fix`

**User says:** "Push my changes to GitHub"
→ `Routing to github-sync — push to remote`

**User says:** "Run the test suite"
→ `Routing to local-dev-runner — execute tests`

**User says:** "We need to think about how notifications should work"
→ `Routing to feature-planner — notification feature scoping`

**User says:** "Where is the auth middleware defined?"
→ `Routing to Explore — codebase search for auth middleware`

**User says:** "Do a full code audit before the demo"
→ `Routing to bug-finder-refiner — pre-demo quality sweep`

**User says:** "Fix the typo on line 42"
→ Main thread — trivial single-line fix

**User says:** "Review my memory files"
→ Main thread — suggest `/context-plane review`
