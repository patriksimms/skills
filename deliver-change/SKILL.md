---
name: deliver-change
description: Deliver an end-to-end GitHub or GitLab change from a clarified outcome through a tracking item, draft pull or merge request, implementation, tests, required green checks, and a bounded independent review. Use when the user asks Codex to implement and shepherd a change until it is ready for human review.
---

# Deliver Change

Own a change until its pull or merge request is green and ready for human review. Leave it unmerged. Prefer correctness and a compact, reviewable change over opportunistic cleanup.

## 1. Establish the contract

Inspect the repository before asking questions. Ask one concise batch containing only decisions that materially change behavior, scope, or acceptance.

Restate and ask the user to confirm:

- outcome and observable behavior
- in-scope and out-of-scope behavior
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

Use one vocabulary for the run:

| Forge | Verify access | Tracking item | Change request |
| --- | --- | --- | --- |
| GitHub | `gh auth status` and `gh repo view` | issue | pull request |
| GitLab | `glab auth status` and `glab repo view` | work item | merge request |

Create a concise tracking item containing `Outcome`, `Scope`, `Acceptance criteria`, and the scenario matrix where useful. Use `gh issue create` on GitHub. On GitLab, prefer `glab work-items create --type issue` and fall back to `glab issue create`. Pass Markdown with actual newline characters.

Create a short branch from the current default branch in the existing working directory, then create a linked draft change request:

- GitHub: `gh pr create --draft` with `Closes #<issue-number>`.
- GitLab: `glab mr create --draft --related-issue <work-item-iid>`.

Include the outcome and planned validation in the description.

## 4. Implement and preflight

Trace the complete affected path before editing, including state ownership, memoization, persistence, API or modal payload construction, and existing tests. Implement the smallest coherent end-to-end change satisfying the contract.

Add behavior-focused tests at the lowest level that proves the behavior. Use existing end-to-end infrastructure when the changed journey is already covered there.

Before publishing:

1. Map every acceptance criterion and scenario to implementation or test evidence.
2. Exercise the full transition sequence, not only isolated predicates.
3. Inspect the diff for accidental formatting, dependency, generated-file, and lockfile churn.
4. Run focused tests first, then the project's required local gates.
5. Record advisory or pre-existing failures accurately without treating them as change-caused blockers.

Do not introduce a new framework or broad refactor only to satisfy a preference when a smaller project-consistent solution is adequate.

## 5. Publish and reach green

Invoke the `commit` skill to commit only the intended changes with the tracking-item reference. Push the branch and update the change-request description when implementation or validation differs from the plan.

Watch checks for the exact pushed commit:

- GitHub: `gh pr checks --watch`; inspect failures with `gh run view <run-id> --log-failed`.
- GitLab: `glab ci status --branch <branch> --live`; inspect failures with `glab ci trace <job-id>`.

Fix a failure only when evidence connects it to the change. Rerun relevant local checks, invoke the `commit` skill, push, and watch the replacement pipeline. For infrastructure, credentials, service, network, or documented baseline failures outside the change, report the evidence; stop only when a required gate cannot complete.

This gate passes when all required checks for the latest commit succeed.

## 6. Run a bounded independent review

Use the `review-code` skill. Reviews return candidates; the delivery owner decides what is blocking before anything is posted or changed.

### First review

After the first green run, start one isolated review thread. When subagents are available, use no inherited conversation turns (`fork_turns="none"`). Provide only:

- repository path and forge
- change-request number and URL
- target branch and reviewed HEAD SHA
- tracking-item number and URL
- project gate summary

Ask for a full `review-code` review of `<target-branch>...<reviewed-HEAD>` and candidate findings without modifying code or posting comments.

For each candidate, independently confirm its evidence and classify it:

- **Blocking:** a reproducible correctness, security, privacy, data-loss, compatibility, or explicit acceptance-criterion failure; or a required project gate caused by the change.
- **Non-blocking:** maintainability improvements, preference-level guidance, possible code smells, naming/style opinions, speculative abstractions, and tooling or baseline issues that do not fail a required gate.

Do not upgrade a finding merely because it is labelled actionable. Post only confirmed blocking findings as `[codex]` discussions, inline when a stable position exists. Summarize non-blocking suggestions in the handoff; do not create resolvable threads for them.

### Fix blocking findings once as a batch

If blockers exist, start one isolated fix thread with no inherited conversation turns. Give it only the repository, forge, change request, tracking item, reviewed SHA, and blocking discussion IDs. For each finding, choose:

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

## 7. Hand off

Mark the draft ready with the forge-supported command or API. Report:

- tracking-item and change-request URLs
- delivered behavior
- required validation and latest green commit
- blocking findings and resolutions
- non-blocking suggestions, if any
- whether the full review and delta verification were clean

Leave the change request unmerged for human review.
