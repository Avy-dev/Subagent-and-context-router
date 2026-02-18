Review the CLAUDE.md and auto memory files (~/.claude/projects/.../memory/) in this project and prune them to keep them focused and effective. Follow these steps:

## 0. Load state and filter

1. Check whether `--all` or the bare word `all` appears anywhere in `$ARGUMENTS`. If found, strip it from the arguments and set the **all-files** flag.
2. Read `.claude/context-plane-state.json`. If it does not exist, contains invalid JSON, or has an unknown `version`, treat this as a first run (equivalent to `--all`). Warn the user if the file was corrupt or had an unknown version.
3. If the state file has no `version` field or `version` is 1, treat it as needing migration — all files will be treated as changed for this run, and hashes will be computed during the state update step.
4. Extract `last_invoked` from the state file.
5. For each memory file discovered, detect whether it has genuinely changed:
   - **Fast path**: Compare the file's filesystem mtime (use `stat`) against `last_invoked`. If mtime is older and the file exists in the state `files` map, proceed to hash check only if a `content_hash` is stored.
   - **Hash check**: If the state file contains a `content_hash` for this file (format: `"sha256:<hex>"`), compute the SHA-256 hash of the current file content and compare. If hashes match, the file has **not** genuinely changed — treat as unchanged even if mtime differs.
   - Include the file if it has genuinely changed (hash differs or no hash stored and mtime > `last_invoked`), or if the file path is not yet in the state `files` map.
   - If the **all-files** flag is set, include every file regardless.
6. If zero files qualify and `--all` was not used, print:
   ```
   No memory files have changed since the last run.
   Use --all to review all files regardless.
   ```
   Do NOT update `last_invoked`. Stop here.

### Agent-router cross-reference

Read `agent_manager_tracking.modifications[]` from the state file (if it exists). For each modification entry, check if any `files_modified` overlap with files in the current project that are referenced by memory files in scope. If overlap is found, annotate the memory file when listing it — these files are more likely to contain stale context since the codebase has diverged.

## 1. Analyze all memory files

Discover and read the project's CLAUDE.md and any auto memory files (MEMORY.md and other .md files in ~/.claude/projects/.../memory/). Exclude anything inside `.snapshots/` directories and exclude `session-context.md` (managed by the session-resume rule and checkpoint command, not by prune). Categorize every entry into one of these buckets:

- **Core**: Project identity, tech stack, architecture, coding standards, build/test/lint commands — things that are always relevant
- **Active**: Current workflows, recent decisions, in-progress conventions — things that matter right now
- **Stale**: References to completed tasks, old debugging notes, one-off fixes, outdated warnings, or context that no longer applies
- **Redundant**: Duplicate or near-duplicate entries, instructions that restate what's already obvious from the codebase
- **Vague**: Entries that are too generic to be actionable (e.g., "write clean code", "follow best practices")

### Staleness scoring

For each section, check the state file for staleness metadata under `files.<path>.sections.<section-heading>`:

- If `review_count >= 5` without a content change, annotate the section as `[stale?]` — it has been kept through 5+ reviews without changes, suggesting it may no longer be actively relevant.
- If `last_verified` is more than 30 days old, annotate as `[unverified >30d]` — it hasn't been verified in over a month.
- These annotations bias toward `Stale` categorization but do not auto-prune. You still make the final call.
- If agents recently modified source files described by a section (from agent-manager tracking), apply extra scrutiny — the section may be outdated.

## 2. Propose changes

When multiple files are in scope, group proposals by file. Present a summary in this format:

```
## ./CLAUDE.md

### Keeping (N entries)
- [brief description of each kept entry and why]

### Removing (N entries)
- [brief description of each removed entry and why]

### Merging (N entries -> M entries)
- [which entries are being consolidated and the proposed merged version]

### Rewording (N entries)
- [entries that are kept but sharpened for clarity]
```

If only one file is in scope, omit the file-level headings.

Include staleness annotations in the reasons where applicable (e.g., "Removing — one-off fix, no longer relevant [stale?]").

## 3. Wait for confirmation

Do NOT modify any file until I explicitly approve the changes. If I ask you to keep something you proposed removing, adjust accordingly.

## 3.5. Snapshot before modify

Before applying any changes, create a snapshot of all files that will be modified:

1. Resolve the snapshot directory: `~/.claude/projects/<project-key>/memory/.snapshots/`
2. Create a timestamped snapshot folder: `<ISO-timestamp>_prune` (e.g., `2026-02-18T12-00-00Z_prune`). Use hyphens instead of colons in the timestamp for filesystem compatibility.
3. For each file that will be modified by the approved proposal, copy its current content into the snapshot folder. Use a path-safe filename: replace `/` with `__` in the relative path (e.g., `./src/api/CLAUDE.md` → `src__api__CLAUDE.md`, `MEMORY.md` stays `MEMORY.md`). This prevents collisions when multiple files share the same basename.
4. **Retention**: After creating the new snapshot, check how many snapshot folders exist. If more than 5, delete the oldest ones to keep only 5.

## 4. Apply changes

Once approved, first create the snapshot (Step 3.5), then rewrite each affected file with these guidelines:

- Keep total length under 80 lines per file if possible (unless the project genuinely needs more)
- Use clear markdown headings to group related instructions
- Put the most important context (stack, commands, architecture) at the top
- Remove any conversational tone — every line should be a direct, actionable instruction or fact
- Preserve any entries marked with `<!-- pinned -->` regardless of other criteria

### MEMORY.md overflow check

After applying changes, if MEMORY.md exists, count its lines:
- If over 150 lines:
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
{"timestamp":"<ISO 8601 UTC>","command":"prune-memory","action":"remove","file":"<path>","section":"<heading or description>","reason":"<reason>","lines_removed":<N>}
{"timestamp":"<ISO 8601 UTC>","command":"prune-memory","action":"reword","file":"<path>","section":"<heading>","reason":"<reason>","lines_before":<N>,"lines_after":<M>}
{"timestamp":"<ISO 8601 UTC>","command":"prune-memory","action":"merge","file":"<path>","section":"<merged headings>","reason":"<reason>","lines_before":<N>,"lines_after":<M>}
```

`keep` decisions are not logged (no action was taken).

If the log exceeds 500 lines, trim the oldest entries to bring it back to 500.

## 5. Update state

After applying approved changes:

1. Read `.claude/context-plane-state.json` (or start with `{ "version": 2, "files": {} }` if missing).
2. Set `version` to `2`.
3. Set `last_invoked` to the current ISO 8601 UTC timestamp.
4. For each file that was reviewed during this run (whether modified or not):
   - Compute the SHA-256 hash of the file's current content.
   - If the path is not in `files`, add it with `created_at` and `updated_at` both set to the current timestamp, `updated_by` set to `"prune-memory"`, and `content_hash` set to `"sha256:<hex>"`.
   - If the path already exists:
     - Update `updated_at` to the current timestamp if the file was modified.
     - Set `updated_by` to `"prune-memory"` if the file was modified.
     - Update `content_hash` to the current hash.
   - **Section-level staleness tracking**: For each section in the file:
     - Look up `files.<path>.sections.<section-heading>` in the state.
     - If it doesn't exist, create it with `last_verified` set to now and `review_count` set to `1`.
     - If it exists, increment `review_count` by 1 and set `last_verified` to now.
     - If the section's content changed during this prune (reword, merge), reset `review_count` to `0`.
     - If the section was removed, remove its entry from `sections`.
     - Set `status` to the decision made (`keep`, `remove`, `reword`, `merge`).
5. Remove any entries in `files` whose paths no longer exist on disk.
6. Do NOT modify `agent_manager_tracking` — that key belongs to the agent-manager.
7. Write the updated JSON to `.claude/context-plane-state.json`.

$ARGUMENTS
