---
name: review-code
description: Review a branch, pull request, merge request, or work-in-progress diff against a fixed point along Standards and Spec axes, then deduplicate and risk-rank evidence-backed findings into blocking and non-blocking results. Use for full code reviews, post-fix delta verification, or when another workflow needs a concise independent review without nit-pick-driven refactoring.
---

# Review Code

Review a fixed diff for merge-relevant risk. Keep Standards and Spec investigations independent, then curate their output into one risk-ranked report. Remain read-only unless the caller explicitly requests comments or changes.

## 1. Pin the review

Require and resolve:

- repository path
- fixed point or target branch
- reviewed HEAD SHA
- originating issue, PRD, or other spec when one exists
- mode: `full` or `delta`

Use `git diff <fixed-point>...<reviewed-head>` and `git log <fixed-point>..<reviewed-head> --oneline`. Fail early on a bad ref or empty diff.

For `delta` mode, also require the previously reviewed SHA. Review `<previously-reviewed-sha>..<reviewed-head>`, the resolution of prior blockers, and behavior directly affected by those edits. Do not reopen unchanged code or search it for new smells.

## 2. Gather authoritative context

Fetch the exact spec from the tracking system when available. Identify repository-authored standards such as `AGENTS.md`, `CONTRIBUTING.md`, or `CODING_STANDARDS.md` and inspect configured CI and package scripts.

When the diff changes user-facing frontend behavior and the tracking item contains labelled before/after screenshots, open every matched pair and compare the affected state. Record the evidence each pair demonstrates and any attachment that is missing or inaccessible. Visual context gathering is complete when every materially changed frontend state represented by the attachments has been inspected or recorded as unavailable.

Record which gates are required, advisory, allowed to fail, or already failing on the fixed point. A tool preference is not a hard rule. A repository baseline failure is not introduced by the diff unless evidence shows otherwise.

## 3. Review along two independent axes

When subagents are available, run Standards and Spec in parallel with `fork_turns="none"`; otherwise run them sequentially with separate notes. Give each only the repository path, exact refs, relevant standards or spec, and the brief below. For frontend changes, give the Spec axis the inspected visual evidence.

### Standards axis

Find concrete violations of documented repository rules and material maintainability risks introduced by the diff. Use common code smells only as diagnostic lenses, not a checklist: duplication, primitive obsession, repeated branching, speculative generality, shotgun surgery, divergent change, unclear naming, feature envy, data clumps, message chains, middle men, and inheritance misuse.

Do not report a smell unless the diff creates a concrete near-term risk that can be explained with evidence. Label preference-level guidance and judgement calls non-blocking. Skip formatting, lint, or type diagnostics already enforced by a required gate; report the gate result instead.

### Spec axis

Trace each acceptance criterion through implementation, state transitions, tests, and observable outputs. Report:

- missing or partial requirements
- incorrect behavior or wiring
- material unrequested scope with risk
- tests that pass without proving the required behavior

Exercise sequences, not only isolated predicates: state change, filtering, retry, persistence, failure, narrowing/widening, payload creation, and deselection where relevant.

For frontend changes with matched screenshots, compare the after state with the observable requirements and use the before state to verify the claimed change. Treat screenshots as supporting evidence, not a substitute for exercising interactive behavior or unpictured states.

## 4. Apply the evidence threshold

Every candidate finding must contain:

- exact file and line or stable hunk
- violated spec or documented rule, when applicable
- concrete failure scenario or maintenance impact
- evidence that the diff introduced or retains the problem
- smallest proportionate correction

Reject findings based only on words such as “possible,” “consider,” “cleaner,” or “more type-safe.” Reject speculative future extensibility concerns without present impact. Deduplicate overlapping Standards and Spec findings.

## 5. Classify risk

Use these outcomes:

- **P0 blocking:** active security/privacy breach, data loss, or broadly unusable behavior.
- **P1 blocking:** reproducible correctness, compatibility, or explicit acceptance-criterion failure likely to affect users; or a required gate broken by the diff.
- **P2 conditional:** a concrete but limited defect. Mark blocking only when it violates an explicit acceptance criterion or documented hard standard; otherwise mark non-blocking.
- **Suggestion:** preference, maintainability improvement, possible smell, naming/style opinion, or disproportionate refactor. Always non-blocking.

Soft guidance never blocks by itself. The proposed fix must be proportional to the task; prefer a local correction over architectural expansion.

## 6. Curate the result

Do not return the two axes verbatim. Reconcile, deduplicate, and rank them by user impact. For each retained blocker, verify the scenario yourself before reporting it.

Return:

## Blocking findings

Ordered P0 to P2. Include location, scenario, requirement, evidence, and proportionate fix. Write `None` when empty.

## Non-blocking observations

Include only useful suggestions a human reviewer may reasonably act on. Keep this short; omit nits that add no decision value.

## Verification

State the reviewed refs, checks inspected or run, baseline/advisory failures, prior blocker status in delta mode, important acceptance paths verified, and, for frontend changes, the screenshot pairs inspected or unavailable.

End with exactly one of:

- `Review result: blocking findings present.`
- `Review result: no blocking findings.`

Do not post comments or modify code unless the caller explicitly asks. When asked to post, post blocking findings only; summarize non-blocking observations in one non-resolvable note at most.
