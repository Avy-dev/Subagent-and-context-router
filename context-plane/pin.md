Mark the specified entry or section in CLAUDE.md or auto memory files as pinned so it is preserved during pruning.

## How to pin

- If the target is a single line (a bullet point, a command, a note), append `<!-- pinned -->` to the end of that line.
- If the target is an entire section (a heading and everything under it), wrap it with `<!-- pinned -->` above the heading and `<!-- /pinned -->` after the last line of the section.

## Examples

Single line:
```
- Always use named exports <!-- pinned -->
```

Full section:
```
<!-- pinned -->
## Build Commands
- `npm run build` — production build
- `npm run dev` — start dev server on port 3000
<!-- /pinned -->
```

## Rules

- Do not modify the content of the entry — only add the pin markers.
- If the entry is already pinned, let me know and make no changes.
- After pinning, confirm what was pinned and show the updated lines.

## Update state

After pinning is complete and confirmed:

1. Read `.claude/context-plane-state.json`. If it does not exist or contains invalid JSON, start with `{ "version": 2, "files": {} }`.
2. Set `version` to `2`.
3. Set `last_invoked` to the current ISO 8601 UTC timestamp.
4. For the file that was modified:
   - Compute the SHA-256 hash of the file's current content.
   - If the path is not in `files`, add it with `created_at` and `updated_at` both set to the current timestamp, `updated_by` set to `"pin"`, and `content_hash` set to `"sha256:<hex>"`.
   - If the path already exists, update `updated_at` to the current timestamp, `updated_by` to `"pin"`, and `content_hash` to the current hash.
5. Do NOT modify `agent_manager_tracking` — that key belongs to the agent-manager.
6. Write the updated JSON to `.claude/context-plane-state.json` (create `.claude/` directory if needed).

## Audit log

After pinning, append one entry to `~/.claude/projects/<project-key>/context-plane-audit.log` (JSONL format):
```jsonl
{"timestamp":"<ISO 8601 UTC>","command":"pin","action":"pin","file":"<path>","section":"<heading or line description>","reason":"User-requested pin"}
```

If the log exceeds 500 lines, trim the oldest entries to bring it back to 500.

$ARGUMENTS
