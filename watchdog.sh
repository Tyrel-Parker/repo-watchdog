#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "Error: .env not found. Copy .env.example to .env and configure it." >&2
  exit 1
fi

source "$SCRIPT_DIR/.env"

: "${REPOS_DIR:?REPOS_DIR must be set in .env}"
: "${NTFY_URL:?NTFY_URL must be set in .env}"
: "${NTFY_TOPIC:?NTFY_TOPIC must be set in .env}"

report=""

for repo_dir in "$REPOS_DIR"/*/; do
  [ -d "$repo_dir/.git" ] || continue

  name=$(basename "$repo_dir")

  git -C "$repo_dir" remote get-url origin &>/dev/null || continue

  git -C "$repo_dir" fetch --all --quiet 2>/dev/null || true

  issues=()

  # Dirty working tree (staged, unstaged, or untracked files)
  if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]; then
    issues+=("uncommitted changes")
  fi

  # Ahead/behind origin
  tracking=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -n "$tracking" ]; then
    ahead=$(git -C "$repo_dir" rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)
    behind=$(git -C "$repo_dir" rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)
    [ "$ahead" -gt 0 ] && issues+=("$ahead unpushed commit(s)")
    [ "$behind" -gt 0 ] && issues+=("$behind unpulled commit(s) from origin")
  fi

  # If an upstream remote exists (fork), check divergence from upstream
  if git -C "$repo_dir" remote get-url upstream &>/dev/null; then
    upstream_branch=$(git -C "$repo_dir" symbolic-ref "refs/remotes/upstream/HEAD" 2>/dev/null \
      | sed 's|refs/remotes/upstream/||') || upstream_branch="main"
    fork_ahead=$(git -C "$repo_dir" rev-list --count "upstream/$upstream_branch..HEAD" 2>/dev/null || echo 0)
    fork_behind=$(git -C "$repo_dir" rev-list --count "HEAD..upstream/$upstream_branch" 2>/dev/null || echo 0)
    [ "$fork_ahead" -gt 0 ] && issues+=("$fork_ahead commit(s) to PR upstream")
    [ "$fork_behind" -gt 0 ] && issues+=("$fork_behind commit(s) behind upstream")
  fi

  if [ ${#issues[@]} -gt 0 ]; then
    issue_str=$(IFS=', '; echo "${issues[*]}")
    report+="• $name: $issue_str\n"
  fi
done

if [ -n "$report" ]; then
  body="$(printf "Repo status for %s:\n\n%b" "$(date '+%A, %B %d')" "$report")"

  curl_args=(
    -s
    -H "Title: Repo Watchdog"
    -H "Priority: low"
    -H "Tags: floppy_disk"
    -d "$body"
  )

  if [ -n "${NTFY_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: Bearer $NTFY_TOKEN")
  fi

  curl "${curl_args[@]}" "$NTFY_URL/$NTFY_TOPIC"
fi
