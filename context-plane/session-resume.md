# Session Context — MANDATORY

## REQUIRED ACTIONS (every message)

**ON EVERY USER MESSAGE — DO THIS FIRST:**
1. Read `~/.claude/projects/<project-key>/memory/session-context.md`
2. If it exists, load its contents as active working context
3. If missing, proceed normally (you'll create it after significant work)
4. Do NOT mention the read to the user unless they ask

**AFTER SIGNIFICANT WORK — DO THIS BEFORE RESPONDING:**
Significant = task completions, bug fixes, architecture decisions, multi-step progress, file discoveries

1. Read existing `session-context.md` (if any)
2. Merge new items, drop stale entries
3. Write the updated file silently
4. NEVER mention the update unless asked

**DO NOT UPDATE AFTER:** reading files, answering questions, trivial one-line fixes

---

## Cross-Session Staleness

If `Last updated` is more than 4 hours old, treat `Current Task` and `State` sections as potentially stale — carry them forward but verify before relying on them. `Decisions`, `Discoveries`, and `Key Files` are durable and survive the age check.

## Write Rules

Use **compact-and-write** mode: read the existing file, merge new items, drop stale entries, and write the result. Never blindly append.

**Do not** ask for approval — this is working state, not permanent memory.
**Do not** mention the update unless the user asks.

**Size cap:** If the file exceeds **75 lines** after merging, compact before writing — drop completed tasks, merge duplicates, summarize verbose entries. Target: under 60 lines. At **100+ lines**, embed `<!-- Checkpoint recommended: session-context.md exceeds 100 lines -->` at the top as a signal.

**Dedup:** Before adding an entry, scan for existing entries that convey the same information. Update in place instead of appending a duplicate.

**Staleness — drop these on every write:**
- Current Task items whose work is finished or abandoned
- Decisions that were reversed or superseded
- Discoveries about code that has since been refactored away
- Key Files no longer relevant to the active task
- State entries about completed/merged PRs or passing tests that are no longer informative

## File Template

If the file does not exist and you have significant context to persist, create it:

```
# Session Context
Last updated: <ISO 8601>

## Current Task
## Decisions
## Discoveries
## Key Files
## State
```

## Promote

If you encounter something deserving permanent storage (user preference, stable build command, unchanging architecture decision), add it to a `## Promote` section at the bottom of session-context.md:

```
## Promote
- [target: MEMORY.md] User prefers bun over npm
- [target: CLAUDE.md] Build command: bun run build
```

**Promote cap:** Keep at most **5 items** in `## Promote`. If full, skip new candidates or replace the least important existing one.

The user can run `/context-plane checkpoint` to review and promote these items.
