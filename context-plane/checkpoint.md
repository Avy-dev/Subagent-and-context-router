Extract and persist key context from the current session. Primary target is `session-context.md` (autonomous rewrite). Secondary target is MEMORY.md / CLAUDE.md (promotions only, requires approval).

**This command works autonomously for session-context.md.** User approval is only needed for promotions to permanent storage.

## Step 0: Load state

1. Read `.claude/context-plane-state.json`. If it does not exist, contains invalid JSON, or has an unknown `version`, start with `{ "version": 2, "files": {} }`.
2. Resolve the auto memory directory: `~/.claude/projects/<project-key>/memory/`.
3. Read `session-context.md` in that directory (if it exists) — this is the primary checkpoint target.
4. Read `MEMORY.md` in that directory (if it exists) and note its current line count.
5. Read the root `CLAUDE.md` (if it exists).
6. Read any topic files in the auto memory directory (e.g., `debugging.md`, `patterns.md`). Exclude anything inside `.snapshots/` directories and exclude `session-context.md` (it was already read in step 3).
7. Read `.claude/agents/` definitions in scope (if any).

## Step 1: Scan conversation for extractable context

Review the full conversation history and identify items worth persisting. Look for:

- **Decisions made** — "we decided to use X because Y", technology choices, trade-off resolutions
- **Bug fixes and root causes** — what broke, why, how it was fixed
- **Architecture patterns discovered** — structural insights about the codebase
- **User preferences expressed** — workflow preferences, tool choices, style preferences
- **Commands/workflows that worked** — build commands, deployment steps, useful CLI invocations
- **Project conventions confirmed** — naming patterns, file organization, testing strategies
- **Gotchas and pitfalls** — things that were confusing or error-prone
- **Current task state** — what's in progress, what's passing/failing, open PRs
- **Key files** — important files discovered or modified and their purpose

For each item, classify its **permanence**:
- `session` — working context that may change (current task, progress, recent discoveries) → goes to session-context.md
- `permanent` — stable facts unlikely to change (user preferences, build commands, architecture decisions) → candidate for MEMORY.md or CLAUDE.md promotion

## Step 2: Rewrite session-context.md (autonomous — no approval needed)

Compose a clean, current snapshot of all `session` items and merge with any still-relevant content from the existing session-context.md. This is a **full rewrite**, not an append — stale entries are dropped, current entries are kept or updated.

Use this structure:

```markdown
# Session Context
Last updated: <ISO 8601>

## Current Task
- What's actively being worked on

## Decisions
- Key decisions made and their rationale

## Discoveries
- Bug root causes, architecture insights, gotchas

## Key Files
- Important files and what they do

## State
- Current progress, what's passing/failing, open PRs

## Promote
- [target: MEMORY.md] Items worth promoting to permanent storage
- [target: CLAUDE.md] Items worth promoting to project config
```

**Writing guidelines:**
- Every entry should be a concise, actionable bullet point.
- Drop stale entries that no longer apply (completed tasks, resolved bugs, outdated state).
- Preserve the `## Promote` section if it has items not yet promoted.
- Add new promotion candidates identified in Step 1 (items classified as `permanent`).
- **Size target:** After rewriting, target **under 50 lines** (75 hard max). If the pre-checkpoint file was over 100 lines, report: `Compacted from N lines to M lines.`
- Remove any `<!-- Checkpoint recommended -->` comments left by the session-resume rule.

Write the file immediately — this is working state and does not require user approval.

After writing, report:
```
Session context updated: session-context.md (N lines)
```

If more than 3 items remain in `## Promote` after rewrite, add:
```
Note: N items pending promotion. Review below or run checkpoint again after promoting.
```

## Step 3: Identify promotions

Collect all items from the `## Promote` section of session-context.md (both pre-existing and newly added). For each item:

1. Check if MEMORY.md already contains this information (exact or semantically equivalent).
2. Check if CLAUDE.md already contains this information.
3. Check if any topic file already contains this information.

Classify each as:
- **new** — not captured anywhere yet
- **update** — partially captured but needs updating
- **skip** — already adequately captured

Drop all `skip` items.

If no items remain after filtering, report:
```
No promotions pending. Session context is up to date.
```
Remove promoted `skip` items from the `## Promote` section in session-context.md. Stop here (skip to Step 6).

## Step 4: Present promotion proposal

If promotable items remain, present them:

```
## Promotion Proposal

### New entries (N items)

#### → MEMORY.md
- [concise entry] — reason it belongs here

#### → CLAUDE.md
- [concise entry] — reason it belongs here

#### → memory/<topic>.md
- [concise entry] — reason and target file

### Updates (N items)
- [file]: [section] — what changes and why

### Skipped (N items)
- [brief description] — already in [file]

### MEMORY.md Status
- Current: N lines
- After promotions: ~M lines (estimated)
- Limit: 200 lines (first 200 loaded into system prompt)
```

If the estimated MEMORY.md line count after promotions would exceed 150 lines, add:
```
MEMORY.md will be at M/200 lines after promotions.
Consider running /context-plane overflow to move detailed sections to topic files.
```

If it would exceed 200 lines, add:
```
MEMORY.md will exceed the 200-line system prompt limit.
Running /context-plane overflow after this checkpoint is strongly recommended.
```

Then ask: **"Apply these promotions?"**

## Step 5: Apply promotions

On approval:

1. For each `new` item targeting MEMORY.md: append to the appropriate section, or create a new section if no suitable one exists.
2. For each `new` item targeting CLAUDE.md: append to the appropriate section.
3. For each `new` item targeting a topic file: append or create the file.
4. For each `update` item: edit the existing entry in place.
5. Remove all successfully promoted items from the `## Promote` section in session-context.md.

**Writing guidelines:**
- Every entry should be a direct, actionable fact or instruction — no conversational tone.
- Use concise bullet points, not paragraphs.
- Group related items under clear headings.
- Preserve any existing `<!-- pinned -->` markers.

After applying, show:
```
Promotions applied:
- MEMORY.md: N lines → M lines (if changed)
- CLAUDE.md: N lines → M lines (if changed)
- [other files changed]
- session-context.md: Promote section cleaned
```

## Step 6: Update state

1. Read `.claude/context-plane-state.json` (or start with `{ "version": 2, "files": {} }` if missing).
2. Set `version` to `2`.
3. Set `last_invoked` to the current ISO 8601 UTC timestamp.
4. For each file that was modified during this run:
   - Compute the SHA-256 hash of the file content.
   - If the path is not in `files`, add it with `created_at` and `updated_at` both set to the current timestamp, `updated_by` set to `"checkpoint"`, and `content_hash` set to `"sha256:<hash>"`.
   - If the path already exists, update `updated_at`, `updated_by`, and `content_hash`.
5. Do NOT modify `agent_manager_tracking` — that key belongs to the agent-manager.
6. Write the updated JSON to `.claude/context-plane-state.json`.

## Step 7: Overflow check

After writing, if MEMORY.md was modified, count its lines. If it exceeds 150 lines, suggest:
```
MEMORY.md is at N/200 lines. Run /context-plane overflow to move detailed sections to topic files.
```

## Audit log

After applying changes, append one entry per action to `~/.claude/projects/<project-key>/context-plane-audit.log` (JSONL format):
```jsonl
{"timestamp":"<ISO 8601 UTC>","command":"checkpoint","action":"rewrite","file":"session-context.md","reason":"Session context checkpoint","lines_after":<N>}
{"timestamp":"<ISO 8601 UTC>","command":"checkpoint","action":"promote","file":"<target path>","section":"<heading or description>","reason":"Promoted from session context","lines_added":<N>}
```

If the log exceeds 500 lines, trim the oldest entries to bring it back to 500.

## Rules

- **session-context.md is always rewritten autonomously** — no user approval needed for working state.
- **Promotions to MEMORY.md / CLAUDE.md always require approval** — these are permanent storage.
- Never ask questions during scanning (Step 1). All decisions are autonomous.
- The only user interaction is approving or rejecting promotions in Step 4.
- Prefer MEMORY.md for cross-project learnings and user preferences.
- Prefer CLAUDE.md for project-specific facts (build commands, architecture, conventions).
- Prefer topic files for detailed notes that would bloat MEMORY.md.
- Never duplicate information — if it exists in permanent storage, skip rather than promote again.
- Preserve all `<!-- pinned -->` markers in permanent files.
- When invoked directly (not via the dispatcher), handle state updates independently.

$ARGUMENTS
