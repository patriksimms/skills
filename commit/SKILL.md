---
name: commit
description:
  Create a well-formed git commit from current changes using session history for
  rationale and summary; use when asked to commit, prepare a commit message, or
  finalize staged work.
---

# Commit

## Goals

- Produce a commit that reflects the actual code changes and the session
  context.
- Follow common git conventions (type prefix, short subject, wrapped body).
- Include both summary and rationale in the body.

## Inputs

- Codex session history for intent and rationale.
- `git status`, `git diff`, and `git diff --staged` for actual changes.
- Repo-specific commit conventions if documented.
- GitLab issue or MR references that should be included in the subject/body
  (for example `Closes #123` or `Related to !456`) when the repo expects them.

## Steps

1. Read session history to identify scope, intent, and rationale.
2. Inspect the working tree and staged changes (`git status`, `git diff`,
   `git diff --staged`).
3. Stage intended changes, including new files (`git add -A`) after confirming
   scope.
4. Sanity-check newly added files; if anything looks random or likely ignored
   (build artifacts, logs, temp files), flag it to the user before committing.
5. If staging is incomplete or includes unrelated files, fix the index or ask
   for confirmation.
6. Choose a conventional type and optional scope that match the change (e.g.,
   `feat(scope): ...`, `fix(scope): ...`, `refactor(scope): ...`).
7. Write a subject line in imperative mood, <= 72 characters, no trailing
   period.
8. Write a body that includes:
   - Summary of key changes (what changed).
   - Rationale and trade-offs (why it changed).
   - Tests or validation run (or explicit note if not run).
   - GitLab issue/MR references if they are part of the task context or local
     convention.
9. Add AI trailers with `git commit --trailer` when available. If `--trailer`
   is unavailable, place the same trailer lines manually at the very end of the
   commit message.
10. Wrap body lines at 72 characters.
11. Create the commit message with a here-doc or temp file and use
    `git commit -F <file>` so newlines are literal (avoid `-m` with `\n`). When
    using a message file, pass any AI trailers with `git commit -F <file>
    --trailer ...`.
12. Commit only when the message matches the staged changes: if the staged diff
    includes unrelated files or the message describes work that isn't staged,
    fix the index or revise the message before committing.

## Trailer Format

Always include:

```
AI-Assisted: true
```

Include `AI-Agent` only when the coding harness explicitly provides the agent
identity. Do not guess.

```
AI-Agent: codex
```

Include `AI-Model` only when the coding harness explicitly provides the model
identity. Do not guess. Prefer canonical provider/model IDs over marketing
names.

```
AI-Model: openai/gpt-5
```

If the agent or model identity is not available from the harness, omit that
trailer rather than inventing a value.

Prefer this form when committing:

```sh
git commit -F "$message_file" \
  --trailer "AI-Assisted=true" \
  --trailer "AI-Agent=codex" \
  --trailer "AI-Model=openai/gpt-5.5"
```

Omit `AI-Agent` or `AI-Model` from the command if the harness does not
explicitly provide those values.

Rules:

- Keep the trailers at the very end of the commit message.
- Prefer `git commit --trailer` over writing trailer lines manually.
- Use exactly `AI-Assisted`, `AI-Agent`, and `AI-Model` as trailer keys.
- Do not add `Co-authored-by` unless the user explicitly asks for it.
- If tests or checks were run, mention the result in the commit body and after
  committing, not in the trailers.

## Output

- A single commit created with `git commit` whose message reflects the session.

## Template

Type and scope are examples only; adjust to fit the repo and changes.

```
<type>(<scope>): <short summary>

Summary:
- <what changed>
- <what changed>

Rationale:
- <why>
- <why>

Tests:
- <command or "not run (reason)">

AI-Assisted: true
AI-Agent: codex
AI-Model: openai/gpt-5.5
```
