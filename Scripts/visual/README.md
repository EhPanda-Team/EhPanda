# Rendering environment

`regression-environment.json` is the tracked, immutable rendering contract shared by
regression, CI and marketing. It was authored from successful real measurements after
17-24 Task 1 committed its producer. Validation never regenerates or rewrites the pin.
Run-local `environment.json` files are observations, not alternative pin inputs.

## Measure the current environment

From the repository root, select Xcode and run:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer
python3 -B -m unittest discover -s Scripts/visual -p test_environment.py
python3 -B Scripts/visual/environment.py measure --output .capture/environment-measurement
```

Use a new output directory for each run. `--derived-data PATH` is optional; by default the
command queries the project's simulator build settings for its normal DerivedData directory.
The command resolves currently available simulator IDs from the model and runtime metadata.
It requires exactly one available simulator per selected model on that runtime; it never
uses a historical UDID or a previous `.capture/` directory to select a destination.

`GeometryTests.swift` belongs to the existing app-hosted **VisualSnapshotTests** target in
**FeatureTests.xctestplan**. The probe creates a full-size real window through FullContentHost,
waits for stable native geometry and records actual points, pixels, safe areas, scale,
size classes, appearance and system font metrics. It rejects a hardware rectangle mismatch
rather than resizing the window to an expected value. The rectangles are 1260×2736 pixels
for iPhone Air and 1668×2420 for iPad Pro 11-inch (M5), with axes exchanged in landscape.

The command reuses the verified native invocation and simulator lifecycle code in
`Scripts/verify-full-content-capture.py`. It builds FeatureTests and UITests, then runs
phone followed by tablet, one xcodebuild at a time. A native UI test rotates the device
before each hosted geometry invocation; another restores portrait afterward. Test repetition
policies are removed from run-local xctestrun copies. Missing, failed, skipped, repeated or
misattributed tests/attachments fail the command. Original text size and Booted/Shutdown
ownership are restored, including on errors.

Each successful run retains four named `phase17-geometry` JSON attachments and their
xcresults, plus six rotation/restore results, complete logs, commands, source hashes and
simulator lifecycle records. `environment.json` separates public rendering characteristics
from local destination IDs and evidence paths. It records exact Xcode/Swift and SDK versions,
runtime identifier/build, model/hardware identifiers, both orientations and deterministic
reference settings. Its source digests identify the measurement producer; its timestamps
are run metadata and do not enter the pin.

## Validate the tracked pin

```sh
python3 -B Scripts/visual/environment.py validate \
  --environment Scripts/visual/regression-environment.json \
  --output .capture/environment-pin-check
```

Validation reads the explicitly supplied pin, resolves fresh IDs by its model/runtime,
measures both families and orientations again, and compares every pinned characteristic.
The output records the original pin bytes' SHA-256 as `pinSHA256`. Success requires the
input bytes to remain unchanged. A mismatch produces a separate failed observation with
an actionable field path; it never repairs or updates the pin. A run-local observations
file is rejected when supplied as `--environment`.

If validation fails, inspect its error and retained results. Select the pinned Xcode,
install the matching runtime, and ensure each named model has exactly one available
simulator. Correct configuration drift before retrying into a new output directory.
A deliberate rendering-contract change requires explicit new measurement, review and a
separate tracked pin edit; ordinary validation and CI do not perform that edit.

The current reference settings are English (`en_US`), GMT, fixed fixture date
2025-01-01T00:00:00Z, system fonts, Large Dynamic Type, light appearance and disabled
animations. The text size comes from the simulator/app setting, not a window override.
Font names, point sizes and line heights for body, caption1 and title1, Bold Text,
legibility weight and display gamut are observed and pinned. The locale, appearance and
Dynamic Type matrix axes are later capture inputs; validating this reference environment
does not reduce their approved coverage.

Reduce Motion is pinned on (owner approval, 2026-10-06). Disabling UIView animations does
not reach time-driven Metal animation such as the dark Home card's gradient, which the app
freezes only under Reduce Motion; without it a capture can race the gradient's bloom.

The pin also depends on device settings that a new or erased simulator does not have.
Validation detects each one; restore them on the pinned simulators instead of editing the pin:

| Setting | Pinned value | Restore on a booted simulator |
|---|---|---|
| Reduce Motion (both) | on | `xcrun simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` |
| iPhone system appearance | dark | `xcrun simctl ui <udid> appearance dark` |
| iPad multitasking (bottom safe area 25 pt) | Full Screen Apps | `xcrun simctl spawn <udid> defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO`, then reboot |

Return each simulator to its original power state afterwards; the runner and gate restore
only the state they found.

Measured native geometry at the initial pin:

| Family | Orientation | Points | Pixels | Insets top/left/bottom/right | H/V size class |
|---|---|---|---|---|---|
| iPhone Air | Portrait | 420×912 | 1260×2736 | 68/0/34/0 | compact/regular |
| iPhone Air | Landscape | 912×420 | 2736×1260 | 0/68/20/68 | regular/compact |
| iPad Pro 11-inch (M5) | Portrait | 834×1210 | 1668×2420 | 32/0/25/0 | regular/regular |
| iPad Pro 11-inch (M5) | Landscape | 1210×834 | 2420×1668 | 32/0/25/0 | regular/regular |

These are measurements, not library presets or new window-size axes. The pin has no
host-specific UDIDs or paths. Plan 17-02 owns regression-runner integration; 17-05 and
17-07 consume the same unchanged `--environment` input for marketing. This directory's
measurement tooling does not yet implement those runners or approve screenshot baselines.

# Real marketing fixtures

Marketing captures show real galleries. `acquire-fixtures.py` saves a declared selection's pages
and images once, with provenance and checksums, so capture runs replay them offline without an
account or a personal library. Synthetic public fixtures for snapshot tests are separate; real
assets stay in the git-ignored `.capture/marketing/` and never become public baselines.

The owner supplies every gallery identifier for both content sets (decision of 2026-10-07,
recorded in `17-03-PLAN.md`). The agent selects no real gallery.

## Selection

The input is a JSON file with exactly these keys:

```json
{
  "schemaVersion": 1,
  "selectionID": "marketing-final",
  "selectionStatus": "provisional",
  "selectionAuthority": "owner",
  "galleries": [{"url": "https://e-hentai.org/g/<gid>/<token>/", "set": "nonexplicit"}],
  "scenes": {
    "nonexplicit": {
      "home": {
        "hero": {"galleries": ["<gid>", "<gid>", "<gid>"], "selectedIndex": 1},
        "frontpage": ["<gid>", "<gid>"],
        "toplists": {"yesterday": ["<gid>"], "pastMonth": ["<gid>"], "pastYear": ["<gid>"], "allTime": ["<gid>"]}
      },
      "flow": {"gallery": "<gid>", "readerPage": 4, "liveTextPage": 4, "pages": [3, 4, 5]},
      "downloads": [{"gallery": "<gid>", "status": "completed"},
                    {"gallery": "<gid>", "status": "active", "completedPages": 12}]
    }
  }
}
```

- `selectionStatus` is `provisional` or `final`; a final selection requires `selectionAuthority: owner`.
- Each gallery URL has the canonical form `https://e-hentai.org/g/<gid>/<token>/` and an explicit
  `set`, `nonexplicit` or `explicit`. Set labels are never derived from gallery categories.
- `scenes` holds one scene per declared content set. Every slot names a gallery of that set, and
  every declared gallery appears in at least one slot.
- The flow gallery is the Detail, Comments, Reading and Live Text gallery. `pages` lists every
  reader page to save, in ascending order, and includes `readerPage` and `liveTextPage`.
- Download `status` is a `DownloadDisplayStatus` case. `completed` and `updateAvailable` carry no
  `completedPages`; the other statuses require it.
- A screen never repeats a gallery, including across Home's hero, frontpage and Toplists sections.
  The same gallery may appear on different screens.

Validation here covers the schema, references and repetition. The marketing composition (slot
counts per section and display order) is checked by `selection-review.py`.

## Acquire

```sh
python3 -B Scripts/visual/acquire-fixtures.py --selection PATH --output .capture/marketing
```

For every gallery, in declaration order, acquisition saves the detail page the app requests
(`<gallery URL>?hc=1`) and its cover. For each flow gallery it also saves the detail page's
preview images, the preview page `?p=<n>` that holds each declared reader page (the app's
`PreviewConfig` page number), each reader page and its image. Pages come only from
`e-hentai.org`; images only from `ehgt.org` hosts or `*.hath.network`, over HTTPS, without
redirects. Requests are at least one second apart.

Acquisition is anonymous. It reads no credentials and sends only the app's `nw=1` content
preference cookie, and only to `e-hentai.org`. A response that shows an account session fails
acquisition. Galleries that need an account, and the multi-page viewer, are rejected
explicitly. Before a page is stored, the values that grant access are zeroed in place: the API
key, the reader's show key, the image server's `keystamp`, preview path keys, original-image keys
and static-link tokens. The manifest records the same scrubbed URLs, so replay still matches.

## Output and versions

```text
.capture/marketing/
  current -> versions/marketing-<16 hex>
  versions/marketing-<16 hex>/
    selection.json  manifest.json
    responses/<gid>/detail.html  thumbnails-<n>.html  pages/<page>.html
    assets/<gid>/cover.<ext>  previews/<i>.<ext>  pages/<page>.<ext>
```

`manifest.json` has `purpose: marketingReal`, the selection identity and digest, generator
source digests and an `assets` list in path order. Each entry records `kind`, `gid`, `index` (the
preview page number, preview ordinal or reader page, otherwise null), the scrubbed source `url`,
relative `path`, `mime`, `bytes`, `sha256` and `retrievedAt`. The version is content-addressed:
the aggregate digest covers the selection bytes and every entry except its timestamp. Acquiring
unchanged content again therefore keeps the same version, while any change to content or
configured order produces a new one. Earlier versions are kept.

An output that already has `current` is not acquired again unless `--refresh` is given.

## Integrity

`fixtures.validate_fixtures(PATH)` accepts a version directory or the `current` link. It repeats
the resource derivation over the stored files and rejects:

- missing, extra or relocated files, and checksum or length mismatches;
- malformed manifest entries, such as an unsupported media type;
- symbolic links, links that leave `versions/`, and path traversal;
- disallowed hosts and replay URLs that differ from the stored pages;
- unscrubbed values and account sessions;
- a selection that changed after acquisition;
- an aggregate digest or directory name that does not match the version.

Acquisition writes into a fresh `.staging-*` directory and holds an exclusive lock on the output,
so a second writer fails at once. It verifies the staged files completely, then renames them
into `versions/` and replaces `current` atomically. An interrupted or failed run publishes
nothing, and a staging directory left by a killed run is removed by the next writer. Inside the
repository, the output must be git-ignored.

A published version directory never changes, but a later acquisition can repoint `current` at
any moment. A reader therefore resolves the path once with `fixtures.resolve_fixtures(PATH)` and
reads only the returned version directory, as `selection-review.py` does.

Tests use synthetic responses and the repository's saved parser responses, and never touch the
network:

```sh
python3 -B -m unittest discover -s Scripts/visual -p test_fixtures.py
```

## Review a selection

```sh
python3 -B Scripts/visual/selection-review.py --fixtures .capture/marketing/current --output DIR
```

The review validates the fixture's integrity first, then writes `review.json`, `review.html` and a
`.gitignore` that ignores the directory itself, because the ledger quotes real titles and
comments. `DIR` must not exist yet. Images are referenced in place, never copied. The same
fixture always produces byte-identical output.

`review.json` records:

- the fixture version and the selection's identity, status and authority;
- every gallery occurrence by content set and screen, each with its source URL, title and cover;
- Home's hero, frontpage pairs and Toplists rankings in configured order;
- the flow gallery's reader and Live Text pages and its saved comments;
- downloads with status, progress, page count and display priority;
- the unresolved final inputs and the Phase 17 closure checkpoint.

`review.html` lays out the same content as a contact sheet for visual review.

Composition checks apply to the proposed populated marketing scenes, not to the app in general.
Each content set needs:

- at least three hero galleries, with a neighbor on each side of `selectedIndex`;
- an even frontpage count of at least two;
- at least three galleries in each Toplists period;
- a readable saved comment on the flow gallery;
- at least two downloads, in an order the app would display unchanged.

The app lists downloads by status priority (active, queued, update available, error, inactive,
completed), so equal statuses keep their configured order and capture must give them descending
download dates in that order. An incomplete download needs fewer completed pages than the
gallery has. Any problem is listed in the ledger and on standard error, and the command then
exits with status 1. Integrity failures write nothing.

The review approves nothing. A provisional selection, or a content set without a scene, stays
listed as unresolved until the owner supplies the final selection before Phase 17 closes.

```sh
python3 -B -m unittest discover -s Scripts/visual -p test_selection_review.py
```

# Capture launches

A capture launch runs the actual app on one validated fixture version, offline and isolated from
the device's own account, settings, caches and downloads. Only Debug builds have it; Release
builds cannot start one.

## Launch keys

The app reads exactly two environment keys:

- `EHPANDA_CAPTURE_CONFIGURATION`: one JSON object with exactly the keys `purpose`
  (`marketingReal` or `regressionPublic`), `scenarioID` and `fixtureID`. Both identifiers match
  `[a-z][a-z0-9-]*`, for example
  `{"purpose":"marketingReal","scenarioID":"home","fixtureID":"nonexplicit"}`.
- `EHPANDA_CAPTURE_FIXTURES`: the absolute path of one fixture version directory, never a link to
  one. Resolve `current` once and pass the version it names.

A capture takes no other `EHPANDA_` key: setting one beside these two, or setting only one of
them, refuses the launch. `purpose` decides which fixture schema is accepted, so a marketing
configuration cannot read a public fixture or the reverse. For marketing, `fixtureID` names a
selection set and `scenarioID` names the screen; `home` is the only marketing scene so far. A
public configuration validates its fixture and is then refused until 17-11 adds public scenes.

Before the app builds any state, the launch verifies the whole fixture as
`fixtures.validate_fixtures` does: exact file set, lengths, SHA-256 digests, canonical paths, no
links, media types, the selection digest and identity, and the aggregate digest and version.
It also checks that Home can show the selection as configured, for example that the hero's
`selectedIndex` is Home's starting card, 1. Any failure ends the launch with a message that names
the check and the fixture-relative path or identifier involved, never file contents.

## Isolation

A capture launch replaces, before the first store exists:

- settings and other app storage with fresh in-memory stores, so nothing reads or writes the
  device's own values;
- cookies, analytics, clipboard, logs and downloads with inert clients;
- the clock with 2025-01-01T00:00:00Z and identifiers with an incrementing sequence;
- Home's gallery client with the selection's galleries in configured order, parsed by the app's
  own parser from the saved detail pages;
- every HTTP(S) request with an exact replay of the fixture: a `GET` of a listed URL gets that
  file's verified bytes and recorded media type, and anything else fails and is recorded.

Image caches live in `EhPandaCapture` under the app's temporary directory. Every capture launch
empties that directory first and touches nothing else, so each launch starts cold and a capture
never removes a user's files.

## Diagnostics

UI tests read the capture's state from one invisible accessibility element, identified
`capture_diagnostics`, present only in capture launches. Its value is JSON, computed when read:

| Field | Meaning |
|---|---|
| `screenID` | The screen shown, `home`, or absent for a screen no capture identifies yet |
| `selectionID` | The selection the fixture was acquired from |
| `fixtureVersion` | The fixture version directory name |
| `galleryIDs` | The galleries the screen shows, in display order |
| `page` | The reader page shown; absent until reader scenes exist |
| `readiness` | `loading`, `ready` or `failed` |
| `pendingImages` | Images the replay delivered that the image cache does not hold yet |
| `unknownRequests` | Requests the replay refused, as `METHOD URL` |

Home is `ready` once all of its lists hold galleries, nothing is loading, the current card's cover
is cached and no delivered image waits for the cache. It is `failed` as soon as a list fails to
load or the replay refuses a request, because the screen can then never be complete.

## Isolation test

`CaptureIsolationUITests` launches the app on a real fixture, waits for Home, compares the
diagnostics with the selection (screen, selection, version, gallery order, no pending image, no
refused request), and repeats this after a relaunch, which resets the capture's storage. Each
launch attaches its diagnostics and a screenshot to the result bundle. The test copies the fixture
into its own temporary directory and removes the copy when it ends.

The fixture holds real content, so the runner names it through an environment variable instead of
the repository. Without it the test fails rather than skip. Resolve the simulator from its model
and runtime, run one destination at a time, and return each simulator to the power state you
found:

```sh
TEST_RUNNER_EHPANDA_CAPTURE_SOURCE="$PWD/.capture/marketing/current" \
  xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:EhPandaUITests/CaptureIsolationUITests \
  -resultBundlePath .capture/<new run directory>/result.xcresult
```

The result bundle quotes real content and belongs under the git-ignored `.capture/`.
