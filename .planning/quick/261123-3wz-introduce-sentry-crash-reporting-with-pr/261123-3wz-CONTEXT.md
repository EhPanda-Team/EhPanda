# Quick Task 261123-3wz: Introduce Sentry crash reporting with privacy-preserving settings - Context

**Gathered:** 2026-11-23
**Status:** Ready for planning

<domain>
## Task Boundary

Add Sentry crash reporting to the EhPanda app, configured with the privacy-preserving settings of an
established reference design (crashes only, nothing about the person, a `beforeSend` scrubber), declare it in
`App/PrivacyInfo.xcprivacy`, and upload each release archive's dSYMs from CI. README copy is out of scope.

</domain>

<decisions>
## Implementation Decisions (locked: owner, 2026-11-23)

- **D-01:** (When reports are sent) Mirror the reference: the SDK starts at launch, before and regardless of the analytics choice, under every
`AnalyticsLevel`. The README's "nothing is sent until you choose" statement stays as written, because crash
reports are not analytics data (owner's words: "mirror the project. and the statement in readme still stand,
because it's not analytics data."). Do not gate the SDK on `Setting.analyticsLevel`, and do not edit README files.

- **D-02:** (How the DSN gets into the app) Follow EhPanda's TelemetryDeck pattern, not a hard-coded DSN: a `SENTRY_DSN` repository secret is passed to the
archive step of each deploy workflow, written into `App/Info.plist` through the build configuration the same way
`TELEMETRYDECK_APP_ID` is, and read through `AppInfo` (as `AppInfo.telemetryDeckAppID` is). A nil or empty DSN
means the SDK is never started, so builds from source and forks send nothing. The workflows' existing
"Verify analytics credentials" style check is extended (or mirrored) so a release archive without a DSN fails.

- **D-03:** (Scope) In: the SDK module and its options, the scrubber, the start call, tests, the privacy manifest entry, and the CI
dSYM upload. Out: README (all six languages), the ehpanda.app privacy policy, any settings UI or toggle.

### Claude's Discretion
- Exact module name and placement (one module is the SDK's only importer; see the reference design below).
- The Sentry `environment` value (derive it from `DistributionChannel`, not a hard-coded string).
- How the start rule detects test runs and UI-test/automation launches in EhPanda.
- dSYM-upload wiring details within the constraints below.

</decisions>

<specifics>
## Reference Design (established pattern, to mirror)

**Module boundary.** One module (e.g. `CrashReporting`) is the only importer of `Sentry`
(`.product(name: "Sentry", package: "sentry-cocoa")`, a current 9.x release). The app target starts it; the
share extension never links it. Add the module's `.swiftlint.yml` with `parent_config` per AGENTS.md.

**Start rule.** `start(...)` is the first call of the app delegate's launch path, outside `#if DEBUG` logic but
never starting in a Debug build, a unit/UI test run, or an automation launch. A testable internal overload takes
the environment, the testing flags and the DSN, and returns whether it started. Nothing in first-party code sends
a report by hand: the only reports are crashes the SDK finds on the next launch.

**Options (every switch that could record more than the crash is set explicitly, so a changed SDK default cannot
turn it on):**
- `dsn`, `environment`; release and dist stay the SDK defaults; no traces sample rate, sampler, profiling, replay.
- `sendDefaultPii = false`; no user is ever set.
- Crashes only: `enableAutoSessionTracking`, `enableWatchdogTerminationTracking`, `enableAppHangTracking`,
  `enableCaptureFailedRequests` all `false`.
- Nothing about the network or the screen: `enableNetworkBreadcrumbs = false`, `enableAutoBreadcrumbTracking =
  false`, `enableSwizzling = false`, `maxBreadcrumbs = 0`.
- Tracing instrumentation off: `enableAutoPerformanceTracing`, `enableNetworkTracking`, `enableFileIOTracing`,
  `enableCoreDataTracing`, `enableUIViewControllerTracing`, `enableUserInteractionTracing`,
  `enablePreWarmedAppStartTracing` all `false`.
- `attachScreenshot = false`, `attachViewHierarchy = false`.
- `enableMetrics`, `enableLogs`, `enableSpotlight`, `enableMemoryIntrospection`, `sendClientReports`,
  `enableMetricKit` all `false`.
- `attachStacktrace = true`; `beforeSend = { scrub($0) }`.
Check each option name against the resolved SDK version's `Options` before relying on it.

**Scrubber (`beforeSend`; never drops an event: a smaller crash report is still a crash report):**
- Clear `user`, `breadcrumbs`, `request`, `tags`, `extra`.
- Keep only reviewed contexts `app`, `culture`, `device`, `os`, `trace`; drop every other context whole (the SDK
  puts an uncaught NSException's `userInfo` free text in its own context). Remove `device_app_hash` from `app`.
- Free text (`message.formatted`/`message`/`params`, each exception `value`, every string at any depth in
  `exception.mechanism.data`, which holds the Swift runtime's `crash_info_messages`) is redacted: each URL
  (`scheme://...`), `name@host` token, IPv4 and IPv6 address becomes `[redacted]` first, then a `/Users/<name>`
  home folder name becomes `/Users/_`, then the text is cut at 300 characters. The order matters (a home-folder
  match must not swallow a following URL's scheme). Address matches respect token boundaries.
- Paths: each stack frame `package` (exception, thread and event stack traces) and each debug image `codeFile`
  get the home-folder redaction.
- EhPanda-specific addition to weigh: gallery URLs, E-Hentai cookies or tokens must never survive in free text;
  the URL rule covers `https://e-hentai.org/...` and `exhentai.org`, and the planner should add tests for them.

**Tests (Swift Testing, parallel, no `.serialized`):** options tests (every switch above asserted), start-rule
tests (Debug/testing/automation/nil DSN never start; the overload returns whether it started), scrubber tests
(each rule, the ordering case, mechanism data at depth, contexts filtering, `device_app_hash`, truncation, IPv6).

**Privacy manifest.** Add to `App/PrivacyInfo.xcprivacy` `NSPrivacyCollectedDataTypeCrashData`, linked `false`,
tracking `false`, purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`. The SDK bundles its own manifest
for its required-reason APIs; the app's file states only what the app declares itself. Keep
`actions-tool/tests/test_privacy_manifest.py` in agreement.

**dSYM upload.** A shell script uploads the archive's `dSYMs` folder with a pinned `sentry-cli` release whose
bytes are checked against SHA-256 values written in the script (read from that release's page) before it runs;
a download is never piped into a shell. `SENTRY_AUTH_TOKEN` is read from the environment only, never put on a
command line or printed, and the tool's output passes through a filter that hides it. A failed upload never
fails the build: it prints one `warning:` line and exits 0; a `--reupload <dSYMs folder>` form for a person
exits non-zero on failure. In EhPanda it runs as a GitHub Actions step after a successful archive in the deploy
workflows (`deploy.yml`, `deploy-beta.yml`, `deploy-pal.yml`), before the `.app` is moved out of the archive.
Org, project and the Sentry region URL come from repository variables with full names (owner rule: secrets and
variables use full names, never abbreviations), e.g. `SENTRY_ORGANIZATION`, `SENTRY_PROJECT`, `SENTRY_URL`.
Keep `test_workflows.py` and actionlint green.

</specifics>

<canonical_refs>
## Canonical References

- `AGENTS.md` / `CLAUDE.md` (module `.swiftlint.yml`, test parallelism, SwiftLint rules)
- `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` (`telemetryDeckAppID` pattern for D-02)
- `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift` (nil ID resolves to no-op)
- `.github/workflows/deploy.yml`, `deploy-beta.yml`, `deploy-pal.yml` (archive step, credential check)
- `App/PrivacyInfo.xcprivacy`, `actions-tool/tests/test_privacy_manifest.py`

</canonical_refs>
</content>
</invoke>
