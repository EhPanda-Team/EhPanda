#!/usr/bin/env bash
#
# Fails unless the screenshot check (Phase 19's snapshot-gate.yml) concluded `success` on <sha>.
#
# Usage: require-snapshot-gate.sh <sha> <check name>
#
# The check runs of the commit are read with `gh api repos/<repo>/commits/<sha>/check-runs`; the repository is
# $GITHUB_REPOSITORY and `gh` needs $GH_TOKEN with `checks: read`. Only runs of GitHub Actions count, so a
# same-named check from another app cannot stand in for it. The release reads the verdict and never runs the gate
# itself (it takes hours).
#
# Passes only when every such run is completed with the conclusion `success`. Anything else stops the release:
# `neutral`, `skipped`, `cancelled`, `timed_out`, `failure`, `action_required` and `stale`, a run that has not
# finished (`queued`, `in_progress`) and no run at all. The message names the commit and the state.

set -euo pipefail

sha="${1:-}"
check="${2:-}"
repo="${GITHUB_REPOSITORY:-}"

if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error::'$sha' is not a full commit SHA."
  exit 1
fi
if [[ -z "$check" ]]; then
  echo "::error::No check name was given."
  exit 1
fi
if [[ -z "$repo" ]]; then
  echo "::error::GITHUB_REPOSITORY is not set."
  exit 1
fi

if ! runs="$(gh api --paginate "repos/$repo/commits/$sha/check-runs?per_page=100")"; then
  echo "::error::Could not read the check runs of commit $sha, so the '$check' check cannot be confirmed."
  exit 1
fi

# --paginate prints one JSON document per page, so they are read together.
if ! states="$(jq -rs --arg name "$check" '
  [.[].check_runs[]? | select(.name == $name and .app.slug == "github-actions")]
  | if length == 0 then "none"
    else .[] | if .status != "completed" then .status
               elif .conclusion == null then "completed with no conclusion"
               else .conclusion end
    end' <<< "$runs")"; then
  echo "::error::Could not read the check runs of commit $sha."
  exit 1
fi

if [[ "$states" == "none" ]]; then
  echo "::error::Commit $sha has no '$check' check run from GitHub Actions: the screenshot check did not run on it."
  exit 1
fi

failed=0
while IFS= read -r state; do
  if [[ "$state" != "success" ]]; then
    echo "::error::The '$check' check on commit $sha is '$state', not 'success'."
    failed=1
  fi
done <<< "$states"
(( failed == 0 )) || exit 1

echo "The '$check' check passed on commit $sha."
