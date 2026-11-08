#!/usr/bin/env bash
#
# Packages one channel's copy of an unsigned app as an IPA, with the channel stamped into the app.
#
# Usage: package-channel.sh <app> <channel> <ipa>
#
#   <app>      the built, unsigned EhPanda.app; it is copied, never changed
#   <channel>  github, altstore, sidestore, altstorePAL or beta
#   <ipa>      the IPA to write, e.g. EhPanda-GitHub.ipa
#
# The app reads the channel from `EhPandaDistributionChannel` in its Info.plist and reports it as the
# install source when MarketplaceKit cannot name a store (DistributionChannel in
# AppPackage/Sources/InstallSourceClient). The committed value is `source`, for builds that no
# workflow made; this script overwrites it in the copy. One build can so be packaged once per
# channel without rebuilding. Only the app is stamped: the share extension never reports a source.
#
# The channels are a closed list, the same as the app's. The app ignores any other value, so a typo
# here would silently report `unknown`; failing is better.

set -euo pipefail

app="${1:-}"
channel="${2:-}"
ipa="${3:-}"
key='EhPandaDistributionChannel'

case "$channel" in
  github | altstore | sidestore | altstorePAL | beta) ;;
  *)
    echo "::error::'$channel' is not a distribution channel (github, altstore, sidestore, altstorePAL, beta)."
    exit 1
    ;;
esac

if [[ ! -f "$app/Info.plist" ]]; then
  echo "::error::'$app' is not an app bundle."
  exit 1
fi
if [[ -z "$ipa" ]]; then
  echo "::error::No IPA path given."
  exit 1
fi
# Stamping changes the Info.plist, which would break a signature. The workflows build unsigned, and
# the installing store signs each copy.
if [[ -e "$app/_CodeSignature" ]]; then
  echo "::error::'$app' is signed; only an unsigned app can be stamped."
  exit 1
fi
committed="$(plutil -extract "$key" raw -o - "$app/Info.plist" 2>/dev/null || true)"
if [[ "$committed" != 'source' ]]; then
  echo "::error::The app's $key is '$committed', not the committed 'source'. Package copies from the unstamped build."
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Payload"
ditto "$app" "$work/Payload/$(basename "$app")"
copy_plist="$work/Payload/$(basename "$app")/Info.plist"

plutil -replace "$key" -string "$channel" "$copy_plist"
stamped="$(plutil -extract "$key" raw -o - "$copy_plist")"
if [[ "$stamped" != "$channel" ]]; then
  echo "::error::The copy's $key reads '$stamped' after stamping '$channel'."
  exit 1
fi

mkdir -p "$(dirname "$ipa")"
ipa="$(cd "$(dirname "$ipa")" && pwd)/$(basename "$ipa")"
rm -f "$ipa"
(cd "$work" && zip -qr "$ipa" ./Payload)
echo "Packaged $(basename "$ipa") with $key = $channel."
