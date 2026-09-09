# Login, cover, and pending visual recheck — 2026-09-09

## Scope and outcome

The owner requested fresh screenshots for D13-4, #23, and #28, then reported a blank Favorites page after login, unexplained native-login refusals, and two-tone cover placeholders. This pass does not close the owner review or grant ROUND1-CLEAR.

Evidence is outside the repository at `$HOME/.codex/visualizations/2026/09/09/01a08497-6c61-7343-82a3-f277e0964e23/phase16-recheck/`. Images contain live account gallery content and must not be copied into public repository artifacts.

## Fresh visual evidence

Both review simulators run iOS 26.5 in light appearance. The app under review is `app.ehpanda.personal`.

| Item | Conditions and evidence | Result |
| --- | --- | --- |
| D13-4 | Populated Favorites on iPad mini, portrait/landscape AX3 and AX5; `favorites-ipad-portrait-ax3.png`, `favorites-ipad-portrait-ax5.png`, `favorites-ipad-landscape-ax3.png`, `favorites-ipad-landscape-ax5.png` | Sampled trailing page counts and glyphs are complete. This is a sampled pass, pending owner disposition. |
| #28 | iPhone portrait AX5, Account Configuration, Multi-Page Viewer toggle and display-style options; `ehsettings-ax5-toggle.png`, `ehsettings-ax5.png` | Sampled labels wrap into distinct rows and remain scrollable. No overlap reproduced. Pending owner disposition. |
| #23 | iPhone Detail delete confirmation opened at Large, rotated to landscape while open, then changed live to AX3/AX5; `detail-delete-large.png`, `detail-delete-landscape-ax3.png`, `detail-delete-landscape-ax5.png` | Still reproduced: AX3 clips the message; AX5 hides the message and Cancel while Delete remains visible. This is live-change evidence, not a cold-entry matrix. |

The correct Detail route for an existing download was Downloads row context menu → Detail. The alert was cancelled after restoring Large. No gallery was deleted. A real 35-page download created for this check remains on the iPhone. Both simulators were restored to Large and portrait. A URL-scheme attempt reached a separate measurement app; that app's screen was excluded from the evidence above.

## Code changes and limits

- Favorites and Watched previously updated their login-wall visibility through shared login state but requested data only through presentation actions. Both views now send their existing guarded `onPresented` action when login changes to true. This covers the two whole-page login walls found in the source audit. The live logout/login-return transition has not been re-tested; existing signed-in loading after installing the build is not equivalent evidence.
- `GalleryCover` now gives its loading placeholder the cover's aspect ratio. The old list implementation at `59fb2eb9^` used `Placeholder(style: .activity(ratio: Defaults.ImageSize.rowAspect))` and `.scaledToFit()`. Loaded artwork therefore already used fit, not fill. The newer outer secondary background makes unused aspect-fit space gray. This pass preserves loaded-image scaling and background. The files named `placeholder-fixed*.png` show loaded artwork, not a pending spinner, and are not proof that the loading-placeholder rendering passes.
- Native login now detects a returned Turnstile form independently of the forum error box, before the generic refusal fallback. Tests cover forms both with and without the site-wide bounce-login marker. The observed earlier device log contained only a refusal without a readable reason; its response body was unavailable. This classification fix is not proof of the actual failure's cause or successful native authentication. A fresh failing exchange is still needed to establish that cause; no credential retry or logout was performed in this pass.

## Validation

- Debug app build succeeded with Xcode 26.6.
- `NetworkingFeatureTests/LoginRejectionSurfacingTests` and `FavoritesFeatureTests`: 12 tests passed, including the parameterized CAPTCHA-without-error-box regression.
- Changed Swift sources and tests passed SwiftLint without suppressions; `git diff --check` passed.
- The build was installed over the iPhone's existing app; its session remained available. No simulator erase or app uninstall was performed.

After viewing the snapshot, the owner accepted #23 because landscape AX5 has insufficient display space. Its reproduction evidence remains valid; the finding is accepted, not fixed. D13-4 and #28 remain pending owner disposition. Native login and the two unverified UI transitions above must not be described as fully verified fixes.

The owner deferred native-login verification until a later sim-use session. Do not infer authentication success from the classification tests.

Owner update: the historical `scaledToFit` artwork and its current surrounding space are accepted. The owner still observes two-tone loading placeholders and requires an actual pending-image screenshot before that issue can close.

## Controlled pending-image verification — 2026-09-09

A temporary app-shell entry hosted the actual `GalleryDetailCell` in a SwiftUI `List`, with neutral fixture metadata. A test URLProtocol held only `cover-loading.invalid` requests pending without delivering data or completion, so Kingfisher rendered its real loading placeholder. These are simulator screenshots of a controlled loading scenario, not live server latency or composited images.

On iPhone portrait Large, `loading-list-before.png` reproduces the two gray bands with the aspect-ratio line removed. `loading-list-after.png` uses the identical harness with the aspect-ratio line restored: all four loading covers have one uniform gray background. The only cover-code difference is that line. A separate direct-component capture also showed uniform loading backgrounds for compact, standard, and hero roles. This verifies the existing ratio correction under the sampled loading conditions; no additional production rendering change was needed. The reason the owner still observed the old appearance on their screen was not established.

The temporary entry was removed from `App/EhPandaApp.swift` after capture; its source is kept beside the external screenshots as `LoadingReviewHarness.swift` for reproducibility. The normal app was rebuilt for reinstallation. Loaded-artwork fit/background remains unchanged and owner-accepted. The earlier `placeholder-fixed*.png` files remain insufficient evidence by themselves; use the new controlled pair above.

## Dark artwork background — 2026-09-09

The owner approved the controlled loading screenshots, then reported that the backing behind loaded artwork disappears into the cell in dark mode. Reproduced in the actual populated iPad Favorites list: `secondarySystemBackground` matches the dark grouped row. `GalleryCover` now uses `systemGray5` for its backing in dark appearance and retains the existing light backing. This shares the dark loading-placeholder gray and keeps the accepted aspect-fit behavior.

`dark-cover-before.png` and `dark-cover-after.png` show the same live rows in portrait Large. The after capture visibly distinguishes the full cover bounds from the cell. Build, SwiftLint, and whitespace checks passed. Both simulators received the normal updated app; iPad remains on dark Favorites for owner inspection. This pass does not claim a new full appearance/size matrix.

## Reducer ownership and Setting selection follow-up

The owner accepted the dark cover result. Login-return observation has since moved from the Favorites/Watched views to cancellable cookie-change effects in their reducers, started by `onPresented`. Each observer detects a false-to-true login transition and sends `loginSucceeded`; the existing empty-list and in-flight fetch guards remain responsible for avoiding redundant work. View-level login-change callbacks were removed. The observation stays alive while a pushed login route covers the original screen.

Setting-tab source inspection: the `.sending` binding setter sends an action without directly mutating the selected value. `TabBarReducer` handles a Setting request by asynchronously resolving device type; on iPad it emits a presentation delegate while leaving the selected tab unchanged. It does not select Setting and then restore the previous reducer value. The reported transient visual selection is not explained by a reducer rollback; SwiftUI's tab selection rendering and asynchronous presentation remain distinct from that state invariant. No change to the Setting-tab presentation mechanism is part of this follow-up.

Validation for the reducer follow-up: both login-return observation tests and six Setting presentation tests passed (8 total); changed Swift files passed SwiftLint and whitespace checks. These tests prove action routing and selected-state invariants, not the absence of a transient native tab animation.


## Native login verified — 2026-09-10

This follow-up supersedes the deferred native-login status above. The owner supplied credentials in a private temporary file outside the repository, completed Cloudflare verification on the simulator, and confirmed successful login. No credential values or raw authentication exchanges are included in repository artifacts.

### Root cause and correction

The app's cached native-login POST responses contained a successful sign-in page, authentication `Set-Cookie` headers, and a `bounce_login.php` redirect. The general response parser interprets that URL as an authentication-required marker. `LoginRequest` converted the marker into a reasonless refusal before passing the successful response to the cookie client. The earlier CAPTCHA-form classification change did not address this failure.

`LoginRequest` now permits a response with that marker when both authentication cookies are present, nonempty, and unexpired. Explicit site errors, forum error messages, and CAPTCHA forms retain their existing handling. A marker-bearing page without valid credentials still throws before its cookie tombstones can reach the shared jar. Login requests also use `reloadIgnoringLocalCacheData`, so a new attempt cannot reuse an earlier local authentication response.

### Live evidence

- Correct test app: `app.ehpanda.personal`, iPhone review simulator, iOS 26.5.
- Proxyman captured POST flow 1900: HTTP 403 with `Cf-Mitigated: challenge`. The app presented its challenge web view. After the owner clicked verification, the Cloudflare page kept spinning; app logs reported an empty challenge cookie store and no clearance capture.
- The system proxy was disabled, restoring its initial state. A fresh native-login attempt again presented a challenge. The owner completed it; at 00:56:44 JST the app logged clearance capture, a response without the login form, and successful login.
- The final successful exchange was inspected through the existing local DEBUG response dump, not Proxyman: HTTP 200, the successful-login message, the bounce redirect, and both authentication cookie names. Cookie values were not printed. The final exchange occurred with the system proxy disabled.
- Account displayed Logout. Selecting Favorites loaded real gallery rows and covers. `native-login-favorites-2026-09-10.png` records that populated state; `native-login-challenge-pending-2026-09-10.png` records the earlier spinner. Both are stored with the external evidence described above.

This is a successful native-login run, including user-completed Cloudflare verification and subsequent Favorites loading. It does not independently verify returning directly from a Favorites login wall without selecting the tab. Disabling the proxy was sufficient for this later verification to complete, but this sequence does not establish the exact cause of the earlier Cloudflare spinner.

### Validation

The final build passed 39 tests: 27 request-layer tests across login rejection, account request assembly, and CAPTCHA handling, plus 12 login challenge-flow tests. New coverage preserves authentication cookies on an anonymous successful bounce-redirect fixture and asserts the login request's cache policy. Changed Swift files passed SwiftLint without suppressions, and `git diff --check` passed. The normal updated app remains installed and logged in on Favorites.
