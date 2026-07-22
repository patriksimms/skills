# Out-of-Scope Knowledge Base

Read this file when checking whether an enhancement was previously rejected or when the maintainer approves closing an enhancement as `wontfix`.

The `.out-of-scope/` directory stores durable records of rejected enhancement concepts. It preserves the reasoning behind decisions and helps identify future requests that would otherwise reopen the same discussion.

Use one Markdown file per concept, not per GitLab issue or merge request. Group multiple requests for the same concept in one record.

```text
.out-of-scope/
├── dark-mode.md
├── graphql-api.md
└── plugin-system.md
```

## Check prior decisions

During context gathering:

1. Read every `.out-of-scope/*.md` file when the directory exists.
2. Compare concepts, not only keywords. “Night theme” may match a record named `dark-mode.md`.
3. Surface a likely match and summarize its reasoning.
4. Ask whether the maintainer wants to confirm, reconsider, or reject the match.

If confirmed, append the current GitLab issue or MR link to the existing record and close the item using the approved triage outcome.

If reconsidered, update or remove the record only with maintainer approval, then return the item to normal triage. Historical issues do not need to be reopened automatically.

## Record a rejection

Write or update an out-of-scope record only when all of these are true:

- the request is an enhancement, not a bug
- the maintainer explicitly rejects it
- the reason is a durable product, architectural, or strategic decision

Do not write a record when:

- the behavior is already implemented
- the request is merely deferred
- current staffing or schedule is the only reason
- the report is a bug

## File format

Name the file after the concept in short kebab-case. Write enough context that a future maintainer can understand the decision without reopening the linked discussion.

```markdown
# Concept name

State the decision in one direct sentence.

## Why this is out of scope

Explain the product boundary, architectural constraint, or strategic reasoning. Prefer durable reasoning over temporary circumstances. Include small examples when they clarify the boundary.

## Prior requests

- [GitLab issue #42](https://gitlab.example/group/project/-/issues/42) — short title
- [GitLab MR !87](https://gitlab.example/group/project/-/merge_requests/87) — short title
```

## Apply the decision

After the maintainer approves the rejection:

1. Check for an existing concept record.
2. Append the item link when a matching record exists; otherwise create one.
3. Post a GitLab comment that explains the decision and links to the record.
4. Apply the `enhancement` and `wontfix` roles.
5. Close the issue or MR.

Preserve unrelated working-tree changes when editing `.out-of-scope/`. Do not commit, push, or open an MR unless the user asks for those actions.
