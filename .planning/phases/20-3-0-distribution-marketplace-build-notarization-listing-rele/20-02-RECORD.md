# 20-02 Record: build number and screenshots repository

## Build number (Task 2)

Read from `origin/main`, fetched with `git fetch --no-tags origin main` on 2026-11-09:

| | |
|---|---|
| `main` SHA | `37b979965cf7c4778877c795e8df60c2c0ff6eb3` ("Fix typos") |
| `AltStore.json` highest `buildVersion` | 158 (one version listed) |
| `SideStore.json` | absent on `main` (skipped, as `check-build-number.sh` does) |
| `altstore-beta.json` | absent on `main` (skipped) |
| chosen `n` | **159** = max(158 + 1, 159) |

`Scripts/bump-version.sh -v 3.0.0 -b 159` set `CURRENT_PROJECT_VERSION = 159` and `MARKETING_VERSION = 3.0.0`
on the four app and share-extension configurations. The four test configurations (EhPandaUITests,
VisualSnapshotTests) stay at 1.0 (1). The first run also bumped them, because the script recognised test
configurations only by the bundle ID `app.ehpanda.tests`, which no target uses any more. That was fixed in the
script (TEST_HOST or TEST_TARGET_NAME also marks a test configuration), the project file was put back, and the
bump was run again.

`bash actions-tool/check-build-number.sh 159 <main's AltStore.json>` printed: "Build 159 is greater than every
published build (highest: 158)."

Still needed before the 3.0.0 release PR passes its notes check: `ReleaseNotes/3.0.0.md`. That is owner content
and not part of this phase (D-03).
