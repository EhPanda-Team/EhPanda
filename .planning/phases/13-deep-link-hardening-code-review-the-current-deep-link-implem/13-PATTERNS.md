# Phase 13: Deep Link Hardening - Pattern Map

**Mapped:** 2026-07-23
**Files analyzed:** 16 new/modified files
**Analogs found:** 13 / 16 (3 files are first-of-kind, patterns drawn from RESEARCH.md)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| Pure parser type (D-13, new — module home at planner's discretion) | utility (pure namespace) | transform (URL → route) | `AppPackage/Sources/AppTools/FileUtil.swift` + existing `URLClient.swift` route logic | exact (namespace shape) + exact (route facts) |
| Parser unit test suite (new) | test | transform | `AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift` | exact (Swift Testing conventions) |
| `AppPackage/Sources/AppModels/Support/AppError.swift` (modified: `unsupportedDeepLink`) | model | request-response (error surface) | its own `cloudflareChallengeFailed` case (Phase 12) | exact |
| `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` (modified: new keys × 6 locales) | config | — | existing `app_error.cloudflare_challenge_failed*` entries | exact |
| `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` (modified: source-aware `handleDeepLink`, sleep removal) | reducer | event-driven | itself (existing effect/toast conventions) | exact |
| `AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift` (modified: parser migration, 500ms removal) | reducer | event-driven | `PresentationFeature.swift` (same toast/fetch shape) | exact |
| `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` (modified: sheet `onDismiss:`) | component | event-driven | its own `.sheet(item:)` at line 82 | exact |
| `ShareExtension/ShareViewController.swift` (modified: scheme rewrite) | controller | event-driven | `AppPackage/Sources/AppTools/Extensions/URL+Components.swift` (`replaceScheme`) | exact |
| `AppPackage/Sources/AppTools/Defaults.swift` (modified: host set, if D-12 hosts land here) | config | — | its own `Defaults.URL` §lines 63-66 | exact |
| Stub seam: launch-env flag resolution (D-06, new) | utility (DEBUG-gated) | event-driven | `AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift` | exact |
| Stub seam: `URLProtocol` subclass + fixture router (new) | service (DEBUG-gated) | request-response | none in repo — RESEARCH.md Code Examples §URLProtocol | no analog |
| Fixture constants / fixture HTML routing (new) | config | file-I/O | `AppPackage/Sources/TestingSupport/Resources/Parser/Gallery/GalleryDetail.html` + `TestFixtures.swift` | role-match |
| `EhPandaUITests/*.swift` (new XCUITest classes) | test (UI) | event-driven | none in repo (first UI target) — RESEARCH.md Patterns 7/8 | no analog |
| `EhPandaUITests/.swiftlint.yml` (new) | config | — | `AppPackage/Sources/URLClient/.swiftlint.yml` | exact (adjust depth) |
| `UITests.xctestplan` (new) | config | — | `AppPackage/Tests/FeatureTests.xctestplan` | exact |
| `EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme` (modified: second plan) | config | — | its own `<TestPlans>` block lines 30-35 | exact |
| New xcodeproj UI-test target (pbxproj edit) | config | — | none (all existing test targets are SPM) — RESEARCH.md Pattern 6 | no analog |

## Pattern Assignments

### Pure parser type (utility, transform) — D-11/D-13

**Analogs:** `AppPackage/Sources/AppTools/FileUtil.swift` (namespace shape) and `AppPackage/Sources/URLClient/URLClient.swift` (route facts to preserve; the code being replaced).

**Namespace shape** (`FileUtil.swift` lines 1-13) — Phase 8 D-06 precedent: pure helpers are static-member types, no `DependencyKey`, no `noop`/`unimplemented`:
```swift
import Foundation

public struct FileUtil {
    public static var logsDirectoryURL: URL {
        .documentsDirectory.appendingPathComponent(Defaults.FilePath.logs)
    }
    ...
}
```

**Route facts that must survive the rewrite** (`URLClient.swift`):
- Lines 36-43 — path decomposition the parser keeps (as `URLComponents`/`pathComponents` based):
```swift
private extension URL {
    var galleryRoute: GalleryRoute? {
        var components = pathComponents.dropFirst()
        guard let kind = components.popFirst(), let gid = components.popFirst() else { return nil }
        return GalleryRoute(kind: kind, gid: gid, token: components.first)
    }
}
```
- Lines 59-65 — `/s/` token is `<gid>-<page>` and carries the gid (returns `""` today — becomes optional, F2):
```swift
guard let token = route.token, let range = token.range(of: "-") else { return route.gid }
return String(token[..<range.lowerBound])
```
- Lines 46-48 — `isMPVURL` static migrates as-is:
```swift
public static func isMPVURL(_ url: URL?) -> Bool {
    url?.pathComponents.dropFirst().first == "mpv"
}
```
- **Defects NOT to copy:** line 52-53 substring host check (F1); lines 87-93 string-range `#c` extraction (F3 — use `url.fragment()`); lines 68-73 `resolveAppSchemeURL`'s `URL?` contract (F4 — normalize internally); lines 100-128 dependency/noop/unimplemented ceremony (F5 — delete entirely).

**Scheme normalization helper to reuse** (`AppPackage/Sources/AppTools/Extensions/URL+Components.swift` lines 17-21):
```swift
func replaceScheme(to newScheme: String?) -> URL? {
    modifyComponent(for: self) { components in
        components.scheme = newScheme
    }
}
```

**Host parity anchor** (`AppPackage/Sources/AppTools/Defaults.swift` lines 64-66) — D-12 exact-match set derives from `ehentai`/`exhentai` hosts + `www.` variants; `sexhentai` (`s.exhentai.org`) must stay excluded:
```swift
public static let ehentai: Foundation.URL = .init(string: "https://e-hentai.org/").forceUnwrapped
public static let exhentai: Foundation.URL = .init(string: "https://exhentai.org/").forceUnwrapped
public static let sexhentai: Foundation.URL = .init(string: "https://s.exhentai.org/").forceUnwrapped
```

**Call sites to migrate (F5):** `PresentationFeature.swift:63,157-158,166,173`, `CommentsReducer.swift:89,159,163,167`, `AppReducer.swift:161` (`checkIfHandleable` gate in `runLaunchAutomation` — an "explicit" source), `ReadingFeature` (`checkIfMPVURL`), `DownloadClient+ExecutionSupport.swift:193` (static `URLClient.isMPVURL`).

---

### `AppError.swift` + `Localizable.xcstrings` (model + config) — D-03

**Analog:** the `cloudflareChallengeFailed` case in the same file (Phase 12 D-10 precedent). Copy this exact five-touch pattern for `unsupportedDeepLink`:

1. Case declaration (`AppError.swift:19`): `case cloudflareChallengeFailed`
2. `isRetryable` (line 34): listed under non-retryable — `unsupportedDeepLink` is also non-retryable
3. `localizedDescription` (lines 56-57): `return String(localized: .appErrorCloudflareChallengeFailed)`
4. `alertText` (lines 92-93): `return String(localized: .appErrorCloudflareChallengeFailedDescription)`
5. `solution` (lines 117-118): `String(localized: .appErrorCloudflareChallengeSolution)` — the D-03 recovery suggestion naming what links EhPanda can open

`LocalizedError` conformance (lines 134-142) needs no change — `errorDescription`/`recoverySuggestion` derive automatically.

**Localization keys** — copy the catalog entry shape of `app_error.cloudflare_challenge_failed` in `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings`: snake-case dotted keys (`app_error.unsupported_deep_link`, `…_description`, `…_solution` mapping to `appErrorUnsupportedDeepLink*` symbols), `"extractionState": "manual"`, all 6 locales (en, de, ja, ko, zh-Hans, zh-Hant) with `"state": "translated"`. No numeric arguments expected; if any appear, use named `%#@variable@` substitutions per CLAUDE.md.

**ErrorInfo context** — `AppError+Context.swift:61-92`: the `ContextKey` whitelist deliberately has **no raw-URL slot**; `galleryFailure(url:action:reason:)` keeps only a validated decimal gid. The new case's context rows must follow this sanitization discipline (RESEARCH.md Security table flags this as a design point — do not put the raw URL into persisted `Context`).

---

### `PresentationFeature.swift` (reducer, event-driven) — D-01/D-02/D-14, F6/F7/F9

**Analog:** itself — the surrounding conventions are the pattern; only the defective lines change.

**Silent no-op + 1000ms sleep being fixed** (lines 156-170):
```swift
case .handleDeepLink(let url):
    let url = urlClient.resolveAppSchemeURL(url) ?? url
    guard urlClient.checkIfHandleable(url) else { return .none }   // F6: D-01 silent no-op
    var delay = 0
    if state.detail != nil {
        delay = 1000                                               // F6: magic sleep
        state.detail = nil
        state.path.removeAll()
    }
    let analysis = urlClient.analyzeURL(url)
    return .run { [delay] send in
        try await Task.sleep(for: .milliseconds(delay))
        await send(.fetchGallery(url: url, isGalleryImageURL: analysis.isGalleryImageURL))
    }
```

**Error-toast presentation pattern to copy for the D-01 unsupported-link failure** (lines 219-231) — this is the Phase 9 shape (also shows the 500ms sleep F7 to remove):
```swift
case .failure(let error):
    let context = Context.galleryFailure(
        url: url,
        action: "Fetch gallery",
        reason: error.localizedDescription
    )
    let errorInfo = ErrorInfo(error: error, context: context)
    // Let the loading toast animate out before showing the error toast.
    return .run { send in
        try await Task.sleep(for: .milliseconds(500))      // F7: remove; set .error directly
        await send(.setToast(.error(errorInfo)))
    }
```
Toast → ErrorInfoView tap wiring already exists (`TabBarView.swift:95-100` `.toast(..., onErrorTap:)` → `.presentErrorInfo`); the new failure rides it unchanged.

**Entry-source seam (F9):** `detectClipboardURL` (lines 144-154) currently funnels into the same `handleDeepLink`; either add `source:` to the action or pre-validate with the parser in the clipboard case (RESEARCH.md Pattern 2 — pre-validation keeps D-02 literally free). `AppReducer.swift:161` (launch automation) is a third caller, "explicit" source.

**Dismissal coordination (D-14):** `case .detail(.dismiss): state.path.removeAll()` (lines 80-82) is the existing dismiss handler the new completion action must not fight (RESEARCH.md Pitfall 6); gate re-present on explicit pending-link state.

**Reducer effect conventions to copy** (lines 199-212): `state.toast = .loading()` then `.run { do throws(AppError) { … } catch { … } }` with a typed request — the Phase 4 typed-throws shape any new effect follows.

---

### `TabBarView.swift` (component, event-driven) — D-14 sheet `onDismiss:`

**Analog:** its own detail sheet (lines 82-94):
```swift
.sheet(item: $store.scope(\.presentationState.$detail, action: \.presentation.detail)) { detailStore in
    NavigationStack(
        path: $store.scope(\.presentationState.path, action: \.presentation.path)
    ) {
        DetailView(store: detailStore, gid: detailStore.gid)
    } destination: { elementStore in
        galleryDestination(elementStore)
    }
    .privacyMask()
}
```
Change: add `onDismiss: { store.send(.presentation(.detailDismissalCompleted)) }` (name at planner's discretion). The view only reports the fact; the decision stays in the reducer (Phase 11 lifecycle rule; `lifecycle_modifiers` lint bans only `.onAppear/.onDisappear/.task` — `onDismiss:` is clean). The `onOpenURL` entry to keep as-is is line 104: `.onOpenURL { store.send(.presentation(.handleDeepLink($0))) }`.

---

### Toast loading→error hand-off (D-14, F7) — `SystemNotification/View+Toast.swift`

**Analog:** the overlay's own id-keyed rendering (lines 66-93):
```swift
.glassEffect(.regular, in: .capsule)
.id(id)
...
.transition(toastTransition)
...
// Scoped inside the overlay: the host view can mutate in the same transaction that
// presents or clears the toast, and must not inherit this animation.
.animation(toastAnimation, value: item != nil)
```
The content is already `.id(id)`-keyed with a transition; only `.animation(_, value: item != nil)` animates presence, not replacement. RESEARCH.md Pattern 4 option 1: key the animation on the presented toast's id so loading→error replacement cross-transitions; both reducers (`PresentationFeature.swift:227-230`, `CommentsReducer.swift:283-286`) then set the error toast directly with zero sleeps. Note the existing `.task(id:)` auto-dismiss timer (lines 74-87) restarts per toast id — replacement is already cancellation-safe there.

---

### `CommentsReducer.swift` (reducer, event-driven) — parser migration + F7

**Analog:** `PresentationFeature.swift` (same shapes). Its own non-handleable fallback stays (lines 158-164):
```swift
case .handleCommentLink(let url):
    guard urlClient.checkIfHandleable(url) else {
        return .run(operation: { _ in await applicationClient.openURL(url) })   // keep: browser fallback
    }
    let analysis = urlClient.analyzeURL(url)
    return .send(.fetchGallery(url: url, isGalleryImageURL: analysis.isGalleryImageURL))
```
Migrate `urlClient` calls to the pure parser; remove the 500ms sleep at lines 283-286 (uses caption-only `.error()` auto-hide — same toast mechanism applies).

---

### `ShareViewController.swift` (controller, event-driven) — F8

**Analog:** `AppTools/Extensions/URL+Components.swift` `replaceScheme(to:)` (excerpt above). The defect being replaced (lines 21-23):
```swift
if let shareURL = item as? URL, let scheme = shareURL.scheme,
   let replacedURL = URL(string: shareURL.absoluteString
                            .replacingOccurrences(of: scheme, with: "ehpanda")) {
```
Replace the whole-string `replacingOccurrences` with a `URLComponents`-backed scheme swap. Note: the ShareExtension target does not link `AppPackage` products today — either link `AppTools` or inline the tiny URLComponents mutation locally (planner's call; do not reintroduce string surgery).

---

### Stub seam launch-env resolution (utility, DEBUG-gated) — D-06

**Analog:** `AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift` — copy this exact shape for new `EHPANDA_UITEST_*` keys.

**DEBUG gating + env resolution** (lines 40-64):
```swift
public static var current: Self? {
    #if DEBUG
    resolve(environment: ProcessInfo.processInfo.environment)
    #else
    nil
    #endif
}

public static func resolve(environment: [String: String]) -> Self? {
    #if DEBUG
    ...
    let galleryURL = trimmedValue(
        environment: environment,
        key: "EHPANDA_AUTOMATION_GALLERY_URL"
    )
    .flatMap(URL.init(string:))
    ...
```
**Value hygiene helper** (lines 125-132):
```swift
private static func trimmedValue(environment: [String: String], key: String) -> String? {
    environment[key]
        .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        .flatMap(\.nonEmpty)
}
```
`AppLaunchAutomation` resolves at `AppReducer` `.runLaunchAutomation` / `onLaunchFinish` (`AppReducer.swift:153-170`) — but the URLProtocol registration and `prepareDependencies` must run **earlier** (before first dependency resolution); RESEARCH.md Open Question 3 recommends the app entry (`App/EhPandaApp.swift` — currently an 12-line shell calling into `AppFeature`; add a DEBUG hook there, keeping the shell thin).

**URLProtocol subclass + `prepareDependencies` clipboard override:** no repo analog — copy the skeletons in RESEARCH.md §Code Examples verbatim as starting points.

**Fixtures:** `AppPackage/Sources/TestingSupport/Resources/Parser/Gallery/GalleryDetail.html` (gid 2725078, 10 comments, 156 pages) is the content source; per RESEARCH.md Pattern 5, embed needed fixtures as `#if DEBUG` constants rather than linking `TestingSupport` into the app. `TestingSupport/TestFixtures.swift` shows the existing fixture-constant style.

---

### Parser unit test suite (test, transform)

**Analog:** `AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift` (lines 1-40) — the repo's Swift Testing conventions to copy:
```swift
@testable import AppFeature
import AppModels
...
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. ...
struct PresentationFeatureTests {
    @Test(arguments: [
        GalleryFailureRouteFixture(
            url: "https://e-hentai.org/g/123/secret-token?next=private",
            secret: "secret-token"
        ),
        ...
    ])
    @MainActor
    private func galleryFailureToastUsesSanitizedContext(fixture: GalleryFailureRouteFixture) async throws {
        let url = try #require(URL(string: fixture.url))
        ...
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init
        )
        await store.send(...)
```
Copy: `@Test(arguments:)` parameterized fixtures, `try #require(URL(string:))` (never force-unwrap — `force_unwrapping` is at error even in tests), sorted imports, `@MainActor` on members only for store-driving cases (pure parser tests need no `@MainActor`). Reducer-policy tests (entry-source, dismissal coordination) copy the `TestStore` usage in the same file.

---

### `UITests.xctestplan` (config)

**Analog:** `AppPackage/Tests/FeatureTests.xctestplan` (lines 1-21):
```json
{
  "configurations" : [
    { "id" : "C0DEC0DE-FEED-4A11-BEEF-FEA7011E5751", "name" : "Configuration 1", "options" : { } }
  ],
  "defaultOptions" : { "testTimeoutsEnabled" : true },
  "testTargets" : [
    { "target" : { "containerPath" : "container:AppPackage",
                   "identifier" : "AppFeatureTests", "name" : "AppFeatureTests" } }
  ]
}
```
Difference for the UI plan: `"containerPath" : "container:EhPanda.xcodeproj"` and `"identifier"` = the new target's PBX object ID; add `"testRepetitionMode" : "retryOnFailure"` / `"maximumTestRepetitions" : 3` for GUI runs (CLI needs `-retry-tests-on-failure -test-iterations 3` regardless — Xcode 26 regression, RESEARCH.md Pitfall 2).

### Scheme wiring (config)

**Analog:** `EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme` lines 30-35:
```xml
<TestPlans>
   <TestPlanReference
      reference = "container:AppPackage/Tests/FeatureTests.xctestplan"
      default = "YES">
   </TestPlanReference>
</TestPlans>
```
Add a second `<TestPlanReference reference = "container:UITests.xctestplan">` without `default` so the default run stays unit-only (D-07).

### `EhPandaUITests/.swiftlint.yml` (config)

**Analog:** `AppPackage/Sources/URLClient/.swiftlint.yml` — the entire file is:
```yaml
parent_config: ../../../.swiftlint.yml
```
For a repo-root-level `EhPandaUITests/` directory the depth is `parent_config: ../.swiftlint.yml`. Any new AppPackage module also gets one (AGENTS.md rule).

---

## Shared Patterns

### Error surface (toast → ErrorInfoView)
**Source:** `PresentationFeature.swift:219-231` (excerpt above) + `TabBarView.swift:95-100` (`onErrorTap` → `presentErrorInfo`) + `AppError+Context.swift:61-92` (sanitized context — no raw-URL slot).
**Apply to:** D-01 unsupported-link failure, D-04 fetch failure (unchanged).

### Presentation-driven lifecycle
**Source:** `PresentationFeature.swift:126-138` — presenting sends `.detail(.presented(.onPresented))`; no view `onAppear`. Any new coordination (D-14 re-present) must stay reducer-driven; views only report facts (`onDismiss:` is allowed).

### Pure-namespace helpers
**Source:** `FileUtil.swift` / Phase 8 D-06. Apply to the parser and any stub-seam helper: static members, no dependency ceremony, `Feature` suffix only for reducers (the parser is not one).

### DEBUG-only env seams
**Source:** `AppLaunchAutomation.swift:40-46` (`#if DEBUG` + `resolve(environment:)` testable split). Apply to every stub-seam piece; nothing test-only compiles into release.

### Lint-clean-from-start
**Source:** root `.swiftlint.yml` (all Phase 11 rules at error, tests included). Apply to parser, stub seam, and UI-test target: no `URL(string:)!` (use `try #require`/`XCTUnwrap`), sorted imports, no `try?`.

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason | RESEARCH.md Section |
|------|------|-----------|--------|---------------------|
| `EhPandaUITests/*.swift` XCUITest classes | test (UI) | event-driven | First UI-automation target; all 18 existing test targets are SPM Swift Testing | Patterns 7 (delivery matrix), 8 (share-sheet drive), Code Examples |
| xcodeproj UI-test target (pbxproj) | config | — | No existing xcodeproj test target to copy | Pattern 6 (target mechanics; GUI-creation fallback A4) |
| `URLProtocol` stub subclass | service | request-response | No network interception exists in the repo | Code Examples §URLProtocol stub skeleton |

Also note: the codebase has **zero** `accessibilityIdentifier` usages — the UI tests' assertion hooks on detail/reader/comments screens are net-new (Claude's-discretion item; RESEARCH.md Wave 0 Gaps).

## Metadata

**Analog search scope:** `AppPackage/Sources/**` (URLClient, AppFeature, DetailFeature, AppModels, AppTools, AppLaunchAutomationClient, SystemNotification, TestingSupport), `AppPackage/Tests/**`, `ShareExtension/`, `App/`, `EhPanda.xcodeproj/xcshareddata/`
**Files scanned:** ~20 read in full or targeted ranges
**Pattern extraction date:** 2026-07-23
