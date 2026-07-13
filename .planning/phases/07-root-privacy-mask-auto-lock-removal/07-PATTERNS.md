# Phase 7: Root Privacy Mask & Auto-Lock Removal - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 8 primary change surfaces (plus the 39→40 mask-site sweep + 22 view-type param removals, which RESEARCH.md §Enumeration 1/2 already enumerates verbatim)
**Analogs found:** 8 / 8 (all in-repo; this is a rename/removal refactor, every pattern has an established sibling)

> **Scope note for the planner.** RESEARCH.md already nails three things with exact, copy-ready code — do NOT re-derive them, just cite:
> - the `.privacyMask()` modifier body (RESEARCH §"Self-Sourcing Modifier", the `PrivacyMaskModifier: ViewModifier` shape),
> - the `@Shared(.inMemory)` key declaration (RESEARCH §"Self-Sourcing Modifier" + `AppSharedKeys.swift:68-72` `greeting` idiom, confirmed below),
> - the `AppReducer.onScenePhaseChange` inactive/active fold (RESEARCH §Enumeration 3 + Pitfall 1).
>
> This document focuses effort where RESEARCH.md is thin on analogs: the **Appearance relocation target**, the **`.xcstrings` add**, the **`.testTarget` block**, and the **rename ripple list**.

## File Classification

| File (modified unless noted) | Role | Data Flow | Closest Analog | Match Quality |
|------------------------------|------|-----------|----------------|---------------|
| `AppComponents/ViewModifiers.swift` | view-modifier | transform (state→visual) | existing `autoBlur` (same file, 29-33) + `greeting` `@Shared(.inMemory)` | exact (rewrite in place) |
| `AppModels/Persistence/AppSharedKeys.swift` | shared-key decl | in-memory state | `greeting` key (68-72, same file) | exact |
| `AppFeature/DataFlow/AppReducer.swift` | reducer | event-driven (scenePhase) | its own `onScenePhaseChange` (82-136) | exact (self-fold) |
| `AppFeature/DataFlow/AppLockReducer.swift` (**DELETE**) | reducer | — | — | n/a (removed) |
| `AuthorizationClient/**` (**DELETE MODULE**) | client | — | — | n/a (removed) |
| `AppModels/Persistent/Setting.swift` | model | CRUD (persisted pref) | Phase 5 `enablesLandscape` in-place removal precedent | exact (precedent) |
| `SettingFeature/AppearanceSetting/AppearanceSettingView.swift` | component (setting screen) | request-response (binding) | `DownloadSettingView` footer + the departing `GeneralSettingView` blur `VStack`/`Slider` (107-130) | exact for footer; mechanics-analog for slider |
| `SettingFeature/AppearanceSetting/AppearanceSettingReducer.swift` | reducer | request-response | its own `preferredColorSchemeChanged` binding-bridge idiom | exact |
| `SettingFeature/GeneralSetting/{View,Reducer}.swift` | component + reducer | request-response | — (section deletion) | n/a (removal) |
| `SettingFeature/Resources/Localizable.xcstrings` | l10n catalog | config | `background_blur_radius` / `detects_links_from_clipboard` entries | exact |
| `Package.swift` | config | — | existing `.target`/`.testTarget` blocks | exact |

---

## Pattern Assignments (high-value, analog-thin surfaces)

### `AppearanceSettingView.swift` — the relocation target (D-10)

**Analog A — where the row goes:** the tint-color row is `AppearanceSettingView.swift:30`, inside the first (header-less) `Section`:

```swift
ColorPicker(.tintColor, selection: Binding($setting.accentColor))
```

Owner wants the Privacy Mask control **directly under this row**. Two viable placements:
- Same first `Section` (no header), immediately after line 30 — but then the "Privacy Mask" label + footer must live inline (label as a `Text` above the slider, footer as `.footer`-less inline `Text`). A header-less section can't carry a `footer:` cleanly next to the tint row.
- **Recommended:** a dedicated `Section { … } footer: { … }` placed right after the first section (visually under the tint row) so the required footer (D-10) has a native home. This matches the `DownloadSettingView` footer analog below.

**Analog B — the slider mechanics** (the departing control, `GeneralSettingView.swift:122-129` — copy verbatim, just rename the binding + swap the label):

```swift
VStack(alignment: .leading) {
    Text(.backgroundBlurRadius)           // → Text(.privacyMask)  (new key)
    HStack {
        Image(systemSymbol: .eye)
        Slider(value: Binding($setting.backgroundBlurRadius), in: 0...100, step: 10)  // → $setting.privacyMaskIntensity
        Image(systemSymbol: .eyeSlash)
    }
}
```

Keep the `0...100, step: 10`, eye/eye-slash icons exactly (D-10 says "keep the existing slider mechanics").

**Analog C — the footer** (`DownloadSettingView.swift:25-34` — the canonical header+footer `Section` in SettingFeature):

```swift
Section {
    Toggle(.allowCellularDownloads, isOn: Binding($setting.downloadAllowCellular))
} header: {
    Text(.network)
} footer: {
    Text(.networkDescription)
}
```

For Privacy Mask the header is unnecessary (D-10: the label lives inline); use just `footer:`:

```swift
Section {
    VStack(alignment: .leading) {
        Text(.privacyMask)
        HStack {
            Image(systemSymbol: .eye)
            Slider(value: Binding($setting.privacyMaskIntensity), in: 0...100, step: 10)
            Image(systemSymbol: .eyeSlash)
        }
    }
} footer: {
    Text(.privacyMaskFooter)
}
```

**Binding convention (whole file uses it):** every Setting field is written through `Binding($setting.<field>)` off the view-local `@Shared(.setting) private var setting: Setting` (declared `AppearanceSettingView.swift:10`). No reducer action, no store scoping — the slider writes straight into `@Shared(.setting)`. This is the settingBinding-removal idiom; the new control needs **zero reducer changes** in `AppearanceSettingReducer` (see next).

### `AppearanceSettingReducer.swift` — no change needed for the slider

The reducer only bridges changes that must run an *effect* (e.g. `preferredColorSchemeChanged` at `AppearanceSettingReducer.swift:21,34-35` runs `applicationClient.setUserInterfaceStyle`). The privacy-mask slider has **no side effect** — it only mutates persisted `@Shared(.setting)`, read later by `AppReducer`'s scenePhase writer. So, per the file's own comment (lines 19-20: "writes … into `@Shared(.setting)`, which dispatches no action"), **add no action, no binding-bridge** for the mask. This is the "read/write shared state at the leaf" pattern — cite it so the planner does not add a spurious reducer case.

### `.xcstrings` add — `SettingFeature/Resources/Localizable.xcstrings` (D-15 new keys)

**Analog entry** (`background_blur_radius`, line 920 — the exact shape to copy for a plain translatable label; the catalog supports precisely these 6 locales: `en, de, ja, ko, zh-Hans, zh-Hant`):

```json
"background_blur_radius": {
  "extractionState": "manual",
  "localizations": {
    "en":      { "stringUnit": { "state": "translated", "value": "Background blur radius" } },
    "de":      { "stringUnit": { "state": "translated", "value": "Hintergrund-Unschärfe" } },
    "ja":      { "stringUnit": { "state": "translated", "value": "バッググラウンドぼかし度" } },
    "ko":      { "stringUnit": { "state": "translated", "value": "백그라운드 흐림 정도" } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "后台模糊效果" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "後台背景模糊" } }
  }
}
```

**Add TWO new keys following this exact shape** (both plain strings — no `%@`, no `%#@…@`; AGENTS.md numeric-format rules impose only the "fill every one of the 6 locales" duty):
- `privacy_mask` → label, e.g. en "Privacy Mask" (fill all 6 locales — translations owner/planner-supplied).
- `privacy_mask_footer` → footer, e.g. en "Blurs the app in the App Switcher and when it moves to the background." (fill all 6 locales).

**Access convention:** module-local keys are auto-exposed as `Text(.privacyMask)` / `Text(.privacyMaskFooter)` once present in the module's own catalog (mirrors `.backgroundBlurRadius`, `.detectsLinksFromClipboard`, `.networkDescription`). **No `ResourceStringSymbols.swift` entry** — that file is only for shared `Resources` catalog keys.

**Keys to DELETE** (RESEARCH §Enumeration 4 gives exact lines): `background_blur_radius` (920), `auto_lock` (879), `security` (4585) in this catalog; `auto_lock_reason` in AppFeature catalog; `auto_lock_policy.instantly`/`.never` in AppModels catalog. Keep shared `seconds`/`minutes`.

### `Package.swift` — `.testTarget` block (ONLY if planner elects the scenePhase test)

There is **no `AppFeatureTests` target or `AppPackage/Tests/AppFeatureTests/` dir today** (verified — `Tests/` has AppModelsTests, DetailFeatureTests, … but no AppFeature). Standing one up is a Wave-0 cost the planner must weigh (RESEARCH §Validation flags this). If elected, copy the smallest sibling `.testTarget` block (`Package.swift:933-939`, `appModelsTests`):

```swift
.testTarget(
    module: .appModelsTests,
    dependencies: [
        .module(.appModels)
    ],
    plugins: swiftLintPlugins
),
```

Required accompanying edits (three sites, mirroring every existing test target):
1. Add a `Module` enum case near `Package.swift:113-122`: `case appFeatureTests = "AppFeatureTests"`.
2. Add the `.testTarget(module: .appFeatureTests, dependencies: [.module(.appFeature), .targetDependency(.composableArchitecture)], plugins: swiftLintPlugins)` block in the targets array.
3. Create `AppPackage/Tests/AppFeatureTests/` with the test file; add it to `FeatureTests.xctestplan` if the suite is run through that plan.
4. Per AGENTS.md, a new module needs a `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml` at the test target root.

The convenience `static func testTarget(module:dependencies:…)` wrapper (`Package.swift:223-251`) already threads `sharedSwiftSettings` + swiftlint — no bespoke settings needed.

### Property rename ripple — `Setting.backgroundBlurRadius` → `privacyMaskIntensity` (D-11)

Full rename surface (every reference — classify each so the planner sees the whole blast radius as one analog-grouped list):

| Site | Role | Current | Action |
|------|------|---------|--------|
| `AppModels/Persistent/Setting.swift:16` | model (init param) | `backgroundBlurRadius: Double = 10,` | rename param |
| `AppModels/Persistent/Setting.swift:41` | model (init assign) | `self.backgroundBlurRadius = backgroundBlurRadius` | rename |
| `AppModels/Persistent/Setting.swift:92-110` | model (property + `didSet` coupling) | `public var backgroundBlurRadius: Double = 10 { didSet … }` + coupling comment | rename to `privacyMaskIntensity`, **drop the `didSet` entirely** (D-13) → plain `public var privacyMaskIntensity: Double = 10` |
| `AppReducer.swift:89` | reducer (inactive read) | `let blurRadius = …setting.backgroundBlurRadius` | rename ref (this is the value written to shared blur on inactive — D-05) |
| `AppReducer.swift:111` | reducer (active read) | same | rename ref (or delete — active sets shared blur `0`, D-05) |
| `AppReducer.swift:283` | reducer (launch reconcile) | same | rename or drop with the `becameInactiveDate` block (RESEARCH §Enumeration 3) |
| `GeneralSettingView.swift:123` | component (label) | `Text(.backgroundBlurRadius)` | **moves** to Appearance as `Text(.privacyMask)` (control relocates, D-10) |
| `GeneralSettingView.swift:126` | component (slider binding) | `Binding($setting.backgroundBlurRadius)` | **moves** to Appearance as `Binding($setting.privacyMaskIntensity)` |

No other module references `backgroundBlurRadius` (grep-verified across `AppPackage/Sources`, `App`, `ShareExtension`).

---

## Shared Patterns (cited, not re-derived — see RESEARCH.md)

### `@Shared(.inMemory)` blur key
**Source analog:** `AppSharedKeys.swift:68-72` (`greeting`).
```swift
extension SharedKey where Self == InMemoryKey<Greeting?>.Default {
    public static var greeting: Self {
        Self[.inMemory("greeting"), default: nil]
    }
}
```
New key follows this exactly with `InMemoryKey<Double>.Default` + `default: 0` (RESEARCH gives the copy-ready `privacyMaskBlur` shape). Declare it in this same file next to `greeting`.

### `.privacyMask()` self-sourcing modifier
**Source analog:** `ViewModifiers.swift:29-33` (`autoBlur`, body kept verbatim minus the floor).
```swift
public func autoBlur(radius: Double) -> some View {
    blur(radius: radius)
        .allowsHitTesting(radius < 1)
        .animation(.linear(duration: 0.1), value: radius)
}
```
Rewrite as a `struct PrivacyMaskModifier: ViewModifier` holding `@SharedReader(.privacyMaskBlur)` (read-only — the modifier never writes; RESEARCH §"Self-Sourcing Modifier"), body identical with `blur` value sourced from the shared reader. `AppComponents` already depends on `appModels`+`sharing`+`composableArchitecture`, so no new target dep.

### scenePhase → shared-blur write (the one non-mechanical behavior)
**Source analog:** `AppReducer.onScenePhaseChange` (82-136) folds `AppLockReducer`'s two writes: inactive → shared blur = `privacyMaskIntensity`; active → shared blur = `0`, plus the re-homed `fetchGreeting`/`detectClipboardURL` (D-06). See RESEARCH §Enumeration 3 (exact line table) + §Pitfall 1 (exactly-once launch-effect guard) — do not re-derive.

---

## No Analog Found

None. Every surface has an in-repo precedent:
- In-place model-property removal without migration → Phase 5 `enablesLandscape` (D-12 cites it).
- Module deletion + Package.swift target/enum removal → the DEP-01/DEP-03 de-vendor precedents (auto-derived product at `Package.swift:995-1002`, no standalone product line to touch).
- The scenePhase test target is the only *potentially new* artifact, and even it copies the `appModelsTests` block above — the planner's decision is whether to add it at all, not how.

## Metadata

**Analog search scope:** `AppPackage/Sources/{SettingFeature,AppComponents,AppModels,AppFeature}`, `AppPackage/Package.swift`, `AppPackage/Tests/`, the four `.xcstrings` catalogs, `App/`, `ShareExtension/`.
**Files scanned:** ~14 (targeted reads + grep sweeps).
**Pattern extraction date:** 2026-07-14
</content>
</invoke>
