---
phase: 07-root-privacy-mask-auto-lock-removal
reviewed: 2026-07-14T02:00:00Z
depth: standard
files_reviewed: 41
files_reviewed_list:
  - App/Info.plist
  - App/InfoPlist.xcstrings
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/ViewModifiers.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/Resources/Localizable.xcstrings
  - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
  - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
  - AppPackage/Sources/AppModels/Persistent/Setting.swift
  - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/DetailFeature/GalleryDestination.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
  - AppPackage/Sources/HomeFeature/History/HistoryView.swift
  - AppPackage/Sources/HomeFeature/HomeView.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/SearchFeature/SearchRootView.swift
  - AppPackage/Sources/SearchFeature/SearchView.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
  - AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
  - AppPackage/Sources/SettingFeature/Login/LoginView.swift
  - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Sources/SettingFeature/SettingView.swift
  - AppPackage/Tests/AppFeatureTests/.swiftlint.yml
  - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
  - AppPackage/Tests/AppModelsTests/SettingPrivacyMaskTests.swift
  - AppPackage/Tests/FeatureTests.xctestplan
findings:
  critical: 0
  warning: 1
  info: 2
  dismissed: 1
  total: 4
status: resolved
resolution:
  wr-01: dismissed (pre-release, no persisted blob)
  wr-02: fixed (9848e75e) and verified on a physical device 2026-07-14
  in-01: fixed (a4ce8b12); full suite green (507 tests)
  in-02: confirmed intentional by owner 2026-07-14
---

# Phase 07: Code Review Report

**Reviewed:** 2026-07-14T02:00:00Z
**Depth:** standard
**Files Reviewed:** 41
**Status:** resolved (all findings closed — see resolution notes per finding)

## Summary

This phase replaces the passcode/biometric auto-lock feature with a scene-phase-driven "privacy
mask" (a blur applied when the app resigns active). The change is broad but mechanically consistent:
`AppLockReducer`, `AuthorizationClient`, `AutoLockPolicy`, `backgroundBlurRadius`, and the
`NSFaceIDUsageDescription` plist entry are all removed; a `@Shared(.privacyMaskBlur)` in-memory key
is written by `AppReducer.onScenePhaseChange` and read by a new `PrivacyMaskModifier`
(`.privacyMask()`). Every `.autoBlur(radius:)` call site and every `blurRadius` view parameter was
threaded out cleanly — I confirmed there are no dangling references to any removed symbol across
`AppPackage/Sources` and `App/`, the new `privacy_mask` / `privacy_mask_footer` catalog keys are
fully localized across all six supported locales, and the removed `auto_lock_*` catalog keys have no
remaining referents. The new `AppFeatureTests` target is correctly wired into `Package.swift`, the
test plan, and carries a `parent_config` SwiftLint file.

An earlier round on this file recorded `status: clean`. Re-reviewing adversarially, two behavioral
concerns surfaced that the prior pass did not: a persisted-settings reset on upgrade caused by
making the renamed field non-optional (WR-01), and a blur-animation timing risk that can undermine
the App Switcher snapshot the feature exists to protect (WR-02). No security defects or crashes were
found.

**WR-01 dismissed by owner (2026-07-14):** the persisted-`Setting` reset is accepted as-is under the
project's "v1-schema-until-release" stance — the app is not yet released, so there is no live
persisted blob to preserve. The finding is retained below for the record but is not actionable and
carries no migration debt at this time.

**All findings closed (2026-07-14):** WR-01 dismissed (above); WR-02 fixed (`9848e75e`) and verified
on a physical device; IN-01 fixed (`a4ce8b12`) with the full 507-test suite green; IN-02 confirmed
intentional by the owner. See the per-finding resolution banners below. This review is resolved.

## Narrative Findings (AI reviewer)

### Warnings

#### WR-01: Renamed `privacyMaskIntensity` is a required Codable field — silently resets the entire persisted `Setting` on upgrade

> **DISMISSED by owner (2026-07-14) — will not fix.** Accepted under the "v1-schema-until-release"
> stance: the app is unreleased, so no live persisted `Setting` blob exists to preserve and the
> upgrade-path reset cannot affect any user. Recorded for the record only; re-open before release if
> a real migration path becomes necessary. The `Fix` below is retained for reference, not scheduled.

**File:** `AppPackage/Sources/AppModels/Persistent/Setting.swift:90`
**Issue:** The field `backgroundBlurRadius` was renamed to `privacyMaskIntensity` (a non-optional
`Double`) and `autoLockPolicy` was removed, while `Setting` still uses **synthesized** `Codable`
(no hand-written `init(from:)`, does not adopt `MigratableModel`, and `schemaVersion` stays `1`).
A persisted blob written by a prior build contains `backgroundBlurRadius`/`autoLockPolicy` but
**no** `privacyMaskIntensity` key. Synthesized `init(from:)` throws `keyNotFound` for that required
key, so `@Shared(.setting)` (`AppStorageKey<Setting>.Default`, `AppSharedKeys.swift:53-56`) falls
back to the key default `Setting()` — wiping **every** unrelated preference (gallery host, accent
color, reading direction, scale factors, etc.), not just the renamed one. The reset bypasses the
`schemaVersion` downgrade gate entirely, and it contradicts this model's own documented invariant
(`Setting.swift:66-69`: *"a field added later must stay optional so old blobs keep decoding"*) and
its schema note (`Setting.swift:57-58`: *"adopt `MigratableModel` when a breaking change lands"*),
neither of which was honored.

The project's documented stance is "v1-schema-until-release," so a pre-release reset may be
acceptable by decision — but here the reset is broader than intended (the whole struct, not the one
field) and happens through an unintended path, so it should be a conscious call rather than a side
effect. Confirm intent; if preserving the rest of the blob is wanted, either fix below works.

**Fix:** Make the field optional so old blobs keep decoding (minimal, matches the model's invariant):
```swift
public var privacyMaskIntensity: Double? = 10
// read sites: `setting.privacyMaskIntensity ?? 10`
```
or add a versioned migration that maps the old key forward (keeps the non-optional type):
```swift
enum SchemaV2: VersionedSchema {
    static let version = 2
    static func migrate(_ object: inout [String: JSONValue]) throws {
        if let blur = object["backgroundBlurRadius"] { object["privacyMaskIntensity"] = blur }
        object["autoLockPolicy"] = nil
    }
}
// append SchemaV2.self to `schemas` and adopt MigratableModel per Setting.swift:57-58
```

#### WR-02: Animated privacy blur may not render before iOS captures the App Switcher snapshot

> **RESOLVED (2026-07-14) — fixed in `9848e75e`, verified on a physical device.** The scoped
> animation is now suppressed whenever the blur becomes nonzero (`reduceMotion || blur != 0 ? nil :
> .linear(duration: 0.1)`), so the mask is applied instantly on `.inactive` and only fades out on
> return to active. The App Switcher card was confirmed fully masked on-device.

**File:** `AppPackage/Sources/AppComponents/ViewModifiers.swift:12-16`
**Issue:** `PrivacyMaskModifier` animates the blur with `.linear(duration: 0.1)` for users who do not
have Reduce Motion enabled. The blur value is written on the `.inactive` scene phase
(`AppReducer.swift:88-90`), which is exactly when iOS captures the App Switcher / task-switcher
snapshot. Because the first animation frame is unblurred and the mask ramps in over 100ms, the
snapshot can be taken before the blur is visually applied, exposing content in the App Switcher —
defeating the primary purpose of this feature. The safer path (instant, `nil` animation) is taken
only for Reduce Motion users; standard users get the delayed blur. (The pre-existing `autoBlur`
animated too, but privacy masking is now the whole point of this surface, so the risk is central.)

**Fix:** Do not animate the blur ramp-in on resign-active; only ease the blur *out* on return to
active, so masking appears instantly when the snapshot is taken:
```swift
public func body(content: Content) -> some View {
    content
        // Blur must appear instantly (the App Switcher snapshot happens on .inactive);
        // only animate its removal when returning to active.
        .blur(radius: blur)
        .animation(reduceMotion ? nil : .linear(duration: 0.1), value: blur == 0)
        .allowsHitTesting(blur < 1)
}
```
Then verify on-device that the App Switcher card is fully masked.

### Info

#### IN-01: `AppReducerScenePhaseTests` relies on `.serialized` over process-global `@Shared` storage

> **RESOLVED (2026-07-14) — fixed in `a4ce8b12`.** `makeStore(...)` now injects a fresh
> `UserDefaults.inMemory` + `InMemoryStorage()` via `withDependencies` (both while building shared
> state and on the `TestStore`), and `.serialized` was dropped. Full suite green at 507 tests with the
> suite running unserialized.

**File:** `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift:14`
**Issue:** The suite is `@Suite(.serialized)` and drives `@Shared(.privacyMaskBlur)` (process-global
`InMemoryKey`) and `@Shared(.setting)` without overriding `defaultInMemoryStorage`/`defaultAppStorage`.
`.serialized` only orders tests *within* this suite; a parallel suite in the same test process that
touched the same in-memory key could still pollute it. The project convention (recorded in project
memory) is to fix parallel-shared pollution by injecting an isolated storage dependency rather than
serializing. No current test exercises the same global concurrently, so this is not failing today —
flagging for convention alignment and future-proofing.
**Fix:** Override the storage dependency in `makeStore(...)` `withDependencies` (e.g. a fresh
`InMemoryStorage()` / ephemeral `UserDefaults(suiteName:)`) so each `TestStore` is isolated, and drop
`.serialized`.

#### IN-02: `AppActivityLogsView` run-picker sheet gains a mask it never had before

> **CONFIRMED INTENTIONAL (2026-07-14) — owner decision, no change.** Masking the `RunPickerSheet`
> modal is deliberate consistency, not accidental over-application. No fix required.

**File:** `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:51`
**Issue:** `.privacyMask()` was added to the `RunPickerSheet` sheet, which previously had no
`.autoBlur`. This is a net improvement (consistent masking of a modal) rather than a defect, but it
is a behavioral change with no matching removal elsewhere — worth a one-line confirmation that it was
intentional and not accidental over-application. No fix required if intended.

---

_Reviewed: 2026-07-14T02:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
