Manage MEMORY.md line count by moving detailed sections to topic files, keeping MEMORY.md under the 200-line system prompt limit.

**This command works autonomously.** You analyze MEMORY.md, identify sections to offload, present a proposal, and wait for approval before writing.

## Step 0: Load state

1. Read `.claude/context-plane-state.json`. If it does not exist, contains invalid JSON, or has an unknown `version`, start with `{ "version": 2, "files": {} }`.
2. Resolve the auto memory directory: `~/.claude/projects/<project-key>/memory/`.
3. Read `MEMORY.md` and count its lines.
4. Read all existing topic files in the memory directory (any `.md` file that is not `MEMORY.md` and not `session-context.md`). Exclude anything inside `.snapshots/` directories. (`session-context.md` is managed by the session-resume rule and checkpoint command, not by overflow.)

## Step 1: Assess line count

Report the current status:

```
## MEMORY.md Status

- Current lines: N
- System prompt limit: 200 lines (first 200 loaded)
- Target: ≤150 lines (50-line buffer)
- Status: [OK | Warning | Critical]
```

- **OK** (under 150 lines): Print "MEMORY.md is within limits. No overflow needed." and stop — unless `--force` is in `$ARGUMENTS`.
- **Warning** (150–199 lines): Print "MEMORY.md is approaching the limit. Overflow recommended."
- **Critical** (200+ lines): Print "MEMORY.md exceeds the system prompt limit. Lines after 200 are silently truncated. Overflow is required."

## Step 2: Analyze sections

Parse MEMORY.md into sections by markdown headings. For each section, score it on three dimensions:

1. **Specificity** (high = detailed implementation notes; low = high-level facts)
   - High-specificity sections are better candidates for topic files
   - Low-specificity sections (links, one-liners) should stay in MEMORY.md

2. **Size** — line count of the section
   - Larger sections benefit more from being moved

3. **Topic coherence** — does this section match an existing topic file?
   - If a topic file already exists for this domain, the section should live there

Rank sections by overflow priority: `(specificity × size) + topic_coherence_bonus`

## Step 3: Plan overflow moves

For each section recommended to move:

1. Determine the target topic file:
   - If an existing topic file matches the section's domain, use it.
   - Otherwise, propose a new topic file name (lowercase, hyphenated, descriptive).
2. Calculate what MEMORY.md would look like after the move:
   - The moved section is replaced with a one-line HTML comment reference:
     `<!-- See <filename>.md for <topic> -->`
   - This reference counts as 1 line instead of N.

Continue selecting sections until the projected MEMORY.md line count is ≤150 lines, or no more sections qualify for overflow.

**Topic file naming convention:** lowercase, hyphenated, descriptive. Examples: `debugging.md`, `api-patterns.md`, `ui-conventions.md`, `deployment-notes.md`, `testing-strategies.md`.

## Step 4: Present proposal

```
## Overflow Proposal

### Moves

| Section | Lines | Target File | Exists? |
|---------|-------|-------------|---------|
| Debugging Patterns | 28 | debugging.md | Yes |
| API Integration Notes | 15 | api-patterns.md | New |
| ...

### MEMORY.md After Overflow
- Before: N lines
- After: ~M lines
- References added: K one-line comments

### Topic Files
- debugging.md: N lines → M lines (appended)
- api-patterns.md: [new file] (N lines)
```

If MEMORY.md will still be over 150 after all proposed moves, warn:
```
⚠ Cannot bring MEMORY.md under 150 lines with section-level moves alone.
Consider running /context-plane prune to remove stale entries first.
```

Then ask: **"Apply these overflow moves?"**

## Step 5: Apply changes

On approval:

1. For each section being moved:
   a. If the target topic file exists, append the section content under a clear heading.
   b. If the target topic file is new, create it with the section content.
   c. In MEMORY.md, replace the section (heading + content) with a one-line reference comment:
      `<!-- See <filename>.md for <topic> -->`
2. After all moves, verify MEMORY.md line count is correct.

**Writing guidelines:**
- Preserve all `<!-- pinned -->` markers — never move pinned sections.
- Maintain heading hierarchy in topic files.
- Add a brief header comment at the top of new topic files: `# <Topic Name>` followed by the content.
- Do not modify the content being moved — transfer it exactly.

After applying, show:
```
Overflow applied:
- MEMORY.md: N lines → M lines
- [topic-file]: N lines → M lines (or [new file])
- ...
```

## Step 6: Update state

1. Read `.claude/context-plane-state.json` (or start with `{ "version": 2, "files": {} }` if missing).
2. Set `version` to `2`.
3. Set `last_invoked` to the current ISO 8601 UTC timestamp.
4. For each file that was modified or created during this run:
   - Compute the SHA-256 hash of the file content.
   - If the path is not in `files`, add it with `created_at` and `updated_at` both set to the current timestamp, `updated_by` set to `"overflow"`, and `content_hash` set to `"sha256:<hash>"`.
   - If the path already exists, update `updated_at`, `updated_by`, and `content_hash`.
5. Do NOT modify `agent_manager_tracking` — that key belongs to the agent-manager.
6. Write the updated JSON to `.claude/context-plane-state.json`.

## Audit log

After applying changes, append one entry per moved section to `~/.claude/projects/<project-key>/context-plane-audit.log` (JSONL format):
```jsonl
{"timestamp":"<ISO 8601 UTC>","command":"overflow","action":"move","file":"MEMORY.md","section":"<heading>","destination":"<topic-file>","reason":"Overflow: <N> lines moved to topic file","lines_removed":<N>,"lines_added_ref":1}
```

If the log exceeds 500 lines, trim the oldest entries to bring it back to 500.

## Rules

- **Never move pinned sections** (`<!-- pinned -->`). If a pinned section is large, warn but leave it in place.
- **Never ask questions during analysis.** The only user interaction is approving or rejecting the proposal.
- Always replace moved sections with a reference comment, never delete them silently.
- Topic files live in the same directory as MEMORY.md (`~/.claude/projects/<project-key>/memory/`).
- If MEMORY.md doesn't exist, print "No MEMORY.md found. Nothing to overflow." and stop.
- When invoked directly (not via the dispatcher), handle state updates independently.

$ARGUMENTS
