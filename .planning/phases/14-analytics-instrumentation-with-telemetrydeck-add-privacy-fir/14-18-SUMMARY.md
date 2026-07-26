---
phase: 14-analytics-instrumentation
plan: 18
completed: 2026-07-26
tasks_completed: 2
tasks_total: 2
requirements-completed: [ANALYTICS-01]
---

# 14-18 Summary: Owner verification and phase close

**The two guarantees no test can prove are confirmed against a live build: a credential-free build reaches the ingestion host zero times, and a credentialed one delivers payloads that carry no forbidden value. Reading the disclosure against the observed traffic found it understated, in English and absent entirely in five languages; both are fixed. The owner then reversed D-01, so a runtime opt-out was built and verified on device.**

## Task 1 (recorded 2026-07-25)

Whole-phase static and suite verification: full app-scheme run green with all three new test targets confirmed executed by name, exactly one SDK import, no deprecated manager spelling, no suppression directive added during the phase, zero build warnings, SDK pinned to a 2.x stable tag. Results are in `14-VALIDATION.md`.

## Task 2: the owner checks

### Check A, silence without a credential (D-13)

Preconditions were established rather than assumed. `git status --porcelain Config/` was empty and `Config/` held only the tracked default; both credential keys read back empty from the **built** bundle's `Info.plist` rather than the source plist, on a bundle timestamped minutes earlier so a stale artifact could not be mistaken for a clean one.

Method: a decrypting proxy on the simulator, with a positive control taken first. With the host filter cleared, the app's ordinary `e-hentai.org` and image-CDN traffic appeared, proving capture was live before any conclusion was drawn from an empty list. Six emissions across five signal cases were driven, then a 25 second wait covered the SDK's 10 second transmit interval so an unflushed batch could not pass for silence.

**Result: zero requests.** 79 domains captured overall, none matching the vendor. The absent `TelemetryDeck.Session.started` is the load-bearing part: that signal comes from the SDK itself rather than from app instrumentation, so its absence shows the gate resolves before initialization rather than merely suppressing call sites.

### Check B, live delivery and payload inspection (D-10, T-14-01)

The same flows against a build carrying the real credential, captured decrypted so the inspection read the bytes that left the device rather than the vendor's post-parse view. Eight `POST /v2/` requests, all `200 OK`, every emitted signal accounted for and nothing unexpected among them.

The forbidden-value sweep ran over every request body, with a positive control (a known-present key matched 8/8) proving the body search was live. Search keyword text, gallery title, uploader name, gallery identifier, gallery token and any URL: zero matches each. No `Cookie` header on any request.

The three highest-risk signals were read in full. A 28 character, four word, tag-syntax query rendered as `keywordLength: 28`, `wordCount: 2-5`, `usedTagSyntax: true`, `resultCount: 21-50`. A gallery with roughly thirty tags rendered as `category: manga` plus two namespace counts. The reading signal rendered as bucketed pages and duration with no reference to which gallery was read. D-11 freshness was proven inside a single session: `leftToRight` on one signal, `vertical` on a later one, no relaunch between them.

Visual confirmation in the vendor's web console was not separately performed; delivery is evidenced by the ingestion endpoint's responses plus the decrypted bodies.

### Check C, disclosure against observed reality (T-14-17)

**Two findings, both fixed.**

The never-collected list held: nothing on it appeared in any payload. But every signal also carried SDK-attached enrichment the disclosure did not mention, including device model and architecture, screen metrics, OS version, locale, region and time zone, seven accessibility settings, appearance, retention and session counts, first-session date, and the event's date and time of day. `Search.resultCount` was likewise undescribed. The accessibility flags carry the most weight, since reduce-motion, bold-text and text-size can imply disability status, and region plus time zone are coarse location. The code was left unchanged, since the enrichment follows from the `sessionStatsEnabled` decision already recorded in `COVERAGE.md`; the README was extended to disclose it.

The second finding was wider: the `## Analytics` section existed **only in English**. All five translated READMEs were structurally identical to the English file but carried no such section and no mention of the vendor at all, so a reader of any translation received no disclosure whatsoever. The section is now present in all six at the same position, written once the wording had settled.

Both fixes deliberately describe the SDK's date and time-of-day fields as the date and time the event was sent, never as calendar data, so a reader cannot mistake them for personal calendar events, and without an explicit denial that would plant the same idea.

## Beyond the plan's declared scope (owner-directed)

**D-01 is reversed.** After the checks above, the owner asked for an in-app opt-out. `Setting.shareAnalyticsData` gates `AnalyticsClient.send` and empties `AnalyticsDefaultParameters.snapshot`; `start` is untouched, so the SDK still initializes and its session signal still counts installs. `TelemetryDeck.Config.analyticsDisabled` stays opted out in `COVERAGE.md`, now for a new reason: it would silence the session signal too. The supersession is recorded on that row.

The field is optional by necessity rather than by taste. Synthesized `Codable` throws on a missing non-optional key, so a blob written before the toggle shipped would fail to decode and reset every other preference to its default. `isSharingAnalyticsData` resolves the resulting `nil` to the opt-in state the build already had.

The owner also directed the scope of the opt-out: an opted-out install stops sending the six app settings as well as the thirteen signals, so its host, login state and reading preferences no longer ride along on the session signal. The disclosure states plainly that switching it off does not make the app silent, since the anonymous identifier and the SDK's technical details are still sent once per session; an opt-out that implied total silence would be its own disclosure failure.

**Check D verified the opt-out on device**, by the same method as Check A. With the toggle off, telemetry flow IDs stopped advancing while `e-hentai.org` traffic from the same session ran roughly 340 flows further, including the search request itself. New tests cover old-blob decode tolerance, the opt-in resolution of `nil`, the accessor round-trip, and an empty snapshot under every other setting combination.

## Verification

- Full suite: **TEST SUCCEEDED**, build clean with zero errors and zero warnings.
- Checks A, B, C and D all pass; `14-VALIDATION.md` records each with its evidence and is marked owner-verified.
- Localized strings added for all six locales the catalog supports.
- Each translated README names the opt-out path using that locale's own UI strings, verified against the string catalogs. This caught two wrong paths before they shipped: Simplified Chinese labels that screen 一般 rather than 通用, and Traditional Chinese uses 一般設定.

## Notes for later

- The German and Korean disclosures were written without a native reviewer. They are grammatical and use Apple's platform accessibility vocabulary, but a privacy disclosure is a place where a subtly weak verb changes what is promised, so both deserve a native read before release.
- An injected instantaneous tap does not actuate a SwiftUI `Toggle`; a touch path with a short dwell does. Three taps looked like a binding failure until a known-good toggle in the same form reproduced it.
- Two pre-existing warnings (`try`/`await` with nothing throwing or suspending) surface in `AnalyticsDefaultParametersTests` only when the test target is compiled. The app-scheme build does not compile `Tests/`, which is why the phase's zero-warning check did not see them.
