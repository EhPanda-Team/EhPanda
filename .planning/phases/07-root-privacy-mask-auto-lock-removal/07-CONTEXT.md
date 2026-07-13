# Phase 7: Root Privacy Mask & Auto-Lock Removal - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Two coupled refactors on the app's privacy surface, at behavior parity except for the intentional, owner-approved user-facing changes noted below:

1. **Root-level privacy mask (UIARCH-04)** — replace the `blurRadius` parameter-drilling (~22 view types take a `blurRadius` init param; `.autoBlur(radius:)` re-applied at ~41 sites) with **one self-sourcing mask per root surface** (app root + every one of the ~41 modal roots), driven by shared in-memory state. No view initializer takes `blurRadius`. No content leak in the App Switcher / when backgrounded, for any modal.
2. **Auto-lock removal (UIARCH-05)** — delete the custom biometric auto-lock (`AuthorizationClient`, `AutoLockPolicy`, the `isAppLocked`/`lockApp`/`authorize`/threshold machinery) and defer to iOS's built-in per-app lock. **Keep** the background/app-switcher blur (now reframed as the "Privacy Mask" control).

**Intended user-facing changes** (this phase is where they are allowed to break strict parity):
- The auto-lock Setting control is **removed** (no replacement description).
- The background-blur slider **relocates** from General → Appearance settings, reframed as "Privacy Mask".

Everything else (scene-phase blur timing, the blur effect itself, on-active side effects) stays at parity.

**Not in scope** (belongs to later phases): de-globalizing the other `*Util`/singletons (Phase 8), cookies→Keychain (Phase 8), structured error handling (Phase 9), the lint capstone (Phase 11). This phase does its own dead-code/dead-l10n cleanup only for the surfaces it removes.

</domain>

<decisions>
## Implementation Decisions

### Privacy-mask source & modifier (UIARCH-04)
- **D-01: Self-sourcing modifier.** Introduce a shared in-memory blur value, `@Shared(.inMemory("...blur..."), default: 0)` (matches the established `greeting` / `tagTranslator` / `appActivityLogs` in-memory-key idiom in `AppSharedKeys.swift`), and a **zero-argument** SwiftUI modifier that reads it internally. Each root surface simply attaches the modifier — no value is passed in, no per-root store scoping, no `blurRadius` init parameter anywhere. This makes the mask uniform and unmissable across all ~41 modal roots + the app root. (Rejected: passing the value explicitly per root, and SwiftUI `@Environment` — the latter is exactly the sheet/cover propagation boundary that made per-root masking necessary in the first place, so it's fragile for a leak-critical mask.)
- **D-02: Rename `.autoBlur` → `.privacyMask()`.** Every call site changes anyway (from `.autoBlur(radius: blurRadius)` to zero-arg), so rename for clarity and vocabulary-consistency with the new setting. Definition currently at `AppComponents/ViewModifiers.swift:29-33`.
- **D-03: NavBar-collapse workaround is DROPPED.** Owner confirms the "setting blurRadius to 0 collapses the NavigationBar" issue **no longer reproduces** on the current stack (iOS 26 + the Phase 5 navigation/adaptive-layout modernization). So there is **no `max(0.00001, radius)` floor** anywhere: the shared value is a true `0` when off, `N` when backgrounded, and the modifier applies a plain `.blur(radius:)`. **This overrides UIARCH-04's "NavigationBar-collapse workaround preserved" acceptance criterion.** Planning should include a light visual check that no navbar collapse occurs at radius `0`.
- **D-04: Keep the `allowsHitTesting(radius < 1)` guard** inside the modifier (cheap parity; blocks touches while the mask is up, interactive when off).

### Blur reducer & state (UIARCH-04)
- **D-05: Delete `AppLockReducer` + `AppLockState` entirely.** After lock removal the reducer is down to two trivial blur writes, so fold them directly into `AppReducer`'s existing `onScenePhaseChange` handler: **inactive → set shared blur = `privacyMaskIntensity`**, **active → set shared blur = `0`**. Remove the `Scope(\.appLockState, action: \.appLock, AppLockReducer.init)`, the `appLock` action case, and the `isAppLocked` lock-button overlay in `TabBarView`. (Matches the project's "remove emptied actions" + de-globalize ethos.)
- **D-06: Re-home the on-unlock side effects.** Today `AppReducer` runs "fetch greeting + detect clipboard" off `.appLock(.unlockApp)`. With lock gone, "became active" always means unlocked, so this logic moves to the became-active branch of the scenePhase handler. Preserve the behavior; only its trigger changes.
- **D-07: Blur is written on `.inactive`** (as today, before `.background`) so the App Switcher snapshot is already masked — keep this timing for the no-leak guarantee.

### Auto-lock removal & security section (UIARCH-05)
- **D-08: Remove the auto-lock control outright — no replacement description.** **This overrides UIARCH-05's criterion 3** ("replaced by a description pointing to the iOS built-in lock"). Rationale surfaced in discussion: iOS's built-in per-app lock ("Require Face ID", iOS 18+, universally available on the iOS 26 floor) is enabled via **touch-and-hold on the Home Screen app icon → Require Face ID** — there is no Settings URL or API that targets it, so any in-app "pointer" would be either dead prose or a misleading deep-link to the app's generic Settings page. Cleaner to simply remove it.
- **D-09: Remove the now-empty `Section(.security)`** in `GeneralSettingView` — it held only the auto-lock Picker + the blur Slider, both of which leave.

### Privacy-mask control relocation & naming
- **D-10: Relocate the blur control to the Appearance settings page**, positioned **under the tint-color row**, reframed as a **"Privacy Mask"** control (`AppearanceSettingView` / `AppearanceSettingReducer`). Keep the existing slider mechanics (0…100, step 10, eye / eye-slash icons); it now needs a visible **"Privacy Mask"** label (no section header gives it context there) plus a short footer explaining it blurs the app in the App Switcher / when backgrounded.
- **D-11: Rename the persisted property `Setting.backgroundBlurRadius` → `Setting.privacyMaskIntensity`.** "Intensity" over "radius" (owner pick) — product-friendly, describes strength without exposing the blur-radius-in-points detail; consistent with the `.privacyMask()` modifier and the UI label. Update every reference. The value still maps directly to `.blur(radius:)` points.

### Model / persistence changes (v1 in-place)
- **D-12: Remove `Setting.autoLockPolicy` and the `AutoLockPolicy` enum in place at v1** — same precedent as Phase 5's `Setting.enablesLandscape` removal. No `VersionedSchema` v2 / migration (established pre-release stance).
- **D-13: Delete the bidirectional `didSet` coupling** between `backgroundBlurRadius` and `autoLockPolicy` in `Setting.swift:92-110` (it referenced the now-gone policy). `privacyMaskIntensity` becomes a plain, independently-`0`-able value with **no `didSet`**.
- **D-14: `privacyMaskIntensity` default = `10`** (parity — privacy mask on by default, matching today's `backgroundBlurRadius` default). A dev's old persisted `backgroundBlurRadius` value won't decode under the renamed key and falls back to `10` — accepted pre-release, no migration.

### Cleanup mandate (owner directive — hard requirement)
- **D-15: Leave no orphans.** After the removals, delete **all now-unused code AND localization keys**:
  - **Code:** the `AuthorizationClient` module (`AppPackage/Sources/AuthorizationClient/`), its `Package.swift` target/product (`Package.swift:72,382-385`) and the two target deps (`:264` appFeature, `:643` settingFeature); the `AutoLockPolicy` enum + `autoLockPolicy` property; the `isAppLocked`/`lockApp`/`unlockApp`/`authorize`/`authorizeDone`/threshold/`becameInactiveDate` machinery; the `TabBarView` lock-button overlay; `GeneralSettingReducer.checkPasscodeSetting` + `passcodeNotSet` and the passcode-not-set warning triangle.
  - **L10n:** `.autoLockReason`, all `AutoLockPolicy.value` strings (never/instantly/15s/1m/5m/10m/30m), the `.security` section header (if unused after the section is removed), any passcode-not-set copy. New keys needed: the "Privacy Mask" label + its footer on the Appearance page (follow the project's `.xcstrings` l10n conventions in AGENTS.md).

### Leak-prevention audit (UIARCH-04 acceptance)
- **D-16: Audit that the app root AND every modal root applies `.privacyMask()`.** This is the no-content-leak guarantee — the reason the mask lives at each root rather than only the app root (SwiftUI sheets/covers present in separate windows the app-root overlay can't cover). The zero-arg modifier makes uniform application trivial; planning must enumerate the ~41 modal roots and confirm each is covered.

### Claude's Discretion
- Exact naming of the `@Shared(.inMemory)` key string, the `.privacyMask()` file/location, and the Appearance footer copy — left to planning, following existing conventions.
- Whether to add a light unit test for the scenePhase→shared-blur write (this phase is not a test phase; Phase 8 owns client-seam tests). Planner's discretion.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements & scope (authoritative)
- `.planning/REQUIREMENTS.md` §UIARCH-04, §UIARCH-05 — the acceptance criteria for both refactors. **Note the two owner overrides captured above: D-03 overrides UIARCH-04's "workaround preserved"; D-08 overrides UIARCH-05's "replaced by a description".**
- `.planning/ROADMAP.md` §"Phase 7: Root Privacy Mask & Auto-Lock Removal" — goal + 4 success criteria.
- `.planning/PROJECT.md` §Key Decisions — "Remove auto-lock (use iOS built-in per-app lock); keep background blur"; §Constraints — v1 in-place model edits, SwiftLint-as-error, parity bar.

### Project conventions
- `CLAUDE.md` / AGENTS.md — reducer `Feature`-suffix naming, `.xcstrings` localized-format rules (labeled numeric args; non-translated keys need every locale), SwiftLint-as-error (no suppressions), new-module `.swiftlint.yml` rule (N/A here — no new module; `AuthorizationClient` is being deleted).

No external ADRs/specs for this phase — requirements fully captured in the decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Most important files to read first
- `AppPackage/Sources/AppFeature/DataFlow/AppLockReducer.swift` — the whole lock+blur state machine; **deleted** in this phase (D-05), with the two blur writes folded into AppReducer.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` — `onScenePhaseChange` (lines ~82-136) drives inactive/active; the launch reconcile at ~280-297 seeds a lock check (simplify); `Scope` wiring at ~318 (remove); reacts to `.appLock(.unlockApp)` at ~176-183 (re-home per D-06).
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` — the single root reader of `blurRadius` (`store.appLockState.blurRadius`), the app-level modal roots (`newDawn`/`setting`/`detail` sheets at ~82-113), and the lock-button overlay (~75-80, remove). Natural home for the app-root `.privacyMask()`.
- `AppPackage/Sources/AppModels/Persistent/Setting.swift` — `backgroundBlurRadius` (~97-103) → rename to `privacyMaskIntensity`; `autoLockPolicy` (~104-110) + `AutoLockPolicy` enum (~201-225) → delete; the coupling `didSet`s (~92-110) → delete.
- `AppPackage/Sources/AuthorizationClient/AuthorizationClient.swift` — biometric client (LocalAuthentication/LAContext) → **delete the whole module** + Package refs.
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift` (~107-130) + `GeneralSettingReducer.swift` (~145-147) — the security section (auto-lock Picker + blur Slider) and the only other `AuthorizationClient` consumer (`passcodeNotSet`).
- `AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift` / `AppearanceSettingReducer.swift` — **destination** for the relocated "Privacy Mask" slider (under the tint-color row).
- `AppPackage/Sources/AppComponents/ViewModifiers.swift:29-33` — the `.autoBlur(radius:)` modifier → rewrite as zero-arg self-sourcing `.privacyMask()`.
- `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift` — where the new `@Shared(.inMemory)` blur key is declared (alongside `greeting`/`tagTranslator`).

### Reusable Assets / Established Patterns
- **`@Shared(.inMemory("key"), default:)`** already used for ephemeral cross-cutting state (`greeting`, `tagTranslator`, `appActivityLogs`) — the exact pattern for the mask value; readable from any module without drilling.
- **Every Setting screen reads `@Shared(.setting)` directly** (the settingBinding-removal refactor) — no parameter drilling; the mask follows the same "read shared state at the leaf" philosophy.
- **`blurRadius` drilling** currently threads through ~22 view types across HomeFeature/DetailFeature/SearchFeature/FavoritesFeature/DownloadsFeature/SettingFeature/ReadingFeature — every one loses the init param.

### Integration Points
- Scene-phase transitions (`AppReducer.onScenePhaseChange`) write the shared blur value; the `.privacyMask()` modifier reads it. That's the entire data flow after the refactor.

</code_context>

<specifics>
## Specific Ideas

- The relocated control belongs on the **Appearance** page **directly under the tint-color row** (owner-specified placement), labeled **"Privacy Mask"**.
- Value word is **"Intensity"**, not "radius" (owner pick), for the user-facing/property vocabulary.
- Owner is explicit that the phase must **remove dead l10n keys and dead code**, not just stop referencing them.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (De-globalizing the remaining `*Util`/singletons, cookies→Keychain, structured error surface, and the lint capstone are already scheduled as Phases 8/9/11.)

</deferred>

---

*Phase: 7-root-privacy-mask-auto-lock-removal*
*Context gathered: 2026-07-14*
