#!/usr/bin/env bash
#
# Fails unless <build> is a whole number greater than every buildVersion already listed in the given
# AltStore sources. A source file that does not exist yet is skipped.
#
# Usage: check-build-number.sh <build> <source.json>...
#
# AltStore treats a build whose version and build number are already listed as the same build, so a
# repeated number is never offered as an update. Each beta therefore needs a fresh CFBundleVersion;
# set it with `Scripts/bump-version.sh -v <x.y.z> -b <build>`.

set -euo pipefail

build="${1:-}"
shift || true

if [[ ! "$build" =~ ^[0-9]+$ ]]; then
  echo "::error::The build number '$build' is not a whole number."
  exit 1
fi

highest=0
for source in "$@"; do
  [[ -f "$source" ]] || continue
  source_highest="$(jq '[.apps[].versions[]?.buildVersion | tonumber? // empty] | max // 0' "$source")"
  if (( source_highest > highest )); then
    highest="$source_highest"
  fi
done

if (( build <= highest )); then
  echo "::error::Build $build is not greater than build $highest, the highest already published. Run Scripts/bump-version.sh -v <version> -b $((highest + 1)) and commit it before releasing."
  exit 1
fi

echo "Build $build is greater than every published build (highest: $highest)."
