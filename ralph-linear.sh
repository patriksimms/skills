#!/bin/bash
set -euo pipefail

LINEAR_TEAM_KEY="${LINEAR_TEAM_KEY:-EE}"
LINEAR_AGENT_LABEL="${LINEAR_AGENT_LABEL:-agent-task}"
LINEAR_PROJECT_LABEL="${LINEAR_PROJECT_LABEL:-xxx}"
LINEAR_DONE_STATE="${LINEAR_DONE_STATE:-Done}"
LINEAR_ISSUE_LIMIT="${LINEAR_ISSUE_LIMIT:-250}"
LINEAR_RETRY_ATTEMPTS="${LINEAR_RETRY_ATTEMPTS:-3}"
LINEAR_RETRY_DELAY_SECONDS="${LINEAR_RETRY_DELAY_SECONDS:-1}"
COMPLETE_MARKER="<promise>COMPLETE</promise>"
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
final_result='select(.type == "result").result // empty'
assistant_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty'
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

retry_linctl() {
  local attempt=1
  local exit_code=0

  while true; do
    if "$@"; then
      return 0
    fi

    exit_code=$?
    if [ "$attempt" -ge "$LINEAR_RETRY_ATTEMPTS" ]; then
      return "$exit_code"
    fi

    echo "linctl command failed (attempt ${attempt}/${LINEAR_RETRY_ATTEMPTS}): $*" >&2
    sleep "$LINEAR_RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done
}

linear_issue_list() {
  retry_linctl linctl issue list \
    --team "$LINEAR_TEAM_KEY" \
    --newer-than all_time \
    --limit "$LINEAR_ISSUE_LIMIT" \
    --json
}

get_candidate_issues() {
  printf '%s' "$1" | LINEAR_AGENT_LABEL="$LINEAR_AGENT_LABEL" LINEAR_PROJECT_LABEL="$LINEAR_PROJECT_LABEL" bun --eval '
    const data = JSON.parse(await Bun.stdin.text());
    const issues = Array.isArray(data) ? data : (data.results ?? data.nodes ?? []);
    const requiredLabels = [process.env.LINEAR_AGENT_LABEL, process.env.LINEAR_PROJECT_LABEL];
    const candidates = issues.filter((issue) => {
      const labels = issue.labels?.nodes?.map((label) => label.name) ?? [];
      const isOpen =
        !issue.completedAt &&
        !issue.canceledAt &&
        !issue.archivedAt &&
        !["completed", "canceled"].includes(issue.state?.type ?? "");

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
    const openIssueIds = new Set(
      openIssues.flatMap((issue) => [issue.id, issue.identifier].filter(Boolean)),
    );

    const extractBlockedBy = (description) => {
      const text = description ?? "";
      const sectionMatch = text.match(/## Blocked by\s*([\s\S]*?)(?=\n##\s|$)/i);
      if (!sectionMatch) {
        return [];
      }

      return Array.from(sectionMatch[1].matchAll(/#([A-Za-z0-9_-]+)/g), (match) => match[1]);
    };

    const summary = candidates.map((issue) => {
      const blockedBy = extractBlockedBy(issue.description);
      const unresolvedBlockers = blockedBy.filter((issueId) => openIssueIds.has(issueId));

      return {
        id: issue.identifier,
        uuid: issue.id,
        title: issue.title ?? "",
        priority: issue.priority ?? null,
        priorityLabel: issue.priorityLabel ?? "",
        state: issue.state?.name ?? "",
        labels: issue.labels?.nodes?.map((label) => label.name) ?? [],
        url: issue.url ?? "",
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
    const issue = issues.find((item) => item.identifier === process.env.ISSUE_ID || item.id === process.env.ISSUE_ID);
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
Choose the single best next Linear issue for this repository.

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

Linear selection data:
${selection_payload}
EOF
)

  selection_output=$(claude \
    --print \
    --permission-mode bypassPermissions \
    "$selection_prompt")

  selected_issue_id=$(extract_selected_issue_id "$selection_output" "$selection_payload")
  if [ -z "$selected_issue_id" ]; then
    return 0
  fi

  get_issue_by_id "$candidate_issues_json" "$selected_issue_id"
}

for ((i=1; i<=$1; i++)); do
  echo "Iteration $i"
  echo "--------------------------------"

  open_issues=$(linear_issue_list)
  candidate_issues=$(get_candidate_issues "$open_issues")
  candidate_count=$(get_issue_count "$candidate_issues")
  if [ "$candidate_count" -eq 0 ]; then
    echo "No open Linear issues found for team ${LINEAR_TEAM_KEY} with labels ${LINEAR_AGENT_LABEL} and ${LINEAR_PROJECT_LABEL}."
    exit 0
  fi

  next_issue=$(select_next_issue "$candidate_issues" "$open_issues")
  if [ -z "$next_issue" ]; then
    echo "No dependency-ready Linear issue selected from ${candidate_count} candidates."
    exit 0
  fi

  issue_id=$(get_issue_field "$next_issue" "identifier")
  issue_title=$(get_issue_field "$next_issue" "title")
  issue_description=$(get_issue_field "$next_issue" "description")
  issue_url=$(get_issue_field "$next_issue" "url")

  prompt=$(cat <<EOF
Use the tdd-ralph skill.

Selected Linear issue:
- ID: ${issue_id}
- Title: ${issue_title}
- URL: ${issue_url}
- Description:
${issue_description}

1. Work only on the selected Linear issue above. Stay on the current branch for the whole task.
2. Check that the types check via bun run typecheck, lint via bun run lint, tests via bun run test.
3. Update the PRD with the work that was done if the PRD is affected by the task.
4. Append your progress to the progress.txt file.
Use this to leave a note for the next person working in the codebase.
5. Make a git commit for the task if you completed meaningful work.
6. Do not mark the Linear issue complete yourself; this loop will update Linear if you emit the completion marker.
ONLY WORK ON A SINGLE LINEAR ISSUE.
If the selected Linear issue is complete at the end of your run, output ${COMPLETE_MARKER}. Otherwise do not output that marker.
EOF
)

  tmpfile=$(mktemp)
  claude \
    --verbose \
    --print \
    --output-format stream-json \
    --permission-mode bypassPermissions \
    "$prompt" \
    | grep --line-buffered '^{' \
    | tee "$tmpfile" \
    | jq --unbuffered -rj "$stream_text"

  result=$(jq -r "($final_result), ($assistant_text)" "$tmpfile")

  if [[ "$result" == *"${COMPLETE_MARKER}"* ]]; then
    retry_linctl linctl issue update "$issue_id" --state "$LINEAR_DONE_STATE"
    echo "Completed Linear issue ${issue_id}."
  else
    echo "Linear issue ${issue_id} was not marked complete; leaving it open."
  fi

  rm -f "$tmpfile"
  tmpfile=""
done
