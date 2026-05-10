#!/bin/bash
set -euo pipefail

TODOIST_AGENT_LABEL="${TODOIST_AGENT_LABEL:-agent-task}"
TODOIST_PROJECT="${TODOIST_PROJECT:-}"
TODOIST_PROJECT_LABEL="${TODOIST_PROJECT_LABEL:-}"
TODOIST_TASK_LIMIT="${TODOIST_TASK_LIMIT:-250}"
TODOIST_RETRY_ATTEMPTS="${TODOIST_RETRY_ATTEMPTS:-3}"
TODOIST_RETRY_DELAY_SECONDS="${TODOIST_RETRY_DELAY_SECONDS:-1}"
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

retry_td() {
  local attempt=1
  local exit_code=0

  while true; do
    if "$@"; then
      return 0
    fi

    exit_code=$?
    if [ "$attempt" -ge "$TODOIST_RETRY_ATTEMPTS" ]; then
      return "$exit_code"
    fi

    echo "td command failed (attempt ${attempt}/${TODOIST_RETRY_ATTEMPTS}): $*" >&2
    sleep "$TODOIST_RETRY_DELAY_SECONDS"
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

todoist_task_list() {
  local args=(task list --label "$TODOIST_AGENT_LABEL" --limit "$TODOIST_TASK_LIMIT" --json --full --no-spinner)

  if [ -n "$TODOIST_PROJECT" ]; then
    args+=(--project "$TODOIST_PROJECT")
  fi

  retry_td td "${args[@]}"
}

get_candidate_tasks() {
  printf '%s' "$1" | TODOIST_AGENT_LABEL="$TODOIST_AGENT_LABEL" TODOIST_PROJECT_LABEL="$TODOIST_PROJECT_LABEL" bun --eval '
    const data = JSON.parse(await Bun.stdin.text());
    const tasks = Array.isArray(data) ? data : (data.results ?? data.nodes ?? []);
    const requiredLabels = [process.env.TODOIST_AGENT_LABEL, process.env.TODOIST_PROJECT_LABEL].filter(Boolean);
    const candidates = tasks.filter((task) => {
      const labels = task.labels ?? [];
      const isOpen = !task.checked && !task.completedAt && !task.isDeleted;

      return isOpen && requiredLabels.every((label) => labels.includes(label));
    });

    process.stdout.write(JSON.stringify(candidates));
  '
}

get_task_count() {
  printf '%s' "$1" | bun --eval 'const tasks = JSON.parse(await Bun.stdin.text()); process.stdout.write(String(tasks.length));'
}

get_task_field() {
  local task_json="$1"
  local field_name="$2"

  printf '%s' "$task_json" | bun --eval "const task = JSON.parse(await Bun.stdin.text()); process.stdout.write(String(task[\"${field_name}\"] ?? \"\"));"
}

build_selection_payload() {
  local candidate_tasks_json="$1"
  local open_tasks_json="$2"

  printf '%s' "$candidate_tasks_json" | OPEN_TASKS_JSON="$open_tasks_json" bun --eval '
    const candidates = JSON.parse(await Bun.stdin.text());
    const openTasksData = JSON.parse(process.env.OPEN_TASKS_JSON ?? "[]");
    const openTasks = Array.isArray(openTasksData) ? openTasksData : (openTasksData.results ?? openTasksData.nodes ?? []);
    const openTaskIds = new Set(
      openTasks.flatMap((task) => [task.id].filter(Boolean)),
    );

    const extractBlockedBy = (description) => {
      const text = description ?? "";
      const sectionMatch = text.match(/## Blocked by\s*([\s\S]*?)(?=\n##\s|$)/i);
      if (!sectionMatch) {
        return [];
      }

      return Array.from(sectionMatch[1].matchAll(/#([A-Za-z0-9_-]+)/g), (match) => match[1]);
    };

    const summary = candidates.map((task) => {
      const blockedBy = extractBlockedBy(task.description);
      const unresolvedBlockers = blockedBy.filter((taskId) => openTaskIds.has(taskId));

      return {
        id: task.id,
        title: task.content ?? "",
        priority: task.priority ?? null,
        labels: task.labels ?? [],
        url: task.url ?? "",
        description: task.description ?? "",
        blockedBy,
        unresolvedBlockers,
        ready: unresolvedBlockers.length === 0,
      };
    });

    const readyTaskIds = summary.filter((task) => task.ready).map((task) => task.id);
    process.stdout.write(
      JSON.stringify(
        {
          openTaskIds: Array.from(openTaskIds),
          readyTaskIds,
          tasks: summary,
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

extract_selected_task_id() {
  local selection_output="$1"
  local selection_payload="$2"

  printf '%s' "$selection_output" | SELECTION_PAYLOAD="$selection_payload" bun --eval '
    const payload = JSON.parse(process.env.SELECTION_PAYLOAD ?? "{}");
    const readyTaskIds = Array.isArray(payload.readyTaskIds) ? payload.readyTaskIds : [];
    const text = (await Bun.stdin.text()).trim();

    if (text === "NONE") {
      process.exit(0);
    }

    const match = text.match(/<task_id>\s*([^<\s]+)\s*<\/task_id>/i);
    if (!match) {
      console.error("Task selector did not return a <task_id> marker.");
      process.exit(1);
    }

    const selectedId = match[1].trim();
    if (!readyTaskIds.includes(selectedId)) {
      console.error(`Task selector returned task id that is not dependency-ready: ${selectedId}`);
      process.exit(1);
    }

    process.stdout.write(selectedId);
  '
}

get_task_by_id() {
  local tasks_json="$1"
  local task_id="$2"

  printf '%s' "$tasks_json" | TASK_ID="$task_id" bun --eval '
    const tasks = JSON.parse(await Bun.stdin.text());
    const task = tasks.find((item) => item.id === process.env.TASK_ID);
    if (task) {
      process.stdout.write(JSON.stringify(task));
    }
  '
}

select_next_task() {
  local candidate_tasks_json="$1"
  local open_tasks_json="$2"
  local repo_context
  local selection_payload
  local selection_prompt
  local selection_output
  local selected_task_id
  local ready_task_count
  local selection_output_file

  repo_context=$(build_repo_context)
  selection_payload=$(build_selection_payload "$candidate_tasks_json" "$open_tasks_json")
  ready_task_count=$(printf '%s' "$selection_payload" | bun --eval '
    const payload = JSON.parse(await Bun.stdin.text());
    process.stdout.write(String(Array.isArray(payload.readyTaskIds) ? payload.readyTaskIds.length : 0));
  ')

  if [ "$ready_task_count" -eq 0 ]; then
    return 0
  fi

  if [ "$ready_task_count" -eq 1 ]; then
    selected_task_id=$(printf '%s' "$selection_payload" | bun --eval '
      const payload = JSON.parse(await Bun.stdin.text());
      process.stdout.write(String(payload.readyTaskIds?.[0] ?? ""));
    ')
    get_task_by_id "$candidate_tasks_json" "$selected_task_id"
    return 0
  fi

  selection_prompt=$(cat <<EOF
Choose the single best next Todoist task for this repository.

Rules:
1. Dependency analysis has already been computed from only the parsed "## Blocked by" section for each task.
2. Ignore any other task IDs elsewhere in the descriptions, such as parent PRD references.
3. Only choose a task whose "ready" field is true and whose id is present in "readyTaskIds".
4. Prefer the task that is the best fit for the current repo context and likely to make meaningful progress now.
5. Return exactly one of:
   - <task_id>THE_ID</task_id>
   - NONE
6. Do not return any explanation.

${repo_context}

Todoist selection data:
${selection_payload}
EOF
)

  selection_output_file=$(mktemp)
  run_codex_exec "$selection_output_file" "$selection_prompt" false
  selection_output=$(cat "$selection_output_file")
  rm -f "$selection_output_file"

  selected_task_id=$(extract_selected_task_id "$selection_output" "$selection_payload")
  if [ -z "$selected_task_id" ]; then
    return 0
  fi

  get_task_by_id "$candidate_tasks_json" "$selected_task_id"
}

for ((i=1; i<=$1; i++)); do
  echo "Iteration $i"
  echo "--------------------------------"

  open_tasks=$(todoist_task_list)
  candidate_tasks=$(get_candidate_tasks "$open_tasks")
  candidate_count=$(get_task_count "$candidate_tasks")
  if [ "$candidate_count" -eq 0 ]; then
    echo "No open Todoist tasks found with label ${TODOIST_AGENT_LABEL}${TODOIST_PROJECT_LABEL:+ and label ${TODOIST_PROJECT_LABEL}}${TODOIST_PROJECT:+ in project ${TODOIST_PROJECT}}."
    exit 0
  fi

  next_task=$(select_next_task "$candidate_tasks" "$open_tasks")
  if [ -z "$next_task" ]; then
    echo "No dependency-ready Todoist task selected from ${candidate_count} candidates."
    exit 0
  fi

  task_id=$(get_task_field "$next_task" "id")
  task_title=$(get_task_field "$next_task" "content")
  task_description=$(get_task_field "$next_task" "description")
  task_url=$(get_task_field "$next_task" "url")

  prompt=$(cat <<EOF
Use the tdd-ralph skill.

Selected Todoist task:
- ID: ${task_id}
- Title: ${task_title}
- URL: ${task_url}
- Description:
${task_description}

1. Work only on the selected Todoist task above. Stay on the current branch for the whole task.
2. Check that the types check via bun run typecheck, lint via bun run lint, tests via bun run test.
3. Update the PRD with the work that was done if the PRD is affected by the task.
4. Append your progress to the progress.txt file.
Use this to leave a note for the next person working in the codebase.
5. Make a git commit for the task if you completed meaningful work.
6. Do not mark the Todoist task complete yourself; this loop will complete the Todoist task if you emit the completion marker.
ONLY WORK ON A SINGLE TODOIST TASK.
If the selected Todoist task is complete at the end of your run, output ${COMPLETE_MARKER}. Otherwise do not output that marker.
EOF
)

  tmpfile=$(mktemp)
  run_codex_exec "$tmpfile" "$prompt" true
  result=$(cat "$tmpfile")

  if [[ "$result" == *"${COMPLETE_MARKER}"* ]]; then
    retry_td td task complete "$task_id" --no-spinner
    echo "Completed Todoist task ${task_id}."
  else
    echo "Todoist task ${task_id} was not marked complete; leaving it open."
  fi

  rm -f "$tmpfile"
  tmpfile=""
done
