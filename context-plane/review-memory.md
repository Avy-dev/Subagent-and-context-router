Autonomously review and manage memory across the project. This covers the root CLAUDE.md, auto memory files (~/.claude/projects/.../memory/), subdirectory CLAUDE.md files, .claude/rules/, and subagent definitions in .claude/agents/.

**This command works autonomously.** You read everything, make your own decisions, present a single proposal, and wait for one approval before applying.

## Step 0a: Load state and determine filtering

1. Check whether `--all` or the bare word `all` appears anywhere in `$ARGUMENTS` (but not as part of the scope keyword). If found, strip it from the arguments and set the **all-files** flag.
2. Read `.claude/context-plane-state.json`. If it does not exist, contains invalid JSON, or has an unknown `version`, treat this as a first run (equivalent to `--all`). Warn the user if the file was corrupt or had an unknown version.
3. If the state file has no `version` field or `version` is 1, treat it as needing migration — all files will be treated as changed for this run, and hashes will be computed during the state update step.
4. Extract `last_invoked` from the state file.

## Step 0b: Determine scope

If `$ARGUMENTS` contains a scope keyword, use it:

- **all** — every memory file
- **root** — only the root CLAUDE.md (and CLAUDE.local.md if present)
- **memory** — only auto memory files (~/.claude/projects/.../memory/)
- **subdirs** — only subdirectory CLAUDE.md files
- **rules** — only .claude/rules/ files
- **agents** — only .claude/agents/ subagent files

If no scope keyword is provided, default to **all**.

## Step 1: Discover all memory files

Scan the project and list every memory file found, grouped by type. Never include `.claude/context-plane-state.json`, `context-plane-audit.log`, `session-context.md`, or anything inside `.snapshots/` directories. (`session-context.md` is managed by the session-resume rule and checkpoint command, not by review.)

```
## Memory Map

### Root memory
- ./CLAUDE.md (N lines)
- ./CLAUDE.local.md (N lines)        <- if present

### Auto memory
- ~/.claude/projects/.../memory/MEMORY.md (N lines)
- ~/.claude/projects/.../memory/other.md (N lines)   <- if any

### Subdirectory memory
- ./src/api/CLAUDE.md (N lines)
- ...

### Rules
- ./.claude/rules/general.md (N lines)
- ...

### Subagents
- ./.claude/agents/code-reviewer.md (N lines)
- ...

Total: X files, Y total lines
```

### Change detection (content-hash + mtime)

For each file in the memory map, detect whether it has genuinely changed since the last run:

1. **Fast path**: Compare the file's filesystem mtime (use `stat`) against `last_invoked`. If mtime is older than `last_invoked` and the file exists in the state `files` map, proceed to hash check only if the state entry has a `content_hash`.
2. **Hash check**: If the state file contains a `content_hash` for this file (format: `"sha256:<hex>"`), compute the SHA-256 hash of the current file content and compare. If hashes match, the file has **not** genuinely changed — mark it `[unchanged]` even if mtime differs.
3. **Classification**:
   - `[new]` — file is not in the state `files` map
   - `[changed]` — file is in the state `files` map and hash differs (or no hash stored, falling back to mtime comparison)
   - `[unchanged]` — file is in the state `files` map and hash matches (or mtime is older than `last_invoked` with no hash to compare)

Unless the **all-files** flag is set, only include `[changed]` and `[new]` files in the review scope.

After the memory map, show a filter summary:
```
Reviewing N changed files (M unchanged hidden — use --all to include them).
```

If zero files are changed/new and `--all` was not used, print:
```
No memory files have changed since the last run.
Use --all to review all files regardless.
```
Do NOT update `last_invoked`. Stop here.

### Agent-router cross-reference

Read `agent_manager_tracking.modifications[]` from the state file (if it exists). For each modification entry, check if any `files_modified` overlap with files in the current project that are referenced by memory files in scope. If overlap is found, annotate the memory file in the Memory Map:
```
- ./CLAUDE.md (65 lines) [changed] [touched by: github-sync, ui-specialist]
```

This annotation indicates that agents have recently modified source files described by this memory file, making it more likely to contain stale context. Prioritize these files higher in the review order.

## Step 2: Autonomous analysis

For each file in scope, read it and break it into logical sections:
- A markdown heading (any level) and all content under it until the next heading of the same or higher level
- Any top-level content before the first heading counts as its own section
- For subagent files, treat the YAML frontmatter as its own section labeled `[frontmatter]`
- For rules files with `paths:` frontmatter, treat the frontmatter as its own section labeled `[scope]`

### Staleness scoring

For each section, check the state file for staleness metadata under `files.<path>.sections.<section-heading>`:

- If `review_count >= 5` without a content change since the last review (i.e., the section content hash has not changed across 5+ reviews), annotate the section as `[stale?]` in the proposal.
- If `last_verified` is more than 30 days old, annotate as `[unverified >30d]`.
- These annotations prompt more aggressive re-evaluation but do **not** auto-prune. You still make the final decision.

If agent-manager tracking indicates source files related to this section were recently modified by agents, note this in your analysis — the memory section may no longer be accurate.

**Autonomously decide** what to do with each section using these criteria:

| Decision | When to use |
|----------|-------------|
| **keep** | Accurate, useful, not duplicated, still relevant |
| **prune** | Outdated, factually wrong, stale task references, one-off debugging notes, or content that no longer applies |
| **edit** | Mostly correct but needs updating (outdated values, missing new info, could be sharper) |
| **merge** | Two or more sections in the same file cover the same topic |
| **move** | Section belongs in a more specific file (e.g., detailed API notes -> subdirectory CLAUDE.md) |
| **pin** | Critical instructions that must never be pruned |

**Decision guidelines:**
- Cross-reference facts against the actual codebase — read key files to verify claims
- Remove entries that duplicate what's obvious from the code
- Remove generic advice ("write clean code", "follow best practices")
- Preserve build/test/lint commands, architecture decisions, and project-specific conventions
- Never prune or edit `<!-- pinned -->` sections (keep them as-is)
- Never remove or alter subagent YAML frontmatter unless it contains errors
- Never remove rules file `paths:` frontmatter unless it's wrong
- Weight staleness annotations in your decisions — `[stale?]` sections deserve extra scrutiny
- If agents recently modified files described by a section, verify the section is still accurate

**Do NOT ask the user any questions during analysis.** Make your best judgment call on every section.

## Step 3: Present proposal

Present a single summary grouped by file:

```
## Review Proposal

### ./CLAUDE.md
| # | Section | Decision | Reason |
|---|---------|----------|--------|
| 1 | Project Overview | keep | Accurate and essential |
| 2 | Build Commands | keep | Core reference |
| 3 | Old Debug Notes | prune | One-off fix, no longer relevant |
| 4 | API Conventions | edit | Missing new endpoint added last week |

#### Edits
**Section 4 — API Conventions**
```diff
- Supports 3 endpoints: /members, /visits, /admin
+ Supports 4 endpoints: /members, /visits, /admin, /events (SSE)
```

### ~/.claude/projects/.../memory/MEMORY.md
| # | Section | Decision | Reason |
|---|---------|----------|--------|
| 1 | User Preferences | keep | Active preference |
| 2 | Old Workaround | prune | Bug was fixed [stale?] |

### Overall
- Files reviewed: X
- Sections reviewed: Y
- Keeping: N sections
- Pruning: N sections (estimated -M lines)
- Editing: N sections
- Stale annotations: N sections
```

For edits, show a clear diff or before/after of what will change.
For merges, show the proposed merged section.
For moves, show source -> destination.
Sections with staleness annotations should include those annotations in the Reason column.

Then ask: **"Apply these changes?"**

## Step 3.5: Snapshot before modify

Before applying any changes, create a snapshot of all files that will be modified:

1. Resolve the snapshot directory: `~/.claude/projects/<project-key>/memory/.snapshots/`
2. Create a timestamped snapshot folder: `<ISO-timestamp>_review` (e.g., `2026-02-18T12-00-00Z_review`). Use hyphens instead of colons in the timestamp for filesystem compatibility.
3. For each file that will be modified by the approved proposal, copy its current content into the snapshot folder. Use a path-safe filename: replace `/` with `__` in the relative path (e.g., `./src/api/CLAUDE.md` → `src__api__CLAUDE.md`, `MEMORY.md` stays `MEMORY.md`). This prevents collisions when multiple files share the same basename.
4. **Retention**: After creating the new snapshot, check how many snapshot folders exist. If more than 5, delete the oldest ones to keep only 5.

## Step 4: Apply changes

- If the user says yes (or any affirmative), first create the snapshot (Step 3.5), then apply all changes across all files.
- If the user says no or asks for adjustments, revise the proposal accordingly and re-present only the changed parts.
- For moved sections:
  - Create the destination file if it doesn't exist.
  - If the destination is a new subagent, scaffold it with minimal YAML frontmatter.
  - If the destination is a new rules file, add a `paths:` scope based on the destination path.
  - Preserve any pin markers.
- After applying, show a before/after line count per file.

### MEMORY.md overflow check

After applying changes, if MEMORY.md exists, count its lines:
- If over 150 lines: append to the output:
  ```
  MEMORY.md is at N/200 lines. Consider running /context-plane overflow to move detailed sections to topic files.
  ```
- If over 200 lines:
  ```
  Warning: MEMORY.md exceeds the 200-line system prompt limit. Lines after 200 are silently truncated. Run /context-plane overflow to fix this.
  ```

### Audit log

After applying changes, append one JSONL entry per action to `~/.claude/projects/<project-key>/context-plane-audit.log`:

```jsonl
{"timestamp":"<ISO 8601 UTC>","command":"review-memory","action":"prune","file":"<path>","section":"<heading>","reason":"<reason>","lines_removed":<N>}
{"timestamp":"<ISO 8601 UTC>","command":"review-memory","action":"edit","file":"<path>","section":"<heading>","reason":"<reason>","lines_before":<N>,"lines_after":<M>}
{"timestamp":"<ISO 8601 UTC>","command":"review-memory","action":"merge","file":"<path>","section":"<merged headings>","reason":"<reason>","lines_before":<N>,"lines_after":<M>}
{"timestamp":"<ISO 8601 UTC>","command":"review-memory","action":"move","file":"<source path>","section":"<heading>","destination":"<dest path>","reason":"<reason>","lines_removed":<N>}
```

`keep` decisions are not logged (no action was taken).

If the log exceeds 500 lines, trim the oldest entries to bring it back to 500.

## Step 5: Update state

After applying approved changes:

1. Read `.claude/context-plane-state.json` (or start with `{ "version": 2, "files": {} }` if missing).
2. Set `version` to `2`.
3. Set `last_invoked` to the current ISO 8601 UTC timestamp.
4. For each file that was reviewed during this run (whether modified or not):
   - Compute the SHA-256 hash of the file's current content.
   - If the path is not in `files`, add it with `created_at` and `updated_at` both set to the current timestamp, `updated_by` set to `"review-memory"`, and `content_hash` set to `"sha256:<hex>"`.
   - If the path already exists:
     - Update `updated_at` to the current timestamp if the file was modified.
     - Set `updated_by` to `"review-memory"` if the file was modified.
     - Update `content_hash` to the current hash.
   - **Section-level staleness tracking**: For each section in the file:
     - Look up `files.<path>.sections.<section-heading>` in the state.
     - If it doesn't exist, create it with `last_verified` set to now and `review_count` set to `1`.
     - If it exists, increment `review_count` by 1 and set `last_verified` to now.
     - If the section's content changed during this review (edit, merge), reset `review_count` to `0` and set `last_verified` to now.
     - If the section was pruned, remove its entry from `sections`.
     - Set `status` to the decision made (`keep`, `edit`, `merge`, etc.).
5. Remove any entries in `files` whose paths no longer exist on disk.
6. Do NOT modify `agent_manager_tracking` — that key belongs to the agent-manager.
7. Write the updated JSON to `.claude/context-plane-state.json`.

## Rules

- **Never ask the user questions during analysis.** All decisions are autonomous.
- **The only user interaction is approving or rejecting the final proposal.**
- Process files in the order listed in the memory map (root -> auto memory -> subdirs -> rules -> agents).
- If a section is already pinned, always keep it — never prune or edit pinned sections.
- Never modify any file until the user gives final approval in Step 4.
- If a file has no clear heading structure, break it into logical chunks of ~5-10 lines each.
- For subagent files, never remove or alter the YAML frontmatter unless it contains factual errors.
- For rules files, never remove the `paths:` frontmatter unless it's wrong.
- When invoked directly (not via the dispatcher), handle `--all` parsing and state updates independently.
- Never show `.claude/context-plane-state.json` or `context-plane-audit.log` as memory files.
- Always create a snapshot before applying changes (Step 3.5).

$ARGUMENTS
