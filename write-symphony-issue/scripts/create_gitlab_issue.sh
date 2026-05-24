#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s --title TITLE --body-file BODY.md [--repo group/project] [--label label]\n' "$0" >&2
}

title=""
body_file=""
repo=""
labels=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --title)
      title="${2:-}"
      shift 2
      ;;
    --body-file)
      body_file="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --label)
      labels+=("${2:-}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "$title" ] || [ -z "$body_file" ]; then
  usage
  exit 2
fi

if [ ! -f "$body_file" ]; then
  printf 'Body file does not exist: %s\n' "$body_file" >&2
  exit 2
fi

if ! command -v glab >/dev/null 2>&1; then
  printf 'glab CLI is required but was not found on PATH.\n' >&2
  exit 127
fi

cmd=(glab issue create --title "$title" --description-file "$body_file")

if [ -n "$repo" ]; then
  cmd+=(--repo "$repo")
fi

for label in "${labels[@]}"; do
  if [ -n "$label" ]; then
    cmd+=(--label "$label")
  fi
done

"${cmd[@]}"
