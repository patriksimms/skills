---
name: deliver-change
description: Deliver an end-to-end GitLab change from clarified outcome through work item, merge request, implementation, tests, green pipeline, and fresh-context review/fix loops. Use when the user asks Codex to implement and shepherd a change until it is ready for human review.
---

# Deliver Change

Own a change until its merge request is green and independently reviewed. Stop at human review; leave the merge request unmerged.

## 1. Establish the contract

Require the user to state the desired change or outcome. Inspect the repository for context before asking follow-ups. Ask concise questions in one batch whenever possible, limited to decisions whose answers materially change behavior, scope, or acceptance. Include a recommended answer when it helps.

Restate the shared contract as:

- outcome and observable behavior
- in-scope and out-of-scope behavior
- acceptance criteria
- relevant product or technical decisions
- expected test coverage

Ask the user to confirm or correct it. Batch any remaining blockers once more. This step is complete only when the contract contains no unresolved decision that would materially change the implementation.

## 2. Open the work

Read the repository instructions, verify `glab auth status` and `glab repo view`, identify the default branch, and preserve unrelated working-tree changes. Use the repository's required `glab` wrapper when its instructions define one.

Create a concise GitLab work item containing the confirmed contract under `Outcome`, `Scope`, and `Acceptance criteria`. Pass Markdown with actual newline characters. Capture its IID and URL.

Create a short branch from the current default branch and check it out in the existing working directory. Use no additional worktree. Create a draft merge request with `glab mr create --related-issue <work-item-iid>` so GitLab links it to the work item. Include the work item reference, the outcome, and the planned validation in the MR description. Capture the MR IID and URL.

This step is complete when the linked work item and draft MR exist and the MR source branch is checked out locally.

## 3. Implement the contract

Trace the affected behavior and existing conventions before editing. Implement the smallest coherent end-to-end slice that satisfies every acceptance criterion.

Add reasonable behavior-focused tests at the lowest useful level. When the repository already has end-to-end test infrastructure and the change affects a covered user journey, add or update an end-to-end test. Run the relevant focused tests first, then the repository's normal formatting, linting, type-checking, and test commands.

This step is complete when every acceptance criterion is represented by implementation or test evidence and all relevant local checks pass.

## 4. Publish and reach green

Invoke the `commit` skill to commit the intended changes, including the work item reference. Push the checked-out branch and update the MR description if implementation or validation differs from the original plan.

Watch the branch pipeline to completion with `glab`. For each failure, inspect the failing job and its trace:

- If the failure is caused by this change, fix it, rerun the relevant local checks, invoke the `commit` skill, push, and watch the new pipeline.
- If the evidence points to project configuration, runner infrastructure, credentials, dependency service availability, or a network failure outside this change, stop and report the failing job, evidence, and MR URL to the user.

This gate is complete only when the latest MR commit has a successful pipeline.

## 5. Run the fresh-context review loop

After each green pipeline, start a fresh review thread with no implementation conversation. Give it only the repository path, MR IID/URL, target branch as the fixed point, and work item IID/URL. Direct it to:

1. Fetch the current work item description and use it as the exact spec.
2. Invoke the `code-review` skill against `<target-branch>...HEAD`.
3. Post every actionable finding to the MR, inline on the diff when a stable position is available and otherwise as a top-level MR note. Prefix agent-authored comments with `[codex]`.
4. Return the posted discussion or note IDs and explicitly report whether the review found zero actionable issues.

Wait for that thread to finish. When it posts findings, start a separate fresh fix thread with the repository path, MR IID/URL, work item IID/URL, and finding IDs. Direct it to inspect each finding and choose one resolution:

- Accept: reply with the intended correction, implement and test it, invoke the `commit` skill, push, then reply with the commit SHA and resolve the discussion.
- Rebut: reply with concrete spec or code evidence and resolve the discussion without changing code.
- Clarify: leave the discussion open and return the exact decision needed from the user.

The fix thread must avoid changing code concurrently with any other thread. If clarification is required, stop and ask the user. Otherwise, wait for the new pipeline and apply the green-pipeline gate again. Then start another fresh review thread. A later review should not repost an identical resolved finding unless the problem still exists.

Repeat until a fresh review reports zero actionable findings, every agent-generated review discussion is resolved, and the latest commit's pipeline is green.

## 6. Hand off

Mark the draft MR ready, if applicable. Report the work item and MR URLs, the delivered outcome, validation performed, and that the pipeline and final review are clean. Leave the merge request for the human to review and merge.

The skill is complete only at this handoff state.
