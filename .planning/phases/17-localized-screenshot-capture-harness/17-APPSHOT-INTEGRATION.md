# Standalone appshot consumer

The 2026-10-15 request moves the tool's implementation, history and GSD design documents to
`$HOME/Fork/appshot-cli`. This branch contains only the app's use of that package. The independent
repository has the SDK at its root and the executable package in `CLI/`. No tool source is vendored here.

## Current integration

- `AppPackage` references the sibling checkout through `../../appshot-cli`. AppFeature imports the SDK
  only in Debug code. The UI-test target links its XCTest helper through a local project reference,
  and the capture test compiles only in Debug. The SDK's protocol and helper are empty in iOS Release;
  the protocol remains available in macOS Release for the CLI.
- `APPSHOT_SCENE` is decoded strictly before the first Store exists. A capture goes through the existing
  fixture validation, network replay, isolated storage and navigation. Conflicting app automation keys
  fail. A pin probe has no fixtures and uses the existing isolated visual host.
- The existing diagnostics producer feeds the SDK state element, including the app's screen, readiness,
  selection, fixture identity, content and native sheet bounds. The original UI-test diagnostics channel
  remains available to the reference runner. The two paths share their content verifier.
- `AppshotCapture.xctestplan` selects exactly one capture test and has no retry policy. Ordinary UITests
  excludes that test. The CLI independently validates the actual result count and repetition rules.
- `appshot.json5` declares 384 marketing coordinates, with the existing eight screens, two content sets,
  six locales, two appearances, iPhone Air and iPad Pro 11-inch (M5), portrait and large text. It uses new
  named Appshot simulators. Actual fixtures and all run evidence stay outside Git.

## Run from the app checkout

The CLI checkout must sit beside this repository. Build it once with the pinned Xcode:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer
swift build -c release --package-path ../appshot-cli/CLI --product appshot
../appshot-cli/CLI/.build/release/appshot doctor
../appshot-cli/CLI/.build/release/appshot simulators create
../appshot-cli/CLI/.build/release/appshot pin measure --output "$HOME/Library/Caches/Appshot/app-pin"
```

Review the measured candidate before saving it to `Scripts/visual/appshot-pin.json`. Do not copy the
example app's pin: its phone model and app geometry are different. Then run a bounded actual-app capture:

```sh
../appshot-cli/CLI/.build/release/appshot capture \
  --filter screen=home,set=nonexplicit,locale=en,appearance=light \
  --input fixtures=.capture/marketing/current \
  --output "$HOME/Library/Caches/Appshot/app-smoke"
../appshot-cli/CLI/.build/release/appshot verify "$HOME/Library/Caches/Appshot/app-smoke"
../appshot-cli/CLI/.build/release/appshot export "$HOME/Library/Caches/Appshot/app-smoke" \
  --to "$HOME/Library/Caches/Appshot/app-export"
```

Use a fresh output directory for each new run. A failed run retains its evidence. Resolve the reported
problem before explicitly resuming; no script retries or changes comparison policy automatically.

## Acceptance boundaries

The Python capture/export path remains the reference until output parity has been measured. In
particular, its current sheet comparison can restrict comparison to sheet pixels; appshot compares
entire frames strictly. Do not claim that these comparison contracts are already equivalent. The
legacy Live Text recording entry point and the marketing consumer/export adapter still use Python.

A config covering 384 coordinates does not establish that all 384 ran. Pin probes establish geometry,
not content parity. The migration verification record must list actual tested coordinates and failures.
Tool implementation, a real app integration, full workflow replacement and v1 acceptance are separate
claims. The original three identical soak matrices failed that acceptance condition, and native
simulator setting persistence remains unresolved even though appshot now detects the failure after a
reboot and retains the recovery journal.

Prior selections of agent-recommended engineering options are revisable on evidence. They are not
permanent owner positions. The instruction to keep compiler reports local and post no upstream comment
is an explicit user constraint.

## Implementation map and complete split

The app-only integration was committed directly on `feature/gsd-phase-17` as `0986221596`; it was
not a literal cherry-pick of either old capture-cli branch. It owns the following boundaries:

| Files | Implementation responsibility |
|---|---|
| `AppPackage/Package.swift`, project file and shared app scheme | Sibling package products and dedicated test plan wiring |
| `UITestSupport/AppshotCapture.swift` | Strict scene decoding; Mutex-held launch scene; rejects competing `EHPANDA_` keys, unsupported screens, non-portrait/non-large coordinates, unexpected custom keys or input names; requires the fixtures input and one of the two supported sets |
| `UITestSupport/UITestAutomation.swift` | Resolves the scene before Store construction, translates capture coordinates to the existing validated fixture request, preserves offline replay/storage isolation, and routes input-free probes through the isolated visual host |
| `RootView.swift` and `UITestSupport/CaptureDiagnostics.swift` | Probe presentation and the SDK state child inside the existing diagnostics element; one app diagnostics producer supplies both consumers; pending and failed states retain blockers and unknown-request failures |
| `EhPandaUITests/Support/CaptureLauncher.swift` | Shared `CaptureContentVerifier` preserves fixture identities, content, sheet, Live Text and download checks; `CaptureFixtureCopy.read` reads the helper-owned copy without taking teardown ownership |
| `EhPandaUITests/AppshotCaptureUITests.swift` | One Debug-only test uses `captureAppshotScene`, maps the scene's coordinate, decodes app diagnostics and runs the shared content verifier; the SDK helper owns copying and cleanup |
| `AppshotCapture.xctestplan`, `UITests.xctestplan` | Dedicated one-test, nonparallel, no-retry capture plan; ordinary regression tests exclude the capture class |
| `appshot.json5`, `Scripts/visual/appshot-pin.json` | 384 app coordinates, consumer bundle/build identity, fixture input and export paths; measured device/locale pin independent of the tool example |
| `AppshotCaptureTests.swift` under AppFeatureTests | Scene decoding, invalid-coordinate/input and conflicting-launch-key coverage; seven selected tests passed |

Paths abbreviated with `UITestSupport/` are under `AppPackage/Sources/AppFeature/`. SDK geometry and
rendering checks stay in the tool; readiness and content truth stay in the app. Release declarations
are compiled out of the iOS SDK and app entry points; macOS CLI Release still needs the protocol.
See [17-APPSHOT-VERIFICATION.md](17-APPSHOT-VERIFICATION.md) for the original Release failure,
corrected binary checks, exact source identities, capture hashes and the bounded coverage claim.

The earlier app-side command correction is `d6be7faa31`. The single-pass implementation `cea354a45e`
retains `Gate.single_pass_run`, strips repetition only from a run-local xctestrun copy, enumerates
compiled tests, validates exact selected identities/counts and rejects skips or Repetition nodes.
Disabled tests outside the requested selection are allowed; disabled requested tests are rejected.
Its complete [proposal and execution record](17-SINGLE-PASS-PROPOSAL.md) is now stored here, alongside
the existing validation, research, plans 17-05/08/09/10/11 and `Scripts/visual/README.md`.

All tool work moved to the sibling repository: 136 commits, 222 tip files, nine original Markdown
paths and all 91 distinct historical document versions. The verification checked every changed
path in every source commit, and the entire mapped tree's blobs and modes at every revision.
The standalone repository's `.planning/migrations/standalone/PRESERVATION.md` and `PRESERVATION.json`
contain the full proof and ownership index. Its full DESIGN, PLAN, PORT-LEDGER, VERIFICATION,
protocol, integration guide, restoration investigation and review decisions remain there; none
were replaced with this summary. App-specific Phase 17 documents and implementation remain here.

The original and failed run evidence remains in `$HOME/Library/Caches/Appshot/`; compiler reports
stay local. Removing the obsolete worktrees and branches after backup does not complete the
remaining 382 app coordinates, establish reference parity, solve native persistence or accept v1.
