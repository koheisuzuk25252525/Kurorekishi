#!/bin/bash
# Fetch committed updates only; preserve local changes and never force/reset.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
mkdir -p .mac-sync
if ! mkdir .mac-sync/lock 2>/dev/null; then
  echo 'Another sync is running (or stale .mac-sync/lock exists).'
  exit 0
fi
trap 'rmdir .mac-sync/lock' EXIT
if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  echo 'Skipped: commit or stash local changes before automatic sync.'
  exit 0
fi
branch="$(git symbolic-ref --quiet --short HEAD)" || { echo 'Skipped: detached HEAD.'; exit 0; }
if [[ "$branch" != main ]]; then
  echo 'Skipped: automatic sync is restricted to main.'
  exit 0
fi
# Do not hang on an authentication prompt in the background.
export GIT_TERMINAL_PROMPT=0
git fetch origin main
if ! git merge-base --is-ancestor HEAD origin/main; then
  echo 'Skipped: local main has diverged. Resolve manually; no changes made.'
  exit 0
fi
git merge --ff-only origin/main
