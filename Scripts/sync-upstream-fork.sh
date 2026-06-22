#!/usr/bin/env bash
set -euo pipefail

# Sync the HackXIt fork with winyunq/UnrealMotionGraphicsMCP while preserving local commits.
# Expected remotes:
#   origin   git@github.com:HackXIt/UnrealMotionGraphicsMCP.git
#   upstream https://github.com/winyunq/UnrealMotionGraphicsMCP.git
#
# Usage:
#   Scripts/sync-upstream-fork.sh          # rebase current branch onto upstream/main
#   Scripts/sync-upstream-fork.sh main     # rebase current branch onto upstream/main
#
# After a successful sync, review, then push:
#   git push origin HEAD:main

UPSTREAM_BRANCH="${1:-main}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/winyunq/UnrealMotionGraphicsMCP.git
else
  git remote set-url upstream https://github.com/winyunq/UnrealMotionGraphicsMCP.git
fi

git remote set-url origin git@github.com:HackXIt/UnrealMotionGraphicsMCP.git

git fetch upstream --prune
git fetch origin --prune || true

CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "error: detached HEAD; check out a branch before syncing" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "error: tracked working tree changes are present; commit or stash before syncing" >&2
  git status --short --untracked-files=no
  exit 1
fi

UNTRACKED="$(git ls-files --others --exclude-standard)"
if [[ -n "$UNTRACKED" ]]; then
  echo "warning: untracked files are present and will be left untouched:"
  printf '%s\n' "$UNTRACKED" | sed 's/^/  /'
fi

BACKUP="backup/${CURRENT_BRANCH}-before-upstream-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP"

echo "Rebasing $CURRENT_BRANCH onto upstream/$UPSTREAM_BRANCH (backup: $BACKUP)"
git rebase "upstream/$UPSTREAM_BRANCH"

python - <<'PY'
import json
from pathlib import Path

plugin = Path('UmgMcp.uplugin')
json.loads(plugin.read_text(encoding='utf-8-sig'))
print(f'Validated {plugin} JSON')
PY

echo
printf 'Sync complete. Review with:\n  git log --oneline --decorate upstream/%s..HEAD\n  git diff --stat upstream/%s..HEAD\n\n' "$UPSTREAM_BRANCH" "$UPSTREAM_BRANCH"
echo "Push when ready: git push origin HEAD:$CURRENT_BRANCH"
