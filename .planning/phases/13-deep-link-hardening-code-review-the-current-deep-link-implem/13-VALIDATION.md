---
phase: 13
slug: deep-link-hardening-code-review-the-current-deep-link-implem
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-23
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source of truth: 13-RESEARCH.md §Validation Architecture + each plan's `<verify><automated>` command.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (unit)** | Swift Testing — 18 existing SPM test targets, ~565 tests, parallel |
| **Framework (UI, new)** | XCTest / XCUIAutomation (Swift Testing has no UI-automation API) |
| **Config file (unit)** | `AppPackage/Tests/FeatureTests.xctestplan` — the scheme's **default** plan |
| **Config file (UI)** | `UITests.xctestplan` — created by 13-08, a **second, non-default** plan (D-07) |
| **Quick run command** | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:<Target>` |
| **Full suite command (unit)** | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'` |
| **Full suite command (UI)** | `xcodebuild test -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,name=iPhone Air' -retry-tests-on-failure -test-iterations 3` |
| **Estimated runtime** | targeted unit target ~30-60s · full unit plan ~3-5 min · UI plan ~5-10 min (retry budget included) |

**Invocation constraints (project-specific):**
- The retry flags on the UI command are **mandatory** on every scripted invocation: Xcode 26 ignores the test plan's `testRepetitionMode` from the CLI (research Pitfall 2). The plan's own retry settings only take effect in the Xcode GUI.
- `xcodebuild` runs must **never overlap** on this machine — all waves and all gate commands are sequential.
- Everyday `xcodebuild test` without `-testPlan` stays unit-only by design (D-07); UI tests never enter the default feedback loop.

---

## Sampling Rate

- **After every task commit:** the task's own `<automated>` command (targeted `-only-testing:` unit run, or a `grep`+build gate for source-shape tasks). Waves 1-7 are all unit/build scoped and stay under ~1 min.
- **After every plan wave:** full unit plan (`FeatureTests`) green. Waves 8-10 additionally run the UI plan, which is the artifact they build.
- **Before `/gsd-verify-work`:** the three-command phase gate in 13-10 Task 3 — full unit plan, full UI plan on iPhone, iPad-only class on the iPad destination — all green, run sequentially.
- **Max feedback latency:** ~60s for waves 1-7 (targeted unit runs); ~10 min for waves 8-10 (UI plan with retries) — inherent to iOS UI automation, accepted.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | SC-1 | T-13-01 | Exact case-insensitive host match against the closed D-12 set; no `absoluteString` scanning | build + lint gate | `xcodebuild build -scheme EhPanda -destination '…iPhone Air'` | ❌ W0 (`AppTools/GalleryURLParser.swift`) | ⬜ pending |
| 13-01-02 | 01 | 1 | SC-1, SC-3 | T-13-01 / T-13-02 | Spoof URL (`evil.com` embedding the real host in a query) proven rejected; malformed shapes return nil, never crash | unit (Swift Testing) | `xcodebuild test … -only-testing:AppToolsTests` | ❌ W0 (`AppToolsTests/GalleryURLParserTests.swift` — new target) | ⬜ pending |
| 13-02-01 | 02 | 2 | SC-3 | — | — | catalog lint + schema assertion | `plutil -lint …Localizable.xcstrings` + python3 key/locale assertion | ✅ (`Localizable.xcstrings`) | ⬜ pending |
| 13-02-02 | 02 | 2 | SC-3 | T-13-03 | Sanitized link rendering: query, fragment, userinfo, and token-bearing path slots never reach `Context` | unit (Swift Testing) | `xcodebuild test … -only-testing:AppModelsTests` | ❌ W0 (`AppModelsTests/UnsupportedDeepLinkErrorTests.swift`) | ⬜ pending |
| 13-03-01 | 03 | 3 | SC-1 | T-13-01 | Last substring-matching call sites removed; every consumer routes through the exact-host parser | build gate | `xcodebuild build -scheme EhPanda -destination '…iPhone Air'` | ✅ (sources) | ⬜ pending |
| 13-03-02 | 03 | 3 | SC-1 | T-13-06 | Fake-recognizer test overrides deleted — reducer tests now exercise real parsing | grep gate + full unit plan | `test ! -d …/URLClient && ! grep -rq … && xcodebuild test -scheme EhPanda -destination '…iPhone Air'` | ✅ (7 existing test files migrated) | ⬜ pending |
| 13-04-01 | 04 | 4 | SC-3, SC-1 | T-13-02 / T-13-03 | Explicit opens fail loudly with the sanitized context; clipboard opens stay silent (no toast from unsolicited input) | unit (TCA TestStore, tdd) | `xcodebuild test … -only-testing:AppFeatureTests` | ✅ (`PresentationFeatureTests.swift`, extended) | ⬜ pending |
| 13-04-02 | 04 | 4 | SC-1 | T-13-05 | Scheme rewrite mutates only the scheme component — a URL embedding the scheme in its query survives intact | grep gate + build | `! grep -q "replacingOccurrences" … && grep -q "URLComponents" … && xcodebuild build …` | ✅ (`ShareExtension/ShareViewController.swift`) | ⬜ pending |
| 13-05-01 | 05 | 5 | SC-1 | T-13-07 | Modal replacement gates on the dismissal-completion fact, not a 1000 ms stopwatch | grep gate + build | `! grep -q "milliseconds(1000)" … && grep -q "detailDismissalCompleted" … && xcodebuild build …` | ✅ (sources) | ⬜ pending |
| 13-05-02 | 05 | 5 | SC-1 | T-13-07 | Every ordering of dismissal-vs-fetch completion pinned deterministically; no real-time sleeps in tests | unit (TCA TestStore, tdd) | `xcodebuild test … -only-testing:AppFeatureTests` | ✅ (`PresentationFeatureTests.swift`, extended) | ⬜ pending |
| 13-06-01 | 06 | 6 | SC-1 | T-13-07 | Zero sleep-based effects remain in the deep-link path (D-14 exit criterion with 13-05) | grep gate + build | `! grep -q "milliseconds(500)" (both reducers) && xcodebuild build …` | ✅ (sources) | ⬜ pending |
| 13-06-02 | 06 | 6 | SC-1 | T-13-07 | Failure arms emit no follow-up action (exhaustive store); 09-12 sanitized-context fixtures still pass | unit (TCA TestStore) | `xcodebuild test … -only-testing:AppFeatureTests -only-testing:DetailFeatureTests` | ✅ (`PresentationFeatureTests.swift`, `CommentsReducerTests.swift`) | ⬜ pending |
| 13-07-01 | 07 | 7 | SC-2 | T-13-04 | Entire stub seam `#if DEBUG`; hermetic 404 default; no force-unwraps | build gate | `xcodebuild build -scheme EhPanda -destination '…iPhone Air'` | ❌ W0 (`AppFeature/UITestSupport/*`) | ⬜ pending |
| 13-07-02 | 07 | 7 | SC-2 | T-13-04 / T-13-08 | Seam arms before first dependency resolution; route table + env resolution pinned in-process | unit (Swift Testing) | `xcodebuild test … -only-testing:AppFeatureTests` | ❌ W0 (`AppFeatureTests/UITestStubTests.swift`) | ⬜ pending |
| 13-07-03 | 07 | 7 | SC-2 | T-13-09 | Identifier-only additions — no label/value/trait change; UI assertions stop depending on localized text | grep gate + full unit plan | `grep -rq "detail_view" … && grep -rq "comment_cell_" … && xcodebuild test -scheme EhPanda -destination '…iPhone Air'` | ✅ (5 existing view files) | ⬜ pending |
| 13-08-01 | 08 | 8 | SC-2 | T-13-04 | UI target never links into the app product; fixtures live in the test bundle only; default plan stays unit-only | project lint + build-for-testing | `xcodebuild -list \| grep EhPandaUITests && plutil -lint UITests.xctestplan && xcodebuild build-for-testing … -testPlan UITests` | ❌ W0 (whole `EhPandaUITests/` target) | ⬜ pending |
| 13-08-02 | 08 | 8 | SC-2 | T-13-09 | Hermetic round trip proven by a marker title the live network could never serve | UI (XCTest) | `xcodebuild test … -testPlan UITests … -retry-tests-on-failure -test-iterations 3` | ❌ W0 (`DeepLinkSmokeUITests.swift`) | ⬜ pending |
| 13-09-01 | 09 | 9 | SC-2 | T-13-02 | All three locked routes land on their locked destinations in cold + warm variants; reader is never reached without detail | UI (XCTest) | `xcodebuild test … -testPlan UITests … -only-testing:EhPandaUITests/DeepLinkSchemeUITests` | ❌ W0 (`DeepLinkSchemeUITests.swift`) | ⬜ pending |
| 13-09-02 | 09 | 9 | SC-3 | T-13-02 / T-13-09 | Malformed scheme opens surface the error toast → ErrorInfoView chain, and reach no detail screen | UI (XCTest) | `xcodebuild test … -testPlan UITests …` (full plan, wave gate) | ❌ W0 (`DeepLinkSchemeUITests.swift`) | ⬜ pending |
| 13-10-01 | 10 | 10 | SC-2 | T-13-09 | Clipboard leg never writes the real pasteboard (Allow Paste never triggers); pushed gallery distinguished by the Alt marker | UI (XCTest) | `xcodebuild test … -testPlan UITests … -only-testing:EhPandaUITests/DeepLinkEntryUITests` | ❌ W0 (`DeepLinkEntryUITests.swift`) | ⬜ pending |
| 13-10-02 | 10 | 10 | SC-2 | T-13-05 / T-13-09 | Real share-sheet hand-off integrity; app-side arrival still hermetic (marker title) | UI (XCTest, cross-app) | `xcodebuild test … -testPlan UITests … -only-testing:EhPandaUITests/ShareSheetUITests` | ❌ W0 (`ShareSheetUITests.swift`) | ⬜ pending |
| 13-10-03 | 10 | 10 | SC-2 | T-13-07 | iPad tab-modal replaced through the 13-05 dismissal coordination; phase exit evidence collected | UI (XCTest) + phase gate | 3 sequential commands: full unit plan, full UI plan (iPhone), `-only-testing:EhPandaUITests/DeepLinkPadUITests` on iPad Pro 11-inch (M5) | ❌ W0 (`DeepLinkPadUITests.swift`) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Requirement IDs are the ROADMAP §13 success criteria (the phase has no REQUIREMENTS.md IDs — `Requirements: TBD`):*
- ***SC-1** — fragile spots resolved at root, destination-routing behavior unchanged for currently-supported links*
- ***SC-2** — UI automation exercises deep-link navigation end-to-end for every supported route*
- ***SC-3** — malformed or unresolvable links fail gracefully: no crash, no unrecoverable silent no-op*

---

## Wave 0 Requirements

Test infrastructure that does not exist yet and must be created before the behavior it validates:

- [ ] `AppToolsTests` SPM test target + `AppPackage/Tests/AppToolsTests/.swiftlint.yml`, registered in `FeatureTests.xctestplan` — 13-01 (Phase 11 lesson: unregistered targets are silently skipped)
- [ ] `AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift` — parser accept/reject matrix, SC-1/SC-3
- [ ] `AppPackage/Tests/AppModelsTests/UnsupportedDeepLinkErrorTests.swift` — sanitized-context regressions, SC-3
- [ ] `AppError.unsupportedDeepLink` localization keys × 6 locales — 13-02 (a green build depends on the generated string symbols)
- [ ] `AppPackage/Sources/AppFeature/UITestSupport/` stub seam (URLProtocol + clipboard override + fixture routing) — 13-07; precedes every hermetic UI test
- [ ] `AppPackage/Tests/AppFeatureTests/UITestStubTests.swift` — in-process seam regressions ahead of the UI harness
- [ ] Accessibility identifiers on the destination screens — 13-07 Task 3; the repo currently has **zero** `accessibilityIdentifier` usages, so without these every UI assertion would query localized labels
- [ ] `EhPandaUITests` xcodeproj target + `UITests.xctestplan` + scheme reference + module `.swiftlint.yml` — 13-08 (the harness itself)
- [ ] `EhPandaUITests/Fixtures/` (4 patched HTML files) + `Support/UITestConstants.swift` — 13-08; the marker titles are what make hermeticity assertable
- [ ] `XCUIApplication.open(_:)` cold-delivery probe — 13-08 Task 2; pins the cold-launch mechanism for 13-09/13-10 (RESEARCH Open Question 1)

**Wave 0 is spread across waves 1-8 rather than front-loaded**, because the UI harness cannot be built before the app-side seam it drives exists (13-07 → 13-08), and the seam cannot be built before the parser it stubs around is in place (13-01 → 13-03). Every plan creates its own test scaffolding within its own wave, and no task's `<automated>` command references a file a prior task has not created.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Toast loading→error cross-transition *appearance* (13-06) | SC-1 | The state hand-off is asserted automatically, but whether the replacement animation reads correctly is a visual judgment no assertion captures | Trigger a gallery deep link whose fetch fails (airplane mode, or a valid-shaped link to a nonexistent gid); watch the loading toast give way to the error toast — it should cross-fade, not blink |
| Six-locale wording quality of the new `unsupportedDeepLink` strings (13-02) | SC-3 | Automation asserts key presence, locale completeness, and non-emptiness; register and naturalness in de/ja/ko/zh-Hans/zh-Hant are human judgments | Switch the simulator language per locale, open a malformed `ehpanda://` link, read the toast and the ErrorInfoView solution row |
| VoiceOver behavior after the identifier additions (13-07 Task 3) | SC-2 | Identifiers are invisible to assistive technology by design; the automated gate proves they exist, not that nothing regressed for VoiceOver users | Enable VoiceOver on the simulator, swipe through Detail, Reading, Comments, and a toast — announcements must be unchanged from before the phase |

All other phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (waves 1-7) / < 10 min (waves 8-10, UI plan)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
