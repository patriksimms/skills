---
name: debug
description:
  Investigate stuck runs and execution failures by tracing Symphony and Codex
  logs with GitLab issue, merge request, and session identifiers; use when runs
  stall, retry repeatedly, or fail unexpectedly.
---

# Debug

## Goals

- Find why a run is stuck, retrying, or failing.
- Correlate GitLab issue/MR identity to a Codex session quickly.
- Read the right logs in the right order to isolate root cause.

## Log Sources

- Symphony implementation: `~/projects/symphony`
- Primary runtime logs:
  - Symphony is a Go daemon that logs to stderr by default.
  - Inspect the terminal, service manager, or redirected file used to run:
    `cd ~/projects/symphony && go run ./cmd/symphony --workflow ./WORKFLOW.md`
- Redirected runtime logs:
  - If the daemon is run with redirection, inspect that file and any rotated
    variants.
  - Common local fallback: `~/projects/symphony/log/symphony.log*` if you have
    configured redirection there.

## Correlation Keys

- `issue_identifier`: human ticket key when mirrored from a tracker (example:
  `MT-625`)
- `issue_id`: GitLab issue IID or mirrored tracker UUID, depending on the
  integration
- `merge_request_iid`: GitLab merge request IID
- `project_id` / `project_path`: GitLab project identity
- `session_id`: Codex thread-turn pair (`<thread_id>-<turn_id>`)

`~/projects/symphony/resources/spec.md` defines the expected work-item and
session log context fields. Use whichever identifiers are present as join keys
during debugging.

## Quick Triage (Stuck Run)

1. Confirm scheduler/worker symptoms for the ticket.
2. Find recent lines for the ticket or MR (`merge_request_iid` first for MR
   runs, `issue_identifier` or `issue_id` for issue runs).
3. Extract `session_id` from matching lines.
4. Trace that `session_id` across start, stream, completion/failure, and stall
   handling logs.
5. Decide class of failure: timeout/stall, app-server startup failure, turn
   failure, or orchestrator retry loop.

## Commands

```bash
# 0) Work from the Symphony implementation
cd ~/projects/symphony

# 1) Narrow by GitLab MR IID when debugging an MR run
rg -n "merge_request_iid=123" <symphony-log-file>

# 2) Narrow by ticket key when debugging an issue run
rg -n "issue_identifier=MT-625" <symphony-log-file>

# 3) If needed, narrow by GitLab issue IID, project, or mirrored issue UUID
rg -n "issue_id=<issue-id>|project_path=<group/project>" <symphony-log-file>

# 4) Pull session IDs seen for that ticket/MR
rg -o "session_id=[^ ;]+" <symphony-log-file> | sort -u

# 5) Trace one session end-to-end
rg -n "session_id=<thread>-<turn>" <symphony-log-file>

# 6) Focus on stuck/retry signals
rg -n "Issue stalled|scheduling retry|turn_timeout|turn_failed|Codex session failed|Codex session ended with error" <symphony-log-file>
```

## Investigation Flow

1. Locate the ticket slice:
    - For MR runs, search by `merge_request_iid=<IID>` plus `project_path` or
      `project_id` if present.
    - For issue runs, search by `issue_identifier=<KEY>` or `issue_id=<ID>`.
    - If noise is high, add `project_path=<group/project>` or `project_id=<ID>`.
2. Establish timeline:
    - Identify first `Codex session started ... session_id=...`.
    - Follow with `Codex session completed`, `ended with error`, or worker exit
      lines.
3. Classify the problem:
    - Stall loop: `Issue stalled ... restarting with backoff`.
    - App-server startup: `Codex session failed ...`.
    - Turn execution failure: `turn_failed`, `turn_cancelled`, `turn_timeout`, or
      `ended with error`.
    - Worker crash: `Agent task exited ... reason=...`.
4. Validate scope:
    - Check whether failures are isolated to one issue/session or repeating across
      multiple tickets.
5. Capture evidence:
    - Save key log lines with timestamps, GitLab issue/MR identifiers,
      `project_path`/`project_id`, and `session_id`.
    - Record probable root cause and the exact failing stage.

## Reading Codex Session Logs

In Symphony, Codex session diagnostics are emitted by the Go daemon logger and
keyed by `session_id`. Read them as a lifecycle:

1. `Codex session started ... session_id=...`
2. Session stream/lifecycle events for the same `session_id`
3. Terminal event:
    - `Codex session completed ...`, or
    - `Codex session ended with error ...`, or
    - `Issue stalled ... restarting with backoff`

For one specific session investigation, keep the trace narrow:

1. Capture one `session_id` for the ticket.
2. Build a timestamped slice for only that session:
    - `rg -n "session_id=<thread>-<turn>" <symphony-log-file>`
3. Mark the exact failing stage:
    - Startup failure before stream events (`Codex session failed ...`).
    - Turn/runtime failure after stream events (`turn_*` / `ended with error`).
    - Stall recovery (`Issue stalled ... restarting with backoff`).
4. Pair findings with GitLab issue/MR and project identifiers from nearby lines
   to confirm you are not mixing concurrent retries.

Always pair session findings with GitLab issue/MR and project identifiers to
avoid mixing concurrent runs.

## Notes

- Prefer `rg` over `grep` for speed on large logs.
- Check the service manager logs or rotated redirected logs before concluding
  data is missing.
- If required context fields are missing in new log statements, align with
  `~/projects/symphony/resources/spec.md` conventions.
