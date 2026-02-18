Manual agent routing command. Parse the first word of `$ARGUMENTS` as a subcommand.

## Subcommand Table

| Subcommand | Action |
|---|---|
| `help` (or empty) | Show available agents and usage |
| `status` | Show routing state and recent modifications |
| `version` | Show version |
| `<agent-name> <task>` | Force-dispatch to the named agent |

## Steps

1. Parse the first word of `$ARGUMENTS` as the subcommand. Everything after becomes the task description.

2. Route the subcommand:

   **If `help` or no arguments provided:** Print the following and stop:
   ```
   AgentManager — automatic and manual sub-agent dispatch. (Run /agent-manager version for current version.)

   Usage: /agent-manager <command> [arguments]

   Commands:
     help                          Show this message
     status                        Show routing state and tracked modifications
     version                       Show version

   Force-dispatch (case-insensitive):
     ui-specialist <task>          Route to UI specialist agent
     bug-finder-refiner <task>     Route to bug finder/refiner agent
     local-dev-runner <task>       Route to local dev runner agent
     github-sync <task>            Route to GitHub sync agent
     feature-planner <task>        Route to feature planner agent
     explore <task>                Route to codebase explorer agent
     plan <task>                   Route to architecture planner agent

   Examples:
     /agent-manager status
     /agent-manager ui-specialist fix the header alignment on mobile
     /agent-manager local-dev-runner run pytest with verbose output
     /agent-manager bug-finder-refiner audit the auth module
   ```

   **If `version`:** Read the `VERSION` file from the same directory as this command file. Print:
   ```
   AgentManager v<version>
   ```

   **If `status`:** Read `~/.claude/projects/<current-project-key>/context-plane-state.json` (the same path Claude Code uses for project-scoped `.claude/` files). Display using this format:
   ```
   AgentManager Status
   -------------------
   Last context-plane review: <last_run or "never">
   Last context-plane invocation: <last_invoked or "never">
   Tracked modifications: <count>

   Recent (last 5):
     [<timestamp>] <agent> — <file1>, <file2>, ...
     [<timestamp>] <agent> — <file1>
     ...
   ```
   If no `agent_manager_tracking` data exists, print: "No agent-manager modifications tracked yet."

   **If a recognized agent name** — match case-insensitively against: `ui-specialist`, `bug-finder-refiner`, `local-dev-runner`, `github-sync`, `feature-planner`, `explore` (subagent_type: `Explore`), `plan` (subagent_type: `Plan`):
   - The remaining arguments after the agent name become the task description.
   - If no task description provided, print: `Error: No task specified. Usage: /agent-manager <agent-name> <task>`
   - Otherwise, announce: `Force-routing to <agent-name> — <task summary>`
   - Dispatch using the `Task` tool with `subagent_type` set to the canonical agent name (use `Explore` and `Plan` with capital letters for those two) and `model: "opus"`.
   - After completion, follow the post-change tracking protocol:
     1. Discover modified files using `git diff --name-only` and `git ls-files --others --exclude-standard`. If both are empty, fall back to `git diff --name-only HEAD~1` to catch committed changes. If not in a git repo, rely on the agent's output.
     2. If `files_modified` is empty, skip tracking.
     3. Read `~/.claude/projects/<current-project-key>/context-plane-state.json`.
     4. If `agent_manager_tracking` does not exist, create it: `{ "modifications": [] }`.
     5. Append the tracking entry to `agent_manager_tracking.modifications[]`.
     6. Write the updated state back.
   - Relay the agent's results to the user.

   **If unrecognized:** Print:
   ```
   Unknown agent or command: "<word>"
   Run /agent-manager help for available commands.
   ```

## Rules

- Always use `model: "opus"` when dispatching agents.
- Match agent names case-insensitively (e.g., "explore" matches "Explore", "plan" matches "Plan").
- Pass the full task description to the agent — do not truncate or interpret it.
- After any agent dispatch, update the tracking state only if files were actually modified.
- Do not modify any files during dispatch — only the dispatched agent may modify files (except the state file).

$ARGUMENTS
