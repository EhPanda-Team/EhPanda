# Phase 7: Root Privacy Mask & Auto-Lock Removal - Research

**Researched:** 2026-07-14
**Domain:** In-repo Swift/TCA/SwiftUI refactor — privacy-mask consolidation + custom-auto-lock removal
**Confidence:** HIGH (pure codebase verification; every path/line cross-checked against current HEAD)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01: Self-sourcing modifier.** Shared in-memory blur value `@Shared(.inMemory("...blur..."), default: 0)` (matches the `greeting`/`tagTranslator` in-memory idiom) + a **zero-argument** SwiftUI modifier that reads it internally. Each root just attaches the modifier — no value passed, no per-root store scoping, no `blurRadius` init parameter anywhere. (Rejected: passing the value explicitly; SwiftUI `@Environment` — the latter is the sheet/cover propagation boundary that made per-root masking necessary, so it is fragile for a leak-critical mask.)
- **D-02: Rename `.autoBlur` → `.privacyMask()`.** Definition at `AppComponents/ViewModifiers.swift:29-33`.
- **D-03: NavBar-collapse workaround DROPPED.** No `max(0.00001, radius)` floor anywhere — the shared value is a true `0` when off, `N` when backgrounded; the modifier applies a plain `.blur(radius:)`. **Overrides UIARCH-04's "NavigationBar-collapse workaround preserved" criterion.** Include a light visual check for navbar collapse at radius `0`.
- **D-04: Keep the `allowsHitTesting(radius < 1)` guard** inside the modifier.
- **D-05: Delete `AppLockReducer` + `AppLockState` entirely.** Fold the two blur writes into `AppReducer.onScenePhaseChange`: **inactive → shared blur = `privacyMaskIntensity`**, **active → shared blur = `0`**. Remove the `Scope(\.appLockState, …)`, the `appLock` action case, and the `isAppLocked` lock-button overlay in `TabBarView`.
- **D-06: Re-home the on-unlock side effects.** The `.appLock(.unlockApp)` logic (fetch greeting + detect clipboard) moves to the became-active branch of the scenePhase handler. Preserve behavior; only the trigger changes.
- **D-07: Blur written on `.inactive`** (before `.background`) so the App Switcher snapshot is already masked.
- **D-08: Remove the auto-lock control outright — no replacement description.** **Overrides UIARCH-05's criterion 3.** iOS's built-in per-app lock ("Require Face ID", enabled via touch-and-hold on the Home Screen icon) has no Settings URL/API to target, so any in-app pointer would be dead prose or a misleading deep-link.
- **D-09: Remove the now-empty `Section(.security)`** in `GeneralSettingView` (held only the auto-lock Picker + blur Slider).
- **D-10: Relocate the blur control to Appearance**, under the tint-color row, reframed **"Privacy Mask"** (`AppearanceSettingView`/`AppearanceSettingReducer`). Keep slider mechanics (0…100, step 10, eye/eye-slash icons); add a visible **"Privacy Mask"** label + short footer explaining it blurs the app in the App Switcher / when backgrounded.
- **D-11: Rename `Setting.backgroundBlurRadius` → `Setting.privacyMaskIntensity`.** Update every reference; value still maps directly to `.blur(radius:)` points.
- **D-12: Remove `Setting.autoLockPolicy` and the `AutoLockPolicy` enum in place at v1** — no VersionedSchema v2 / migration (same precedent as Phase 5's `enablesLandscape` removal).
- **D-13: Delete the bidirectional `didSet` coupling** between `backgroundBlurRadius` and `autoLockPolicy` (`Setting.swift:92-110`). `privacyMaskIntensity` becomes a plain, independently-`0`-able value with **no `didSet`**.
- **D-14: `privacyMaskIntensity` default = `10`** (parity). Old persisted `backgroundBlurRadius` won't decode under the renamed key and falls back to `10` — accepted pre-release, no migration.
- **D-15: Leave no orphans.** Delete all now-unused code AND l10n keys (full surface enumerated below).
- **D-16: Audit that the app root AND every modal root applies `.privacyMask()`** — the no-content-leak guarantee. The zero-arg modifier makes uniform application trivial; planning must enumerate the modal roots and confirm each is covered.

### Claude's Discretion
- Exact naming of the `@Shared(.inMemory)` key string, the `.privacyMask()` file/location, and the Appearance footer copy — follow existing conventions.
- Whether to add a light unit test for the scenePhase→shared-blur write (this phase is not a test phase; Phase 8 owns client-seam tests). Planner's discretion.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (De-globalizing the remaining `*Util`/singletons, cookies→Keychain, structured error surface, and the lint capstone are already Phases 8/9/11.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UIARCH-04 | Root privacy mask: no view initializer takes `blurRadius`; mask applied only at root surfaces driven by shared in-memory state; no lock-time/background content leak in any modal. *(D-03 overrides the "NavigationBar-collapse workaround preserved" clause.)* | §Enumeration 1 (39 `.autoBlur` sites → `.privacyMask()`), §Enumeration 2 (22 view types shed the `blurRadius` param), §Modal-Root Audit (D-16 checklist + the one unmasked modal found), §Self-Sourcing Modifier design |
| UIARCH-05 | Remove `Setting.autoLockPolicy`, the biometric re-auth path, and `AuthorizationClient`. Retain background/app-switcher blur. *(D-08 overrides the "replaced by a description" clause — control removed outright.)* | §Enumeration 3 (full removal surface + Package.swift lines), §Enumeration 4 (dead l10n), §Hidden Coupling: launch greeting/clipboard flow |
</phase_requirements>

## Project Constraints (from CLAUDE.md / AGENTS.md)

- **Reducer `Feature`-suffix naming** — N/A for new reducers this phase (none added; `AppLockReducer` is deleted). Existing `AppReducer`/`AppearanceSettingReducer`/`GeneralSettingReducer` keep their names (pre-existing, not renamed).
- **Read root `.swiftlint.yml` before writing Swift** — done; see §SwiftLint Constraints. Resolve every violation at root; suppression/`disable` forbidden without explicit user permission.
- **`.xcstrings` localized-format rules** — numeric args as labeled `%#@variable@` substitutions; **string (`%@`) args stay positional**; module-local outer values never carry a bare numeric specifier; `en`/`de` substitution category sets must match, `ja`/`ko`/`zh-Hans`/`zh-Hant` are `other`-only. The two new keys (Privacy Mask label + footer) are **plain strings, no numeric args**, so these rules impose only the "fill every locale" duty.
- **Non-translated keys need every locale filled** — not applicable to the two new keys (they are translatable UI copy), but relevant if any retained key is `shouldTranslate:false`.
- **New-module `.swiftlint.yml`** — N/A (no new module; `AuthorizationClient` is being deleted, not added).
- **No absolute home paths / no local-project names in generated docs** — honored in this file.

## Summary

This is a two-part refactor entirely within the team's own Swift/TCA/SwiftUI code — no external libraries, no new packages, no dependency changes beyond **deleting** the `AuthorizationClient` module. The CONTEXT locks the full approach (D-01…D-16); the research value is verification and exhaustive enumeration, not exploration.

**Part A (UIARCH-04, privacy mask):** Today a `blurRadius: Double` is drilled from `AppReducer.appLockState.blurRadius` through **22 view types** and re-applied at **39 `.autoBlur(radius:)` call sites** (one per root/modal surface). The refactor introduces one `@Shared(.inMemory)` blur value written by `AppReducer.onScenePhaseChange` and read by a new zero-arg `.privacyMask()` modifier; every `blurRadius` init param and every `.autoBlur(radius:)` argument disappears. The mechanical 1:1 transform is `.autoBlur(radius: blurRadius)` → `.privacyMask()` at all 39 sites, plus deleting the param from all 22 initializers and their call sites.

**Part B (UIARCH-05, auto-lock removal):** Delete `AppLockReducer`, the whole `AuthorizationClient` module, `Setting.autoLockPolicy` + the `AutoLockPolicy` enum, the coupling `didSet`s, `GeneralSettingReducer.checkPasscodeSetting`/`passcodeNotSet`, the `TabBarView` lock-button overlay, and the dead l10n keys. Fold the two surviving blur writes into the scenePhase handler.

**Primary recommendation:** Implement Part A (modifier + shared key + param removal) and Part B (auto-lock deletion) as coordinated waves; treat the launch-time greeting/clipboard side-effect flow (§Hidden Coupling) as the single highest-risk seam — it currently rides the `.appLock(.unlockApp)` cascade and must be re-homed to the became-active branch with exactly-once semantics. The one genuinely surprising finding is a **modal root that is unmasked today** (`AppActivityLogsView`'s run-picker sheet), which the D-16 uniform-mask mandate now requires covering.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Privacy-mask blur value (source of truth) | App state (`@Shared(.inMemory)`) | AppReducer scenePhase writer | Ephemeral cross-cutting state, read from any module without drilling — same tier as `greeting`/`tagTranslator` |
| Writing the blur value on scene transitions | AppReducer (`onScenePhaseChange`) | SwiftUI scene env → `.onChange(of: scenePhase)` in `TabBarView` | Reducer owns side effects; the view only forwards the OS scenePhase signal |
| Rendering the mask | SwiftUI View modifier (`AppComponents`) | — | A leaf visual concern; self-sources the value, applied at each root window |
| Persisted mask intensity (user preference) | `Setting` model (`AppModels`) | AppearanceSetting UI | Durable preference in the existing whole-struct `@Shared(.setting)` |
| Per-app lock | **iOS platform** (built-in Require Face ID) | — | Removed from app entirely (D-08); the OS owns it, no app surface |

## Standard Stack / Package Legitimacy

**Not applicable — no external packages are added, upgraded, or verified this phase.** The only dependency-graph change is the **removal** of the in-repo `AuthorizationClient` local module and its two consumer target-deps (see §Enumeration 3). No `npm`/`pypi`/`crates`/SPM registry lookups are relevant. `LocalAuthentication` (an Apple SDK framework, imported only by the deleted module and the deleted `GeneralSettingReducer` import) leaves with the code that used it.

## Modal-Root Audit Method (D-16)

The mask must live at every **separately-presented root window**, because SwiftUI `.sheet`/`.fullScreenCover` present in a window the app-root overlay cannot cover. Empirically the codebase already follows exactly one rule that the audit should preserve:

- **NavigationStack roots** (tab content, the iPad detail sheet's stack) get one `.privacyMask()`.
- **Each `.sheet` / `.fullScreenCover` *presented content*** gets its own `.privacyMask()`.
- **Pushed navigation pages inherit the root window's mask** — they do NOT each need one (e.g. `CommentsView`'s list body is unmasked; only its `postComment` sheet carries its own mask). This is correct and should stay.

**Audit finding — one modal root is unmasked today:**
- `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:49` — `.sheet(isPresented: $isRunPickerPresented) { RunPickerSheet(...) }` has **no** `.autoBlur`/mask. It is a real (non-preview) separately-presented sheet. Under D-16's uniform mandate it should receive `.privacyMask()`. Content sensitivity is low (diagnostic run picker), but the mandate is uniform coverage. **Flag for the planner: this is a NEW mask site, not a rename.**

**Preview-only sheets to EXCLUDE from the audit** (they are `PreviewProvider` scaffolding using `.sheet(isPresented: .constant(true))`, not runtime roots): `AppComponents/NewDawnView.swift:174`, `DetailFeature/Components/TagDetailView.swift:126`, `ReadingFeature/ReadingView.swift:440` (`.fullScreenCover`), and the `_Previews` blocks in Detail/Home/Search/Setting views that pass `blurRadius: 0`.

## Enumeration 1 — `.autoBlur(radius:)` call sites → `.privacyMask()` (39 sites)

Every one is `.autoBlur(radius: blurRadius)` (or `store.appLockState.blurRadius`) today and becomes zero-arg `.privacyMask()`. Grouped by module; each corresponds to a root/modal surface.

### AppFeature — app root (`View/TabBar/TabBarView.swift`)
| Line | Surface |
|------|---------|
| 74 | Root `TabView` content (app root) |
| 84 | `newDawn` sheet content |
| 92 | `setting` sheet content (iPad modal Setting) |
| 110 | `detail` sheet `NavigationStack` content (iPad/deep-link modal detail) |

### DetailFeature
| Line | Surface |
|------|---------|
| `DetailView.swift:197` | `postComment` sheet |
| `DetailView.swift:201` | `newDawn` sheet |
| `DetailView.swift:205` | `tagDetail` sheet |
| `DetailView.swift:220` | `reading` fullScreenCover |
| `DetailView.swift:233` | `archives` sheet |
| `DetailView.swift:246` | `torrents` sheet |
| `DetailView.swift:253` | `folderManager` sheet |
| `DetailView.swift:257` | `share` (ActivityView) sheet |
| `Comments/CommentsView.swift:104` | `postComment` sheet |
| `DetailSearch/DetailSearchView.swift:46` | DetailSearch root content |
| `DetailSearch/DetailSearchView.swift:52` | DetailSearch nested (quick-search) sheet content |
| `Previews/PreviewsView.swift:75` | Previews root content |
| `Torrents/TorrentsView.swift:48` | `share` sheet inside Torrents |

### HomeFeature
| Line | Surface |
|------|---------|
| `Frontpage/FrontpageView.swift:41` | filters sheet content (`.inSheet` env set) |
| `Frontpage/FrontpageView.swift:53` | Frontpage root content |
| `Popular/PopularView.swift:39` | filters sheet content (`.inSheet`) |
| `Watched/WatchedView.swift:53` | Watched root content |
| `Watched/WatchedView.swift:59` | filters sheet content (`.inSheet`) |
| `Watched/WatchedView.swift:71` | second modal content |

### SearchFeature
| Line | Surface |
|------|---------|
| `SearchRootView.swift:44` | filters sheet content (`.inSheet`) |
| `SearchRootView.swift:57` | SearchRoot root content |
| `SearchView.swift:46` | Search root content |
| `SearchView.swift:52` | nested quick-search sheet content |
| `SearchView.swift:64` | filters sheet content |

### FavoritesFeature
| Line | Surface |
|------|---------|
| `FavoritesView.swift:64` | first sheet content |
| `FavoritesView.swift:76` | second sheet content |

### DownloadsFeature
| Line | Surface |
|------|---------|
| `DownloadsView.swift:63` | first sheet content |
| `DownloadsView.swift:70` | second sheet content |
| `DownloadsView.swift:81` | `reading` fullScreenCover content |
| `DownloadsView+Subviews.swift:107` | subview modal content |

### ReadingFeature
| Line | Surface |
|------|---------|
| `ReadingView.swift:107` | `readingSetting` sheet content |
| `ReadingView.swift:112` | `share` (ActivityView) sheet content |

### SettingFeature
| Line | Surface |
|------|---------|
| `AccountSetting/AccountSettingView.swift:53` | `webView` sheet content |
| `EhSetting/EhSettingView.swift:53` | `webView` sheet content |
| `Login/LoginView.swift:76` | `webView` sheet content |

**Total: 39 `.autoBlur` sites → 39 `.privacyMask()`.** Plus **+1 new** at `AppActivityLogsView.swift:49` (audit gap above) = **40 mask sites** after the phase. CONTEXT's "~41 modal roots" is the correct order of magnitude.

## Enumeration 2 — View types taking a `blurRadius` init param (22) + their call sites

Each type drops the `let blurRadius: Double` stored property, the `blurRadius:` initializer parameter, `self.blurRadius = blurRadius`, and every `blurRadius:` argument at its call sites (including the `_Previews` `blurRadius: 0` calls, which are simply removed).

| # | View type | File | Param decl (`let`/init/assign) | Notable call sites feeding it |
|---|-----------|------|-------------------------------|-------------------------------|
| 1 | `HomeView` | `HomeFeature/HomeView.swift` | 13, 17, 20 | `TabBarView:46`; internal 93/97/101/105/109/113; preview 185 |
| 2 | `FrontpageView` | `HomeFeature/Frontpage/FrontpageView.swift` | 14, 18, 21 | via HomeView; preview 84 |
| 3 | `PopularView` | `HomeFeature/Popular/PopularView.swift` | 13, 17, 20 | via HomeView; preview 67 |
| 4 | `WatchedView` | `HomeFeature/Watched/WatchedView.swift` | 15, 19, 22 | via HomeView; preview 117 |
| 5 | `ToplistsView` | `HomeFeature/Toplists/ToplistsView.swift` | 12, 16, 19 | via HomeView; preview 73 |
| 6 | `HistoryView` | `HomeFeature/History/HistoryView.swift` | 12, 16, 19 | via HomeView; preview 72 |
| 7 | `FavoritesView` | `FavoritesFeature/FavoritesView.swift` | 15, 19, 22 | `TabBarView:51`; internal 35; preview 129 |
| 8 | `SearchRootView` | `SearchFeature/SearchRootView.swift` | 13, 17, 20 | `TabBarView:56`; internal 87/91; preview 263 |
| 9 | `SearchView` | `SearchFeature/SearchView.swift` | 14, 18, 21 | via SearchRootView; preview 109 |
| 10 | `DownloadsView` | `DownloadsFeature/DownloadsView.swift` | 14, 18, 21 | `TabBarView:61`; internal 29/60/78; preview 320 |
| 11 | `DownloadGalleryCell`/subview | `DownloadsFeature/DownloadsView+Subviews.swift` | 16, 20, 23 | via DownloadsView |
| 12 | `SettingView` | `SettingFeature/SettingView.swift` | 10, 12, 14 | `TabBarView:66` & `:89`; internal 42/54/57; preview 163 — **note `public init`** |
| 13 | `AccountSettingView` | `SettingFeature/AccountSetting/AccountSettingView.swift` | 13, 15, 17 | `SettingView:42`; preview 185 |
| 14 | `LoginView` | `SettingFeature/Login/LoginView.swift` | 12, 17, 19 | `SettingView:54`; preview 154 |
| 15 | `EhSettingView` | `SettingFeature/EhSetting/EhSettingView.swift` | 12, 17, 19 | `SettingView:57`; preview 140 |
| 16 | `DetailView` | `DetailFeature/DetailView.swift` | 14, 18, 22 | `TabBarView:101`; `GalleryDestination:16`; preview 314 |
| 17 | `GalleryDestination` (helper + wrapper) | `DetailFeature/GalleryDestination.swift` | 10, 49, 56, 62 | `TabBarView:106`; feeds DetailView/Previews/Comments/etc. (16/21/28/33/71) |
| 18 | `CommentsView` | `DetailFeature/Comments/CommentsView.swift` | 17, 23, 31 | `GalleryDestination`; preview 255 |
| 19 | `DetailSearchView` | `DetailFeature/DetailSearch/DetailSearchView.swift` | 14, 18, 22 | `GalleryDestination`; preview 94 |
| 20 | `PreviewsView` | `DetailFeature/Previews/PreviewsView.swift` | 13, 17, 21 | `DetailView:217`/`GalleryDestination`; internal 72; preview 90 |
| 21 | `TorrentsView` | `DetailFeature/Torrents/TorrentsView.swift` | 12, 14, 18 | `DetailView:243`; preview 118 |
| 22 | `ReadingView` | `ReadingFeature/ReadingView.swift` | 28, 40, 45 | `DetailView:217`? no — `DetailView:214-218` fullScreenCover; `DownloadsView`; preview 444 |

**Drilling hubs to unwind (highest fan-out):** `TabBarView` (7 `blurRadius:` args, lines 46/51/56/61/66/89/101/106), `GalleryDestination` (the DetailFeature routing helper — passes `blurRadius` into 4 destinations), `HomeView` (6 internal passes), `SettingView` (3 internal passes). The `_Previews` providers all pass `blurRadius: 0`; those arguments simply vanish with the parameter.

## Enumeration 3 — Auto-lock removal surface (UIARCH-05, D-05/D-08/D-12/D-15)

### Whole files to DELETE
- `AppPackage/Sources/AppFeature/DataFlow/AppLockReducer.swift` — the entire lock+blur state machine (72 lines; **note: currently shows an uncommitted working-tree edit** removing the `max(0.00001, radius)` floor — see §CONTEXT Accuracy).
- `AppPackage/Sources/AuthorizationClient/` — the whole module: `AuthorizationClient.swift` (client, `AuthorizationClientKey` DependencyKey, `passcodeNotSet`, `localAuthroize`, live/noop/unimplemented) + the module's `.swiftlint.yml`.

### `AppReducer.swift` (`AppFeature/DataFlow/AppReducer.swift`) edits
| Location | Current | Action |
|----------|---------|--------|
| 25 | `var appLockState = AppLockReducer.State()` | delete |
| 46 | `case appLock(AppLockReducer.Action)` | delete |
| 87-91 | `.active`: reads `autoLockPolicy.rawValue` + `backgroundBlurRadius`, sends `.appLock(.onBecomeActive(...))` | rewrite: set shared blur = `0`; **add the re-homed greeting/clipboard effects (D-06)** |
| 110-112 | `.inactive`: reads `backgroundBlurRadius`, sends `.appLock(.onBecomeInactive(...))` | rewrite: set shared blur = `privacyMaskIntensity` |
| 176-183 | `case .appLock(.unlockApp):` → `fetchGreeting` (+ `detectClipboardURL` if enabled) | **re-home to the became-active branch (D-06), then delete this case** |
| 185-186 | `case .appLock: return .none` | delete |
| 280-297 | `case .setting(.loadUserSettingsDone):` reads `autoLockPolicy.rawValue`, sets `appLockState.becameInactiveDate = .distantPast`, conditionally sends `.appLock(.onBecomeActive(...))` | simplify: drop the threshold/`becameInactiveDate`/`onBecomeActive` block; **preserve the `detectClipboardURL` and launch-automation effects** (see §Hidden Coupling for the exactly-once concern) |
| 318 | `Scope(\.appLockState, action: \.appLock, AppLockReducer.init)` | delete |

### `TabBarView.swift` (`AppFeature/View/TabBar/`) edits
- 27 / 81: the outer `ZStack { ... }` exists only to host the lock button over the `TabView` — collapse it once the button is gone (**this ZStack removal also feeds POLISH-02**, but the button removal is in scope here).
- 46/51/56/61/66/89/101/106: `blurRadius: store.appLockState.blurRadius` args → remove (param gone).
- 74/84/92/110: `.autoBlur(radius: store.appLockState.blurRadius)` → `.privacyMask()`.
- 75-80: the lock `Button { store.send(.appLock(.authorize)) } label: { Image(.lockFill) } … .opacity(store.appLockState.isAppLocked ? 1 : 0)` → **delete**.

### `SettingFeature/GeneralSetting/` edits
- `GeneralSettingReducer.swift`:
  - 5: `import AuthorizationClient` → delete.
  - 1: `import LocalAuthentication` → delete (only the client used it).
  - 45: `public var passcodeNotSet = false` → delete.
  - 63: `case checkPasscodeSetting` → delete.
  - 69: `@Dependency(\.authorizationClient) private var authorizationClient` → delete.
  - 145-147: `case .checkPasscodeSetting: state.passcodeNotSet = authorizationClient.passcodeNotSet()` → delete.
  - *(Keep `navigateToSystemSetting`/`applicationClient` — unrelated.)*
- `GeneralSettingView.swift`:
  - 107-130: the whole `Section(.security)` (auto-lock `Picker` + `passcodeNotSet` warning triangle + blur `VStack`/`Slider`) → **remove the section (D-09)**; the blur control **relocates** to Appearance (D-10).
  - 155: `store.send(.checkPasscodeSetting)` in `.onAppear` → delete.

### `AppModels/Persistent/Setting.swift` edits (D-11/D-12/D-13)
- 16-17 / 41-42: init params `backgroundBlurRadius` (rename → `privacyMaskIntensity`) and `autoLockPolicy` (delete).
- 92-110: the coupled `didSet` block — rename `backgroundBlurRadius` → `privacyMaskIntensity` as a **plain `var … = 10` with no `didSet`**, and delete `autoLockPolicy` entirely (property + its `didSet`) plus the explanatory comment.
- 201-211: `public enum AutoLockPolicy: Int, …` → delete.
- 213-226: `extension AutoLockPolicy { public var value: … }` → delete (this is the sole consumer of `AutoLockPolicy`'s `.autoLockPolicyNever`/`.autoLockPolicyInstantly` + the shared `.seconds(count:)`/`.minutes(count:)` — the shared time keys stay, see §Enumeration 4).

### `Package.swift` edits (exact lines, verified at HEAD)
- **72:** `case authorizationClient = "AuthorizationClient"` in the `Module` enum → delete.
- **264:** `.module(.authorizationClient),` in the **appFeature** target deps → delete.
- **381-387:** the `.target(module: .authorizationClient, dependencies: [.targetDependency(.composableArchitecture)], plugins: swiftLintPlugins)` block → delete (CONTEXT said `382-385`; the full target spans **381-387**).
- **643:** `.module(.authorizationClient),` in the **settingFeature** target deps → delete.
- **Product:** there is **no explicit product line** — products are auto-generated at `Package.swift:995-1002` (`products: targets.filter{…}.map{ .library(name:$0, targets:[$0]) }`). Deleting the target + enum case removes the `AuthorizationClient` library product automatically. **(CONTEXT's "target/product (…:72,382-385)" is slightly imprecise: the product is derived, not a standalone line, and the target is 381-387.)**
- After edits, regenerate `AppPackage/Package.resolved` if the resolver touches it (it should not — no external dep changes). No test target references `AuthorizationClient` (verified: no `AuthorizationClientTests` dir; no refs in `App/`, `ShareExtension/`, or `AppPackage/Tests/`).

## Enumeration 4 — Dead l10n keys to remove + new keys to add

### Keys to DELETE (verified locations)
| Key | Catalog | Line | Symbol used at |
|-----|---------|------|----------------|
| `auto_lock_reason` | `AppFeature/Resources/Localizable.xcstrings` | 4 | `AppLockReducer.swift:63` (`String(localized: .autoLockReason)`) — deleted with the reducer |
| `auto_lock` | `SettingFeature/Resources/Localizable.xcstrings` | 879 | `GeneralSettingView.swift:110` (`Picker(.autoLock, …)`) — deleted with the section |
| `background_blur_radius` | `SettingFeature/Resources/Localizable.xcstrings` | 920 | `GeneralSettingView.swift:123` (`Text(.backgroundBlurRadius)`) — control relocates & renames |
| `security` | `SettingFeature/Resources/Localizable.xcstrings` | 4585 | `GeneralSettingView.swift:107` (`Section(.security)`) — **verify no other use before deleting** (grep confirms sole use is line 107) |
| `auto_lock_policy.instantly` | `AppModels/Resources/Localizable.xcstrings` | 1152 | `Setting.swift:219` (`.autoLockPolicyInstantly`) — deleted with `AutoLockPolicy` |
| `auto_lock_policy.never` | `AppModels/Resources/Localizable.xcstrings` | 1193 | `Setting.swift:217` (`.autoLockPolicyNever`) — deleted with `AutoLockPolicy` |

**No passcode-not-set copy key exists** — the "passcode not set" affordance is a bare `Image(systemSymbol: .exclamationmarkTriangleFill)` (`GeneralSettingView.swift:119`) with **no localized string**. CONTEXT's "any passcode-not-set copy" resolves to: nothing to delete in the catalogs (just the image + the `passcodeNotSet` state). Note this in the plan so no one hunts for a nonexistent key.

**Keys to KEEP (do NOT delete — shared, still used elsewhere):**
- `seconds` / `minutes` (shared, in `Resources/Resources/Localizable.xcstrings`, declared as labeled substitution funcs in `ResourceStringSymbols.swift:198,240`). After `AutoLockPolicy.value` is gone they are still used by `ReadingFeature/ReadingViewComponents.swift:40`, `AppModels/Support/AppError.swift:141,144`, and `Setting.swift` other paths. **Keep.**

### New keys to ADD (in `SettingFeature/Resources/Localizable.xcstrings`, the module that owns AppearanceSettingView)
Both are plain translatable strings (no numeric args → no `%#@…@` substitution, no positional `%@`), so the labeled-format rules impose only the "every supported locale" fill duty. Suggested identifiers (Claude's-discretion naming per D-01; follow the catalog's snake_case convention):
| Suggested key | Kind | Value (en) | Used at |
|---------------|------|-----------|---------|
| `privacy_mask` | label (`Text(.privacyMask)`) | "Privacy Mask" | new Appearance control label |
| `privacy_mask_footer` (or `privacy_mask_description`) | section/control footer | e.g. "Blurs the app in the App Switcher and when it moves to the background." | Appearance footer under the slider |

**Convention to follow (from existing keys):** module-local keys are auto-accessible as `Text(.privacyMask)` once added to the module's own `Localizable.xcstrings` (mirrors `.backgroundBlurRadius`, `.appearanceDisplayMode`, etc. — no hand-written symbol needed; only shared keys in `Resources` need `ResourceStringSymbols.swift` entries). Add every locale the catalog already supports; if either string is ever marked `shouldTranslate:false` it must still carry every locale (it should stay translatable, so this is moot).

## Self-Sourcing `.privacyMask()` Modifier — design notes

- **Where the value lives:** declare the in-memory key in `AppModels/Persistence/AppSharedKeys.swift`, alongside `greeting` (68-72) and `tagTranslator` (114-118), as `InMemoryKey<Double>.Default` with `default: 0`. Example shape (naming per D-01 discretion):
  ```swift
  extension SharedKey where Self == InMemoryKey<Double>.Default {
      public static var privacyMaskBlur: Self {
          Self[.inMemory("privacyMaskBlur"), default: 0]
      }
  }
  ```
- **Where the modifier lives:** `AppComponents/ViewModifiers.swift` (replacing `autoBlur` at 29-33). `AppComponents` **already depends on** `appModels` + `sharing` + `composableArchitecture` (verified `Package.swift:446-459`), so both the key type and `@Shared` are in scope — no new target dep needed.
- **Self-sourcing requires a `ViewModifier`/wrapper struct, not a free `View` extension func.** The current `autoBlur` is a plain `extension View { func … }`; to read `@Shared` internally the modifier must own the property (a `DynamicProperty`). Introduce a small `struct PrivacyMaskModifier: ViewModifier { @Shared(.privacyMaskBlur) var blur … }` (or an equivalent wrapper `View`) and expose `func privacyMask() -> some View { modifier(PrivacyMaskModifier()) }`. Keep the body at parity: `.blur(radius: blur).allowsHitTesting(blur < 1).animation(.linear(duration: 0.1), value: blur)` (D-04 keeps the hit-testing guard; D-03 drops the floor so a plain `.blur(radius:)` on a true `0`).
  - `pfw-sharing` skill note: `@Shared`/`@SharedReader` conform to `DynamicProperty`; a read-only mask should use `@SharedReader(.privacyMaskBlur)` inside the modifier since it never writes. `pfw-modern-swiftui` favors `ViewModifier` structs over stored-closure view extensions for anything holding state — this aligns.
- **Writer side:** `AppReducer` (`AppFeature`) already depends on `AppModels`; the scenePhase handler writes via `@Shared(.privacyMaskBlur) var …` on the reducer, or an injected write. Because both writer (`AppFeature`) and reader (`AppComponents`) resolve the same `.inMemory("…")` key, the value flows without any state scoping — this is the entire post-refactor data path.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-app lock / re-auth | The deleted `AuthorizationClient` biometric flow | iOS built-in "Require Face ID" (D-08) | The OS owns it universally on the iOS 26 floor; an in-app reimplementation is exactly what this phase removes |
| Cross-cutting mask value propagation | Threading `blurRadius` through initializers or SwiftUI `@Environment` | `@Shared(.inMemory)` (D-01) | Env doesn't cross the sheet/cover window boundary — the leak vector this phase closes |
| Mask animation/hit-test plumbing | New bespoke overlay | The existing `autoBlur` body, kept verbatim minus the floor | It's already correct; only its argument-sourcing changes |

## Runtime State Inventory

This is a rename/removal refactor; a grep finds files, not runtime state. Explicit sweep:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `@Shared(.setting)` persisted `Setting` blob in `UserDefaults` (`appStorage("setting")`) carries the old `backgroundBlurRadius` + `autoLockPolicy` keys for existing dev installs. | **No migration (D-14).** The renamed `privacyMaskIntensity` won't decode from the old key → falls back to default `10`; `autoLockPolicy` field is dropped and its old value is ignored on decode (synthesized Codable tolerates absent/extra fields → but a *removed required* field is fine; an *extra* stored key is ignored). Pre-release stance accepted. |
| Live service config | None — no external service embeds these names. | None. |
| OS-registered state | None. The iOS per-app lock (D-08) is user-configured on the Home Screen, not app-registered; nothing to set/unset. | None. |
| Secrets/env vars | None. `LocalAuthentication` needs no entitlement/Info.plist key that must be removed (`NSFaceIDUsageDescription` — **verify** whether Info.plist carries one solely for the deleted biometric flow; if present and unused after removal, delete it). | Verify Info.plist for a now-orphaned `NSFaceIDUsageDescription`. |
| Build artifacts | The `AuthorizationClient` module's build products / any `.build` cache; the SPM graph. | Regenerate after removing the target; run a clean build. No `Package.resolved` change expected (no external deps touched). |

**Info.plist check is the one open verification item** — the deleted biometric flow may have shipped with an `NSFaceIDUsageDescription`. Grep the app target's Info.plist during planning; if it exists only for the removed flow, remove it (leave-no-orphans, D-15).

## Common Pitfalls

### Pitfall 1: Losing (or double-firing) the launch greeting/clipboard side effects — HIGHEST RISK
**What goes wrong:** The greeting fetch + clipboard detection currently ride the `.appLock(.unlockApp)` cascade, and there are **two** launch-time paths that interact with the lock machinery.
**Why it happens (traced):**
- On first `.active` scenePhase, `onBecomeActive` finds `becameInactiveDate == nil` → takes the `else` branch → `.unlockApp` → `AppReducer:176` runs `fetchGreeting` (+ `detectClipboardURL` if enabled). **This is where launch greeting actually fires** (the default `autoLockPolicy == .never` = threshold `-1`).
- Separately, `loadUserSettingsDone` (`AppReducer:280-297`) guards `if threshold >= 0` — **false by default** (never = -1) — so it does NOT send `onBecomeActive`; it only runs `detectClipboardURL` at 288-290 and the launch-automation effects.
**How to avoid:** In the folded became-active branch (D-06), run `fetchGreeting` + conditional `detectClipboardURL` exactly as `.unlockApp` did. Then re-examine `loadUserSettingsDone`: it independently calls `detectClipboardURL` (288-290). Confirm the launch sequence does not now fire `detectClipboardURL` **twice** (once from became-active, once from `loadUserSettingsDone`) — trace the `hasLoadedInitialSetting` gate ordering (`onScenePhaseChange` returns `.none` until settings load; `loadUserSettingsDone` sets it true). Decide a single owner for launch clipboard detection.
**Warning signs:** greeting never appears on cold launch; or clipboard URL prompt appears twice.

### Pitfall 2: Removing a stored `autoLockPolicy` field but leaving a decode landmine
**What goes wrong:** `Setting` is a strict synthesized-Codable whole-struct with a `SchemaVersion` gate. Removing a property is safe (extra stored keys are ignored), but the `didSet` couplings (92-110) must be removed atomically with the property, or the model won't compile / an invariant references a gone enum.
**How to avoid:** Delete `autoLockPolicy` property + both `didSet` bodies + the `AutoLockPolicy` enum in one change; make `privacyMaskIntensity` a plain `var … = 10` (D-13). Do not bump `schemaVersion` (D-12).

### Pitfall 3: NavigationBar collapse at radius 0 (D-03 removed the floor)
**What goes wrong:** The historical `max(0.00001, radius)` floor existed because blur `0` once collapsed the NavigationBar. D-03 asserts this no longer reproduces on iOS 26 + Phase 5 nav modernization.
**How to avoid:** Include the light visual check D-03 mandates — background then foreground the app on a screen with a large-title NavigationBar and confirm no collapse when blur returns to `0`. If it *does* reproduce, escalate (D-03's premise would be wrong).

### Pitfall 4: Missing the unmasked modal root
**What goes wrong:** `AppActivityLogsView:49`'s run-picker sheet has no mask today; a pure "rename every `.autoBlur`" pass would leave it uncovered, violating D-16.
**How to avoid:** Treat it as a NEW `.privacyMask()` site (see §Modal-Root Audit).

## CONTEXT Accuracy / Line-Drift Corrections

Verified every CONTEXT line reference against HEAD. Findings:
- **`AppLockReducer.swift` has an uncommitted working-tree edit** (git status "M"): the `setBlurRadius` floor is already changed from `max(0.00001, radius)` → `radius` (the D-03 change, pre-applied but uncommitted). The file is deleted wholesale this phase, so the edit is moot — but the planner should know the working tree is not clean on this file.
- **Package.swift target span:** CONTEXT says `382-385`; the actual `.target(module: .authorizationClient …)` block is **381-387**. The enum case is correctly **72**. There is **no standalone product line** — the product is auto-derived (995-1002).
- **`AppReducer` line refs:** CONTEXT's "~82-136 onScenePhaseChange", "~280-297 launch reconcile", "~318 Scope", "~176-183 unlockApp" all **confirmed accurate** at HEAD.
- **In-memory idiom location:** CONTEXT lists `greeting`/`tagTranslator`/`appActivityLogs` as the `AppSharedKeys.swift` idiom. **Correction:** only `greeting` (68-72) and `tagTranslator` (114-118) live in `AppSharedKeys.swift`; the `appActivityLogs.currentRun`/`.currentRunLogs` in-memory keys live in a **separate** file, `SettingFeature/AppActivityLogs/AppActivityLogsSharedKeys.swift:9,15`. The pattern is identical and valid — declare the new blur key in `AppSharedKeys.swift` next to `greeting`.
- **`Setting.swift` line refs** (backgroundBlurRadius 97-103, autoLockPolicy 104-110, enum 201-225, didSet coupling 92-110): **confirmed accurate.**
- **`GeneralSettingView.swift` security section** at 107-130 and reducer `checkPasscodeSetting` at 145-147: **confirmed accurate.**
- **No passcode-not-set l10n key exists** (see §Enumeration 4) — CONTEXT's "any passcode-not-set copy" has no catalog target; only the warning `Image` + `passcodeNotSet` state are removed.

## Validation Architecture

`workflow.nyquist_validation` was not disabled in config, but per CONTEXT (Claude's Discretion) this is **not a test phase** and Phase 8 owns client-seam tests. Recommendation: **one small, high-value unit test is worthwhile**, everything else is manual parity/UAT.

### Recommended (planner's discretion, low cost, high value)
A `TestStore` test on `AppReducer.onScenePhaseChange` asserting the shared-blur write:
- `.inactive` → `@Shared(.privacyMaskBlur)` becomes `setting.privacyMaskIntensity`.
- `.active` → `@Shared(.privacyMaskBlur)` becomes `0`, and the re-homed `fetchGreeting`/`detectClipboardURL` effects fire (guarding Pitfall 1's exactly-once concern).

This directly protects the phase's one non-mechanical behavior (D-05/D-06 fold) and the regression-prone launch flow. `pfw-testing`/`swift-testing-pro` patterns apply; there is no existing `AppFeatureTests` target — check before adding (may need a Wave-0 target, which raises cost; if so, the manual check may suffice).

### Manual / UAT (not automatable cheaply)
- App-switcher no-leak audit across all 40 mask sites (D-16) — visual, per surface.
- NavigationBar-no-collapse-at-0 check (D-03).
- Auto-lock control gone from General; Privacy Mask control present under tint in Appearance with label + footer (D-09/D-10).

### Wave 0 Gaps
- [ ] Confirm whether an `AppFeature` test target exists; if not, the scenePhase test requires standing one up (raises cost — planner weighs against manual verification).
- [ ] No other test infrastructure gaps — this phase deletes more than it adds.

## Open Questions (RESOLVED)

All three were resolved during planning and adopted in executable plan content (Phase 7 plans 02/03/07/08).

1. **Info.plist `NSFaceIDUsageDescription`**
   - What we know: the deleted `AuthorizationClient` used `LocalAuthentication`/Face ID.
   - What's unclear: whether the app target's Info.plist declares `NSFaceIDUsageDescription` solely for that flow.
   - Recommendation: grep the app Info.plist during planning; remove if orphaned (D-15 leave-no-orphans). [ASSUMED it may exist — verify.]
   - **RESOLVED:** plan 07-03 (Task 2) deletes the orphaned `NSFaceIDUsageDescription` from both `App/Info.plist` and `App/InfoPlist.xcstrings`; plan 07-08 (Task 2) re-audits its absence by grep.
2. **Launch clipboard double-detection (Pitfall 1)**
   - What we know: `detectClipboardURL` fires from both the `.unlockApp` cascade and `loadUserSettingsDone`.
   - What's unclear: the exact scenePhase/settings-load ordering that decides whether both fire at cold launch today.
   - Recommendation: trace with a `TestStore` (or logging) before folding; pick a single launch owner for clipboard detection.
   - **RESOLVED:** plan 07-02 (Task 2) traces the cold-launch ordering, re-homes greeting/clipboard off `.appLock(.unlockApp)`, and mandates a single documented clipboard owner; plan 07-08 (Task 1) guards exactly-once with the `AppReducer.onScenePhaseChange` TestStore test.
3. **Should `AppActivityLogsView`'s run-picker sheet really be masked?**
   - What we know: it is an unmasked modal root; D-16 mandates uniform coverage.
   - What's unclear: whether the owner considers a diagnostic run-picker sensitive enough to matter.
   - Recommendation: apply `.privacyMask()` for uniform compliance (cheapest, mandate-aligned); surface to owner if they want an exception.
   - **RESOLVED:** plan 07-07 adds `.privacyMask()` to the `AppActivityLogsView:49` run-picker sheet as a NEW site (uniform D-16 compliance, total 40); flagged for owner exception if undesired.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | An `NSFaceIDUsageDescription` may exist in the app Info.plist for the removed biometric flow | Runtime State Inventory / Open Q1 | Low — a grep resolves it; leaving an orphaned key is a minor hygiene miss (D-15) |
| A2 | The launch greeting fetch fires via the first `.active` → `.unlockApp` cascade (not `loadUserSettingsDone`, which is `never`-gated off by default) | Hidden Coupling / Pitfall 1 | Medium — if the real trigger differs, the D-06 re-home could drop or double the greeting/clipboard effects |
| A3 | Deleting the `AuthorizationClient` target + enum case removes its auto-derived library product with no other Package.swift edit | Enumeration 3 | Low — the product-generation code at 995-1002 is explicit and verified |
| A4 | Suggested new l10n key names (`privacy_mask`, `privacy_mask_footer`) — naming is Claude's discretion (D-01); the values/placement are locked | Enumeration 4 | Low — cosmetic; planner/owner may rename |

## Sources

### Primary (HIGH confidence — direct codebase reads at HEAD, 2026-07-14)
- `AppPackage/Sources/AppFeature/DataFlow/AppLockReducer.swift`, `AppReducer.swift`; `View/TabBar/TabBarView.swift`
- `AppPackage/Sources/AppComponents/ViewModifiers.swift`
- `AppPackage/Sources/AppModels/Persistent/Setting.swift`; `Persistence/AppSharedKeys.swift`
- `AppPackage/Sources/AuthorizationClient/AuthorizationClient.swift`
- `AppPackage/Sources/SettingFeature/GeneralSetting/{GeneralSettingView,GeneralSettingReducer}.swift`; `AppearanceSetting/{AppearanceSettingView,AppearanceSettingReducer}.swift`; `AppActivityLogs/AppActivityLogsView.swift`
- `AppPackage/Package.swift` (module enum, targets, product generation)
- `.swiftlint.yml` (root); `AGENTS.md`/`CLAUDE.md`
- Repo-wide `grep` enumerations of `autoBlur`/`blurRadius`/`AuthorizationClient`/`autoLockPolicy`/`.sheet`/`.fullScreenCover` and the four `.xcstrings` catalogs
- `.planning/phases/07-…/07-CONTEXT.md`, `.planning/ROADMAP.md`

### Secondary / Tertiary
- None — no external/web research applicable to this in-repo refactor.

## Metadata

**Confidence breakdown:**
- Enumerations (mask sites, blurRadius types, removal surface, l10n): HIGH — grep + read verified, line numbers cross-checked.
- Package.swift edits: HIGH — exact lines confirmed; product-derivation understood.
- Launch side-effect re-home (Pitfall 1): MEDIUM — behavior traced by reading, not executed; A2 flagged.
- Info.plist Face ID key: LOW — not yet grepped (A1); planner to verify.

**Research date:** 2026-07-14
**Valid until:** ~2026-08-14 (stable in-repo refactor; only risk is further working-tree drift on the touched files before planning)
