# Adds a build to an AltStore source (AltStore.json, SideStore.json, altstore-beta.json or
# AltStorePAL.json).
#
# Arguments (all --arg unless noted):
#   $bundleIdentifier, $version, $buildVersion, $marketingVersion, $date,
#   $localizedDescription, $downloadURL, $minOSVersion
#   $sha256                     the IPA's SHA-256. Required, except with assetURLs, where it is
#                               left out or empty: an ADP has no single IPA to hash.
#   --argjson size              IPA size in bytes
#   --argjson privacy           {"NS...UsageDescription": "..."} read from the build. It REPLACES the app's
#                               appPermissions.privacy: AltStore refuses an install whose IPA asks for a permission
#                               the source does not list, so the list is always the newest build's, never the
#                               union with older builds' (a permission a release dropped must go too).
#   --argjson releaseVersions   null for a regular release; for a beta, the `versions`
#                               array of AltStore.json (the regular releases)
#   --argjson localizedDescriptions   optional: {"en": ..., "de": ..., ...}, the notes per
#                               language (actions-tool/release_notes.py altstore). Its "en" must
#                               equal $localizedDescription. Left out, or null, for a source
#                               that shows English only (SideStore).
#
# AltStore PAL only (Research §4); a call that passes none of these writes what it always did:
#   --argjson assetURLs         {"manifest": url, "signature": url, "<variant>": url}: each ADP file
#                               name without its extension, to its GitHub release asset. Every value is
#                               an https URL and "manifest" must equal $downloadURL. The entry then
#                               carries assetURLs and no sha256.
#   --argjson entitlements      the signed build's entitlement keys. They replace the source's list,
#                               without application-identifier and com.apple.developer.team-identifier,
#                               which AltStore does not want listed. Left out, the list is kept.
#   --arg marketplaceID         the App Store Connect app's Apple ID (digits). Set when the source's is
#                               empty; an equal one passes; a different one is an error.
#
# The entitlements of a source whose call leaves --argjson entitlements out are kept as they are; the Classic
# and beta workflows pass what the unsigned IPA carries (actions-tool/ipa-entitlements.sh), as the PAL one does.
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
| ($ARGS.named.localizedDescriptions // null) as $localizedDescriptions
| ($ARGS.named.assetURLs // null) as $assetURLs
| ($ARGS.named.entitlements // null) as $entitlements
| ($ARGS.named.marketplaceID // null) as $marketplaceID
| ($ARGS.named.sha256 // null) as $sha256
| if $assetURLs == null then
    if ($sha256 | type) != "string" or $sha256 == "" then error("sha256 is required without assetURLs")
    else . end
  elif ($assetURLs | type) != "object" then
    error("assetURLs must be an object of https URLs")
  elif ($assetURLs | [.[] | type == "string" and startswith("https://") and length > 8] | all | not) then
    error("assetURLs must be an object of https URLs")
  elif ($assetURLs | has("manifest") | not) then
    error("assetURLs must have a manifest")
  elif $assetURLs.manifest != $downloadURL then
    error("assetURLs.manifest differs from downloadURL")
  elif $sha256 != null and $sha256 != "" then
    error("an ADP entry has no sha256: leave sha256 out with assetURLs")
  else . end
| if $entitlements == null then .
  elif ($entitlements | type) != "array" or ($entitlements | [.[] | type == "string"] | all | not) then
    error("entitlements must be a list of strings")
  else . end
| if $marketplaceID == null then .
  elif ($marketplaceID | type) != "string" or ($marketplaceID | test("^[0-9]+$") | not) then
    error("marketplaceID must be the app's Apple ID, digits only")
  elif (.apps[0].marketplaceID // "") == "" then .apps[0].marketplaceID = $marketplaceID
  elif .apps[0].marketplaceID != $marketplaceID then
    error("marketplaceID mismatch: source has \(.apps[0].marketplaceID), given \($marketplaceID)")
  else . end
| if $localizedDescriptions == null then .
  elif ($localizedDescriptions | type) != "object"
       or ($localizedDescriptions | [.[] | type == "string" and length > 0] | all | not) then
    error("localizedDescriptions must be an object of non-empty strings")
  elif $localizedDescriptions.en != $localizedDescription then
    error("localizedDescriptions.en differs from localizedDescription")
  else . end
| ({
    version: $version,
    buildVersion: $buildVersion,
    marketingVersion: $marketingVersion,
    date: $date,
    localizedDescription: $localizedDescription
  }
  + (if $localizedDescriptions == null then {} else {localizedDescriptions: $localizedDescriptions} end)
  + (if $assetURLs == null then {
    downloadURL: $downloadURL,
    size: $size,
    sha256: $sha256,
    minOSVersion: $minOSVersion
  } else {
    downloadURL: $downloadURL,
    assetURLs: $assetURLs,
    size: $size,
    minOSVersion: $minOSVersion
  } end)) as $entry
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
    entitlements: (if $entitlements == null then (.apps[0].appPermissions.entitlements // [])
                   else $entitlements
                        | map(select(. != "application-identifier"
                                     and . != "com.apple.developer.team-identifier"))
                   end),
    privacy: $privacy
  }
