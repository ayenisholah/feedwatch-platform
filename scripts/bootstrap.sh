#!/usr/bin/env bash
# Sets up the Feedwatch repos side by side in this folder.
# Clones a repo from GitHub when it's missing, then installs its git hooks.
set -euo pipefail

OWNER="${FEEDWATCH_OWNER:-ayenisholah}"
REPOS=(feedwatch-platform feedwatch-poller feedwatch-api feedwatch-web)
cd "${FEEDWATCH_HOME:-$(dirname "$0")}"   # run from the folder that holds the repos

for repo in "${REPOS[@]}"; do
  if [ -d "$repo/.git" ]; then
    echo "ok      $repo (already here)"
  else
    echo "clone   $repo"
    gh repo clone "$OWNER/$repo" "$repo"
  fi
  if command -v lefthook >/dev/null 2>&1; then
    (cd "$repo" && lefthook install >/dev/null)
  elif [ -f "$repo/package.json" ]; then
    (cd "$repo" && npm install --no-audit --no-fund >/dev/null)   # prepare script installs lefthook
  else
    echo "        lefthook not installed: hooks skipped for $repo (npm i -g lefthook)"
  fi
done

echo
echo "Next: read feedwatch-platform/docs/PROGRESS.md"
