---
name: renovate-review
description: Review and harden Renovate dependency-upgrade merge requests by tracing actual project usage to behavioral protection, checking release-note breakage, adding missing tests, validating the upgrade, and granting narrowly scoped patch or minor automerge when earned. Use when assessing, preparing, fixing, or deciding automerge eligibility for a Renovate or dependency-update MR.
---

# Renovate Review

Establish whether an upgrade preserves the project's behavior, then decide separately whether the dependency has earned unattended future upgrades. Treat MR readiness and automerge eligibility as two gates.

Respect the caller's action scope. Questions and review requests remain read-only. Requests to prepare, harden, or fix the MR authorize local code, test, and Renovate-config changes. Pushes, comments, approvals, and merges require explicit authorization; this workflow never merges implicitly.

## 1. Pin the review

Read the repository's agent instructions and inspect its configured package, test, build, and CI commands. Preserve unrelated working-tree changes.

Use `glab` for GitLab operations. Resolve and record:

- repository and MR IID
- target branch and SHA
- source branch and reviewed SHA
- complete MR description, commits, diff, pipeline state, and existing discussion
- each direct old-to-new dependency change and its package manager

Treat the SHAs as the review boundary. Refresh the evidence before concluding if the source SHA changes. Derive versions from manifests and lockfiles, not the title alone.

## 2. Establish the upgrade facts

For every upgraded package, record its exact old and new versions, update class, direct or transitive status, and role such as runtime, build, development, type, or CI tooling. Inspect meaningful transitive changes introduced by the lockfile instead of treating it as an opaque generated file.

Read the entire MR description and every linked upstream release note, changelog, and migration guide covering the exact version interval. Prefer the package's official repository and documentation when the MR summary is incomplete. Account for:

- breaking changes and removals
- deprecations that affect current usage
- changed defaults or output
- runtime, platform, peer, and engine requirements
- configuration, plugin, type, build, or generated-code changes

Classify every item as `affected`, `unaffected`, or `unknown`, with project evidence. Missing or ambiguous upstream information remains an explicit unknown and blocks automerge eligibility.

## 3. Trace actual project usage

Search beyond imports. Include manifests, dynamic loading, configuration, scripts, CLIs, plugins, code generation, build and test setup, types, generated artifacts, and relevant indirect runtime behavior.

Group equivalent touchpoints by distinct project behavior. For each behavior, identify:

- the project entry point or workflow that reaches the dependency
- the dependency contract relied upon
- the user-visible or system-visible outcome if that contract changes
- which upstream changes can affect it

This step is complete only when every distinct usage behavior and every upstream change has an evidence-backed classification. An unexplained usage or `unknown` classification blocks both gates.

## 4. Judge existing protection

Map each affected usage behavior to the existing test, typecheck, build, lint, or generated-artifact assertion that protects it. Protection counts only when all three are true:

1. The check executes the relevant project usage.
2. Its assertion fails when the relied-upon behavior changes materially.
3. Required CI executes the check for Renovate MRs.

A typecheck or build is sufficient when the relied-upon behavior is compilation, bundling, plugin loading, or type compatibility and the check fails on that incompatibility. Line coverage alone is not evidence. A package import smoke test, an assertion of the installed version, or a test of the dependency's API in isolation is not project protection. A test that mocks away the dependency integration protects only the surrounding project logic.

Label each behavior `protected`, `partially protected`, or `unprotected`. When assertion sensitivity is unclear and a safe local check is practical, temporarily perturb the project-owned adapter or configuration, confirm the relevant test goes red, then restore the perturbation. Never commit the temporary fault.

## 5. Close relevant gaps

In an authorized change request, add the smallest test that observes the project's own behavior for each unprotected behavior. Exercise a project entry point, adapter, workflow, command, or generated output with realistic project inputs and assert only the outcome the project relies upon. One test may protect several equivalent touchpoints.

When an affected upstream change requires adaptation, make the smallest compatibility change and cover the preserved project behavior. Prefer an existing focused test layer over introducing a new framework. Keep an existing build or typecheck as the protection when it already proves the exact contract.

Leave the dependency on manual review when meaningful automated protection is impractical. Explain the manual verification required instead of adding a synthetic dependency test.

## 6. Validate the evidence

Run the narrowest relevant checks first, followed by the repository's required validation suite. Confirm from CI configuration that the protecting checks actually run on Renovate branches and are required rather than advisory or allowed to fail.

Separate failures already present on the target SHA from failures introduced by the upgrade. Review every local diff after testing. Validate Renovate configuration with the repository's existing validator or Renovate's current schema when configuration changes.

Validation is complete when all added or relied-upon checks pass on the reviewed source SHA, required CI coverage is confirmed, baseline failures are identified, and no temporary perturbation remains.

## 7. Apply the two gates

Mark the current MR ready only when:

- every changed dependency and meaningful transitive change is accounted for
- every relevant upstream change is classified without unresolved impact
- every affected project behavior is protected
- required validation passes or only evidenced target-branch failures remain
- no compatibility work remains

Grant **earned automerge** only when the MR is ready and the protection is durable enough to evaluate future upgrades in required CI. Scope the Renovate rule to the exact package and manager or datasource when needed.

Use these policy bounds:

- Stable packages at `1.0.0` or newer may earn `patch` and `minor` automerge.
- Packages below `1.0.0` earn `patch` automerge only; keep minor upgrades manual unless the caller explicitly chooses an exception.
- Major upgrades always remain manual. Verify the effective configuration has a final major-update rule with automerge disabled, including against broader or later package rules.
- A grouped update earns automerge only when every member independently qualifies.
- Keep a package manual when required checks do not run on Renovate MRs, release impact remains unknown, the relevant behavior cannot be automated meaningfully, or the effective config cannot be verified.

Edit the repository's actual Renovate source of truth and follow its existing config style. Account for package-rule merging and order so a broader rule cannot silently override the decision. When configuration is owned by an external preset, report the exact required change and owner instead of changing a different repository.

## 8. Report the decision

Return a compact evidence table:

| Dependency or upstream change | Project usage | Protection | Result |
|---|---|---|---|
| Exact item | Concrete behavior or evidence of no usage | Test, build, typecheck, or gap | Protected, unaffected, or unresolved |

Then report:

- `MR decision: ready` or `MR decision: not ready`
- `Automerge decision: enabled`, `Automerge decision: eligible but not changed`, or `Automerge decision: manual`
- files changed and checks run
- remaining unknowns, baseline failures, and manual verification

Do not describe a dependency as safe in general. State precisely which project behaviors and update classes the evidence protects.
