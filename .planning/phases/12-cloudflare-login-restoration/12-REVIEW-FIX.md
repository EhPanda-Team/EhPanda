---
phase: 12-cloudflare-login-restoration
fixed_at: 2026-07-23T00:00:00Z
review_path: .planning/phases/12-cloudflare-login-restoration/12-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 12: Code Review Fix Report

**Fixed at:** 2026-07-23T00:00:00Z
**Source review:** `.planning/phases/12-cloudflare-login-restoration/12-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (Critical: 0, Warning: 3 — Info findings are out of scope for `critical_warning`)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: `ChallengeWebView`'s one-shot latch can double-fire across suspension points

**Files modified:** `AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift`
**Commit:** `15ff7a97`
**Applied fix:** Added a second latch check in `reportClearanceIfPresent(in:)` immediately before the
commit block, after the last suspension point (`evaluateJavaScript`). The entry guard is kept as a
cheap fast path, and a comment records why main-actor isolation alone does not serialise the method
across its two `await`s. `onClearance` is now handed the pair exactly once, as the type's doc comment
promises, instead of relying on `LoginReducer`'s straggler guard to absorb a duplicate.

### WR-02: `.login` is re-entrant while a login is already in flight

**Files modified:** `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift`
**Commit:** `66cac023`
**Applied fix:** Folded the in-flight condition into `State.loginButtonDisabled`
(`username.isEmpty || password.isEmpty || loginState == .loading`) so the view's `.disabled` and the
reducer's guard read from one property and cannot drift; the `.login` guard is now plainly
`guard !state.loginButtonDisabled else { return .none }`, replacing the inverted `||` form that
*admitted* a tap while loading. `LoginView` needed no change — its existing
`.disabled(store.loginButtonDisabled)` now also covers the loading window, so the button under the
`ProgressView` overlay is no longer tappable. `loginEffect` additionally uses
`.cancellable(id: CancelID.login, cancelInFlight: true)`, making the single-outstanding-POST
invariant a property of the effect rather than of every call site. `loginButtonColor` is unaffected
(it tests `loginState == .loading` first).

**Note:** this changes reducer control flow. The existing `LoginChallengeFlowTests` suite sends
`.login` only from `.idle` with both fields populated, so no case is invalidated; a re-entrancy case
is not added here because `TestStore` cannot express the racing second send without also modelling
the view.

### WR-03: Login form values are not individually percent-encoded

**Files modified:** `AppPackage/Sources/NetworkingFeature/Request.swift`,
`AppPackage/Sources/NetworkingFeature/Request+Account.swift`,
`AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift`
**Commit:** `146b2624`
**Applied fix:** `Dictionary.dictString()` now percent-encodes each key and each value on its own
with an RFC 3986 unreserved-character set (`alphanumerics` + `-._~`) before joining with `=` and `&`,
replacing the raw join plus a single whole-body `.urlQueryAllowed` pass that escaped none of `&`,
`=` or `+`. The now-redundant outer `.urlEncoded` was dropped from all eight form POSTs in
`Request+Account.swift`. The force unwrap in the old implementation disappears with it.

Two call sites had to change with it: `CommentGalleryRequest` and `EditGalleryCommentRequest`
hand-escaped newlines to `%0A` specifically because the old outer pass left `%` alone in the joined
string. Under per-value encoding that pre-escape becomes `%250A`, so the manual
`replacingOccurrences` was removed and the raw content is passed through — which also fixes a latent
double-encoding defect: the old body carried `%250A`, so a posted comment contained the literal
characters `%0A` rather than a line break. The two baseline expectations that pinned that behaviour
were updated to the decoded newline.

Added a regression test, `loginRequestPercentEncodesStructuralCharactersInCredentials`, which drives
`LoginRequest` with the password `p&w=d+q x%y` and asserts the **raw** body carries
`PassWord=p%26w%3Dd%2Bq%20x%25y`. Asserting the raw bytes is deliberate: the suite's `formFields`
decoder splits a pair at its first `=` and leaves `+` untouched, so it reads a corrupted body as
intact — which is why the existing baselines never caught this.

## Verification performed

- Every modified file re-read after editing; `xcrun swiftc -parse` clean on all four.
- No line exceeds the 120-character `line_length` limit; no `swiftlint:disable` was added and no rule
  was suppressed. SwiftLint itself is not installed on this machine, so rule conformance was checked
  by reading the root `.swiftlint.yml` and writing to it (the removed `forceUnwrapped` use and the
  multi-line chain shapes were the relevant rules).
- The new `dictString()` was type-checked and executed standalone: it emits
  `PassWord=p%26w%3Dd%2Bq%20x%25y&UserName=baseline-user` and `commenttext_new=first%0Asecond`,
  matching the updated test expectations exactly.
- Full compilation was **not** run: `AppPackage` is iOS-only and `swift build` on macOS fails at
  manifest resolution (platform floors), before reaching any source. The test suite must be run
  through the iOS scheme during verification.

## Out of scope

IN-01 through IN-06 are Info-tier and were not addressed under `fix_scope: critical_warning`.
IN-01 (the comment overstating what the rejection throw prevents) and IN-04 (the DEBUG redactor's
`,`-only split) sit in `Request+Account.swift`, which this run touched for WR-03; they were left
untouched so each commit stays scoped to its finding.

---

_Fixed: 2026-07-23_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
