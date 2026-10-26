---
name: babysit-pr
description: Monitor a GitHub pull request or GitLab merge request through CI and remote review until the latest commit is ready for human review. Use when asked to babysit checks, address review feedback, or finish the remote review loop, including CodeRabbit on GitHub and GitLab Duo on GitLab.
---

# Babysit PR

Own CI and remote review until the latest pushed commit is green, mergeable, and review-clean. Leave the request unmerged for human review. This skill can run on its own or as the final verification loop of `deliver-change`; it does not replace independent local `review-code` review.

## Establish the target

Accept a pull or merge request URL or number, or infer the request from the current branch. Use `gh` for GitHub and `glab` for GitLab. Inspect repository instructions, required checks, source and target branches, and current HEAD. Read remote configuration without printing credential-bearing URLs.

Work on the request's source branch in the provided checkout. Preserve unrelated changes. Before mutating remote state, refresh it directly from the forge rather than relying on an old watcher snapshot.

Record the latest pushed SHA, required gates, bot review identities, review completion signals, and unresolved published feedback. Include existing unresolved feedback on the first pass. Ignore unpublished pending reviews until submitted. A quiet comment stream does not prove a review has finished.

## Start the forge review

Discover supported review triggers and completion signals from repository instructions, configuration, existing review activity, or the integration's documentation. Verify commands before using them rather than guessing bot handles or API endpoints.

### GitHub

Watch for CodeRabbit's checks, submitted reviews, comments, and unresolved review threads. Also watch other configured bots when repository instructions, checks, or request activity show that they participate. Learn each bot's identity and supported re-review mechanism from that evidence.

If CodeRabbit has not started, inspect whether it needs a supported explicit trigger or whether draft status prevents review. Use the configured trigger when available. If the integration is absent or cannot review this request, report the blocker instead of treating missing feedback as a clean review. Do not install or reconfigure the integration as part of babysitting.

### GitLab

Explicitly assign GitLab Duo as a reviewer and trigger its code review using the supported GitLab mechanism. Creating or pushing a merge request is not proof that Duo has started. Confirm a completed review cycle for the latest HEAD before considering it clean.

If the user has reserved assignment and triggering for themselves, leave those actions to them. Report the merge-request URL and the exact manual action needed, then resume monitoring once the requested review starts. Apply the same rule when a later fix requires another review. A pending manual trigger never counts as a clean review.

Also watch other configured review bots when the project requires them. If Duo is unavailable because of permissions, licensing, or integration configuration, report the blocker rather than silently skipping it.

## Monitor and fix

Maintain one monitoring owner for each request. Prefer a harness-managed watcher that resumes this workflow when checks, reviews, or conflicts change. Register the request with the harness when supported. A watcher registration or an asynchronous yield means monitoring is pending, not that babysitting has completed. If no managed watcher exists, poll forge state about every 60 seconds with interruptible waits. Keep consuming the loop until a completion or blocker condition occurs; leave no detached watcher behind.

Use low-chatter CI waits when appropriate, while continuing to collect review feedback through the monitoring owner:

- GitHub: `gh pr checks <number> --watch --interval 60`. Inspect failed jobs with `gh run view <run-id> --log-failed` or the job logs API when the overall run is still pending.
- GitLab: `glab ci status --branch <branch> --wait`. Inspect failed jobs with `glab ci trace <job-id>`. Associate the pipeline with the request's latest SHA, especially when branch and merge-request pipelines both exist.

On each update:

1. Refresh request state, HEAD, CI, published feedback, and mergeability. Stop if merged or closed.
2. Collect current bot findings from checks, reviews, comments, and unresolved threads. Verify each against the contract and code, including style and suggestion-level findings. Resolve valid findings in a coherent batch. Rebut invalid findings with concrete evidence through an authorized bot-supported mechanism. A finding still awaiting a decision remains unresolved.
3. Inspect failed job logs before deciding whether to fix or retry. Fix failures caused by this branch. For a transient infrastructure or external-service failure, retry the failed jobs at most three times for the same failing check and SHA. Track attempts across monitoring resumptions. Report persistent infrastructure failures or exhausted retries as blockers; avoid changing code to mask them.
4. For each code batch, run proportionate local checks, invoke the `commit` skill, and push. Address review changes before rerunning CI on a SHA that will be replaced. For material correctness changes, invoke `review-code` for focused local verification of the fix.
5. Resolve eligible bot threads only after verifying the fix or rebuttal. After every batch, including rebut-only batches, obtain a fresh review cycle when the bot does not start one automatically. Follow the GitLab assignment and trigger rules above for Duo.
6. Resume monitoring after every push, retry, or re-review request. Reset completion evidence when HEAD changes. A review of an older SHA cannot satisfy the current gate.

Treat human feedback as evidence to assess alongside bot feedback. Fix clear, in-scope defects, but get explicit authorization before posting replies to other people or resolving their threads. Surface decisions that need the user's judgment with the relevant comment link. Leave unrelated suggestions for the handoff unless they block a required gate.

Keep updates concise. Report state changes, fixes, new review findings, and genuine blockers. Do not ask whether to keep watching while work remains pending.

## Completion and blockers

Report ready only after a final fresh forge read confirms all of the following for the same latest HEAD:

- All required checks passed. Advisory or documented baseline failures are identified separately.
- The forge confirms there are no merge conflicts. Report outstanding human approvals separately, since this handoff is for human review.
- CodeRabbit on GitHub or Duo on GitLab, plus every other required configured bot, completed its latest review cycle with no remaining findings or unresolved threads. A stale summary that still lists findings needs a fresh clean cycle.
- No actionable published human feedback remains unaddressed.
- All intended fixes are committed and pushed.

A successful result is ready for human review, not merged. Keep watching while checks or reviews are queued, running, or merely quiet. Do not merge, close, or change draft status unless separately authorized by the calling workflow or user. If draft status prevents required review, report that specific dependency before changing it.

Stop with an incomplete result when user action is required, such as a manual Duo trigger, an unresolved product decision, missing permissions, unavailable review integration, an exhausted CI retry budget, or a conflict that cannot be resolved within the agreed scope. Distinguish this from ready. If merged or closed externally, report that terminal state.

Stop or unregister the watcher when handing back a terminal result. Return the request URL, final SHA, CI summary, mergeability, review completion evidence, fixes pushed, retries used, and any remaining blockers. `deliver-change` may hand off only after a ready result; pending monitoring or a blocker does not count as successful completion.
