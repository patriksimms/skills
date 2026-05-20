#!/bin/bash
set -euo pipefail

GITLAB_REPO="${GITLAB_REPO:-}"
GITLAB_AGENT_LABEL="${GITLAB_AGENT_LABEL:-agent-task}"
GITLAB_PROJECT_LABEL="${GITLAB_PROJECT_LABEL:-}"
GITLAB_ISSUE_LIMIT="${GITLAB_ISSUE_LIMIT:-100}"
GITLAB_RETRY_ATTEMPTS="${GITLAB_RETRY_ATTEMPTS:-3}"
GITLAB_RETRY_DELAY_SECONDS="${GITLAB_RETRY_DELAY_SECONDS:-1}"
CODEX_BIN="${CODEX_BIN:-codex}"
CODEX_MODEL="${CODEX_MODEL:-}"
CODEX_REASONING_EFFORT="${CODEX_REASONING_EFFORT:-}"
CODEX_PROFILE="${CODEX_PROFILE:-}"
CODEX_SANDBOX="${CODEX_SANDBOX:-danger-full-access}"
CODEX_APPROVAL_POLICY="${CODEX_APPROVAL_POLICY:-never}"
COMPLETE_MARKER="<promise>COMPLETE</promise>"
tmpfile=""

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

cleanup_tmpfile() {
  if [ -n "${tmpfile}" ] && [ -f "${tmpfile}" ]; then
    rm -f "${tmpfile}"
  fi
}

trap cleanup_tmpfile EXIT

retry_glab() {
  local attempt=1
  local exit_code=0

  while true; do
    if "$@"; then
      return 0
    fi

    exit_code=$?
    if [ "$attempt" -ge "$GITLAB_RETRY_ATTEMPTS" ]; then
      return "$exit_code"
    fi

    echo "glab command failed (attempt ${attempt}/${GITLAB_RETRY_ATTEMPTS}): $*" >&2
    sleep "$GITLAB_RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done
}

codex_exec_args() {
  local output_file="$1"

  printf '%s\0' --ask-for-approval "$CODEX_APPROVAL_POLICY" \
    exec \
    -C "$(pwd)" \
    -s "$CODEX_SANDBOX" \
    -o "$output_file"

  if [ -n "$CODEX_MODEL" ]; then
    printf '%s\0' -m "$CODEX_MODEL"
  fi

  if [ -n "$CODEX_REASONING_EFFORT" ]; then
    printf '%s\0' -c "model_reasoning_effort=\"$CODEX_REASONING_EFFORT\""
  fi

  if [ -n "$CODEX_PROFILE" ]; then
    printf '%s\0' -p "$CODEX_PROFILE"
  fi
}

run_codex_exec() {
  local output_file="$1"
  local prompt="$2"
  local stream_output="$3"
  local args=()

  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < <(codex_exec_args "$output_file")

  if [ "$stream_output" = "true" ]; then
    "$CODEX_BIN" "${args[@]}" "$prompt"
  else
    "$CODEX_BIN" "${args[@]}" "$prompt" >/dev/null
  fi
}

gitlab_repo_args() {
  if [ -n "$GITLAB_REPO" ]; then
    printf '%s\0' -R "$GITLAB_REPO"
  fi
}

gitlab_issue_list() {
  local args=(issue list --label "$GITLAB_AGENT_LABEL" --per-page "$GITLAB_ISSUE_LIMIT" --output json)

  if [ -n "$GITLAB_PROJECT_LABEL" ]; then
    args+=(--label "$GITLAB_PROJECT_LABEL")
  fi

  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < <(gitlab_repo_args)

  retry_glab glab "${args[@]}"
}

gitlab_issue_close() {
  local issue_id="$1"
  local args=(issue close "$issue_id")

  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < <(gitlab_repo_args)

  retry_glab glab "${args[@]}"
}

get_candidate_issues() {
  printf '%s' "$1" | GITLAB_AGENT_LABEL="$GITLAB_AGENT_LABEL" GITLAB_PROJECT_LABEL="$GITLAB_PROJECT_LABEL" bun --eval '
    const data = JSON.parse(await Bun.stdin.text());
    const issues = Array.isArray(data) ? data : (data.results ?? data.nodes ?? []);
    const requiredLabels = [process.env.GITLAB_AGENT_LABEL, process.env.GITLAB_PROJECT_LABEL].filter(Boolean);
    const candidates = issues.filter((issue) => {
      const labels = (issue.labels ?? []).map((label) => typeof label === "string" ? label : label.name).filter(Boolean);
      const state = String(issue.state ?? issue.state_name ?? "").toLowerCase();
      const isOpen = !["closed", "merged"].includes(state);

      return isOpen && requiredLabels.every((label) => labels.includes(label));
    });

    process.stdout.write(JSON.stringify(candidates));
  '
}

get_issue_count() {
  printf '%s' "$1" | bun --eval 'const issues = JSON.parse(await Bun.stdin.text()); process.stdout.write(String(issues.length));'
}

get_issue_field() {
  local issue_json="$1"
  local field_name="$2"

  printf '%s' "$issue_json" | bun --eval "const issue = JSON.parse(await Bun.stdin.text()); process.stdout.write(String(issue[\"${field_name}\"] ?? \"\"));"
}

build_selection_payload() {
  local candidate_issues_json="$1"
  local open_issues_json="$2"

  printf '%s' "$candidate_issues_json" | OPEN_ISSUES_JSON="$open_issues_json" bun --eval '
    const candidates = JSON.parse(await Bun.stdin.text());
    const openIssuesData = JSON.parse(process.env.OPEN_ISSUES_JSON ?? "[]");
    const openIssues = Array.isArray(openIssuesData) ? openIssuesData : (openIssuesData.results ?? openIssuesData.nodes ?? []);
    const issueKey = (issue) => String(issue.iid ?? issue.i_i_d ?? issue.id ?? "").replace(/^#/, "");
    const openIssueIds = new Set(openIssues.map(issueKey).filter(Boolean));

    const extractBlockedBy = (description) => {
      const text = description ?? "";
      const sectionMatch = text.match(/## Blocked by\s*([\s\S]*?)(?=\n##\s|$)/i);
      if (!sectionMatch) {
        return [];
      }

      return Array.from(sectionMatch[1].matchAll(/#([0-9]+)/g), (match) => match[1]);
    };

    const summary = candidates.map((issue) => {
      const blockedBy = extractBlockedBy(issue.description);
      const unresolvedBlockers = blockedBy.filter((issueId) => openIssueIds.has(issueId));

      return {
        id: issueKey(issue),
        globalId: issue.id ?? "",
        iid: issue.iid ?? issue.i_i_d ?? "",
        title: issue.title ?? "",
        priority: issue.priority ?? null,
        state: issue.state ?? issue.state_name ?? "",
        labels: (issue.labels ?? []).map((label) => typeof label === "string" ? label : label.name).filter(Boolean),
        url: issue.web_url ?? issue.webUrl ?? issue.url ?? "",
        description: issue.description ?? "",
        blockedBy,
        unresolvedBlockers,
        ready: unresolvedBlockers.length === 0,
      };
    });

    const readyIssueIds = summary.filter((issue) => issue.ready).map((issue) => issue.id);
    process.stdout.write(
      JSON.stringify(
        {
          openIssueIds: Array.from(openIssueIds),
          readyIssueIds,
          issues: summary,
        },
        null,
        2,
      ),
    );
  '
}

build_repo_context() {
  local branch
  local status

  branch=$(git branch --show-current 2>/dev/null || true)
  status=$(git status --short 2>/dev/null || true)

  if [ -z "$branch" ]; then
    branch="detached"
  fi

  if [ -z "$status" ]; then
    status="clean"
  fi

  cat <<EOF
Current repo context:
- CWD: $(pwd)
- Branch: ${branch}
- Git status:
${status}
EOF
}

extract_selected_issue_id() {
  local selection_output="$1"
  local selection_payload="$2"

  printf '%s' "$selection_output" | SELECTION_PAYLOAD="$selection_payload" bun --eval '
    const payload = JSON.parse(process.env.SELECTION_PAYLOAD ?? "{}");
    const readyIssueIds = Array.isArray(payload.readyIssueIds) ? payload.readyIssueIds : [];
    const text = (await Bun.stdin.text()).trim();

    if (text === "NONE") {
      process.exit(0);
    }

    const match = text.match(/<issue_id>\s*([^<\s]+)\s*<\/issue_id>/i);
    if (!match) {
      console.error("Issue selector did not return an <issue_id> marker.");
      process.exit(1);
    }

    const selectedId = match[1].trim();
    if (!readyIssueIds.includes(selectedId)) {
      console.error(`Issue selector returned issue id that is not dependency-ready: ${selectedId}`);
      process.exit(1);
    }

    process.stdout.write(selectedId);
  '
}

get_issue_by_id() {
  local issues_json="$1"
  local issue_id="$2"

  printf '%s' "$issues_json" | ISSUE_ID="$issue_id" bun --eval '
    const issues = JSON.parse(await Bun.stdin.text());
    const issue = issues.find((item) => String(item.iid ?? item.i_i_d ?? item.id ?? "") === process.env.ISSUE_ID);
    if (issue) {
      process.stdout.write(JSON.stringify(issue));
    }
  '
}

select_next_issue() {
  local candidate_issues_json="$1"
  local open_issues_json="$2"
  local repo_context
  local selection_payload
  local selection_prompt
  local selection_output
  local selected_issue_id
  local ready_issue_count
  local selection_output_file

  repo_context=$(build_repo_context)
  selection_payload=$(build_selection_payload "$candidate_issues_json" "$open_issues_json")
  ready_issue_count=$(printf '%s' "$selection_payload" | bun --eval '
    const payload = JSON.parse(await Bun.stdin.text());
    process.stdout.write(String(Array.isArray(payload.readyIssueIds) ? payload.readyIssueIds.length : 0));
  ')

  if [ "$ready_issue_count" -eq 0 ]; then
    return 0
  fi

  if [ "$ready_issue_count" -eq 1 ]; then
    selected_issue_id=$(printf '%s' "$selection_payload" | bun --eval '
      const payload = JSON.parse(await Bun.stdin.text());
      process.stdout.write(String(payload.readyIssueIds?.[0] ?? ""));
    ')
    get_issue_by_id "$candidate_issues_json" "$selected_issue_id"
    return 0
  fi

  selection_prompt=$(cat <<EOF
Choose the single best next GitLab issue for this repository.

Rules:
1. Dependency analysis has already been computed from only the parsed "## Blocked by" section for each issue.
2. Ignore any other issue IDs elsewhere in the descriptions, such as parent PRD references.
3. Only choose an issue whose "ready" field is true and whose id is present in "readyIssueIds".
4. Prefer the issue that is the best fit for the current repo context and likely to make meaningful progress now.
5. Return exactly one of:
   - <issue_id>THE_ID</issue_id>
   - NONE
6. Do not return any explanation.

${repo_context}

GitLab selection data:
${selection_payload}
EOF
)

  selection_output_file=$(mktemp)
  run_codex_exec "$selection_output_file" "$selection_prompt" false
  selection_output=$(cat "$selection_output_file")
  rm -f "$selection_output_file"

  selected_issue_id=$(extract_selected_issue_id "$selection_output" "$selection_payload")
  if [ -z "$selected_issue_id" ]; then
    return 0
  fi

  get_issue_by_id "$candidate_issues_json" "$selected_issue_id"
}

for ((i=1; i<=$1; i++)); do
  echo "Iteration $i"
  echo "--------------------------------"

  open_issues=$(gitlab_issue_list)
  candidate_issues=$(get_candidate_issues "$open_issues")
  candidate_count=$(get_issue_count "$candidate_issues")
  if [ "$candidate_count" -eq 0 ]; then
    echo "No open GitLab issues found with label ${GITLAB_AGENT_LABEL}${GITLAB_PROJECT_LABEL:+ and label ${GITLAB_PROJECT_LABEL}}${GITLAB_REPO:+ in repo ${GITLAB_REPO}}."
    exit 0
  fi

  next_issue=$(select_next_issue "$candidate_issues" "$open_issues")
  if [ -z "$next_issue" ]; then
    echo "No dependency-ready GitLab issue selected from ${candidate_count} candidates."
    exit 0
  fi

  issue_id=$(get_issue_field "$next_issue" "iid")
  if [ -z "$issue_id" ]; then
    issue_id=$(get_issue_field "$next_issue" "id")
  fi
  issue_title=$(get_issue_field "$next_issue" "title")
  issue_description=$(get_issue_field "$next_issue" "description")
  issue_url=$(get_issue_field "$next_issue" "web_url")
  if [ -z "$issue_url" ]; then
    issue_url=$(get_issue_field "$next_issue" "webUrl")
  fi
  if [ -z "$issue_url" ]; then
    issue_url=$(get_issue_field "$next_issue" "url")
  fi

  prompt=$(cat <<EOF
Use the tdd-ralph skill.

Selected GitLab issue:
- ID: ${issue_id}
- Title: ${issue_title}
- URL: ${issue_url}
- Description:
${issue_description}

1. Work only on the selected GitLab issue above. Stay on the current branch for the whole task.
2. Check that the types check via bun run typecheck, lint via bun run lint, tests via bun run test.
3. Update the PRD with the work that was done if the PRD is affected by the task.
4. Append your progress to the progress.txt file.
Use this to leave a note for the next person working in the codebase.
5. Make a git commit for the task if you completed meaningful work.
6. Do not close the GitLab issue yourself; this loop will close it if you emit the completion marker.
ONLY WORK ON A SINGLE GITLAB ISSUE.
If the selected GitLab issue is complete at the end of your run, output ${COMPLETE_MARKER}. Otherwise do not output that marker.
EOF
)

  tmpfile=$(mktemp)
  run_codex_exec "$tmpfile" "$prompt" true
  result=$(cat "$tmpfile")

  if [[ "$result" == *"${COMPLETE_MARKER}"* ]]; then
    gitlab_issue_close "$issue_id"
    echo "Completed GitLab issue ${issue_id}."
  else
    echo "GitLab issue ${issue_id} was not marked complete; leaving it open."
  fi

  rm -f "$tmpfile"
  tmpfile=""
done
