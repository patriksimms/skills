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

## Waiting

Use one monitoring owner per request. Handle current failures and feedback before waiting. A wake-up or successful watcher exit is a reason to refresh forge state, not proof of readiness.

### In T3 Code

Link the request with `link_pull_request`. For GitHub, call `watch_pull_request` once actionable work is handled, then end the turn. Resume this workflow on the next event. Delivery remains pending across those turns.

Only the owning thread watches. Delegated children return the request URL, reviewed SHA, findings, and pending state to their parent without starting a watcher. Never run a CLI watcher alongside the managed watcher.

Call `unwatch_pull_request` before a ready or blocked handoff, or before asking the user a question. This returns the thread to the user's inbox. Merge or closure ends the watch automatically.

If watching fails, inspect the error before registering again. For GitHub rate-limit errors, inspect `gh api rate_limit`; honor the exhausted resource's reset time with one resumable wait. Repeated registration attempts consume the same quota. REST reads may remain available when GraphQL is exhausted, but cannot replace the missing review-thread data with an assumed clean result.

For GitLab, first check whether the harness explicitly supports merge-request monitoring. Otherwise use the GitLab path below; do not assume GitHub watch tools accept GitLab URLs.

### Outside managed GitHub monitoring

Use an existing event watcher, such as tstack's `pr-wait`, as the sole watcher. This skill does not bundle that helper. Locate an installed copy and inspect its help before invoking it by absolute path; do not invent a local `scripts/pr-wait` path or write a replacement polling script.

The upstream helper's `ready` mode recognizes Greptile or Macroscope, not our required CodeRabbit review. Use a supported event mode such as `any-change`, then evaluate this skill's completion criteria yourself. Resume the same watcher after handling events, pushing fixes, or resuming the session. Do not duplicate an active watcher whose output still reaches this task. If no compatible watcher is available, report the missing monitoring capability rather than claiming continuous coverage.

### GitLab without managed monitoring

Use `glab ci status --branch <branch> --wait` for the current pipeline. It waits for CI, not Duo reviews. Verify its SHA because branch and merge-request pipelines can coexist. Prefer an existing merge-request event watcher for subsequent review updates. When none exists, the owning session may recheck review and request state with interruptible waits of about 60 seconds. Keep that single session active until ready or blocked; do not create a detached polling process or add another CI watcher.

With every path, stay quiet on unchanged or irrelevant events. Report actions, new blockers, or completion. Do not post filler comments or repeat waiting messages.

## Reviews and CI

Use `gh run view <run-id> --log-failed` or individual job logs to diagnose GitHub failures. Use `glab ci trace <job-id>` on GitLab. Inspect the failing job even if other jobs are still running.

On each update:

1. Refresh request state, HEAD, CI, published feedback, and mergeability. Stop if merged or closed.
2. Collect bot findings from checks, reviews, comments, and unresolved threads, including findings that predate the latest push. Verify them against the current code before acting. Fix in-scope defects in one batch. For false positives or suggestions outside the agreed scope, record a concrete reason through an authorized bot-supported mechanism and resolve eligible threads. A finding still awaiting a decision remains unresolved.
3. Inspect failed job logs before deciding whether to fix or retry. Fix failures caused by this branch. For a transient infrastructure or external-service failure, retry the failed jobs at most three times for the same failing check and SHA. Track attempts across monitoring resumptions. Report persistent infrastructure failures or exhausted retries as blockers; avoid changing code to mask them.
4. For each code batch, run proportionate local checks, invoke the `commit` skill, and push. Address review changes before rerunning CI on a SHA that will be replaced. For material correctness changes, invoke `review-code` for focused local verification of the fix.
5. Resolve eligible bot threads only after verifying the fix or rebuttal. After every batch, including rebut-only batches, obtain a fresh review cycle when the bot does not start one automatically. Follow the GitLab assignment and trigger rules above for Duo.
6. Resume monitoring after every push, retry, or re-review request. Reset completion evidence when HEAD changes. A review of an older SHA cannot satisfy the current gate.

Treat human feedback as evidence to assess alongside bot feedback. Fix clear, in-scope defects, but get explicit authorization before posting replies to other people or resolving their threads. Surface decisions that need the user's judgment with the relevant comment link. Leave unrelated suggestions for the handoff unless they block a required gate.

Keep the change within the user's goal. Assess each suggestion for a defect in the intended behavior before adding tests, abstractions, compatibility, edge-case guards, or optimizations. Explain declined suggestions and include useful follow-ups in the handoff; review feedback alone does not authorize expanding scope.

For Macroscope findings that cite `.macroscope/check-run-agents/*.md`, read the relevant repository rules before responding.

## Base branch and readiness

Fetch the actual target branch before the final readiness check. Compare it with the base used by the latest green run. Inspect both forge mergeability and commits that landed on the target while this request was under review; a conflict-only watcher cannot establish that the tested base is still current.

When required by branch protection, when conflicts exist, or when new base commits affect this change's files or behavior, update the source branch using the repository's merge or rebase policy. Preserve unrelated work and avoid overwriting another contributor's commits. Use a lease if an authorized rebase requires a force push. If safe integration requires a new decision or authority, report the blocker. After updating, rerun local gates, push, and obtain fresh CI and bot-review evidence for the new HEAD. Being behind on unrelated base commits alone does not require a rebase unless the project requires an up-to-date branch.

If another change supersedes this request, stop watching and explain the overlap. Ask before closing it unless closure was already authorized.

## Completion and blockers

Report ready only after a final fresh forge read confirms all of the following for the same latest HEAD:

- All required checks passed. Advisory or documented baseline failures are identified separately.
- The forge confirms there are no merge conflicts, and the base-branch checks above pass. Report outstanding human approvals separately, since this handoff is for human review.
- CodeRabbit on GitHub or Duo on GitLab, plus every other required configured bot, completed its latest review cycle with no remaining findings or unresolved threads. A stale summary that still lists findings needs a fresh clean cycle.
- No actionable published human feedback remains unaddressed.
- All intended fixes are committed and pushed.

A successful result is ready for human review, not merged. Keep watching while checks or reviews are queued, running, or merely quiet. Do not merge, close, or change draft status unless separately authorized by the calling workflow or user. If draft status prevents required review, report that specific dependency before changing it.

Stop with an incomplete result when user action is required, such as a manual Duo trigger, an unresolved product decision, missing permissions, unavailable review integration, an exhausted CI retry budget, or a conflict that cannot be resolved within the agreed scope. Distinguish this from ready. If merged or closed externally, report that terminal state.

Stop or unregister the watcher when handing back a terminal result. Return the request URL, final SHA, CI summary, mergeability, review completion evidence, fixes pushed, retries used, and any remaining blockers. `deliver-change` may hand off only after a ready result; pending monitoring or a blocker does not count as successful completion.

Adapted from [tstack babysit-pr](https://github.com/t3dotgg/tstack/blob/main/skills/babysit-pr/SKILL.md), with required CodeRabbit and Duo review gates and GitLab support.
