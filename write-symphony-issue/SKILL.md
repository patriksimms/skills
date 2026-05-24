---
name: write-symphony-issue
description: Drafts Symphony-ready GitLab issues with acceptance criteria and validation steps. Use when creating, phrasing, or filing Symphony/Codex Work Items through glab after explicit human confirmation.
---

# Write Symphony Issue

## Workflow

1. Gather context from the user's request and, when working in a repository, inspect local docs that define domain language:
   - `AGENTS.md`
   - `CONTEXT.md`
   - `docs/adr/`
   - relevant README or workflow files
2. Draft the issue using `references/symphony-issue-template.md`.
3. Make the issue agent-executable:
   - Use an imperative, outcome-based title.
   - State the current problem or opportunity.
   - Define the desired observable outcome.
   - Separate in-scope and out-of-scope work.
   - Include checkbox acceptance criteria.
   - Include exact validation/test commands or manual checks.
   - Link relevant docs, logs, MRs, screenshots, or prior issues.
4. Prefer the term **Work Item** for Symphony behavior. Use **issue** only when referring to the GitLab tracker object.
5. Include the `symphony` label by default unless the user explicitly says not to.
6. Treat GitLab workflow Status as separate from labels. If the user wants the item agent-runnable, say it should be placed in `Todo`; if not ready, use `Backlog`.
7. Present the full draft to the user and ask for explicit confirmation before creating anything in GitLab.

## Drafting Guidance

Title patterns to prefer:

- `Add <observable capability>`
- `Fix <specific failure mode>`
- `Validate <specific contract>`
- `Document <specific behavior>`
- `Migrate <bounded surface> from <old> to <new>`

Titles to avoid:

- `Fix workflow`
- `Improve Symphony`
- `Clean up code`
- `Agent bug`

Status guidance:

- `Backlog`: Not ready for agent execution or not currently scheduled.
- `Todo`: Ready for Symphony to claim and move into active work.
- `In Progress`: Active implementation underway.
- `Human Review`: MR attached and validation completed, awaiting human approval.
- `Merging`: Human approved; landing flow should run.
- `Done`: Terminal workflow status after merged work is confirmed and native issue closure is appropriate.

## Required Confirmation Gate

Never create or modify a GitLab issue until the human explicitly approves the exact draft.

Acceptable approvals include:

- "approved"
- "yes, create it"
- "ship it"
- "create the issue"
- another clear instruction to create the shown draft

If the user asks for edits, update the draft and ask for confirmation again.

## Creating The Issue

After approval, create a temporary Markdown body file outside the repository or in a scratch location, then run:

```sh
bash /Users/patriksimms/projects/skills/write-symphony-issue/scripts/create_gitlab_issue.sh \
  --title "<issue title>" \
  --body-file /path/to/body.md \
  --repo "<group/project>" \
  --label symphony
```

Omit `--repo` only when the current directory's Git remote is the intended GitLab project. Add extra `--label` flags for metadata labels such as `bug`, `frontend`, or `priority`.

If a workflow Status must be set and `glab issue create` cannot set it, report the created issue URL and the desired Status (`Todo` or `Backlog`) instead of pretending it was set. Only use `glab api` for status updates when the exact project field API is known from local context.

## Quality Bar

A Symphony-ready issue should let an unattended coding agent:

- reproduce or inspect the current state,
- plan implementation without asking basic scope questions,
- know what success looks like,
- run validation before handoff,
- avoid expanding into related but unscheduled work.

Do not over-prescribe implementation unless the implementation approach is itself a requirement.
