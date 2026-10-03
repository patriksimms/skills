---
name: deliver-change
description: Deliver an end-to-end change to a product/ project from a clarified outcome. Use when the user asks the agent to implement and shepherd a change until it is ready for human review.
---

# Deliver Change

Own a change until its pull or merge request is green, every configured code-review bot is clean, and it is ready for human review. Leave it unmerged. Prefer correctness and a compact, reviewable change over opportunistic cleanup.

Every delivery uses a dedicated branch and pull or merge request containing only that change. Work in the directory and branch provided by the harness. Leave worktree creation and cleanup to the harness.

Apply every other workflow step only when it reduces a material delivery risk or is required by the repository, user, or forge. Do not create artifacts, tests, abstractions, evidence, or coordination steps solely because this workflow lists them.

## 1. Establish the contract

Inspect the repository before asking questions. Ask one concise batch containing only decisions that materially change behavior, scope, or acceptance.

When the contract is not already clear, restate only the unresolved parts and ask the user to confirm:

- user problem and journey, not only the proposed implementation
- outcome and observable behavior
- in-scope and out-of-scope behavior & changes
- acceptance criteria
- product or technical decisions
- expected test coverage
- important state transitions and edge cases

For stateful behavior, turn the acceptance criteria into a small scenario matrix such as `initial state -> action -> intermediate state -> observable result`. Include filtering, retries, narrowing/widening, deselection, failure, or persistence when relevant. Resolve material ambiguity before opening work.

## 2. Learn the project gates

Read repository instructions and inspect the configured package manager, lockfiles, CI, formatter, linter, type-checker, and test commands. Distinguish:

- required checks that must pass
- allowed failures or advisory checks
- pre-existing repository-wide failures
- changed-file checks appropriate for a repository with baseline debt

Do not invent a gate the project does not configure. Preserve unrelated working-tree changes. Detect the forge and default branch, and follow any repository-selected CLI or wrapper.

## 3. Open the work

Detect the forge without printing remote URLs. Capture `git remote get-url origin` inside the shell command, classify it as GitHub, GitLab, or unknown, and output only that classification. Never run `git remote -v` or otherwise emit a credential-bearing remote URL. Let the first real forge operation verify access; use `gh auth status` or `glab auth status` only to diagnose a failed operation.

Use one vocabulary for the run:

| Forge | Tracking item | Change request |
| --- | --- | --- |
| GitHub | issue | pull request |
| GitLab | work item | merge request |

Prefer a concise, human-readable title that explains why the change matters:

BAD
> ❌ perf(server): negotiate permassage-deflate on the websocket
> ❌ feat(server): Lock MCP server selection after chat generation

GOOD
> ✅ perf(server): cut websocket frame size by 70%+ with gzipping
> ✅ feat(server): Add opt-in read-only Outline MCP integration
> ✅ feat(server): Inject pinned MCP server instructions into chat system prompts

If the user provides an issue or work item, reuse it as the tracking item. Do not create a duplicate. Refine its acceptance criteria through an edit or comment only when needed. Create a new tracking item only when the repository or user requires one, or when it materially helps coordinate non-trivial work.

When using a tracking item, open or refine it with a simple explanation of the `problem` based on the user's prompt and context, then briefly explain the `solution`. When possible, frame them from the user perspective as a classic user story. Example:

```md
## Problem
As a user of esomeLM I want the MCP servers instructions to be included in the LLM System prompt automatically to be able to include arbitrary MCP servers without having to adjust the System prompt in esomeLM every time.
```

Also include concise `In-Scope` and `Out-of-Scope` areas, concise `Acceptance Criteria`, and a scenario matrix where useful. Use `gh issue create` on GitHub only when a new issue is needed. On GitLab, prefer `glab work-items create --type issue` and fall back to `glab issue create`. Pass Markdown with actual newline characters.

If the user provides an existing pull or merge request, use it as the change request. Inspect its source branch and target branch, fetch the exact source ref, and ensure the current checkout contains that source before editing. Preserve local changes, its existing tracking relationship, and push target. Skip new tracking-item, branch, and change-request creation unless the requested work is materially separate from the existing change.

For a new change request, reuse the dedicated branch provided by the harness. If no dedicated branch exists, fetch the current default branch and create a short branch from it in the current working directory, preserving local changes.

If the project requires local setup, such as dependency installation, `.envrc`/`direnv allow`, generated files, or linked local services, run it in the current working directory before implementing.

For a new change request, create it as a draft, linking the tracking item when one exists:

- GitHub: `gh pr create --draft`; include `Closes #<issue-number>` when applicable.
- GitLab: `glab mr create --draft`; include `--related-issue <work-item-iid>` when applicable.

Include the outcome and planned validation in the description of the PR/ MR.

## 4. Implement and preflight

Use the same working directory for implementation, validation, and review fixes.

Trace the complete affected path before editing, including state ownership, memoization, persistence, API or modal payload construction, and existing tests. Implement the smallest coherent end-to-end change satisfying the contract.

When the contract materially changes a frontend's appearance or interaction, create matched visual evidence:

1. Before editing the frontend, capture the affected UI in its current state.
2. After implementation, capture the same route, viewport, data, and UI state wherever possible.
3. Visually inspect every screenshot before uploading it. Check that it shows the intended state, matches the actual application, and contains no misleading errors or unrelated visual changes.
4. Attach the before and after screenshots, clearly labelled, to the tracking item when one exists; otherwise attach them to the change request. Start with one matched pair; add another only when a distinct route, viewport, or state needed to demonstrate the change cannot be shown by an existing pair.

Synthetic fixtures cannot prove appearance unless they preserve the real application shell and layout. Label synthetic evidence explicitly. For cross-cutting UI changes such as themes, inspect representative route types: shell or navigation, form or editor, and data or report view.

The visual-evidence step is complete when the tracking item or change request contains the minimal set of matched before/after screenshots needed to show every materially changed frontend state.

When changed behavior or material regression risk warrants a test, add it at the lowest level that proves the behavior. Use existing end-to-end infrastructure when the changed journey is already covered there.

Keep tests proportional to the diff. Test changed behavior and material regression risk; do not add coverage for unchanged adjacent paths.

Before publishing:

1. Map every acceptance criterion and scenario to implementation or test evidence.
2. Exercise the full transition sequence, not only isolated predicates.
3. Inspect the diff for accidental formatting, dependency, generated-file, and lockfile churn.
4. Run focused tests first, then the project's required local gates.
5. Record advisory or pre-existing failures accurately without treating them as change-caused blockers.
6. Explicitly record changes outside the repository that are required for complete deployment from the local environment through production. Examples include CI/CD variables set through GitLab, Keycloak client settings, secret names, redirect URIs, permissions, and other environment-specific configuration. Treat these examples as prompts for discovery, not a complete checklist.

Do not introduce a new framework or broad refactor only to satisfy a preference when a smaller project-consistent solution is adequate.

## 5. Publish and reach green

Invoke the `commit` skill to commit only the intended changes, including the tracking-item reference when one exists. Push the branch and update the change-request description when implementation or validation differs from the plan.

Watch checks for the exact pushed commit with the forge's low-chatter wait mode. Let the watcher finish instead of manually polling it in parallel:

- GitHub: `gh pr checks --watch --interval 60`; inspect failures with `gh run view <run-id> --log-failed`.
- GitLab: `glab ci status --branch <branch> --wait`; inspect failures with `glab ci trace <job-id>`.

Fix a failure only when evidence connects it to the change. Rerun relevant local checks, invoke the `commit` skill, push, and watch the replacement pipeline. For infrastructure, credentials, service, network, or documented baseline failures outside the change, report the evidence; stop only when a required gate cannot complete.

This gate passes when all required checks for the latest commit succeed.

## 6. Run a bounded independent review when warranted

Use the `review-code` skill when the repository or user requires independent review, or when the change carries material correctness, security, privacy, data-loss, compatibility, cross-cutting, or state-transition risk. For a routine low-risk change, inspect the final diff yourself and omit the independent agent review. Record the omission in the handoff.

Reviews return candidates; the delivery owner decides what is blocking before anything is posted or changed.

### First review

After the first green run, start one fresh, context-isolated review agent. Do not inherit or summarize the implementation conversation. Give it only:

- working directory and forge
- change-request number and URL
- target branch and reviewed HEAD SHA
- tracking-item number and URL, when one exists
- project gate summary
- for frontend changes, labels and attachment URLs for the matched before/after screenshots

When the client exposes conversation-inheritance controls, disable inherited turns (`fork_turns="none"` in Codex). In Claude Code, use a normal named subagent, not a conversation fork or resumed agent.

Ask for a full `review-code` review of `<target-branch>...<reviewed-HEAD>` and candidate findings without modifying code or posting comments.

For each candidate, independently confirm its evidence and classify it:

- **Blocking:** a reproducible correctness, security, privacy, data-loss, compatibility, or explicit acceptance-criterion failure; or a required project gate caused by the change.
- **Non-blocking:** maintainability improvements, preference-level guidance, possible code smells, naming/style opinions, speculative abstractions, and tooling or baseline issues that do not fail a required gate.

Do not upgrade a finding merely because it is labelled actionable. Post only confirmed blocking findings as `[codex]` discussions, inline when a stable position exists. Summarize non-blocking suggestions in the handoff; do not create resolvable threads for them.

Confirm the defect independently, but do not inherit the reviewer's proposed solution. Re-derive the smallest project-consistent fix. If a review fix materially expands files, concepts, or runtime state, perform a scope check before implementing it.

### Fix blocking findings once as a batch

If blockers exist, fix them as the delivery owner in the same working directory. Keep implementation in the main delivery context; do not delegate it to the reviewer or a fresh fix agent. For each finding, choose:

- **Accept:** reply with intent, fix and test, invoke `commit`, push, reply with the SHA, and resolve.
- **Rebut:** reply with concrete spec or code evidence and resolve without changing code.
- **Clarify:** leave open and ask the user for the exact decision.

Avoid concurrent code edits. After the batch, rerun required checks.

### Delta verification

Run at most one independent delta review from the previously reviewed SHA to the new HEAD. It must:

- verify accepted blockers and their regression tests
- inspect only changed lines plus directly affected behavior
- avoid new smell hunting in unchanged code
- return candidates without posting

If it finds a new blocker caused by the fix, correct it and run targeted local verification of that scenario. Do not restart a broad standards/spec review. Report any unresolved non-blocking concern to the human reviewer.

The normal review budget is one full review and one delta verification. Exceed it only for an unresolved high-risk correctness, security, privacy, or data-loss issue, and tell the user why.

## 7. Clear configured code-review bots

After the independent review, babysit code-review bots configured for the project, including Macroscope and CodeRabbit. Treat a bot as configured when repository files, forge checks, repository instructions, or activity on the change request show that it participates. Do not summon a bot that has no such evidence.

For each configured bot, learn its review identity, completion signal, and supported re-review mechanism from the project configuration or the bot's existing check, review, or comment. Do not guess account names or commands.

Run this loop without an iteration cap:

1. Wait for every configured bot to finish reviewing the latest HEAD. A quiet comment stream is not evidence of completion.
2. Collect every current finding from checks, reviews, top-level comments, and unresolved threads. Do not silently defer style or suggestion-level findings as non-blocking.
3. Verify each finding against the contract and code. Fix valid findings in one coherent batch with proportionate tests. Rebut invalid findings with concrete evidence and resolve or dismiss them through the forge or bot-supported mechanism. Ask the user only when a finding requires a product decision or new authority.
4. When code changed, invoke the `commit` skill, push, and rerun the required project gates. After every batch, including rebut-only batches, request a fresh bot review using the bot's supported mechanism when it does not start automatically.
5. Repeat for the new HEAD whenever a push or fresh review produces findings.

This gate passes only when required checks are green and every configured bot's latest completed review cycle against the latest HEAD produces no findings and leaves no unresolved threads. A completed review of an older commit, a pending bot, or a bot summary that still lists findings does not pass. If a bot cannot complete because its service, credentials, or forge integration is unavailable, keep the change request in draft and report the blocker instead of treating the bot as clean.

## 8. Hand off

Mark the draft ready with the forge-supported command or API.

Confirm all intended changes are committed and pushed. Preserve unrelated local changes and keep the branch for the change request.

Report:

- tracking-item URL when one exists, and the change-request URL
- delivered behavior
- frontend before/after evidence attached to the tracking item or change request, when applicable
- changes outside the repository required for complete deployment, or an explicit statement that none are required
- required validation and latest green commit
- blocking findings and resolutions
- configured code-review bots and their clean result for the latest commit
- non-blocking suggestions, if any
- whether independent review was omitted as proportionate, or whether the full review and delta verification were clean

Leave the change request unmerged for human review.
