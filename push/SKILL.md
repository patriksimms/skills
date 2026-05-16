---
name: push
description:
  Push current branch changes to origin and create or update the corresponding
  merge request; use when asked to push, publish updates, or create merge
  request.
---

# Push

## Prerequisites

- `glab` CLI is installed and available in `PATH`.
- `glab auth status` succeeds for GitLab operations in this repo.

## Goals

- Push current branch changes to `origin` safely.
- Create an MR if none exists for the branch, otherwise update the existing MR.
- Keep branch history clean when remote has moved.

## Related Skills

- `pull`: use this when push is rejected or sync is not clean (non-fast-forward,
  merge conflict risk, or stale branch).

## Steps

1. Identify current branch and confirm remote state.
2. Run local validation (`make -C elixir all`) before pushing.
3. Push branch to `origin` with upstream tracking if needed, using whatever
   remote URL is already configured.
4. If push is not clean/rejected:
   - If the failure is a non-fast-forward or sync problem, run the `pull`
     skill to merge `origin/main`, resolve conflicts, and rerun validation.
   - Push again; use `--force-with-lease` only when history was rewritten.
   - If the failure is due to auth, permissions, or workflow restrictions on
     the configured remote, stop and surface the exact error instead of
     rewriting remotes or switching protocols as a workaround.

5. Ensure an MR exists for the branch:
   - If no MR exists, create one.
   - If an MR exists and is open, update it.
   - If branch is tied to a closed/merged MR, create a new branch + MR.
   - Write a proper MR title that clearly describes the change outcome.
   - For branch updates, explicitly reconsider whether current MR title still
     matches the latest scope; update it if it no longer does.
6. Write/update MR description explicitly using the repo's GitLab merge request
   template:
   - Prefer `.gitlab/merge_request_templates/Default.md` when present.
   - If no default template exists, inspect `.gitlab/merge_request_templates/`
     and choose the template that fits the change.
   - If no GitLab MR template exists, write a concise description with summary,
     rationale, and validation.
   - Fill every section with concrete content for this change.
   - Replace all placeholder comments (`<!-- ... -->`).
   - Keep bullets/checkboxes where template expects them.
   - If MR already exists, refresh description content so it reflects the total
     MR
     scope (all intended work on the branch), not just the newest commits,
     including newly added work, removed work, or changed approach.
   - Do not reuse stale description text from earlier iterations.
7. If the repo has an MR-description validator, run it and fix all reported
   issues.
8. Reply with the MR URL from `glab mr view`.

## Commands

```sh
# Identify branch
branch=$(git branch --show-current)

# Minimal validation gate
make -C elixir all

# Initial push: respect the current origin remote.
git push -u origin HEAD

# If that failed because the remote moved, use the pull skill. After
# pull-skill resolution and re-validation, retry the normal push:
git push -u origin HEAD

# If the configured remote rejects the push for auth, permissions, or workflow
# restrictions, stop and surface the exact error.

# Only if history was rewritten locally:
git push --force-with-lease origin HEAD

# Ensure an MR exists (create only if missing)
mr_json=$(glab mr view "$branch" --output json 2>/dev/null || true)
mr_state=$(printf '%s' "$mr_json" | jq -r '.state // empty' 2>/dev/null || true)
if [ "$mr_state" = "merged" ] || [ "$mr_state" = "closed" ]; then
  echo "Current branch is tied to a closed MR; create a new branch + MR." >&2
  exit 1
fi

# Write a clear, human-friendly title that summarizes the shipped change.
mr_title="<clear MR title written for this change>"
mr_body_file=/tmp/mr_body.md
# Draft the MR description in $mr_body_file from the GitLab template before
# creating or updating the MR.
if [ -z "$mr_state" ]; then
  glab mr create --source-branch "$branch" --target-branch main \
    --title "$mr_title" --description "$(cat "$mr_body_file")" --yes
else
  # Reconsider title on every branch update; edit if scope shifted.
  glab mr update "$branch" --title "$mr_title" \
    --description "$(cat "$mr_body_file")" --yes
fi

# If the repo has a validator for MR descriptions, run it against $mr_body_file.

# Show MR URL for the reply
glab mr view "$branch" --output json | jq -r '.web_url // .webUrl // .url'
```

## Notes

- Do not use `--force`; only use `--force-with-lease` as the last resort.
- Distinguish sync problems from remote auth/permission problems:
  - Use the `pull` skill for non-fast-forward or stale-branch issues.
  - Surface auth, permissions, or workflow restrictions directly instead of
    changing remotes or protocols.
