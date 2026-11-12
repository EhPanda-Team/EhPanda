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

## Screenshots repository (Task 3)

- Consent: owner msg 2787 (yes to creating and pushing the repository), and owner msg 2794 (use his own GitHub
  sign-in).
- Done by the orchestrator with that sign-in. The public repository was created through the GitHub API, then the
  local assets checkout's `main` was pushed with its history unchanged.
- Repository: https://github.com/EhPanda-Team/ehpanda-assets
- Pushed commit: `d69b30a065b2813c787b58f997a0ae4d318a2847` ("Add the AltStore and SideStore iPhone
  screenshots"). `git ls-remote` shows `HEAD` and `refs/heads/main` at this commit.

Owner msg 2804: the folder `altstore/` was renamed `app-marketplace/` (pushed as `87f6f15`), and the old
`altstore/...` URLs now return 404. The three sources and the tests point at the new folder. The first check, on
`d69b30a`'s `altstore/` paths, also returned seven 200s.

`curl -sSfIL` on each `imageURL` in `AltStore.json`, after the rename, 2026-11-09:

```
200 https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/app-marketplace/iphone/01-home.png
200 https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/app-marketplace/iphone/02-detail.png
200 https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/app-marketplace/iphone/03-reading.png
200 https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/app-marketplace/iphone/04-comments.png
200 https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/app-marketplace/iphone/05-downloads.png
200 https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/app-marketplace/iphone/06-filters.png
200 https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/app-marketplace/iphone/07-more.png
```

The SideStore and beta templates list the same seven URLs, and all seven return 200 there too (D-17).
