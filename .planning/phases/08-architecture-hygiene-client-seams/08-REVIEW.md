---
phase: 08-architecture-hygiene-client-seams
reviewed: 2026-07-14T11:02:24Z
depth: standard
files_reviewed: 78
files_reviewed_list:
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/CategoryView.swift
  - AppPackage/Sources/AppComponents/SubSection.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppModels/Utilities/AppInfo.swift
  - AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift
  - AppPackage/Sources/AppModels/Utilities/URLUtil.swift
  - AppPackage/Sources/AppTools/AppUserDefaults.swift
  - AppPackage/Sources/AppTools/DataCache.swift
  - AppPackage/Sources/CookieClient/CookieClient.swift
  - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Download.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
  - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
  - AppPackage/Sources/DetailFeature/DetailView+Navigation.swift
  - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
  - AppPackage/Sources/HapticsClient/HapticsClient.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
  - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
  - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
  - AppPackage/Sources/HomeFeature/HomeReducer.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
  - AppPackage/Sources/ImageClient/ImageClient.swift
  - AppPackage/Sources/LibraryClient/LibraryClient.swift
  - AppPackage/Sources/NetworkingFeature/Request+Account.swift
  - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
  - AppPackage/Sources/NetworkingFeature/Request+GData.swift
  - AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift
  - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
  - AppPackage/Sources/NetworkingFeature/Request+Image.swift
  - AppPackage/Sources/NetworkingFeature/Request.swift
  - AppPackage/Sources/ParserFeature/Parser+Shared.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/SearchFeature/SearchReducer.swift
  - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
  - AppPackage/Sources/SettingFeature/Components/AboutView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
  - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
  - AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift
  - AppPackage/Sources/SettingFeature/SettingReducer.swift
  - AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift
  - AppPackage/Tests/CookieClientTests/.swiftlint.yml
  - AppPackage/Tests/CookieClientTests/CookieClientTests.swift
  - AppPackage/Tests/ImageClientTests/.swiftlint.yml
  - AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift
  - AppPackage/Tests/ImageClientTests/ImageClientTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/DetailRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataDecodeTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/ImageRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/RoutineRequestBaselineTests.swift
  - Scripts/check-cookie-logging.sh
findings:
  critical: 1
  warning: 4
  info: 0
  total: 5
status: issues_found
---

# Phase 08: Code Review Report

**Reviewed:** 2026-07-14T11:02:24Z
**Depth:** standard
**Files Reviewed:** 78
**Status:** issues_found

## Summary

The phase removes the targeted global host/cache/util seams cleanly in most call paths, and the
new CookieClient and ImageClient tests exercise useful behavior rather than padding coverage.
However, one reader completion drops its request-host snapshot before applying a response cookie,
so a host change during the request can write a server cookie to the wrong domain. Four additional
seam and enforcement weaknesses remain: the equivalent profile-completion race, a UserDefaults
read that bypasses the dependency entirely, a logging audit that can be defeated by renaming a
local, and redundant transitive product linkage in the new test targets.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: Normal-image refetch can write a response cookie to the wrong gallery host

**File:** `AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift:231-260`  
**Issue:** The request correctly snapshots `state.setting.galleryHost` at line 231 and supplies it
to `GalleryNormalImageURLRefetchRequest`, but the completion action carries only the index and
result (lines 243-245). When the response is reduced, line 255 reads the mutable *current* setting
again and passes that host to `setSkipServer`. If the account host changes while the network request
is in flight, a response from the original host writes its `skipserver` value into the newly selected
host's cookie jar. That breaks the phase's caller-owned-host invariant and can make later image
requests use a server identifier issued for another domain.

**Fix:** Carry the originating `GalleryHost` in `refetchNormalImageURLsDone` and use that value for
the cookie write on both success and failure paths. Add a reducer test that suspends the request,
changes the shared host, resumes the response, and verifies the cookie was written only for the
originating host.

### Warnings

#### WR-01: Profile verification also discards its request-host snapshot before cookie/profile side effects

**File:** `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift:187-200`; `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift:117-140`  
**Issue:** `fetchEhProfileIndex` snapshots a host for `VerifyEhProfileRequest`, but
`fetchEhProfileIndexDone` carries no host. The helper consequently reads
`state.setting.galleryHost.url` when writing `selectedProfile`, and its profile-not-found branch
sends `createDefaultEhProfile`, which takes another fresh host snapshot. A host switch while verify
is in flight can therefore write the old host's profile id to the new host or create the default
profile on a different host from the one that was verified.

**Fix:** Include the originating `GalleryHost` in `fetchEhProfileIndexDone`. Use it for the cookie
read/write, and make the create-default action carry that same host rather than re-reading shared
state.

#### WR-02: `UserDefaultsClient` does not inject its read side

**File:** `AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift:5-18,35-45`  
**Issue:** Only `setValue` is stored in the dependency value. `getValue` directly reads
`UserDefaults.standard`, so overriding the client with `.noop`, `.unimplemented`, or a test value
cannot control reads. `AppRouteReducer` uses this method for `clipboardChangeCount`; its tests can
therefore observe developer-machine/process-global defaults even after replacing the dependency,
which defeats the seam this phase was meant to establish and makes behavior order-dependent.

**Fix:** Make reading part of the dependency value. Since the only remaining key is typed as an
integer, prefer a focused `clipboardChangeCount: @Sendable () -> Int?` endpoint (plus the existing
write endpoint) over an `Any`-based generic closure. Give noop and test implementations deterministic
read behavior.

#### WR-03: The cookie logging gate misses values after ordinary aliasing

**File:** `Scripts/check-cookie-logging.sh:5-6,43-49,77-88`  
**Issue:** The audit decides whether a logger interpolation is cookie-bearing solely by matching a
fixed list of identifier spellings inside that interpolation. An ordinary refactor such as
`let diagnosticValue = cookie.value` followed by
`logger.info("value: \(diagnosticValue, privacy: .public)")` passes the gate because
`diagnosticValue` is not in the token inventory. The scanner also only recognizes a receiver named
`logger`. Thus the executable check does not enforce its stated property that cookie values can
never reach public logs; it enforces a naming convention that data flow can trivially outgrow.

**Fix:** Replace the token-only AWK scan with a syntax/data-flow-aware rule, or at minimum add
negative fixtures for aliases and alternate `Logger` variable names and fail the check for those
cases. The gate should track sources such as CookieClient accessors to OSLog interpolation privacy,
not local variable spelling.

#### WR-04: New test targets redundantly link modules already supplied by the target under test

**File:** `AppPackage/Package.swift:943-966`  
**Issue:** `CookieClientTests` links both `CookieClient` and its `AppModels` dependency, while
`ImageClientTests` links `ImageClient` together with its `AppTools` and `AppModels` dependencies.
For test bundles, explicitly linking dependencies already provided by the module under test can
load duplicate runtime module/product copies and produce duplicate-class diagnostics or unstable
casts. These declarations are especially risky in tests intended to validate dependency seams.

**Fix:** Link each test target to the target under test plus genuinely test-only support only:
`CookieClientTests` should depend on `CookieClient`; `ImageClientTests` should depend on
`ImageClient` and `TestingSupport`. Keep imports needed by test source, relying on the target graph
rather than re-linking the same products.

---

_Reviewed: 2026-07-14T11:02:24Z_  
_Reviewer: the agent (gsd-code-reviewer; generic-agent workaround)_  
_Depth: standard_
