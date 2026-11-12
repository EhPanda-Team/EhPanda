#!/usr/bin/env bash
#
# Fails unless the "Test" workflow (.github/workflows/test.yml) passed on exactly <sha>. A release does not run the
# test suite again; it asks for the verdict of the run the push of that commit already started.
#
# Usage: require-passing-tests.sh <sha> [--start-grace SECONDS]
#
# The runs are read with `gh api repos/<repo>/actions/workflows/test.yml/runs?head_sha=<sha>`; the repository is
# $GITHUB_REPOSITORY and `gh` needs $GH_TOKEN with `actions: read`.
#
# Which runs count: those of test.yml whose head_sha is <sha> itself, started by a `push` or by a manual
# `workflow_dispatch` (the way to test a commit whose message says [skip test]). A run of another commit, or one
# started by a pull request (its commit is a merge ref, not <sha>), is never taken for it.
#
# The newest run decides (a re-run is the same run's newer attempt, and the API shows the newest attempt):
#   queued, in progress, waiting, ...  wait: poll every $REQUIRE_TESTS_POLL_SECONDS (default 30) until it completes,
#                                      for at most $REQUIRE_TESTS_TIMEOUT_SECONDS (default 5400, 90 minutes);
#   completed with `success`           pass;
#   anything else (`failure`, `cancelled`, `skipped`, `timed_out`, `neutral`, ...) fail, with a link to the run.
# No run at all fails, because test.yml skips a commit whose message says [skip test]. --start-grace gives a push that
# has only just happened that many seconds for its run to appear (a release started by the merge of a pull request
# races the push of the merge commit); it is 0 by default.

set -euo pipefail

sha="${1:-}"
repo="${GITHUB_REPOSITORY:-}"
workflow="test.yml"
grace=0
poll="${REQUIRE_TESTS_POLL_SECONDS:-30}"
timeout="${REQUIRE_TESTS_TIMEOUT_SECONDS:-5400}"
shift $(( $# > 1 ? 1 : $# ))
while (( $# > 0 )); do
  case "$1" in
    --start-grace)
      grace="${2:-}"
      if [[ ! "$grace" =~ ^[0-9]+$ ]]; then
        echo "::error::--start-grace needs a number of seconds."
        exit 1
      fi
      shift
      ;;
    *)
      echo "::error::Unknown option '$1'."
      exit 1
      ;;
  esac
  shift
done

if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error::'$sha' is not a full commit SHA."
  exit 1
fi
if [[ -z "$repo" ]]; then
  echo "::error::GITHUB_REPOSITORY is not set."
  exit 1
fi
if [[ ! "$poll" =~ ^[0-9]+$ || ! "$timeout" =~ ^[0-9]+$ ]]; then
  echo "::error::REQUIRE_TESTS_POLL_SECONDS and REQUIRE_TESTS_TIMEOUT_SECONDS must be numbers of seconds."
  exit 1
fi

actions_url="https://github.com/$repo/actions/workflows/$workflow"
started=$SECONDS
api_failures=0
announced=""

while true; do
  elapsed=$(( SECONDS - started ))
  if ! response="$(gh api --paginate "repos/$repo/actions/workflows/$workflow/runs?head_sha=$sha&per_page=100" 2>&1)"; then
    api_failures=$(( api_failures + 1 ))
    echo "::warning::Could not read the runs of $workflow ($api_failures): $response"
    if (( api_failures >= 5 )); then
      echo "::error::Could not read the runs of $workflow on commit $sha, so its tests cannot be confirmed."
      exit 1
    fi
    sleep "$poll"
    continue
  fi
  api_failures=0

  # --paginate prints one JSON document per page, so they are read together. Newest first; the sha is checked again
  # here whatever the query returned.
  if ! newest="$(jq -rs --arg sha "$sha" '
    [.[].workflow_runs[]?
     | select(.head_sha == $sha and (.event == "push" or .event == "workflow_dispatch"))]
    | sort_by(.run_started_at // .created_at) | reverse
    | if length == 0 then "none"
      else .[0] | [.id, .event, .status, (.conclusion // ""), .html_url, (.run_attempt // 1)] | map(tostring) | join("|")
      end' <<< "$response")"; then
    echo "::error::Could not read the runs of $workflow on commit $sha."
    exit 1
  fi

  if [[ "$newest" == "none" ]]; then
    if (( elapsed < grace )); then
      echo "No $workflow run for commit $sha yet; waiting for the push to start it."
      sleep "$poll"
      continue
    fi
    echo "::error::The Test workflow has no push or manual run on commit $sha, so its tests did not run. A commit whose message says [skip test] is not tested: run Test by hand on it ($actions_url), then release."
    exit 1
  fi

  IFS="|" read -r _ event status conclusion url attempt <<< "$newest"
  if [[ "$status" != "completed" ]]; then
    if (( elapsed >= timeout )); then
      echo "::error::The Test run $url ($event, attempt $attempt) on commit $sha is still '$status' after $elapsed s; gave up waiting."
      exit 1
    fi
    if [[ "$announced" != "$status" ]]; then
      echo "The Test run $url ($event, attempt $attempt) on commit $sha is '$status'; waiting for it to finish (checking every $poll s, for at most $timeout s)."
      announced="$status"
    fi
    sleep "$poll"
    continue
  fi

  if [[ "$conclusion" == "success" ]]; then
    echo "The Test run $url ($event, attempt $attempt) passed on commit $sha."
    exit 0
  fi
  echo "::error::The Test run $url ($event, attempt $attempt) on commit $sha concluded '${conclusion:-none}', not 'success'. Fix the tests or re-run them, then release."
  exit 1
done
