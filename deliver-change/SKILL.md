---
name: deliver-change
description: Deliver an end-to-end GitHub or GitLab change from clarified outcome through tracking item, pull or merge request, implementation, tests, green checks, and fresh-context review/fix loops. Use when the user asks Codex to implement and shepherd a change until it is ready for human review.
---

# Deliver Change

Own a change until its pull or merge request is green and independently reviewed. Stop at human review; leave the change request unmerged.

## 1. Establish the contract

Require the user to state the desired change or outcome. Inspect the repository for context before asking follow-ups. Ask concise questions in one batch whenever possible, limited to decisions whose answers materially change behavior, scope, or acceptance. Include a recommended answer when it helps.

Restate the shared contract as:

- outcome and observable behavior
- in-scope and out-of-scope behavior
- acceptance criteria
- relevant product or technical decisions
- expected test coverage
- user-provided evidence, including every image pasted or attached in the chat

Ask the user to confirm or correct it. Batch any remaining blockers once more. This step is complete only when the contract contains no unresolved decision that would materially change the implementation.

## 2. Open the work

Read the repository instructions, detect the forge from the configured remote, identify the default branch, and preserve unrelated working-tree changes. Follow a user or repository instruction that selects a forge or CLI wrapper.

Use one vocabulary for the rest of the run:

| Forge | Verify access | Tracking item | Change request |
| --- | --- | --- | --- |
| GitHub | `gh auth status` and `gh repo view` | issue | pull request |
| GitLab | `glab auth status` and `glab repo view` | work item | merge request |

Create a concise tracking-item body containing the confirmed contract under `Outcome`, `Scope`, and `Acceptance criteria`. When the user pasted or attached images, add an `Evidence` section and include every image unless the user explicitly excludes it. Obtain the image bytes or local attachment path from the chat harness; when neither is accessible, ask the user to reattach the image or provide a path rather than omitting it.

Attach images through the selected forge:

- On GitLab, upload each image with `glab api --method POST projects/:fullpath/uploads --form "file=@<path>"`. Extract the non-empty `.markdown` value from each response and place every value in `Evidence` before creating the work item.
- On GitHub, place any image with a stable accessible URL in `Evidence`. For a local-only chat image, create the issue with `gh`, then use the authenticated GitHub web issue editor to upload the image into its description and save it. If browser interaction is unavailable, ask the user for an accessible image URL; `gh issue create` has no supported binary-attachment option.

Pass Markdown with actual newline characters. Use `gh issue create` on GitHub. On GitLab, prefer `glab work-items create --type issue` and fall back to `glab issue create` when the installed CLI lacks work-item support. Capture the tracking item's number or IID and URL. Fetch its saved description and verify that it contains a Markdown reference for every included image.

Create a short branch from the current default branch and check it out in the existing working directory. Use no additional worktree. Create a linked draft change request:

- On GitHub, use `gh pr create --draft` and include `Closes #<issue-number>` in its body.
- On GitLab, use `glab mr create --draft --related-issue <work-item-iid>`.

Include the outcome and planned validation in the change request description. Capture its number or IID and URL.

This step is complete when every included chat image is attached to the tracking item, the linked draft change request exists, and its source branch is checked out locally.

## 3. Implement the contract

Trace the affected behavior and existing conventions before editing. Implement the smallest coherent end-to-end slice that satisfies every acceptance criterion.

Add reasonable behavior-focused tests at the lowest useful level. When the repository already has end-to-end test infrastructure and the change affects a covered user journey, add or update an end-to-end test. Run the relevant focused tests first, then the repository's normal formatting, linting, type-checking, and test commands.

This step is complete when every acceptance criterion is represented by implementation or test evidence and all relevant local checks pass.

## 4. Publish and reach green

Invoke the `commit` skill to commit the intended changes, including the tracking item reference. Push the checked-out branch and update the change request description if implementation or validation differs from the original plan.

Watch the latest change-request checks to completion with the selected forge CLI:

- On GitHub, use `gh pr checks --watch`; inspect failures with `gh run view <run-id> --log-failed`.
- On GitLab, use `glab ci status --branch <branch> --live`; inspect failures with `glab ci trace <job-id>`.

For each failure:

- If the failure is caused by this change, fix it, rerun the relevant local checks, invoke the `commit` skill, push, and watch the new pipeline.
- If the evidence points to project configuration, runner infrastructure, credentials, dependency service availability, or a network failure outside this change, stop and report the failing job, evidence, and change-request URL to the user.

This gate is complete only when every required check for the latest change-request commit succeeds.

## 5. Run the fresh-context review loop

After each green check run, start a fresh review thread with no implementation conversation. Give it only the repository path, forge, change-request number/URL, target branch as the fixed point, and tracking-item number/URL. Direct it to:

1. Fetch the current tracking-item description with the selected forge CLI and use it as the exact spec.
2. Invoke the `code-review` skill against `<target-branch>...HEAD`.
3. Post every actionable finding to the change request with the selected forge CLI or API, inline on the diff when a stable position is available and otherwise as a top-level comment. Prefix agent-authored comments with `[codex]`.
4. Return the posted comment or discussion IDs and explicitly report whether the review found zero actionable issues.

Wait for that thread to finish. When it posts findings, start a separate fresh fix thread with the repository path, forge, change-request number/URL, tracking-item number/URL, and finding IDs. Direct it to inspect each finding and choose one resolution:

- Accept: reply with the intended correction, implement and test it, invoke the `commit` skill, push, then reply with the commit SHA and resolve the thread where the forge supports resolution.
- Rebut: reply with concrete spec or code evidence and resolve the thread where the forge supports resolution without changing code.
- Clarify: leave the discussion open and return the exact decision needed from the user.

The fix thread must avoid changing code concurrently with any other thread. If clarification is required, stop and ask the user. Otherwise, wait for the new checks and apply the green-check gate again. Then start another fresh review thread. A later review should not repost an identical resolved finding unless the problem still exists.

Repeat until a fresh review reports zero actionable findings, every agent-generated finding has a recorded resolution, every resolvable review thread is resolved, and the latest commit's required checks are green.

## 6. Hand off

Mark the draft change request ready with `gh pr ready` or `glab mr ready`. Report the tracking-item and change-request URLs, the delivered outcome, validation performed, and that the checks and final review are clean. Leave the pull or merge request for the human to review and merge.

The skill is complete only at this handoff state.
