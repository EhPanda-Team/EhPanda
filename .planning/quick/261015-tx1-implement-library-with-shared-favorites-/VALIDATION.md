# Library and per-list layouts: validation

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Recorded 2026-10-16. These are native implementation results, separate from the historical proposal
at `http://127.0.0.1:55920/index.html`, which remains running and visually unchanged.

## Source attribution and environment

- Xcode 27.1 Release Candidate, SDK 27.1, deployment target 27.0.
- Branch `agent/app-design`, based on `e6efecb69f2430365061e81b1eb4547a04aa555f`.
- Final code/test commit `56f906c76675441de3b79e5fa372c87e5a8bff65`; production continuity fix
  `5536aec8ea`. Duo source hashes match this final tree exactly. The other runs retain the same
  production and FeatureTests sources, with the explicitly recorded UI-query differences below.
- Every run records SHA-256 for tracked and untracked production/test sources, lint configurations
  and runner files. `.build/library/final-source-evidence.json` compares the union of old/current
  paths, including added files. Production and FeatureTests sources are identical to the passing
  feature, iPad and iPhone runs. Later differences affect UI-test targeting only.
- Dedicated iPhone Air `6CE1E40A-7090-484E-8C49-B7BCBDC5E684` and iPad Pro 11
  `114E0258-098C-4C26-B2FF-0B5CECEA4810` run iOS 27.0; Duo
  `05422A43-8575-4BA6-A791-FAC2D5D3BA19` runs iOS 27.1.
- Xcode test commands ran sequentially with `-parallel-testing-enabled NO` and
  `-collect-test-diagnostics never`. Per-device locks isolate manual checks from tests.

## Automated gates

| Gate | Result | Local evidence |
|---|---|---|
| Ten selected FeatureTests targets | 959 exact enumerated identities: 949 passes and 10 named existing expected-diagnostic tests; zero failures, skips or repetitions | `.build/library/final-v3-20261016/feature/` |
| iPad native UI | 6/6 passed; zero build warnings/errors | `.build/library/final-ui-20261016/ipad/` |
| iPhone native UI | 6/6 passed; zero build warnings/errors | `.build/library/final-ui-20261016/iphone/` |
| Duo native UI | 6/6 passed; zero build warnings/errors | `.build/library/final-duo-v3-20261016/` |
| Strict SwiftLint | 53 changed/new Swift files, zero violations | `.build/library/final-lint.json` |

Feature coverage includes real schema migration and unrelated-field preservation, independent
presentation scopes, Library group/filter/path/query/anchor retention, pagination guards, append
and deduplication, failure state, download lifecycle and anchored per-item confirmation ownership.
The ten expected diagnostics are individually named in `feature/result.json`; no blanket allowance
for failing tests was added.

UI coverage exercises row/grid anchor restoration, search → detail → actual dismissal → retained
query, a real next-page fixture, cold native titles/grid at standard/AX1/AX3/AX5, category return and
source switching, mode persistence after relaunch, and real local download reading, status inspection,
folder move, cancel deletion and confirmed deletion. Download operations use test-owned temporary
folders, real manifests and neutral cover/page files.

Run `Scripts/visual/run-library-validation.py --stage feature` or `--stage ui --device <UDID>` with
`DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer` and
`--output <fresh-evidence-directory>`. Each evidence directory contains the exact command, exit,
enumeration, diagnostics, result JSON and xcresult bundle.

## Native manual checks

| Check | Observation | Evidence under `.build/library/native-review/` |
|---|---|---|
| iPad live standard → AX1 → AX3 → AX5 → standard | Same process; native headers and controls retained, grid reflows to one column at AX5 | `ipad/live-*`, `live-app-state.txt` |
| iPhone live text-size sequence | Same process; settled captures preserve native Favorites title at all four sizes; an earlier 0.7-second capture caught title animation and is retained as intermediate evidence | `iphone/favorites-settled-*` |
| iPad focused search, 834 → 375 → 834 pt native window | Search text Library, selected source and grid survive without relaunch | `ipad/window-*` |
| iPad Download Status during 834 → 375 → 766 pt resize | The same Library Download 6 and manifest-derived 2/2 status remain presented | `ipad/status-narrow.*`, `status-expanded.*` |
| iPad floating gallery detail | Native outside-sheet dismissal returns to the retained query | UI return test and local manual inspection |
| iPhone VoiceOver | Real vot focus walks native toolbar/title/search and galleries; announces Actions available; default rotor is custom actions | `iphone/vot.log`, `vo-download-grid.png` |
| iPhone VoiceOver management | Real double taps open Actions → Pages; Close returns focus to Library Download 6 | `iphone/vot.log`, `vo-status-return.txt` |
| Reduce Motion + Reduce Transparency | Grid, visible management menu and Download Status remain usable | `iphone/reduced-effects*` |
| Duo focused search, closed → open → half → closed → open | Same PID 31007, Favorites selection, Library query and grid retained; caret stays focused on the inner display, software keyboard returns on the cover | `duo/query-*` |
| Duo Download Status, closed → open → half → portrait → open → closed | Same PID and Library Download 6; downloaded pages 1–2, pending/failed zero remain; native sheet changes position and size | `duo/status-*` |

Simulator keyboard rotor selection did not establish activation of every named custom action; the
visible native Actions menu and its status round trip were verified with actual VoiceOver double
taps. Physical-device rotor activation and pronunciation are not claimed. This is a bounded check
of the changed surfaces, not a whole-app accessibility certification.

The Duo tool reports a stale portrait screen envelope on the wide inner display and sends manual
taps to the cover. Interactions were therefore performed on the cover, then the running app was
folded with the simulator pose driver; actual active-display captures establish the inner layout. Hardware portrait
means a landscape inner viewport; hardware landscape-left means portrait there. The native search
caret/query survived, but the software keyboard was not visible on the inner captures. No keyboard
workaround was added. The first status probe expected the compact 2/2 accessibility badge, which
the tool omitted outside its incorrect screen envelope; the same sheet’s downloaded/pending/failed
rows and real screenshot confirm the unchanged manifest result. The original probe output is kept.

The completed matrix is the explicit rows above plus the six automated UI scenarios per device.
It is not every possible device × source × orientation × presentation × accessibility permutation.
A separate live iPad rotation with a presented gallery detail, physical-device custom-action rotor
activation, all RTL languages and the historical whole-app Duo/reader matrix were not repeated.

## Failures retained and corrected

- Initial feature fixtures expected a nil-to-nil selection change, an unstubbed folder refresh, old
  automation ordering and pre-extraction source ownership. Expectations now match the real contract
  while retaining behavioral and role/tint assertions.
- iPad revealed a production restoration defect: fixed top anchoring put a restored row behind the
  native bar. Native minimal scrolling reveals the complete row; UI assertions measure the viewport.
- A search-return test could find underlying content without dismissing the floating sheet. The
  shared helper now requires detail to disappear and uses native close/back or outside margins.
- Duo vertical BackButton is a generic accessibility element outside NavigationBar; sheet Close also
  moves outside the horizontal bar. UI queries now follow semantic identifiers across element kinds.
- Duo's cancel-popover fallback assumed a horizontal Downloads title. It now taps the measured
  Presentation control outside the item-anchored dialog and still asserts the gallery remains.

Earlier failing bundles remain under `.build/library/`; none is relabeled as a pass. No app workaround
for native navigation or accessibility title placement was added.

## Native review images

All tracked images are unedited captures using neutral fixtures. `screenshots/manifest.json` records
repository-relative source paths and SHA-256. Live gallery content and raw logs remain local.

- iPad Library Favorites (image removed from repository history)
- iPad Library Downloads (image removed from repository history)
- iPad anchored delete confirmation (image removed from repository history)
- iPhone Favorites (image removed from repository history)
- iPhone Downloads (image removed from repository history)
- iPad narrow native window (image removed from repository history)
- iPad window restored with query retained (image removed from repository history)
- Status in a narrow iPad window (image removed from repository history)
- Duo open, query retained (image removed from repository history)
- Duo half-folded, query retained (image removed from repository history)
- Duo half-folded Download Status (image removed from repository history)
- Duo portrait Download Status (image removed from repository history)

## Cleanup and boundaries

The prior proposal server still returns HTTP 200. iPad was restored to Full Screen Apps and standard
text size, launched normally without test flags (fresh live Home observed), then shut down. iPhone
text size, VoiceOver, Reduce Motion and Reduce Transparency were restored to captured baselines; its
fixture launch was terminated and a normal launch performed before shutdown. Duo was restored to
closed hinge 0°, hardware portrait and standard text size; accessibility settings were unchanged.
Its fixture process was replaced by normal PID 33304 without test flags, fresh Home content was
observed, and the simulator was shut down. All three dedicated devices and locks are released.

Source attribution was repeated after committing: the final Duo hash map is identical; only UI-test
files differ from the earlier iPad/iPhone/feature gates. Strict lint covered all 53 changed Swift files
and `git diff --check` passed. No production change was made after those passing gates.

Search A/B remains an owner design choice outside this task; its implementation change is the
independently remembered row/grid mode. Home preview sections, download manifest authority and
user-owned-folder deletion semantics are unchanged.
