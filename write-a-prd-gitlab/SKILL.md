---
name: write-a-prd-gitlab
description: Create a PRD through user interview, codebase exploration, and module design, then submit it as a GitLab work item in the current project using the glab CLI. Use when user wants to write a PRD, create a product requirements document, or plan a new feature in GitLab.
---

This skill will be invoked when the user wants to create a PRD and file it in GitLab. You may skip steps if you don't consider them necessary.

1. Ask the user for a long, detailed description of the problem they want to solve and any potential ideas for solutions.

2. Explore the repo to verify their assertions and understand the current state of the codebase.

3. Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

4. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

5. Once you have a complete understanding of the problem and solution, use the template below to write the PRD. The PRD should be submitted as a GitLab work item in the current project using `glab`.

Before creating the work item, verify `glab` is authenticated and pointed at the intended GitLab project:

```sh
glab auth status
glab repo view
```

Prefer `glab work-items create` when available:

```sh
glab work-items create --type issue --title "<PRD title>" --description "$(cat /tmp/prd.md)"
```

Use `--repo <group/project>` if the current directory is not the intended project. If the installed `glab` version does not support `work-items create`, use `glab issue create --title "<PRD title>" --description "$(cat /tmp/prd.md)" --yes` as the closest current-project work item equivalent, and tell the user that their `glab` version lacks the experimental work item create command.

<prd-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.

</prd-template>
