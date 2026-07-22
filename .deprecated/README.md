# Deprecated Skills and Commands

> I used to use these skills on a daily basis, but due to developments over the last months I stick more to my more up to date skills in the [project root](https://github.com/patriksimms/skills).

## Planning & Design

* write-a-prd-todoist — Create a PRD through an interactive interview, codebase exploration, and module design. Filed as a todoist PRD issue.

```sh
npx skills@latest add patriksimms/skills/.deprecated/write-a-prd-todoist
```

* write-a-prd-linear — Create a PRD through an interactive interview, codebase exploration, and module design. Filed as a linear PRD issue.

```sh
npx skills@latest add patriksimms/skills/.deprecated/write-a-prd-linear
```

* write-a-prd-gitlab — Create a PRD through an interactive interview, codebase exploration, and module design. Filed as a GitLab work item in the current project.

```sh
npx skills@latest add patriksimms/skills/.deprecated/write-a-prd-gitlab
```

* write-symphony-issue — Draft Symphony-ready GitLab issues with acceptance criteria and validation steps, then create them with `glab` after human confirmation.

```sh
npx skills@latest add patriksimms/skills/.deprecated/write-symphony-issue
```

* prd-to-issues-todoist — Break a PRD into independently-grabbable Todoist tasks using vertical slices.

```sh
npx skills@latest add patriksimms/skills/.deprecated/prd-to-issues-todoist
```

* prd-to-issues-linear — Break a PRD into independently linear issues using vertical slices.

```sh
npx skills@latest add patriksimms/skills/.deprecated/prd-to-issues-linear
```

* prd-to-issues-gitlab — Break a PRD into independently-grabbable GitLab work items using vertical slices.

```sh
npx skills@latest add patriksimms/skills/.deprecated/prd-to-issues-gitlab
```

* grill-me - Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.

```sh
npx skills@latest add patriksimms/skills/.deprecated/grill-me
```

* grill-with-docs - Stress-test a plan against the project's domain language and documented decisions, updating `CONTEXT.md` and ADRs as decisions crystallise.

```sh
npx skills@latest add patriksimms/skills/.deprecated/grill-with-docs
```

* tdd-ralph - Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time. Can work AFK in a ralph loop

```sh
npx skills@latest add patriksimms/skills/.deprecated/tdd-ralph
```

* triage-issue-linear - Investigate a bug by exploring the codebase, identify the root cause, and file a Linear issue with a TDD-based fix plan.

```sh
npx skills@latest add patriksimms/skills/.deprecated/triage-issue-linear
```

* triage-issue-todoist - Investigate a bug by exploring the codebase, identify the root cause, and file a todoist task with a TDD-based fix plan.

```sh
npx skills@latest add patriksimms/skills/.deprecated/triage-issue-todoist
```

* triage-issue-gitlab - Investigate a bug by exploring the codebase, identify the root cause, and file a GitLab work item with a TDD-based fix plan.

```sh
npx skills@latest add patriksimms/skills/.deprecated/triage-issue-gitlab
```

## Development Workflow

* debug - Investigate stuck runs and execution failures by tracing Symphony and Codex logs with issue/session identifiers.

```sh
npx skills@latest add patriksimms/skills/.deprecated/debug
```

* land - Land an MR by monitoring conflicts, resolving them, waiting for checks, and squash-merging when green.

```sh
npx skills@latest add patriksimms/skills/.deprecated/land
```

* pull - Pull latest origin/main into the current local branch and resolve merge conflicts.

```sh
npx skills@latest add patriksimms/skills/.deprecated/pull
```

* push - Push current branch changes to origin and create or update the corresponding merge request.

```sh
npx skills@latest add patriksimms/skills/.deprecated/push
```

## Ralph

The Ralph shell commands can work with Linear issues tagged with `agent-task` in a specific Git project directory.

### Usage

Install:

```sh
git clone git@github.com:patriksimms/skills.git
cd skills
install -m 755 .deprecated/ralph-linear.sh ~/.local/bin/ralph-linear
install -m 755 .deprecated/ralph-linear-codex.sh ~/.local/bin/ralph-linear-codex
install -m 755 .deprecated/ralph-gitlab-codex.sh ~/.local/bin/ralph-gitlab-codex
install -m 755 .deprecated/ralph-todoist-codex.sh ~/.local/bin/ralph-todoist-codex
```

Set in your projects folder environment, e.g. with https://direnv.net/:

```sh
export LINEAR_TEAM_KEY="${LINEAR_TEAM_KEY:-EE}"
export LINEAR_PROJECT_LABEL="${LINEAR_PROJECT_LABEL:-<project-name>}"

# optional
export LINEAR_AGENT_LABEL="${LINEAR_AGENT_LABEL:-agent-task}"
export LINEAR_DONE_STATE="${LINEAR_DONE_STATE:-Done}"
export LINEAR_ISSUE_LIMIT="${LINEAR_ISSUE_LIMIT:-250}"
export LINEAR_RETRY_ATTEMPTS="${LINEAR_RETRY_ATTEMPTS:-3}"
export LINEAR_RETRY_DELAY_SECONDS="${LINEAR_RETRY_DELAY_SECONDS:-1}"

ralph-linear 2 # max iterations
```

### Codex CLI version

`ralph-linear-codex` uses `codex exec` instead of Claude. The worker run streams Codex output directly to the terminal and writes the final assistant message to a temp file so the loop can detect `<promise>COMPLETE</promise>`.

Install the skills used by the worker in the Codex environment or profile that will run the loop:

```sh
npx skills@latest add patriksimms/skills/.deprecated/tdd-ralph
npx skills@latest add patriksimms/skills/commit
```

Optional Codex settings:

```sh
export CODEX_BIN="${CODEX_BIN:-codex}"
export CODEX_MODEL="${CODEX_MODEL:-}"
export CODEX_REASONING_EFFORT="${CODEX_REASONING_EFFORT:-}"
export CODEX_PROFILE="${CODEX_PROFILE:-}"
export CODEX_SANDBOX="${CODEX_SANDBOX:-danger-full-access}"
export CODEX_APPROVAL_POLICY="${CODEX_APPROVAL_POLICY:-never}"

ralph-linear-codex 2 # max iterations
```

For example, to run GPT-5.5 with low reasoning:

```sh
export CODEX_MODEL="gpt-5.5"
export CODEX_REASONING_EFFORT="low"
```

This maps to Codex CLI's `model_reasoning_effort` config key.

### Todoist Codex CLI version

`ralph-todoist-codex` uses `td task list` to fetch open Todoist tasks and `td task complete` when Codex emits the completion marker.

Install the skills used by the worker in the Codex environment or profile that will run the loop:

```sh
npx skills@latest add patriksimms/skills/.deprecated/tdd-ralph
npx skills@latest add patriksimms/skills/commit
```

Required/default Todoist settings:

```sh
export TODOIST_AGENT_LABEL="${TODOIST_AGENT_LABEL:-agent-task}"

# optional filters
export TODOIST_PROJECT="${TODOIST_PROJECT:-}"
export TODOIST_PROJECT_LABEL="${TODOIST_PROJECT_LABEL:-}"
export TODOIST_TASK_LIMIT="${TODOIST_TASK_LIMIT:-250}"
export TODOIST_RETRY_ATTEMPTS="${TODOIST_RETRY_ATTEMPTS:-3}"
export TODOIST_RETRY_DELAY_SECONDS="${TODOIST_RETRY_DELAY_SECONDS:-1}"

ralph-todoist-codex 2 # max iterations
```

Todoist task dependencies are read from a `## Blocked by` section containing `#<todoist-task-id>` references. Tasks with unresolved blockers are skipped.

### GitLab Codex CLI version

`ralph-gitlab-codex` uses `glab issue list` to fetch open GitLab issues and `glab issue close` when Codex emits the completion marker.

Install the skills used by the worker in the Codex environment or profile that will run the loop:

```sh
npx skills@latest add patriksimms/skills/.deprecated/tdd-ralph
npx skills@latest add patriksimms/skills/commit
```

Required/default GitLab settings:

```sh
export GITLAB_AGENT_LABEL="${GITLAB_AGENT_LABEL:-agent-task}"

# optional filters
export GITLAB_REPO="${GITLAB_REPO:-}" # group/project; defaults to current repo
export GITLAB_PROJECT_LABEL="${GITLAB_PROJECT_LABEL:-}"
export GITLAB_ISSUE_LIMIT="${GITLAB_ISSUE_LIMIT:-100}"
export GITLAB_RETRY_ATTEMPTS="${GITLAB_RETRY_ATTEMPTS:-3}"
export GITLAB_RETRY_DELAY_SECONDS="${GITLAB_RETRY_DELAY_SECONDS:-1}"

ralph-gitlab-codex 2 # max iterations
```

GitLab issue dependencies are read from a `## Blocked by` section containing `#<issue-iid>` references. Issues with unresolved blockers are skipped.
