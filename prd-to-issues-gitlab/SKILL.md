---
name: prd-to-issues-gitlab
description: Break a PRD into independently-grabbable GitLab work items using tracer-bullet vertical slices. Use when user wants to convert a PRD to GitLab issues, create implementation tickets, or break down a PRD into work items.
---

# PRD to Issues

Break a PRD into independently-grabbable GitLab work items using vertical slices (tracer bullets).

## Process

### 1. Locate the PRD

Ask the user for the PRD GitLab work item ID, issue IID, or URL.

If the PRD is not already in your context window, fetch it with `glab`. Prefer work item commands when available:

```sh
glab auth status
glab repo view
glab work-items view <id>
```

If the installed `glab` version does not support `work-items view`, use the closest issue equivalent:

```sh
glab issue view <iid> --comments
```

Use `--repo <group/project>` if the current directory is not the intended GitLab project.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code.

### 3. Draft vertical slices

Break the PRD into **tracer bullet** work items. Each work item is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories from the PRD this addresses

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?

Iterate until the user approves the breakdown.

### 5. Create the GitLab work items

For each approved slice, create a GitLab work item in the current project using `glab` as child-issues of the PRD work item. Use the `agent-task` label. Use the issue body template below.

Before creating work items, verify `glab` is authenticated and pointed at the intended GitLab project:

```sh
glab auth status
glab repo view
```

Prefer `glab work-items create` when available:

```sh
glab work-items create --type issue --title "<slice title>" --description "$(cat /tmp/slice.md)" --label agent-task
```

Use `--repo <group/project>` if the current directory is not the intended project. If the installed `glab` version does not support `work-items create`, use `glab issue create --title "<slice title>" --description "$(cat /tmp/slice.md)" --label agent-task --yes` as the closest current-project work item equivalent, and tell the user that their `glab` version lacks the experimental work item create command.

Create work items in dependency order (blockers first) so you can reference real work item or issue numbers in the "Blocked by" field.

If GitLab supports setting a parent relationship for the project, link each created work item to the PRD parent. If no supported `glab` command is available, keep the explicit "Parent PRD" section in the body and do not block creation on parent-link automation.

<issue-template>
## Parent PRD

#<prd-work-item-or-issue-number>

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation. Reference specific sections of the parent PRD rather than duplicating content.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- Blocked by #<work-item-or-issue-number> (if any)

Or "None - can start immediately" if no blockers.

## User stories addressed

Reference by number from the parent PRD:

- User story 3
- User story 7

</issue-template>

Do NOT close or otherwise modify the parent PRD work item. Only add an `in-progress` label when you created all the tasks.
