# Adds a build to an AltStore source (AltStore.json or altstore-beta.json).
#
# Arguments (all --arg unless noted):
#   $bundleIdentifier, $version, $buildVersion, $marketingVersion, $date,
#   $localizedDescription, $downloadURL, $sha256, $minOSVersion
#   --argjson size              IPA size in bytes
#   --argjson privacy           {"NS...UsageDescription": "..."} read from the build
#   --argjson releaseVersions   null for a regular release; for a beta, the `versions`
#                               array of AltStore.json (the regular releases)
#
# The new version is prepended (newest first). An older entry with the same
# version + buildVersion, or with the same downloadURL (a re-uploaded asset), is
# replaced. For a beta source only betas newer than the latest regular release are
# kept, but the newest beta always stays. Every other source and app field is kept.

def version_key:
  ((.version // "") | [scan("[0-9]+") | tonumber]) as $v
  | ((.buildVersion // "") | [scan("[0-9]+") | tonumber]) as $b
  | (($v + [0, 0, 0, 0])[:4]) + (($b + [0])[:1]);

if (.apps | type) != "array" or (.apps | length) == 0 then
  error("source has no apps")
elif .apps[0].bundleIdentifier != $bundleIdentifier then
  error("bundle identifier mismatch: source has \(.apps[0].bundleIdentifier), build has \($bundleIdentifier)")
else . end
| {
    version: $version,
    buildVersion: $buildVersion,
    marketingVersion: $marketingVersion,
    date: $date,
    localizedDescription: $localizedDescription,
    downloadURL: $downloadURL,
    size: $size,
    sha256: $sha256,
    minOSVersion: $minOSVersion
  } as $entry
| .apps[0].versions = (
    [$entry]
    + ((.apps[0].versions // [])
       | map(select(
           ((.version == $entry.version and .buildVersion == $entry.buildVersion)
            or .downloadURL == $entry.downloadURL) | not
         )))
  )
| if $releaseVersions == null then .
  else
    (if ($releaseVersions | length) > 0
     then ($releaseVersions | map(version_key) | max)
     else null end) as $latestRelease
    | .apps[0].versions = (
        .apps[0].versions[:1]
        + (.apps[0].versions[1:]
           | map(select($latestRelease == null or (version_key > $latestRelease))))
      )
  end
| .apps[0].appPermissions = {
    entitlements: (.apps[0].appPermissions.entitlements // []),
    privacy: ((.apps[0].appPermissions.privacy // {}) + $privacy)
  }
