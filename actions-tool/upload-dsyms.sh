#!/usr/bin/env bash
#
# Uploads a release archive's dSYMs to Sentry, so the crash reports of that release can be symbolicated.
#
# Usage:
#   upload-dsyms.sh <archive path>                 the CI form: uploads <archive path>/dSYMs
#   upload-dsyms.sh --reupload <dSYMs folder>      the form for a person: uploads that folder
#
# Environment, all required, full names only:
#   SENTRY_AUTH_TOKEN     an organization auth token that may upload debug files (a secret, read from the
#                         environment only: never a command-line flag, never printed)
#   SENTRY_ORGANIZATION   the organization slug
#   SENTRY_PROJECT        the project slug
#   SENTRY_URL            the organization's region URL, for example https://us.sentry.io
#
# The CI form never fails a release. Any problem, whatever its cause, prints exactly one line starting
# `::warning::` (the GitHub Actions form of a warning) that says what failed and that a person can rerun
# this script with --reupload on the run's dSYMs artifact, and then exits 0. The --reupload form does the same
# steps, but a failure prints one `error:` line to stderr and exits non-zero.
#
# sentry-cli is downloaded from its GitHub release, pinned by version, and its bytes are compared with the
# SHA-256 values below before it is made executable or run. A download is never piped into a shell, and
# nothing downloaded is evaluated. The tool's own output passes through `hide_token`, which hides the token's
# value if it ever appears in it.
#
# Compatible with the bash 3.2 that macOS ships.

# The sentry-cli release this script runs, and the SHA-256 of its two macOS assets. The values were read from
# the release page https://github.com/getsentry/sentry-cli/releases/tag/3.8.2 on 2026-11-23 and match the bytes
# of both downloads. Updating the version means reading the new values from the new release's page.
SENTRY_CLI_VERSION="3.8.2"
SENTRY_CLI_SHA256_ARM64="c80d92b6d34eb64fe7402f56cc7968fbb15aab1c763254ad428b55cc98ec7dcf"
SENTRY_CLI_SHA256_X86_64="084591ee1f0a43ba8696ccde30d4a79cd9a70d0fa294c5a10143a340f8f332ff"

mode="ci"
work_dir=""

# The one place a failure ends the script. The CI form warns and exits 0; the --reupload form errors and exits
# non-zero. Messages never contain the token.
fail() {
  if [[ "$mode" == "reupload" ]]; then
    echo "error: $1" >&2
    exit 1
  fi
  echo "::warning::Uploading the dSYMs to Sentry failed: $1. A person can rerun actions-tool/upload-dsyms.sh with --reupload on this run's dSYMs artifact."
  exit 0
}

# Copies stdin to stdout with every occurrence of the token's value replaced by [hidden]. Bash parameter
# expansion does the replacement, so the token never becomes the argument of a subprocess. A last line without
# a newline is kept as it is, and an empty token passes the text through unchanged.
hide_token() {
  local token="${SENTRY_AUTH_TOKEN:-}" line terminator
  while true; do
    if IFS= read -r line; then
      terminator=$'\n'
    elif [[ -n "$line" ]]; then
      terminator=""
    else
      break
    fi
    if [[ -n "$token" ]]; then
      line="${line//"$token"/[hidden]}"
    fi
    printf '%s%s' "$line" "$terminator"
  done
}

# Sets $dsyms_path from the arguments, and sets $mode.
parse_arguments() {
  if [[ "${1:-}" == "--reupload" ]]; then
    mode="reupload"
    shift
    [[ $# -eq 1 ]] || fail "usage: upload-dsyms.sh --reupload <dSYMs folder>"
    dsyms_path="$1"
  else
    [[ $# -eq 1 ]] || fail "usage: upload-dsyms.sh <archive path>"
    dsyms_path="$1/dSYMs"
  fi
}

check_inputs() {
  [[ -n "${SENTRY_AUTH_TOKEN:-}" ]] || fail "SENTRY_AUTH_TOKEN is not set"
  [[ -n "${SENTRY_ORGANIZATION:-}" ]] || fail "SENTRY_ORGANIZATION is not set"
  [[ -n "${SENTRY_PROJECT:-}" ]] || fail "SENTRY_PROJECT is not set"
  [[ -n "${SENTRY_URL:-}" ]] || fail "SENTRY_URL is not set"
  [[ -d "$dsyms_path" ]] || fail "there is no dSYMs folder at $dsyms_path"
  compgen -G "$dsyms_path/*.dSYM" > /dev/null || fail "the folder $dsyms_path holds no .dSYM"
}

# Sets $asset and $expected_sha256 for this Mac's architecture.
pick_asset() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "sentry-cli is pinned for macOS only"
  case "$(uname -m)" in
    arm64)
      asset="sentry-cli-Darwin-arm64"
      expected_sha256="$SENTRY_CLI_SHA256_ARM64"
      ;;
    x86_64)
      asset="sentry-cli-Darwin-x86_64"
      expected_sha256="$SENTRY_CLI_SHA256_X86_64"
      ;;
    *) fail "the architecture $(uname -m) has no pinned sentry-cli" ;;
  esac
}

# Downloads the pinned asset into $cli_path and fails unless its bytes match the pinned SHA-256. Nothing is made
# executable before the comparison.
download_cli() {
  local url="https://github.com/getsentry/sentry-cli/releases/download/${SENTRY_CLI_VERSION}/${asset}"
  cli_path="$work_dir/$asset"
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --output "$cli_path" "$url" \
    || fail "downloading $asset failed"
  local actual_sha256
  actual_sha256="$(shasum -a 256 "$cli_path" | awk '{ print $1 }')"
  [[ "$actual_sha256" == "$expected_sha256" ]] || fail "$asset does not match its pinned SHA-256"
  echo "sentry-cli $SENTRY_CLI_VERSION ($asset) matches its pinned SHA-256."
}

upload() {
  chmod +x "$cli_path"
  # Without pipefail the pipeline's status is hide_token's, and sentry-cli's own status is read from PIPESTATUS.
  set +o pipefail
  "$cli_path" --url "$SENTRY_URL" debug-files upload --org "$SENTRY_ORGANIZATION" --project "$SENTRY_PROJECT" \
    --type dsym "$dsyms_path" 2>&1 | hide_token
  local cli_status="${PIPESTATUS[0]}"
  set -o pipefail
  [[ "$cli_status" -eq 0 ]] || fail "sentry-cli exited with status $cli_status"
}

main() {
  set -Eeo pipefail
  trap 'fail "the script stopped unexpectedly at line $LINENO"' ERR
  trap 'if [[ -n "$work_dir" ]]; then rm -rf "$work_dir"; fi' EXIT

  parse_arguments "$@"
  check_inputs
  pick_asset
  work_dir="$(mktemp -d)"
  download_cli
  upload
  echo "Uploaded the dSYMs in $dsyms_path to Sentry."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
