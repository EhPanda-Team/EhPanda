#!/usr/bin/env bash
#
# Bumps MARKETING_VERSION and CURRENT_PROJECT_VERSION for every non-test
# target in EhPanda.xcodeproj at once.
#
# Usage: ./Scripts/bump-version.sh -v <x.y.z> [-b <build>]
# If -b is omitted, the current build number is auto-incremented by 1.
# Example: ./Scripts/bump-version.sh -v 2.8.1 -b 158
#          ./Scripts/bump-version.sh -v 2.8.1

set -euo pipefail

PROG="$(basename "$0")"

usage() {
  echo "Usage: $PROG -v <x.y.z> [-b <build>]" >&2
  exit 1
}

help() {
  cat <<EOF
$PROG — bump version and build number for every non-test target in
EhPanda.xcodeproj at once.

Usage:
  $PROG -v <x.y.z> [-b <build>]
  $PROG -h | --help

Options:
  -v <x.y.z>   Marketing version in semantic format (required).
  -b <build>   Build number (non-negative integer). If omitted, the
               current build number is detected from the project and
               incremented by 1.
  -h, --help   Show this help and exit.

Examples:
  $PROG -v 2.8.1 -b 158   # set version 2.8.1, build 158
  $PROG -v 2.8.1          # set version 2.8.1, auto-increment build
EOF
  exit 0
}

# Translate long --help before getopts (getopts is short-opt only).
for arg in "$@"; do
  case "$arg" in
    --help) help ;;
  esac
done

VERSION=""
BUILD=""

while getopts ":v:b:h" opt; do
  case "$opt" in
    v) VERSION="$OPTARG" ;;
    b) BUILD="$OPTARG" ;;
    h) help ;;
    \?) echo "Error: unknown option -$OPTARG" >&2; usage ;;
    :)  echo "Error: option -$OPTARG requires an argument" >&2; usage ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo "Error: -v <x.y.z> is required" >&2
  usage
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must be in semantic x.y.z format (got '$VERSION')" >&2
  exit 1
fi

if [ -n "$BUILD" ] && ! [[ "$BUILD" =~ ^[0-9]+$ ]]; then
  echo "Error: build number must be a non-negative integer (got '$BUILD')" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBXPROJ="$SCRIPT_DIR/../EhPanda.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "Error: project.pbxproj not found at $PBXPROJ" >&2
  exit 1
fi

TEST_BUNDLE_ID="app.ehpanda.tests"

if [ -z "$BUILD" ]; then
  # Pick the highest CURRENT_PROJECT_VERSION across non-test build configs and add 1.
  CURRENT_BUILD="$(awk -v test_id="$TEST_BUNDLE_ID" '
    function flush(   i, is_test, m) {
      is_test = 0
      for (i = 1; i <= n; i++) {
        if (block[i] ~ ("PRODUCT_BUNDLE_IDENTIFIER = " test_id ";")) { is_test = 1; break }
      }
      if (!is_test) {
        for (i = 1; i <= n; i++) {
          if (match(block[i], /CURRENT_PROJECT_VERSION = [0-9]+;/)) {
            m = substr(block[i], RSTART + 26, RLENGTH - 27)
            if (m + 0 > max + 0) max = m + 0
          }
        }
      }
      n = 0; in_block = 0
    }
    {
      if (in_block) {
        block[++n] = $0
        if ($0 ~ /^\t\t};[[:space:]]*$/) flush()
        next
      }
      if ($0 ~ /isa = XCBuildConfiguration;/) { in_block = 1; n = 1; block[n] = $0; next }
    }
    END { if (in_block) flush(); print max + 0 }
  ' "$PBXPROJ")"

  if [ -z "$CURRENT_BUILD" ] || [ "$CURRENT_BUILD" = "0" ]; then
    echo "Error: could not detect current build number from $PBXPROJ" >&2
    exit 1
  fi
  BUILD=$((CURRENT_BUILD + 1))
  echo "Auto-detected current build $CURRENT_BUILD, bumping to $BUILD."
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

awk -v v="$VERSION" -v b="$BUILD" -v test_id="$TEST_BUNDLE_ID" '
function flush_block(   i, is_test, line) {
  is_test = 0
  for (i = 1; i <= n; i++) {
    if (block[i] ~ ("PRODUCT_BUNDLE_IDENTIFIER = " test_id ";")) {
      is_test = 1
      break
    }
  }
  for (i = 1; i <= n; i++) {
    line = block[i]
    if (!is_test) {
      if (line ~ /MARKETING_VERSION = /) {
        sub(/MARKETING_VERSION = [^;]+;/, "MARKETING_VERSION = " v ";", line)
        marketing_hits++
      } else if (line ~ /CURRENT_PROJECT_VERSION = /) {
        sub(/CURRENT_PROJECT_VERSION = [^;]+;/, "CURRENT_PROJECT_VERSION = " b ";", line)
        build_hits++
      }
    }
    print line
  }
  n = 0
  in_block = 0
}

{
  if (in_block) {
    block[++n] = $0
    # XCBuildConfiguration block ends at 2-tab indented "};"
    if ($0 ~ /^\t\t};[[:space:]]*$/) {
      flush_block()
    }
    next
  }
  if ($0 ~ /isa = XCBuildConfiguration;/) {
    in_block = 1
    n = 1
    block[n] = $0
    next
  }
  print
}
END {
  if (in_block) flush_block()
  printf("Updated %d MARKETING_VERSION and %d CURRENT_PROJECT_VERSION entries.\n", marketing_hits, build_hits) > "/dev/stderr"
}
' "$PBXPROJ" > "$TMP"

mv "$TMP" "$PBXPROJ"
trap - EXIT

echo "Bumped non-test targets to version $VERSION (build $BUILD)."
