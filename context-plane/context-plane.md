Dispatch to a ContextPlane subcommand based on the first word of the arguments.

## Subcommand table

| Subcommand | Alias | Action |
|---|---|---|
| `review-memory` | `review` | Read and follow `review-memory.md` |
| `prune-memory` | `prune` | Read and follow `prune-memory.md` |
| `move-memory` | `move` | Read and follow `move-memory.md` |
| `checkpoint` | `cp` | Read and follow `checkpoint.md` |
| `overflow` | — | Read and follow `overflow.md` |
| `restore` | — | Read and follow `restore.md` |
| `pin` | — | Read and follow `pin.md` |
| `log` | — | Show recent audit log entries |
| `version` | `-v` | Print version from VERSION file |
| `help` | (none / empty) | Print usage summary |

## State tracking

Before dispatching, read `.claude/context-plane-state.json`. If it does not exist, contains invalid JSON, or has an unknown `version`, note that this is a first run — the subcommand will handle it.

Check whether `--all` or the bare word `all` appears as a token anywhere in `$ARGUMENTS` (distinct from the subcommand or scope keywords). If found, strip it from the arguments and pass `--all` as the first token of the remaining arguments sent to the subcommand.

## Steps

1. Parse the first word of `$ARGUMENTS` as the subcommand. Everything after the first word becomes the remaining arguments to pass through to the subcommand. Also check for and strip `--all` as described in "State tracking" above.

2. Resolve aliases: `review` → `review-memory`, `prune` → `prune-memory`, `move` → `move-memory`, `cp` → `checkpoint`, `-v` → `version`.

3. Route the subcommand:

   **If `version` or `-v`:** Read the `VERSION` file from the ContextPlane install directory (look for it alongside the command files — try `.claude/commands/../VERSION`, or the project root `VERSION` file). Print:
   ```
   ContextPlane v<version>
   ```

   **If `log`:** Read the audit log file at `~/.claude/projects/<project-key>/context-plane-audit.log`. If it does not exist, print "No audit log found. Actions are logged after review, prune, move, checkpoint, overflow, and restore operations." and stop. Otherwise:
   - If remaining arguments contain a number N, show the last N entries.
   - If remaining arguments contain `--file <path>`, filter entries where `file` matches.
   - If remaining arguments contain `--command <cmd>`, filter entries where `command` matches.
   - Default: show the last 20 entries.
   - Format each entry as a readable line: `[timestamp] command: action on file — reason`

   **If `help` or no arguments provided:** Print the following usage summary and stop:
   ```
   ContextPlane — slash commands for managing Claude Code memory files.

   Usage: /context-plane <command> [--all] [arguments]

   Commands:
     review-memory (review)  Autonomous review with proposal + approval
     prune-memory  (prune)   Automated pruning with approval
     move-memory   (move)    Move sections between memory files
     checkpoint    (cp)      Capture session context before it's lost
     overflow                Move detailed MEMORY.md sections to topic files
     restore                 List and restore pre-modification snapshots
     pin                     Pin entries to protect from pruning
     log                     Show audit log (options: N, --file, --command)
     version       (-v)      Show version
     help                    Show this message
   ```

   **If a known subcommand (`review-memory`, `prune-memory`, `move-memory`, `checkpoint`, `overflow`, `restore`, `pin`):** Look for the matching `.md` file by checking these locations in order:
   - `.claude/commands/<subcommand>.md` (project-level)
   - `~/.claude/commands/<subcommand>.md` (global)

   Read the file, then follow its instructions exactly as if it were the current prompt. Treat the remaining arguments (everything after the subcommand) as that command's `$ARGUMENTS`. If `--all` was detected in the State tracking step, ensure it is included in the arguments passed to the subcommand.

   **If unrecognized:** Print:
   ```
   Unknown subcommand: "<word>"
   Run /context-plane help for available commands.
   ```

4. After the subcommand finishes, update `.claude/context-plane-state.json`:
   - Read the existing state file first (preserve all existing keys).
   - Set `version` to `2`.
   - Set `last_invoked` to the current ISO 8601 UTC timestamp.
   - Do NOT modify `agent_manager_tracking` or any other existing keys — only update `version` and `last_invoked`.
   - Write the file (create `.claude/` directory if needed).
   This ensures `last_invoked` is updated even if the subcommand made no changes.

## Rules

- Do not modify any files during dispatch — only the resolved subcommand may modify files (except the state file).
- If the subcommand file cannot be found in either location, tell the user and suggest running install.sh.
- Pass remaining arguments through verbatim — do not interpret them.
- When following a subcommand file, behave as if that file's instructions were given directly. Do not add extra confirmation steps beyond what the subcommand itself requires.
- Always update `last_invoked` in the state file after dispatch, even if the subcommand made no changes.

$ARGUMENTS
