#!/usr/bin/env bash
#
# Prints the entitlement keys an unsigned app carries, as a sorted JSON array, for the add-version filter's
# --argjson entitlements: AltStore refuses to install an IPA whose permissions differ from its source's, so a
# source lists what the IPA really has, read the way actions-tool/pal_publish.py reads the signed PAL build.
#
# Usage: ipa-entitlements.sh <app>
#
# It reads the app and each of its app extensions with `codesign -d --entitlements`. The Classic and beta
# workflows archive with CODE_SIGNING_ALLOWED=NO and an empty CODE_SIGN_ENTITLEMENTS, so the answer is [] (an
# arm64 binary the linker signed has no entitlements, and a bundle with no signature at all has none either).
# `application-identifier` and `com.apple.developer.team-identifier` are left out, as for PAL: AltStore does
# not want them listed. Any other failure of codesign stops the run.

set -euo pipefail

app="${1:-}"
if [[ ! -f "$app/Info.plist" ]]; then
  echo "::error::'$app' is not an app bundle." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
shopt -s nullglob
i=0
for bundle in "$app" "$app"/PlugIns/*.appex "$app"/Extensions/*.appex; do
  i=$((i + 1))
  entitlements="$work/$i.plist"
  if ! codesign -d --entitlements - --xml "$bundle" > "$entitlements" 2> "$work/$i.err"; then
    if grep -q 'not signed at all' "$work/$i.err"; then
      : > "$entitlements"
    else
      echo "::error::The entitlements of $(basename "$bundle") could not be read: $(cat "$work/$i.err")" >&2
      exit 1
    fi
  fi
  if [[ -s "$entitlements" ]]; then
    plutil -convert json -o "$work/$i.json" "$entitlements"
  else
    echo '{}' > "$work/$i.json"
  fi
done

jq -s -c 'map(keys) | add // [] | unique
          | map(select(. != "application-identifier" and . != "com.apple.developer.team-identifier"))' "$work"/*.json
