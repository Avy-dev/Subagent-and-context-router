List and restore snapshots of memory files created before review, prune, or move operations.

## Step 0: Locate snapshots

1. Resolve the snapshot directory: `~/.claude/projects/<project-key>/memory/.snapshots/`.
2. If the directory does not exist or is empty, print:
   ```
   No snapshots found. Snapshots are created automatically before review, prune, and move operations.
   ```
   Stop here.

## Step 1: List available snapshots

Scan the `.snapshots/` directory for snapshot folders. Each folder is named `<ISO-timestamp>_<command>` (e.g., `2026-02-18T12-00-00Z_review`).

Snapshot files use path-safe encoding: `/` in the original path is replaced with `__`. For example, `src__api__CLAUDE.md` represents `./src/api/CLAUDE.md`. Decode these names when displaying to the user.

Present:
```
## Available Snapshots

| # | Timestamp | Command | Files |
|---|-----------|---------|-------|
| 1 | 2026-02-18 12:00:00 UTC | review | ./CLAUDE.md, MEMORY.md |
| 2 | 2026-02-18 11:30:00 UTC | prune | MEMORY.md |
| ...
```

If `$ARGUMENTS` contains a snapshot number or timestamp, skip to Step 2 with that selection.

Otherwise ask: **"Which snapshot do you want to restore? (number or 'all' to see full details)"**

## Step 2: Show snapshot details

For the selected snapshot, show a diff between the snapshot version and the current version of each file:

```
## Snapshot: 2026-02-18T12-00-00Z_review

### CLAUDE.md
```diff
- Current content that differs
+ Snapshot content that would be restored
```

### MEMORY.md
```diff
- Current content that differs
+ Snapshot content that would be restored
```

Lines changed: +N / -M per file
```

If the current file no longer exists, note it:
```
### CLAUDE.md
Current file does not exist. Restoring would recreate it (N lines).
```

If the snapshot file and current file are identical:
```
### CLAUDE.md
No differences — file matches snapshot.
```

Then ask: **"Restore these files from this snapshot?"**

Offer options:
- **all** — restore all files from this snapshot
- **<filename>** — restore only a specific file
- **cancel** — abort

## Step 3: Apply restoration

On approval:

1. For each file being restored:
   a. Read the snapshot version.
   b. Overwrite the current file with the snapshot content.
   c. If the current file doesn't exist, create it (and any parent directories).
2. After restoring, show:
   ```
   Restored from snapshot 2026-02-18T12-00-00Z_review:
   - CLAUDE.md: N lines (was M lines)
   - MEMORY.md: N lines (was M lines)
   ```

## Step 4: Update state

1. Read `.claude/context-plane-state.json` (or start with `{ "version": 2, "files": {} }` if missing).
2. Set `version` to `2`.
3. Set `last_invoked` to the current ISO 8601 UTC timestamp.
4. For each restored file:
   - Compute the SHA-256 hash of the restored content.
   - Update `updated_at` to now, `updated_by` to `"restore"`, and `content_hash` to the new hash.
   - If the path is not in `files`, add it with `created_at` set to now.
5. Do NOT modify `agent_manager_tracking` — that key belongs to the agent-manager.
6. Write the updated JSON to `.claude/context-plane-state.json`.

## Audit log

After restoring, append one entry per restored file to `~/.claude/projects/<project-key>/context-plane-audit.log` (JSONL format):
```jsonl
{"timestamp":"<ISO 8601 UTC>","command":"restore","action":"restore","file":"<path>","snapshot":"<snapshot-folder-name>","reason":"Restored from snapshot"}
```

If the log exceeds 500 lines, trim the oldest entries to bring it back to 500.

## Rules

- **Never delete snapshots** during a restore operation.
- Always show a diff before restoring — never restore blindly.
- The only user interaction is selecting a snapshot and confirming restoration.
- If a snapshot contains files that conflict with pinned sections in the current version, warn the user that the restore will overwrite pinned content.
- When invoked directly (not via the dispatcher), handle state updates independently.

$ARGUMENTS
