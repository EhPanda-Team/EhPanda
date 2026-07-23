# Phase 13: Deep Link Hardening - Research

**Researched:** 2026-07-23
**Domain:** iOS deep-link routing (TCA reducers, URL parsing) + first-time XCUITest UI automation infrastructure
**Confidence:** HIGH on codebase facts and parsing rework; MEDIUM on XCUITest deep-link delivery mechanics (needs one Wave-0 probe)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Malformed-link failure UX (criterion 3)**
- **D-01:** An **explicit** open (`ehpanda://` scheme or ShareExtension hand-off) that cannot be recognized as a gallery link surfaces the Phase 9 error path: persistent tappable toast → `ErrorInfoView` with the URL and reason. The current silent no-op for explicit opens is the criterion-3 defect being fixed.
- **D-02:** **Clipboard** URLs that are not gallery links stay a **silent no-op** — the user never asked the app to open them; toasting would be noise. Only a recognized gallery link that then fails to resolve gets the error toast (as today).
- **D-03:** The unrecognized-link failure gets a **dedicated `AppError` case** (e.g. `unsupportedDeepLink`) with its own localized description and a recovery suggestion telling the user what links EhPanda can open — the Phase 12 D-10 precedent for genuinely new, user-actionable failure kinds. New `.xcstrings` keys follow the repo's localization conventions (labeled numeric arguments; non-translated keys filled for every locale).
- **D-04:** A well-formed gallery link whose fetch fails keeps the **existing error mapping** — `GalleryReverseRequest`'s `AppError` flows into the toast → `ErrorInfoView` with URL context. No deep-link-specific cause differentiation.

**UI test harness (criterion 2)**
- **D-05:** A **new XCUITest UI-testing bundle target** in `EhPanda.xcodeproj` — the project's first UI automation infrastructure (all 18 existing test targets are SPM unit-test bundles). Deep links are delivered with the modern system-open API (`XCUIDevice.shared.system.open`) for both cold-launch and warm-foreground variants.
- **D-06:** Tests run **hermetically**: a launch-environment flag makes the app swap in stubbed gallery responses (fixture data) so tests are deterministic, offline, and need no credentials. The stub seam's exact shape is planner detail; the thing under test — routing — stays real.
- **D-07:** The UI test target joins a **second test plan (e.g. `UITests.xctestplan`) on the existing `EhPanda` scheme**. `FeatureTests.xctestplan` (all unit tests) stays the default plan, so everyday `xcodebuild test` stays unit-only; UI tests run on demand via `-testPlan`.
- **D-08:** **iPhone is the primary simulator matrix.** iPad gets targeted coverage only for iPad-exclusive code paths (e.g. the `presentGalleryDetail` tab-modal entry).

**Test route coverage**
- **D-09:** Matrix density is **full on scheme, smoke elsewhere** (~8 UI tests): all three routes (`/g/` → detail; `/s/` → detail + reader at page; `#c` → detail + Comments at comment) plus the malformed-link error-toast test run via `ehpanda://` scheme opens, each in cold-launch and warm-foreground variants; clipboard, share sheet, and comments-view entries each get **one representative happy-path test**. Rationale: all entries converge on the shared consumption site (`DetailReducer+Fetch.swift:58`), so per-entry coverage only needs to prove the arrival leg.
- **D-10:** The ShareExtension entry is tested **true E2E through the real share sheet** (XCUITest drives Safari, opens the share sheet, taps the EhPanda extension, asserts the app lands on detail). Owner chose this over split coverage knowing share-sheet automation is the flakiest XCUITest kind — the planner budgets retries/waits for it.

**Parsing hardening**
- **D-11:** **Full `URLComponents` rebuild** of URL recognition/analysis: exact host matching, path-component route parsing, fragment-based `#c` extraction, optional-returning gallery-ID parsing (no more empty-string-on-failure). Closes the spoofable `absoluteString.contains(...)` host check (`https://evil.com/g/123/token?ref=https://e-hentai.org/` passes today).
- **D-12:** Recognized hosts are **`e-hentai.org`, `exhentai.org`, plus their `www.` variants**. `www.` links are real-world share targets that today fail silently; accepting them is a durability fix in the phase's spirit, and the exact-match check is still stricter overall than today's substring check.
- **D-13:** The `URLClient` **injected dependency is replaced by a pure parser type** (URL in → route/gid/token/page/commentID out), per the Phase 8 D-06 precedent that pure deterministic helpers are namespaces/values, not clients. Kills the `noop`/`unimplemented` ceremony; tests exercise real parsing. Call sites in `PresentationFeature`, `CommentsReducer`, `DetailReducer`, and `ReadingFeature` (`checkIfMPVURL`) migrate.
- **D-14:** **Both magic-number sleeps are root-fixed** with deterministic coordination: the 1000ms modal-dismissal wait in `handleDeepLink` (gates navigation correctness — a slow dismissal can race the re-present) and the 500ms loading-toast → error-toast gap (in both `PresentationFeature` and `CommentsReducer`). No timing-based sequencing remains in the routing path.

### Claude's Discretion
- The stub seam's mechanism for D-06 (how the launch-environment flag swaps dependencies inside the app process) and the fixture gallery content.
- The deterministic-coordination mechanism replacing each sleep (D-14) — e.g. driving the re-present from the dismissal completion seam, and whether the toast library exposes a dismissal hook or the gap is re-expressed as an explicit animation hand-off.
- The pure parser type's name and module home (D-13), within repo conventions.
- Accessibility identifiers or other assertion hooks the UI tests need on destination screens.
- `ErrorInfo` context rows carried by the new `AppError` case (Phase 9 D-06 precedent: planning detail).

### Deferred Ideas (OUT OF SCOPE)
- **Universal links (associated domains)** — opening `https://e-hentai.org/...` links directly from other apps without the `ehpanda://` scheme would be a new capability for a future phase; this phase covers only the existing scheme/share/clipboard entries.
- **MPV route support** — `/mpv/` URLs are recognized by `checkIfMPVURL` for the reader's internal use but are not an openable deep-link route today; adding them as one would be new capability, not hardening.
</user_constraints>

<phase_requirements>
## Phase Requirements

No requirement IDs are mapped to this phase (ROADMAP lists Requirements: TBD). The scope contract is the three ROADMAP §Phase 13 success criteria:

| ID | Description | Research Support |
|----|-------------|------------------|
| SC-1 | Hacky/fragile spots resolved at root, unchanged destination-routing behavior | Fragile-spot inventory (below), URLComponents rebuild pattern, D-14 deterministic-coordination options |
| SC-2 | UI automation tests exercise deep-link navigation E2E for supported routes | XCUITest target/plan wiring, deep-link delivery APIs, hermetic stub seam, fixture inventory |
| SC-3 | Malformed/unresolvable links fail gracefully (no crash, no unrecoverable silent no-op) | New `AppError` case conventions, entry-source differentiation (D-01 vs D-02), Context privacy rules |
</phase_requirements>

## Summary

The deep-link surface is small and well-centralized: four entries (`ehpanda://` scheme via `onOpenURL`, ShareExtension scheme-rewrite, clipboard detection, in-comment gallery links) all converge on `GalleryReverseRequest` → `DetailReducer.State(gallery:pendingDeepLink:)` → the single consumption site in `DetailReducer+Fetch.swift`. The hacky spots are precisely inventoried below: a spoofable substring host check, manual string-range parsing, an empty-string-on-failure gallery-ID parser, a whole-string scheme replacement in the ShareExtension, a `URL?`-returning scheme resolver with a confusing contract, two magic-number sleeps, and a silent no-op for unrecognized explicit opens. All are fixable at root with `URLComponents`-based parsing (a pure parser type replacing the injected `URLClient`), an entry-source distinction (explicit vs clipboard) feeding the Phase 9 error surface, and two deterministic coordination seams (sheet `onDismiss` completion for the modal re-present; id-keyed toast transition for the loading→error swap).

The genuinely new infrastructure is the UI test harness — the project's first xcodeproj test target (`objectVersion = 100`, folder-synchronized project format; all 18 existing test targets are SPM). Three externally-verified facts shape the plan: (1) `XCUIDevice.shared.system.open(_:)` exists (verified in the Xcode 26.6 SDK headers, `XCUIAutomation.framework`) but routes through the OS outside the test-launch context, so **launch-environment variables do not reach an app cold-launched that way** — the D-06 hermetic flag and D-05's cold-launch variants are in tension, and the header-documented alternative `XCUIApplication.open(_:)` (iOS 16.4+, "launches the application … using the provided URL", i.e. through the test harness where `launchEnvironment` applies) is the likely resolution, pending a Wave-0 probe because community reports questioned its URL delivery when it shipped; (2) on Xcode 26.x, test-plan `retryOnFailure` settings are broken for `xcodebuild` — retries must be passed as `-retry-tests-on-failure -test-iterations N` command-line flags (Apple engineer-confirmed forum thread; flags verified in local `xcodebuild -help`); (3) the iOS "Allow Paste" privacy prompt is effectively un-automatable (springboard taps reportedly fail; no grant API), so the clipboard representative test should stub the clipboard dependency behind the same launch-environment seam rather than fight the real pasteboard.

The app already contains a DEBUG-only launch-environment automation seam (`AppLaunchAutomation`, env keys `EHPANDA_AUTOMATION_*`, including `EHPANDA_AUTOMATION_GALLERY_URL` which routes straight into `.presentation(.handleDeepLink)`) — the D-06 stub seam should extend this exact precedent. Because the request layer defaults to `URLSession.shared` at every site (Phase 11 confirmed there is no network seam), the hermetic network stub belongs at `URLProtocol.registerClass` (which intercepts the shared session), serving the existing `TestingSupport` HTML fixtures (`GalleryDetail.html` with gid 2725078, 10 comments, 156 pages).

**Primary recommendation:** Split the phase into (A) parsing/error-surface hardening in `AppPackage` (pure parser + `AppError.unsupportedDeepLink` + D-14 fixes, all unit-testable in the existing SPM suites), and (B) the UI-test harness (xcodeproj target + `UITests.xctestplan` + URLProtocol stub seam + the ~11-test matrix), with a Wave-0 spike that probes `XCUIApplication.open(_:)` URL + env delivery on Xcode 26.6/iOS 26.5 before committing the cold-launch test mechanics.

## Project Constraints (from CLAUDE.md)

Directives the planner must carry into every plan (AGENTS.md at repo root, plus the user's global standards):

1. **Reducer naming**: any new reducer carries the `Feature` suffix (not `Reducer`). The pure parser (D-13) is not a reducer — it needs no suffix.
2. **SwiftLint**: read root `.swiftlint.yml` before writing Swift; all Phase 11 rules are at `error` (`force_unwrapping`, `optional_try` — enforced in test code too, `sorted_imports`, `multiline_function_chains`, `single_line_trailing_closure`, `lifecycle_modifiers`, `binding_initializer`, `unchecked_subscript_index_access`, `labeled_tuple_elements`). No suppressions without owner permission. **UI-test code is scanned too** — force-unwraps and `try?` habits common in XCUITest sample code are violations here.
3. **New module lint config**: a new module gets a `.swiftlint.yml` at its root with `parent_config` pointing at the repo root config (`parent_config: ../../../.swiftlint.yml` under `AppPackage/Sources`; `parent_config: ../.swiftlint.yml` for a top-level UI-test directory). Existing precedent: every `AppPackage/Sources/<Module>/.swiftlint.yml`.
4. **Localization**: new numeric format arguments use named `%#@variable@` substitutions with labeled Swift parameters; string arguments stay positional. `"shouldTranslate": false` keys still fill every locale. The `AppError` catalog is `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` (snake-case dotted keys, e.g. `app_error.cloudflare_challenge_failed`; 6 locales: en, de, ja, ko, zh-Hans, zh-Hant).
5. **Confirmation dialog/alert placement**: attach to the stable action source (not relevant to toasts, which are custom overlays, but relevant if any new alert appears).
6. **No absolute home paths in generated docs**; **never name other local projects** in artifacts.
7. User global: no workarounds/suppressions; prefer modern APIs (iOS 26 target unlocks everything through iOS 26 APIs); no thin wrappers.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| URL recognition/parsing (host, route, gid/token/page/commentID) | Pure parser type (value layer, D-13) | — | Deterministic function of the URL; no side effects, no client ceremony |
| Entry-source policy (explicit → error toast; clipboard → silent) | `PresentationFeature` reducer | — | The reducer receives both entries and owns toast/destination state |
| Deferred-intent landing (`/s/` → reader, `#c` → comments) | `DetailReducer+Fetch` consumption site | `GalleryNavigation` (push mapping) | Locked single consumption site; D-09's density argument rests on it |
| Modal re-present coordination (D-14, 1000ms) | `PresentationFeature` reducer state + sheet `onDismiss` seam in `TabBarView` | — | Dismissal *completion* is only observable at the view layer; the decision stays in the reducer |
| Toast loading→error hand-off (D-14, 500ms) | `SystemNotification` toast modifier (transition keying) | `PresentationFeature`/`CommentsReducer` (set state directly) | Replacement animation is a view concern; reducers stop sleeping |
| Unsupported-link error (D-01/D-03) | `AppModels` (`AppError` case + localization) | `PresentationFeature` (presentation) | Follows Phase 9/12 error-machinery layering exactly |
| ShareExtension scheme rewrite | `ShareExtension/ShareViewController` | — | Runs in the extension process; hardening is local (URLComponents scheme swap) |
| Hermetic stub seam (D-06) | App-process launch wiring (DEBUG-gated, `AppLaunchAutomation` precedent) | `URLProtocol` subclass for network; dependency overrides for clipboard | Stubs must live in the app process; the UI test only sets env vars |
| UI test target + plan (D-05/D-07) | `EhPanda.xcodeproj` + `UITests.xctestplan` + scheme `<TestPlans>` | — | XCUITest bundles are xcodeproj targets, not SPM |
| UI test assertions | New UI-test target (XCTest classes) | Accessibility identifiers on destination screens (discretion) | XCUIApplication API is XCTest-only; Swift Testing has no UI automation |

## Fragile-Spot Inventory (the code review — criterion 1)

Verified against source on 2026-07-23. Each row is a root-fix candidate; behavior parity per the locked routing contract.

| # | Location | Defect | Root fix direction |
|---|----------|--------|--------------------|
| F1 | `AppPackage/Sources/URLClient/URLClient.swift:52-53` | `absoluteString.contains(Defaults.URL.ehentai.absoluteString)` — spoofable substring host check; `https://evil.com/g/123/tok?ref=https://e-hentai.org/` passes | Exact host match on `URLComponents`/`url.host()` against the D-12 host set |
| F2 | `URLClient.swift:59-65` | `parseGalleryID` returns `""` on failure (empty-string sentinel) | Optional-returning parse in the pure parser (D-11) |
| F3 | `URLClient.swift:87-93` | `analyzeURL` finds `#c` by string-range search over `absoluteString` after `token + "/"` — misses `#c` when no trailing slash precedes the fragment, and does manual fragment math | `URLComponents.fragment` (`"c<ID>"` → strip prefix `c`) |
| F4 | `URLClient.swift:68-73` | `resolveAppSchemeURL` returns the *input* URL when the scheme is not `ehpanda` and `nil` only when `URLComponents` fails — confusing `URL?` contract, callers do `?? url` | Parser handles `ehpanda` scheme normalization internally; no optional round-trip |
| F5 | `URLClient.swift` (whole type) | Injected `@Dependency(\.urlClient)` with `noop`/`unimplemented` ceremony for a pure function | Replace with pure parser type (D-13); call sites: `PresentationFeature`, `CommentsReducer`, `ReadingReducer` (`checkIfMPVURL`), `AppReducer:161` (launch-automation gate), plus static `URLClient.isMPVURL` in `DownloadClient+ExecutionSupport.swift:193` |
| F6 | `PresentationFeature.swift:156-170` | `handleDeepLink`: `guard checkIfHandleable else return .none` — the D-01 silent no-op; and the 1000ms `Task.sleep` before `fetchGallery` when a modal was up | Entry-source-aware failure (explicit → `unsupportedDeepLink` toast; clipboard → silent) + dismissal-completion hand-off (D-14) |
| F7 | `PresentationFeature.swift:227-230` and `CommentsReducer.swift:283-285` | 500ms `Task.sleep` between clearing the loading toast and presenting the error toast | Id-keyed toast replacement transition (or `withAnimation(completionCriteria:)` hand-off); reducers set the error toast directly |
| F8 | `ShareExtension/ShareViewController.swift:22-23` | `absoluteString.replacingOccurrences(of: scheme, with: "ehpanda")` — replaces *every* occurrence of e.g. `https` anywhere in the URL string (query params containing `https` get corrupted) | `URL.replaceScheme(to: "ehpanda")` via the existing `URL+Components.swift` helper (URLComponents-backed) |
| F9 | `PresentationFeature.swift:144-154` | Clipboard entry funnels into the same `handleDeepLink` as explicit opens — D-01/D-02 need the entry source distinguished | Add a source discriminator (e.g. `handleDeepLink(URL, source:)` or clipboard pre-validation before sending) |
| F10 | `Defaults.URL` host set | `www.e-hentai.org` / `www.exhentai.org` links fail silently today | D-12: add `www.` variants to the recognized exact-match set (note: `s.exhentai.org` must NOT become a gallery host) |

Non-defects confirmed sound (do not touch): `GalleryDeepLink` enum + precedence initializer; the single consumption site (`DetailReducer+Fetch.swift:58-74`); `GalleryNavigation.appendGuardingDuplicate`; `updateReadingProgress` pre-seeding to `@Shared(.galleryHistory)`.

## Standard Stack

**No new third-party packages are required for this phase.** Everything is first-party Apple or already in the dependency graph.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation `URLComponents` / `URL.host()` / `pathComponents` / `fragment` | iOS 26 SDK | D-11 parsing rebuild | RFC-3986-aware; `url.host()` (iOS 16+) handles percent-encoding correctly `[VERIFIED: local SDK, iOS 26 target]` |
| XCTest / XCUIAutomation | Xcode 26.6 | UI test target (D-05) | `XCUIApplication`, `XCUIDevice.shared.system.open(_:)`, `XCUIApplication.open(_:)` all present in the local SDK headers `[VERIFIED: XCUIAutomation.framework headers, Xcode 26.6]` |
| ComposableArchitecture 1.25.3+ (existing pin) | existing | Reducer-side coordination (D-14), presentation state | Already the app architecture |
| swift-dependencies (existing, via TCA) | existing | `prepareDependencies` for launch-time overrides in the D-06 seam | Documented entry-point override mechanism `[VERIFIED: pfw-dependencies skill]` |
| TestingSupport fixtures (existing module) | local | `GalleryDetail.html` (36 KB, gid 2725078, 10 comments, 156 pages), `GalleryNormalImageURL.html`, list fixtures | Real parser-verified HTML the stub can serve `[VERIFIED: repo]` |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `URLProtocol.registerClass` | Hermetic network stub for `URLSession.shared` traffic | The request layer defaults to `.shared` at every site; registerClass intercepts exactly that session `[VERIFIED: repo grep + web cross-check]` |
| `xcodebuild -testPlan UITests -retry-tests-on-failure -test-iterations N` | Run UI plan with retries (D-10 flake budget) | Flags verified in local `xcodebuild -help`; **required on CLI because Xcode 26 ignores test-plan retry settings** `[CITED: developer.apple.com/forums/thread/813680]` |
| `XCUIApplication(bundleIdentifier:)` for `com.apple.mobilesafari` / `com.apple.springboard` | D-10 share-sheet drive; system-alert handling | Standard cross-app automation on simulator |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `URLProtocol.registerClass` network stub | Threading a `URLSession` seam through 50 request sites | Phase 11 explicitly deferred the network seam; retrofitting it now balloons scope far past this phase |
| Fixture HTML served by URLProtocol | Stubbing at a new "gallery client" dependency | No such dependency exists; requests are value types calling `URLSession` — a client refactor is out of scope |
| XCUITest bundle in xcodeproj | SPM-based UI tests | Not supported: XCUITest bundles must be app-hosted xcodeproj targets |
| XCTest classes for UI tests | Swift Testing | `XCUIApplication`/UI automation is XCTest-only; Swift Testing has no replacement `[VERIFIED: web, multiple sources]` — the swift-testing-pro skill does not apply to this target |

## Package Legitimacy Audit

No external packages are added by this phase. All tooling is first-party Apple (Foundation, XCTest/XCUIAutomation, xcodebuild) or already-pinned dependencies (ComposableArchitecture, swift-dependencies).

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
  ehpanda:// scheme        ShareExtension            Clipboard (cold launch     Comment link tap
  (onOpenURL,              (scheme rewrite →         / foreground)              (CommentsView)
   TabBarView:104)          openURL to app)          detectClipboardURL              │
       │                        │                        │                           │
       └────────┬───────────────┘                        │                           │
                ▼                                        ▼                           ▼
   PresentationFeature.handleDeepLink(url, source: .explicit)   (source: .clipboard)  CommentsReducer
                │                                                                    .handleCommentLink
                ▼                                                                        │
        ┌─ Pure parser (D-13) ──────────────────────────────────────────┐               │
        │  scheme normalize → host exact-match → route parse            │◄──────────────┘
        │  → GalleryRoute(gid, token, pageIndex?, commentID?)           │
        └──────┬──────────────────────────────────┬─────────────────────┘
     recognized│                        unrecognized│
               ▼                                    ▼
        fetchGallery                     source == .explicit ?
        (GalleryReverseRequest,            AppError.unsupportedDeepLink toast → ErrorInfoView (D-01/D-03)
         URLSession.shared ◄── UI tests    : silent no-op (D-02)
         intercept here via URLProtocol)
               │
        ┌──────┴───────┐
        ▼              ▼
     success        failure → existing error toast → ErrorInfoView (D-04)
        │
        ▼
  DetailReducer.State(gallery:, pendingDeepLink:)  ← modal (Presentation) or push (Comments delegate)
        │  .onPresented → fetchGalleryDetail
        ▼
  DetailReducer+Fetch consumption site (single):
     .reading(page:)  → presentReading (progress pre-seeded to @Shared(.galleryHistory))
     .comments(commentID:) → delegate(.pushComments(scrollCommentID:))
```

### Recommended Project Structure (new pieces only)

```
EhPandaUITests/                     # new xcodeproj UI-test target folder (synchronized root group)
├── .swiftlint.yml                  # parent_config: ../.swiftlint.yml (AGENTS.md rule)
├── DeepLinkUITests.swift           # scheme matrix: /g/, /s/, #c, malformed × cold/warm
├── DeepLinkEntryUITests.swift      # clipboard, share-sheet, comments-link representatives
└── Support/                        # launch helpers, env-key constants shared by convention
UITests.xctestplan                  # second plan on the EhPanda scheme (D-07)
AppPackage/Sources/<parser home>    # pure parser (D-13) — either reshaped URLClient module or AppTools
AppPackage/Sources/<stub seam>      # DEBUG-gated URLProtocol stub + fixture routing (D-06)
```

### Pattern 1: Pure parser replacing the injected client (D-13)

**What:** A namespace/value type, e.g. `GalleryURLParser` (name at planner's discretion), exposing pure functions; no `DependencyKey`, no `noop`/`unimplemented`.
**When to use:** Locked — Phase 8 D-06 precedent (`URLUtil`/`FileUtil` stayed pure namespaces; `AppInfo` modeled as uninhabited namespace).
**Example:**

```swift
// Shape sketch (planner refines; source: repo conventions + URLComponents docs)
public enum GalleryURLParser {
    public struct Route: Equatable, Sendable {
        public let gid: String
        public let token: String
        public let pageIndex: Int?     // from /s/<imgkey>/<gid>-<page>
        public let commentID: String?  // from #c<ID>
    }

    /// nil ⇔ not a recognized gallery link (drives D-01/D-02).
    public static func parse(_ url: URL) -> Route? {
        let url = normalizeAppScheme(url)   // ehpanda:// → https:// (F4 fix, internal)
        guard let host = url.host()?.lowercased(),
              Self.recognizedHosts.contains(host)   // D-12: exact match incl. www. variants
        else { return nil }
        var components = url.pathComponents.dropFirst()
        guard let kind = components.popFirst(), let second = components.popFirst()
        else { return nil }
        // /g/<gid>/<token>  |  /s/<imgkey>/<gid>-<page>
        ...
        // commentID: url.fragment().flatMap { $0.hasPrefix("c") ? String($0.dropFirst()) : nil }
    }

    public static func isMPVURL(_ url: URL?) -> Bool { ... } // existing static, migrates as-is
}
```

Existing route facts the parser must preserve exactly (verified in `URLClient.swift` + `AppError+Context.swift`): for `/g/` the gid is path slot 2; for `/s/` the *token* slot is `<gid>-<page>` and carries the gid; `GalleryDeepLink(pageIndex:commentID:)` gives page precedence over comment. `Defaults.URL.ehentai/exhentai` (`AppTools/Defaults.swift:64-65`) is the D-12 parity anchor; `s.exhentai.org` (line 66) is an image host, not a gallery host — it must stay out of the recognized set.

### Pattern 2: Entry-source differentiation (D-01/D-02, F9)

**What:** `handleDeepLink` learns where the URL came from, because the failure policy differs: explicit (scheme/share) → `unsupportedDeepLink` toast; clipboard → silent.
**How:** Either an associated `source` value on the action, or the clipboard path pre-validates with the parser and only sends recognized URLs (leaving `handleDeepLink` explicit-only). The second keeps D-02's "silent" literally free. Note the launch-automation gate at `AppReducer.swift:161` also calls the recognizer before sending `handleDeepLink` — it migrates to the parser and is an "explicit" source.

### Pattern 3: Deterministic modal re-present (D-14, 1000ms sleep)

**What goes wrong today:** `handleDeepLink` nils `state.detail` (a `.sheet` at `TabBarView.swift:82`) then sleeps 1000ms hoping dismissal animation finished before the new detail is presented; a slow dismissal races the re-present.
**Root fix:** SwiftUI reports dismissal *completion* via the sheet's `onDismiss:` parameter — the only place that fact is observable. Stash the pending link in reducer state; `.sheet(item:onDismiss:content:)` sends e.g. `.detailDismissalCompleted`; the reducer then presents the fetched gallery. The fetch itself can start immediately (it overlaps the dismissal today anyway) — only the *presentation* gates on completion. This stays reducer-driven (the view only reports a fact), consistent with the Phase 11 presentation-driven lifecycle rules; the `lifecycle_modifiers` lint regex bans `.onAppear/.onDisappear/.task` only, so `onDismiss:` is clean. `[VERIFIED: .swiftlint.yml:140]`
**Watch:** both `presentGalleryDetail` (iPad tab entry) and `handleDeepLink` share this sheet; `state.detail(.dismiss)` → `path.removeAll()` already runs on dismissal — the completion action must not fight that handler.

### Pattern 4: Deterministic loading→error toast hand-off (D-14, 500ms sleeps)

**What goes wrong today:** reducers clear the loading toast, sleep 500ms "to let it animate out", then set the error toast.
**Root fix options** (discretion):
1. **Direct replacement with id-keyed transition** — the toast overlay already renders content under `.id(state.id)` with a move/opacity transition (`View+Toast.swift:66-88`), but its `.animation(_, value: item != nil)` only animates presence, not replacement. Keying the animation on the presented toast's UUID makes a loading→error replacement animate as a cross-transition; reducers then set `.error(...)` directly with zero timing. Simplest, fully deterministic, view-only change.
2. **Explicit animation hand-off** — `withAnimation(_:completionCriteria:_:completion:)` (iOS 17+) around clearing the loading toast, presenting the error in the completion. More moving parts; only needed if the owner wants the two-step visual preserved exactly.
CommentsReducer's variant uses a caption-only `.error()` (auto-hide) — same mechanism applies.

### Pattern 5: Hermetic stub seam (D-06) — extend the existing automation precedent

**What exists:** `AppLaunchAutomationClient` reads `EHPANDA_AUTOMATION_*` env keys, `#if DEBUG` only, resolved at `appDelegate(.onLaunchFinish)`; `EHPANDA_AUTOMATION_GALLERY_URL` already drives `handleDeepLink` on launch. `[VERIFIED: repo]`
**Recommended shape:**
- A `EHPANDA_UITEST_STUB` (name at discretion) env flag, read DEBUG-only at process start (app entry or AppDelegate before the store's first effect).
- **Network:** a `URLProtocol` subclass registered via `URLProtocol.registerClass` — this intercepts `URLSession.shared`, which every deep-link-path request uses (`GalleryReverseRequest`, `GalleryDetailRequest` default `urlSession: URLSession = .shared`). Route by request path: `/g/…` and resolved gallery URLs → `GalleryDetail.html`-equivalent; `/s/…` → single-page HTML that parses to the fixture gallery URL; `api.php` → gdata JSON; list endpoints → list fixtures (keeps the Home tab quiet). Sessions with custom configurations are NOT intercepted by registerClass — audit any (Kingfisher image loading uses its own session; images will fail to placeholders, which routing assertions tolerate). `[VERIFIED: web cross-check + repo grep]`
- **Clipboard:** override `\.clipboardClient` via `prepareDependencies` (documented entry-point mechanism from swift-dependencies: call once, as early as possible, before any `@Dependency` is resolved) returning a URL from e.g. `EHPANDA_UITEST_CLIPBOARD_URL` and a fresh change count — this sidesteps the un-automatable "Allow Paste" prompt while keeping reducer routing real. `[VERIFIED: pfw-dependencies skill]`
- **Fixture content:** `TestingSupport` has real, parser-verified HTML — but `TestingSupport` must not link into release. Options: (a) embed the needed fixtures as `#if DEBUG` string constants in the stub module (compiled out of release entirely — cleanest for "no leak into release"); (b) app links `TestingSupport` unconditionally (rejected: ships test HTML in release resources). Fixture-internal URLs must be made consistent with the deep-link URLs the tests use (see Pitfall 6).
- The comments-route test needs a fixture comment whose ID matches the `#c<ID>` used by the test; the comments-view entry test additionally needs a comment *containing a gallery link*. Check/extend the fixture comments accordingly.

### Pattern 6: UI test target + plan wiring (D-05/D-07)

- The xcodeproj is `objectVersion = 100` with `PBXFileSystemSynchronizedRootGroup` folders — a new UI-test target is: one `PBXNativeTarget` (`productType = "com.apple.product-type.bundle.ui-testing"`), a synchronized root group for its folder, a target dependency on the app, `TEST_TARGET_NAME = EhPanda` in build settings, and a `TestTargetID` entry in the project's `TargetAttributes`. `[VERIFIED: repo pbxproj format; target mechanics ASSUMED from standard Xcode project structure — creating it via Xcode GUI in a checkpoint is the low-risk path, hand-editing is feasible]`
- `UITests.xctestplan` JSON references the xcodeproj target (`"containerPath" : "container:EhPanda.xcodeproj"`, `"identifier"` = the target's PBX object ID). Include retry defaults for documentation, but do not rely on them (Pitfall 2):

```json
{
  "configurations" : [ { "id" : "…", "name" : "Configuration 1", "options" : { } } ],
  "defaultOptions" : {
    "testTimeoutsEnabled" : true,
    "testRepetitionMode" : "retryOnFailure",
    "maximumTestRepetitions" : 3
  },
  "testTargets" : [
    { "target" : { "containerPath" : "container:EhPanda.xcodeproj",
                   "identifier" : "<target PBX ID>", "name" : "EhPandaUITests" } }
  ]
}
```

- The shared scheme gains a second, non-default `<TestPlanReference>` beside `FeatureTests.xctestplan` (which keeps `default = "YES"`), so `xcodebuild test -scheme EhPanda` stays unit-only and UI runs use `-testPlan UITests`. `[VERIFIED: EhPanda.xcscheme structure]`
- Primary destination: iPhone (D-08). Available now: iPhone Air, iOS 26.5 (booted); iPad Pro 11-inch (M5) for the `presentGalleryDetail` iPad-modal test.

### Pattern 7: Deep-link delivery in tests (D-05) — the delivery matrix

| Variant | Mechanism | Env delivery | Confidence |
|---------|-----------|--------------|------------|
| Warm foreground | `app.launchEnvironment = stub; app.launch()` then `XCUIDevice.shared.system.open(URL(string: "ehpanda://…")!)` | env applied at launch — safe | HIGH (API verified in SDK) |
| Cold launch (preferred candidate) | `app.launchEnvironment = stub; app.open(url)` — `XCUIApplication.open(_:)`, header: "Launches the application synchronously using the provided URL … similar to the behavior of -launch" | header-implied yes ("The environment that will be passed to the application on launch") — **Wave-0 probe required** | MEDIUM `[CITED: XCUIAutomation.framework/Headers/XCUIApplication.h]` |
| Cold launch (fallback A) | `XCUIDevice.shared.system.open` after `app.terminate()` | **env NOT delivered** — the OS launches the app outside the test-launch context; stub seam inert; test hits real network | HIGH (mechanism); this is why plain system.open can't be the cold path |
| Cold launch (fallback B) | `app.launch()` with `EHPANDA_AUTOMATION_GALLERY_URL=<link>` + stub flag — the app's own launch-automation deep-link entry | env applied; exercises `handleDeepLink` at launch-ready, not `onOpenURL` scheme delivery (scheme delivery still proven by the warm variant) | HIGH (seam verified in repo) |

Assert arrival with `app.wait(for: .runningForeground, timeout:)` then destination-screen queries. If the Wave-0 probe shows `XCUIApplication.open(_:)` drops the URL (as 2023-era reports claimed for its introduction), use fallback B for cold variants and keep `system.open` for warm — the combination still covers scheme registration + `onOpenURL` (warm) and launch-time routing (cold).

### Pattern 8: Share-sheet E2E drive (D-10)

```swift
let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
safari.launch()
// navigate to the gallery URL (address bar type + return); do NOT wait for page load —
// sharing only needs the URL, and the real site may be slow/Cloudflare-walled
safari.textFields["Address"].tap()  // identifier varies by iOS version — probe on 26.5
safari.typeText("https://e-hentai.org/g/2725078/<token>/\n")
safari.buttons["ShareButton"].tap()
let cell = safari.collectionViews.cells["EhPanda"]   // may require scrolling the activity view
XCTAssertTrue(cell.waitForExistence(timeout: 10)); cell.tap()
let app = XCUIApplication()
XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
// assert detail screen
```

Safari's chrome identifiers ("Address"/"TabBarItemTitle", "ShareButton") drift across iOS versions — treat them as probe-and-pin values, not constants. `[ASSUMED — verify on iOS 26.5 sim during implementation]` The extension is registered for web URLs (`NSExtensionActivationSupportsWebURLWithMaxCount = 1` `[VERIFIED: ShareExtension/Info.plist]`). Note the Safari leg inherently touches the real network for the page load (the app side stays hermetic); the app must be pre-launched with the stub env in the same test before driving Safari, so the share-sheet hand-off foregrounds the already-stubbed instance rather than cold-launching an unstubbed one.

### Anti-Patterns to Avoid

- **String-search URL parsing** (`absoluteString.contains/range(of:)`) — the class of defect this phase deletes; never reintroduce in the parser or ShareExtension.
- **`sleep`/`Task.sleep` sequencing in reducers or UI tests** — reducers use completion seams (Patterns 3/4); tests use `waitForExistence`/`wait(for:timeout:)`.
- **`addUIInterruptionMonitor` for system alerts** — unreliable for years; query the alert (app or springboard) directly, and for "Allow Paste" don't fight it at all (stub the clipboard).
- **Force-unwraps and `try?` in UI-test code** — both are at `error` severity repo-wide, including test sources.
- **Stubbing the router itself** — D-06 draws the line: dependencies/network are stubbed; parsing and routing stay real.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| URL decomposition | Custom string scanning | `URLComponents`, `url.host()`, `pathComponents`, `fragment` | Percent-encoding, IDN, edge shapes are already solved |
| Waiting for UI state in tests | Polling loops / sleeps | `XCUIElement.waitForExistence`, `XCUIApplication.wait(for:timeout:)` | Built-in, event-driven, the standard flake reducer |
| Test retries (D-10 budget) | Custom retry loops inside tests | `xcodebuild -retry-tests-on-failure -test-iterations N` (+ `-test-repetition-relaunch-enabled YES` for process-fresh reruns) | Per-test relaunch semantics you can't replicate in-process; CLI flags required on Xcode 26 |
| Network interception | A bespoke HTTP layer or seam retrofit | `URLProtocol` subclass + `registerClass` | Intercepts `URLSession.shared` exactly where all 50 request sites already point |
| Launch-time dependency swaps | Ad-hoc globals | `prepareDependencies` + existing `AppLaunchAutomation` env precedent | The library's documented entry-point override; the repo already has the env-key pattern |

**Key insight:** this phase needs zero new dependencies — its risk is not "what library", it's the three environmental traps (env-vars-on-cold-launch, Xcode 26 retry regression, Allow Paste) documented under Pitfalls.

## Runtime State Inventory

This is a refactor phase (no rename/migration), but the checklist was run explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `@Shared(.galleryHistory)` reading-progress records written by `/s/` links — shape unchanged by this phase | None (behavior parity; verified both `updateReadingProgress` sites keep gid/token/progress semantics) |
| Live service config | None — no external service holds deep-link config | None |
| OS-registered state | `ehpanda` scheme registration in `App/Info.plist` (`CFBundleURLTypes`) — unchanged; simulator caches scheme→app bindings per install, fresh installs re-register | None (do not rename the scheme) |
| Secrets/env vars | New DEBUG-only `EHPANDA_UITEST_*` env keys join the existing `EHPANDA_AUTOMATION_*` family — additive | Document keys beside `AppLaunchAutomation` |
| Build artifacts | New target/plan alter `xcodebuild` surface; default plan behavior preserved by keeping `FeatureTests.xctestplan` default | Verify `xcodebuild test -scheme EhPanda` still runs unit-only after wiring |

## Common Pitfalls

### Pitfall 1: `launchEnvironment` does not reach a cold launch triggered by `XCUIDevice.shared.system.open`
**What goes wrong:** D-05 says system-open for cold + warm; D-06 says a launch-env flag arms the stub. A terminated app opened via `system.open` is launched by the OS default-handler path — the test's env dict is not applied; the app cold-starts unstubbed and hits the real network.
**Why it happens:** `launchArguments`/`launchEnvironment` are applied by the test harness's launch sequence (`launch()`/`open(_:)`/re-`activate()`); `XCUISystem.open` is an OS-level action. `[CITED: XCUIApplication.h header semantics; community reports]`
**How to avoid:** Wave-0 probe of `XCUIApplication.open(_:)` (delivers URL through the harness launch, header-documented); fall back to the repo's own `EHPANDA_AUTOMATION_GALLERY_URL` launch entry for cold variants if the probe fails (Pattern 7 table).
**Warning signs:** cold-launch tests pass locally with network but hang/fail offline; loading toast persists.

### Pitfall 2: Xcode 26 ignores test-plan retry settings under `xcodebuild`
**What goes wrong:** `UITests.xctestplan` carries `retryOnFailure`, but `xcodebuild` on Xcode 26.x runs each test once — the D-10 flake budget silently evaporates.
**How to avoid:** pass `-retry-tests-on-failure -test-iterations 3` (and consider `-test-repetition-relaunch-enabled YES`) on every scripted UI-test invocation; keep the plan settings for Xcode-GUI runs. `[CITED: developer.apple.com/forums/thread/813680 — Apple engineer confirmed; flags verified in local xcodebuild -help]`
**Warning signs:** single-attempt failures on known-flaky share-sheet test despite plan settings.

### Pitfall 3: The iOS "Allow Paste" prompt cannot be automated
**What goes wrong:** a UI test that writes `UIPasteboard` from the runner and lets the app read it triggers the cross-app paste prompt; `springboard.buttons["Allow Paste"]` taps are reported not to work, and there is no grant API (unanswered Apple forums thread; Appium hit the same wall).
**How to avoid:** the clipboard representative test stubs `\.clipboardClient` behind the D-06 env seam (the routing under test — `detectClipboardURL` → guard → `handleDeepLink` — stays fully real). Note `hasURLs` (detection) doesn't prompt; the `.url`/`.string` content read does.
**Warning signs:** clipboard test hangs at a system alert only on fresh simulators.

### Pitfall 4: `URLProtocol.registerClass` only intercepts `URLSession.shared`
**What goes wrong:** requests constructed with a custom `URLSessionConfiguration` (e.g. Phase 12's clearance-retry session, Kingfisher's image pipeline) bypass the stub.
**How to avoid:** the deep-link path (`GalleryReverseRequest`, `GalleryDetailRequest`, gdata) all default to `.shared` — verified. Images will fail to placeholders; assert on structure (titles, navigation state), never on images. If any deep-link-path request turns out to use a custom session, add `protocolClasses` there under the same DEBUG flag.
**Warning signs:** stubbed runs still show network activity for one endpoint; a test asserting an image times out.

### Pitfall 5: Fixture-internal URL consistency
**What goes wrong:** `GalleryDetail.html` carries absolute URLs (gid 2725078, parent gallery links, archiver links); a `/s/` single-page fixture must parse (`Parser.parseGalleryURL`) to a gallery URL your stub also serves; the `#c` test needs a comment ID that exists among the fixture's 10 comments; the comments-entry test needs a fixture comment containing a recognized gallery link.
**How to avoid:** build the stub's routing table and the test URLs from one shared constant set (fixture gid/token/page/commentID); patch fixture HTML where needed rather than matching arbitrary real-site content.
**Warning signs:** `/s/` test lands on detail but reader never presents (reverse-parse resolved to an unserved URL); comments test pushes but doesn't scroll.

### Pitfall 6: Sheet re-present races and the shared `.detail` sheet
**What goes wrong:** `handleDeepLink` and the iPad `presentGalleryDetail` share one `.sheet` (`TabBarView.swift:82`); `.detail(.dismiss)` already triggers `path.removeAll()`. A naïve "present in `onDismiss`" can re-enter while state mutations from the dismiss handler are mid-flight, or fire for user-initiated dismissals that have no pending link.
**How to avoid:** gate the completion action on explicit pending-link state (nil for ordinary dismissals); keep all decisions in the reducer; test the interactive-swipe dismissal path (Phase 12's 12-06 lesson: raw case bindings echo reducer dismissals through the same binding).
**Warning signs:** double-present assertions from SwiftUI; deep link during an open detail intermittently shows the old gallery.

### Pitfall 7: New-module and new-target lint debt
**What goes wrong:** the UI-test folder and any new AppPackage module are scanned by the root SwiftLint config at `error`; XCUITest idioms (force-unwrap URLs, `try?`) and unsorted imports fail the build gates.
**How to avoid:** create the module `.swiftlint.yml` with `parent_config` first (AGENTS.md rule) and write lint-clean from the start. `URL(string:)!` is a `force_unwrapping` error — use `try XCTUnwrap(URL(string: …))` in test code, or the repo's sanctioned `Optional.forceUnwrapped` helper (`AppTools/Extensions/Optional+ForceUnwrapped.swift`, an IUO-returning logged accessor that lint accepts, used by `Defaults.URL`) if the UI-test target can import `AppTools`; note an xcodeproj UI-test bundle does not automatically see AppPackage modules, so `XCTUnwrap` is the low-friction default.
**Warning signs:** first CI lint run on the new target fails with dozens of violations.

### Pitfall 8: Warm-vs-cold app state bleed between UI tests
**What goes wrong:** `launch()` terminates any prior instance, but UserDefaults/`@Shared` persistence (`galleryHistory`, clipboard change-count) survives on the simulator between tests — a previous test's change-count suppresses the clipboard test; a reading-progress record changes the `/s/` landing.
**How to avoid:** per-test unique fixtures where possible; reset app state via launch env (the automation seam can clear or namespace persisted state), or use distinct gid/tokens per test.
**Warning signs:** tests pass in isolation, fail in suite order.

## Code Examples

Verified patterns from repo + SDK:

### Deep-link delivery (warm foreground)

```swift
// Source: XCUIAutomation.framework headers (Xcode 26.6), verified locally
let app = XCUIApplication()
app.launchEnvironment["EHPANDA_UITEST_STUB"] = "1"
app.launch()
XCUIDevice.shared.system.open(deepLinkURL)          // opens via default handler (the app)
XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
```

### URLProtocol stub skeleton (app process, DEBUG-gated)

```swift
// Source: URLProtocol canonical pattern (Foundation), adapted to the repo's shared-session default
#if DEBUG
final class UITestStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (data, response) = StubRouter.respond(to: request)   // path-keyed fixture table
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
// At startup, when the env flag is present:
// URLProtocol.registerClass(UITestStubURLProtocol.self)   // intercepts URLSession.shared
#endif
```

### Launch-time dependency override (clipboard stub)

```swift
// Source: swift-dependencies documented entry-point mechanism (pfw-dependencies skill)
// As early as possible, before any @Dependency is resolved:
prepareDependencies {
    $0.clipboardClient = .uiTestStub(url: stubURL)  // reads EHPANDA_UITEST_CLIPBOARD_URL
}
```

### Scheme wiring (second, non-default plan)

```xml
<!-- EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme, TestAction -->
<TestPlans>
   <TestPlanReference reference = "container:AppPackage/Tests/FeatureTests.xctestplan" default = "YES"/>
   <TestPlanReference reference = "container:UITests.xctestplan"/>
</TestPlans>
```

### UI-test invocation (retry flags mandatory on Xcode 26)

```bash
xcodebuild test -scheme EhPanda -testPlan UITests \
  -destination 'platform=iOS Simulator,name=iPhone Air' \
  -retry-tests-on-failure -test-iterations 3
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Safari-typed URLs to test scheme links | `XCUIDevice.shared.system.open(_:)` / `XCUIApplication.open(_:)` | Xcode 14.3 / iOS 16.4 | Direct, no Safari chrome scraping for warm opens; Safari drive remains only for the D-10 share test |
| XCTest umbrella for UI automation | `XCUIAutomation` framework split (headers redirect) | Xcode 16.3-era | `import XCTest` still works; UI classes are MainActor-annotated in the current SDK |
| XCTest for all new tests | Swift Testing for unit tests; **XCTest still mandatory for UI automation** | 2024→ | The new UI target is XCTest-based; repo's Swift Testing conventions don't transfer to it |
| Test-plan-configured retries | CLI retry flags | Xcode 26 regression | `-retry-tests-on-failure -test-iterations N` required in scripts |
| String scanning for URLs | `URLComponents` + `url.host()`/`fragment` accessors (iOS 16+) | long-standing; newer accessors mature | The D-11 rebuild uses the modern accessors freely (iOS 26 floor) |

**Deprecated/outdated:** `addUIInterruptionMonitor`-first alert handling (query springboard/app alerts directly); `UIPasteboard` free reads (iOS 16+ prompts — and are un-automatable, see Pitfall 3).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `XCUIApplication.open(_:)` delivers both the URL (to `onOpenURL`/launch options) and `launchEnvironment` on Xcode 26.6 / iOS 26.5 | Pattern 7 | Cold-launch variants fall back to the `EHPANDA_AUTOMATION_GALLERY_URL` launch entry (fallback B) — matrix intent preserved, delivery mechanism differs from D-05's letter |
| A2 | Safari chrome identifiers ("Address", "ShareButton") and share-sheet cell naming on iOS 26.5 | Pattern 8 | Identifier probing during implementation; test code adjusts, no design change |
| A3 | `XCUIDevice.shared.system.open` of an `ehpanda://` URL foregrounds the app without an intervening confirmation dialog (unlike Safari-typed scheme URLs, which show "Open in EhPanda?") | Pattern 7 | If a dialog appears, tap it via springboard query — add to the launch helper |
| A4 | Hand-editing pbxproj for a UI-test target (`productType = bundle.ui-testing`, `TEST_TARGET_NAME`, `TargetAttributes.TestTargetID`) is complete as listed | Pattern 6 | Fall back to creating the target in the Xcode GUI at a `checkpoint:human-verify` step |
| A5 | Kingfisher image loads bypass the URLProtocol stub (own session) and degrade to placeholders without breaking navigation assertions | Pitfall 4 | Assert only on structure; if a screen blocks on image load (none known), stub that session too |
| A6 | `withAnimation(_:completionCriteria:_:completion:)` (iOS 17+) is available as the alternative toast hand-off | Pattern 4 | Option 1 (id-keyed transition) needs no such API; zero design risk |

## Open Questions

1. **Does `XCUIApplication.open(_:)` reliably deliver the URL on the current toolchain?** (A1)
   - What we know: API verified in the local SDK; header says it launches through the harness "similar to -launch"; 2023-era community reports said URL delivery was broken at introduction; current behavior unverified.
   - Recommendation: Wave-0 probe (one throwaway test: open `ehpanda://` cold, assert detail). Decide cold-variant mechanism from the result; both outcomes have a locked-decision-compatible path (Pattern 7).
2. **Where does the pure parser live?** (D-13 discretion)
   - What we know: `URLClient` module's only contents become pure; dependents are AppFeature, DetailFeature, ReadingFeature, DownloadClient. Options: reshape the `URLClient` module in place (rename target + type; fewest Package.swift edits but a target rename touches Package.swift enum + module `.swiftlint.yml`), or fold into `AppTools` beside `URL+Components.swift` (kills a module; more import churn).
   - Recommendation: planner picks after sizing the Package.swift diff; either satisfies the Phase 8 precedent.
3. **How does the stub seam arm before the store's first effects?**
   - What we know: `AppDelegate` creates the store (`AppDelegateReducer.swift:52`); `AppLaunchAutomation` resolves at `onLaunchFinish`. `URLProtocol.registerClass` and `prepareDependencies` must run before the first request/dependency resolution.
   - Recommendation: arm in the app entry path (`EhPandaApp.init` calling an `AppFeature`-exposed DEBUG hook) — earliest deterministic point; keep `AppLaunchAutomation` semantics untouched.
4. **Fixture comment content for the two comments tests** — does `GalleryDetail.html` contain a comment with a usable ID/gallery link, or does the fixture need a patched variant? (Check during planning; trivial either way.)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | build + UI tests | Yes | 26.6 (17F113) | — |
| iOS simulator runtime | UI tests | Yes | iOS 26.5 (23F77) | — |
| iPhone simulator (D-08 primary) | UI matrix | Yes | iPhone Air (booted) | — |
| iPad simulator (D-08 targeted) | `presentGalleryDetail` test | Yes | iPad Pro 11-inch (M5) | — |
| Safari on simulator | D-10 share test | Yes (built-in) | — | — |
| `xcodebuild` retry flags | D-10 flake budget | Yes (verified in `-help`) | — | — |
| SwiftLint | lint gates | Assumed present (Phase 11 ran it) | — | — |
| Network access from simulator | Safari page-load leg of D-10 only | Host-dependent | — | Share test tolerates failed page load (URL suffices) |

**Missing dependencies with no fallback:** none identified.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework (unit) | Swift Testing (existing 18 SPM targets, 565 tests, parallel) |
| Framework (UI, new) | XCTest / XCUIAutomation (Swift Testing does not support UI automation) |
| Config files | `AppPackage/Tests/FeatureTests.xctestplan` (default); new `UITests.xctestplan` |
| Quick run command | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'` (unit-only, default plan) |
| Full suite command | unit command above + `xcodebuild test -scheme EhPanda -testPlan UITests -destination … -retry-tests-on-failure -test-iterations 3` |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| SC-1 | Parser: host exact-match, route/gid/token/page/commentID extraction, spoof rejection, `www.` acceptance, optional-failure returns | unit (Swift Testing) | targeted suite in the parser's module tests | Wave 0 (new suite; replaces `URLClient` test ceremony) |
| SC-1 | Reducer: entry-source policy, dismissal-completion re-present, toast hand-off (no sleeps) | unit (TCA TestStore) | `AppFeatureTests` / `DetailFeatureTests` additions | Wave 0 additions |
| SC-2 | 8 scheme-matrix UI tests + 3 representative entry tests land on locked destinations | UI (XCTest) | `-testPlan UITests` command above | Wave 0 (new target) |
| SC-3 | Malformed explicit open → `unsupportedDeepLink` toast → ErrorInfoView; clipboard non-gallery → silent | unit (reducer) + 1 UI test | unit suites + UI plan | Wave 0 |

### Sampling Rate
- **Per task commit:** default-plan unit run (stays UI-free by D-07 design).
- **Per wave merge:** unit suite green; UI plan on demand for waves touching the harness.
- **Phase gate:** unit suite + full UI plan (with retry flags) green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] UI-test target + `UITests.xctestplan` + scheme reference (the harness itself)
- [ ] Stub seam (URLProtocol + clipboard override + fixture routing) — precedes every hermetic UI test
- [ ] `XCUIApplication.open(_:)` delivery probe (Open Question 1)
- [ ] Parser unit suite (replaces `URLClient`-dependency test ceremony)
- [ ] Accessibility identifiers / assertion hooks on detail, reader, comments screens (currently **zero** `accessibilityIdentifier` usages in the codebase — tests would otherwise query localized labels, which breaks under pseudo-locales)
- [ ] New `AppError` case localization keys × 6 locales

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Deep links never carry credentials; no change |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | **Yes** | `URLComponents` exact-host parsing (D-11/D-12) — the phase's core security fix |
| V6 Cryptography | No | — |

### Known Threat Patterns for this surface

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Host spoofing via substring match (F1) | Spoofing | Exact match on parsed host against an allowlist (D-12); case-normalized |
| Malicious scheme payloads (`ehpanda://` from any app) | Tampering / DoS | Optional-returning parse, no force-unwraps/crashes on arbitrary input (SC-3); reject before any network fetch |
| Token leakage in diagnostics | Information disclosure | Phase 9 09-12 rule is load-bearing: `ContextKey` whitelist **deliberately has no raw-URL slot**; `galleryFailure` retains only a validated decimal gid. D-01's "ErrorInfoView with the URL" must reconcile with this — recommend a sanitized display form (scheme + host + path with the token elided, or the full URL only in the *transient* toast body, never persisted into `Context`). Flag for the planner as an explicit design point. |
| Test seam in release | Elevation of surface | Entire stub seam `#if DEBUG` (matching `AppLaunchAutomation`); fixtures embedded as DEBUG-compiled constants, not bundled resources |

## Sources

### Primary (HIGH confidence)
- Repo source (all files cited inline) — read directly 2026-07-23
- Xcode 26.6 SDK headers: `XCUIAutomation.framework/Headers/XCUISystem.h`, `XCUIApplication.h` (`system.open`, `open(_:)`, `launchEnvironment` semantics, `wait(for:timeout:)`)
- Local tooling probes: `xcodebuild -version` / `-help` (retry flags), `simctl list` (runtimes/devices)
- pfw-dependencies skill (`prepareDependencies` entry-point override)

### Secondary (MEDIUM confidence)
- [Apple Developer Forums — xcodebuild does not retry UI tests with Xcode 26.2](https://developer.apple.com/forums/thread/813680) (Apple engineer-confirmed workaround)
- [Apple Developer Forums — UI Testing and "Allow Paste"](https://developer.apple.com/forums/thread/806849) (unanswered; springboard tap fails)
- URLProtocol/`registerClass` shared-session behavior (multiple corroborating sources, e.g. [swiftwithvincent.com](https://www.swiftwithvincent.com/blog/how-to-mock-any-network-call-with-urlprotocol), [kandelvijaya.com](https://kandelvijaya.com/2017/04/30/urlprotocolandunittesting/))
- Swift Testing has no UI-automation API (e.g. [blakecrosley.com/blog/swift-testing-vs-xctest](https://blakecrosley.com/blog/swift-testing-vs-xctest))
- xctestplan `testRepetitionMode`/`maximumTestRepetitions` JSON keys ([xctestplanner](https://github.com/atakankarsli/xctestplanner), BrowserStack docs)

### Tertiary (LOW confidence — validate during implementation)
- Deep-link-open URL-delivery reliability reports ([Trendyol Tech](https://medium.com/trendyol-tech/how-to-test-deeplinks-with-xcuitest-d24c8e5318ee), [Apple forums 25355](https://developer.apple.com/forums/thread/25355)) — era-specific, superseded by the Wave-0 probe
- Safari/share-sheet automation element naming (community articles)

## Metadata

**Confidence breakdown:**
- Fragile-spot inventory & parsing rework: HIGH — read directly from source; parity anchors identified
- Error-surface extension (D-01…D-04): HIGH — Phase 9/12 precedent code read; localization catalog verified
- Stub seam design (D-06): HIGH on mechanism (shared-session default verified in repo; registerClass behavior cross-checked), MEDIUM on fixture-consistency details
- UI-test delivery mechanics (D-05 cold variant): MEDIUM — hinges on the Wave-0 probe (A1)
- Share-sheet automation details (D-10): LOW-MEDIUM — inherently version-drifting chrome; mitigated by retry flags + probe-and-pin
- Xcode 26 retry regression: HIGH — Apple-engineer-confirmed + flags verified locally

**Research date:** 2026-07-23
**Valid until:** ~2026-08-22 (stable except Xcode point releases, which may fix the retry regression or change Safari chrome)
