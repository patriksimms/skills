# Agent Skills

A collection of agent skills that extend capabilities across planning, development, and tooling.

The skills use the `td` cli for using todoist as a task management tool instead of github issues 

> This is heavily inspired from https://github.com/mattpocock/skills

## Planning & Design

These skills help you think through problems before writing code.

* write-a-prd — Create a PRD through an interactive interview, codebase exploration, and module design. Filed as a todoist PRD issue.

```sh
npx skills@latest add patriksimms/skills/write-a-prd
```

* write-a-prd — Create a PRD through an interactive interview, codebase exploration, and module design. Filed as a linear PRD project.

```sh
npx skills@latest add patriksimms/skills/write-a-prd-linear
```

* prd-to-issues — Break a PRD into independently-grabbable GitHub issues using vertical slices.

```sh
npx skills@latest add patriksimms/skills/prd-to-issues
```

* prd-to-issues-linear — Break a PRD into independently linear issues using vertical slices.

```sh
npx skills@latest add patriksimms/skills/prd-to-issues-linear
```

* grill-me - Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.

```sh
npx skills@latest add patriksimms/skills/grill-me
```

* tdd-ralph - Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time. Can work AFK in a ralph loop

```sh
npx skills@latest add patriksimms/skills/tdd-ralph
```

* triage-issue - Investigate a bug by exploring the codebase, identify the root cause, and file a Linear issue with a TDD-based fix plan.

```sh
npx skills@latest add patriksimms/skills/triage-issue
```
