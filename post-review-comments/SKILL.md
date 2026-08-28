---
name: post-review-comments
description: When the user wants to comment review findings in a Gitlab MR/ Github PR
---

# Post Review Comments

Publish findings that a review already produced. Each finding **anchors** to the diff line it is about and lands as an inline comment. A finding that belongs to no single line is an **orphan**, and orphans are rolled up into one top-level comment.

Post only findings the review produced. Do not generate new ones here.

## 1. Pin the target

Resolve host, change-request number, and the SHA the findings were reviewed against.

```sh
git remote get-url origin                                   # host
gh pr view <n> --json number,headRefOid,url                 # GitHub
glab api projects/:fullpath/merge_requests/<iid>            # GitLab: .sha and .diff_refs
```

GitLab's `diff_refs` carries the `base_sha`, `start_sha`, and `head_sha` every inline comment needs.

When the current head is past the reviewed SHA, stop and report it. Anchors computed on a stale diff land on unrelated lines.

Then list the inline comments you already authored on this change request and drop any finding already posted at the same path and line, so a second review pass adds comments instead of duplicating them.

```sh
gh api repos/{owner}/{repo}/pulls/<n>/comments --jq '.[] | "\(.path):\(.line) \(.user.login)"'
glab api projects/:fullpath/merge_requests/<iid>/discussions --paginate \
  --jq '.[].notes[] | select(.position) | "\(.position.new_path):\(.position.new_line) \(.author.username)"'
```

## 2. Anchor every finding

Read the diff (`gh pr diff <n>`, `glab mr diff <iid>`) and give each finding a target:

- line the diff **adds**: new-side path and line (`side: RIGHT`, or `new_path` + `new_line`)
- line the diff **removes**: old-side path and line (`side: LEFT`, or `old_path` + `old_line`)
- unchanged context line inside a hunk: both sides, since GitLab derives its line code from the pair
- a whole file: file-level comment
- anything spanning files, or about code the diff does not touch: **orphan**

A line outside the diff cannot carry a comment. Either move the anchor to the nearest diff line that shows the problem, or make the finding an orphan and name the real location in its text.

Anchoring is done when every finding carries a path with a side and line, a file-level target, or an orphan label.

## 3. Write each comment

Keep a comment to the severity label from the review, one sentence naming the defect, the failure scenario, and the proportionate fix. The anchor already states the location, so leave it out of the prose.

Attach a suggestion block when the fix is a small literal edit:

- GitHub: a ` ```suggestion ` block replaces the anchored lines.
- GitLab: a ` ```suggestion:-0+0 ` block does the same, where the offsets extend the replaced range above and below the anchored line.

The orphan roll-up is one comment: a short list, each entry naming its location and its point.

## 4. Post

Both CLIs send `--field` values as flat strings, so pass the JSON body on stdin.

GitHub takes every inline comment plus the orphan roll-up in a single review:

```sh
gh api --method POST repos/{owner}/{repo}/pulls/<n>/reviews --input - <<'JSON'
{
  "commit_id": "<reviewed-head-sha>",
  "event": "COMMENT",
  "body": "<orphan roll-up, omitted when there are no orphans>",
  "comments": [
    { "path": "src/a.ts", "line": 42, "side": "RIGHT", "body": "..." },
    { "path": "src/b.ts", "start_line": 10, "line": 14, "side": "RIGHT", "body": "..." },
    { "path": "src/c.ts", "subject_type": "file", "body": "..." }
  ]
}
JSON
```

One unanchorable comment fails the whole review with a 422 that names the path. Drop that comment, repost the rest, and move the dropped finding into the roll-up.

GitLab takes one discussion per finding, then the roll-up as a plain note:

```sh
glab api projects/:fullpath/merge_requests/<iid>/discussions --method POST --input - <<'JSON'
{
  "body": "...",
  "position": {
    "position_type": "text",
    "base_sha": "<base_sha>", "start_sha": "<start_sha>", "head_sha": "<head_sha>",
    "old_path": "src/a.ts", "new_path": "src/a.ts",
    "new_line": 42
  }
}
JSON

glab mr note <iid> --message "<orphan roll-up>"
```

Send both paths every time, and set only the line fields the anchor calls for; they differ only for a renamed file. A file-level comment omits both line fields. A 400 naming `line_code` means the anchor does not match the diff, so recheck the side before retrying, and fall back to the roll-up when it keeps failing.

## 5. Verify

Refetch the comments with the step 1 commands and confirm every finding landed where it was anchored. Report the change-request URL, the count posted inline, the count in the roll-up, and any finding that failed to post along with why.
