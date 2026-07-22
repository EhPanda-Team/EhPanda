---
phase: 12-cloudflare-login-restoration
fixed_at: 2026-07-23T00:00:00Z
review_path: .planning/phases/12-cloudflare-login-restoration/12-REVIEW.md
iteration: 2
findings_in_scope: 7
fixed: 7
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

## Fixed Issues — iteration 2 (Info tier, at the user's direction)

Iteration 1 covered the `critical_warning` scope. The user then selected IN-01, IN-03, IN-04 and
IN-05 for fixing and left IN-02 and IN-06 alone. Each landed as its own commit.

### IN-01: Comment overstates what the rejection throw prevents

`httpShouldHandleCookies = false` was set only on the clearance-carrying retry, so on the bare path
URLSession filed the response's `Set-Cookie` automatically, before and regardless of the throw. A
user with a live session who mistyped a re-login could have it clobbered by the failure page's
tombstones. Rather than correct the comment, the stronger of the review's two options was taken: the
jar is suppressed on both paths, which makes them symmetric and makes the comment true.

**Behavior change:** the bare login POST no longer sends jar cookies. Nothing is lost — credentials
arrive on the *response* and `setCredentials` applies them on success — and the clearance path had
already shipped on the same reasoning. `CloudflareChallengeDetectionTests` pinned the old value and
was updated with the reason.

### IN-03: The four-attempt transport retry applies to the credential POST

`fetch` now takes an `attempts` count defaulting to the existing four, and `LoginRequest` asks for
one. A POST the forum received but whose response was lost is otherwise replayed, and each replay
spends another of the account's login attempts against the forum's own lockout — the lockout this
phase taught the parser to surface.

The account-layer baseline pinning four attempts read them through `LoginRequest`, so it moved to
`VoteGalleryTagRequest` and still guards the default; the login exception has a case of its own.

### IN-04: `redactedCredentialHeader` splits on `,` only

Hand-splitting the coalesced header was the root cause, so it is gone: `HTTPCookie` parses the
header and the names come from the cookies it recognises. This closes both the reported noise
(`expires` fragments printed as names) and the residual risk the review flagged — a non-compliant
comma inside a value can no longer surface a fragment of that value, because a parser either
recognises a cookie or yields nothing. The function now takes the response URL; without one it names
nothing rather than gambling with a value.

### IN-05: `parseLoginErrorMessage` scans the entire page

The markers now count only as the text of the forum's own error-box label (`pformstrip` /
`formsubtitle`), which is where both real shapes put them.

**Deviation from the review's suggested fix:** it proposed anchoring "before falling back to the
page-wide scan". The fallback was deliberately not implemented — keeping it would preserve the exact
false positive being removed, since a page with no anchor still reaches the page-wide scan.
Unrecognised markup now degrades to the unlabelled generic failure the caller already handles, which
leaves a live session intact; that is the safer of the two failure modes, because the misfire being
removed drops session cookies on a login that actually succeeded.

One existing fixture (`markupAndEntitiesBetweenTheMarkerAndTheMessageAreIgnored`) used a class-less
`<div>` and was updated to the real markup; three cases were added for the new contract.

## Verification performed

Iteration 1 (as recorded when written, before the iOS scheme was available to the fixer):

- Every modified file re-read after editing; `xcrun swiftc -parse` clean on all four.
- No line exceeds the 120-character `line_length` limit; no `swiftlint:disable` was added and no rule
  was suppressed. SwiftLint itself is not installed on this machine, so rule conformance was checked
  by reading the root `.swiftlint.yml` and writing to it (the removed `forceUnwrapped` use and the
  multi-line chain shapes were the relevant rules).
- The new `dictString()` was type-checked and executed standalone: it emits
  `PassWord=p%26w%3Dd%2Bq%20x%25y&UserName=baseline-user` and `commenttext_new=first%0Asecond`,
  matching the updated test expectations exactly.
- Full compilation was **not** run at the time: `AppPackage` is iOS-only and `swift build` on macOS
  fails at manifest resolution (platform floors), before reaching any source.

Iteration 2 closed that gap for both iterations, using the same scheme and flags as CI
(`.github/workflows/test.yml`):

- `xcodebuild build -scheme EhPanda` against an iOS Simulator destination: **BUILD SUCCEEDED**, no
  errors and no compiler warnings. SwiftLint runs as a build-tool plugin in this project, so a clean
  build is also a clean lint — no rule was suppressed and no `swiftlint:disable` was added.
- `xcodebuild test -scheme EhPanda`: **TEST SUCCEEDED**, all suites green. The pre-existing
  `withKnownIssue` blocks remain the only reported known issues.
- Every test added or changed across both iterations was confirmed by name in the run output.
- `scripts/check-cookie-logging.sh` passes.
- `-skipMacroValidation` was required: three macro packages need re-approval after version bumps.
  This is a local Xcode trust prompt, not a code issue, and CI passes the same flag.

## Out of scope

IN-02 and IN-06 were reviewed and deliberately left alone.

- **IN-02** (stale dismissal echo misread as a swipe) — the review concludes the window is
  unreachable in production and records it as a known limitation rather than a defect. Closing it
  would mean threading a challenge ID through the presentation for no observable benefit.
- **IN-06** (locale-dependent assertions in `AppErrorStructuredTests`) — environment-sensitive
  rather than wrong, pre-existing test style, and CI runners are English so it never fires there.

---

_Fixed: 2026-07-23_
_Fixer: Claude (gsd-code-fixer, iteration 1) / Claude Opus 4.8 (iteration 2)_
_Iteration: 2_
