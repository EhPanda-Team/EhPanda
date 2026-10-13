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
The command resolves current simulator IDs from the model and runtime metadata and the
visual simulators' names: exactly one available simulator named `EhPanda Visual iPhone Air`
and one named `EhPanda Visual iPad Pro 11-inch (M5)`, each of its model on that runtime.
Simulators of the same model under other names are ignored. It never uses a historical UDID
or a previous `.capture/` directory to select a destination.

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

Validation reads the explicitly supplied pin, resolves fresh IDs by its model and runtime and
the visual simulators' names, measures both families and orientations again, and compares
every pinned characteristic.
The output records the original pin bytes' SHA-256 as `pinSHA256`. Success requires the
input bytes to remain unchanged. A mismatch produces a separate failed observation with
an actionable field path; it never repairs or updates the pin. A run-local observations
file is rejected when supplied as `--environment`.

If validation fails, inspect its error and retained results. Select the pinned Xcode,
install the matching runtime, and ensure each visual simulator exists exactly once (see
below). Correct configuration drift before retrying into a new output directory.
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

Visual runs use two simulators of their own on the pinned runtime, named so that no other work
on this host shares their settings or adds an ambiguous match (owner decision, 2026-10-08).
Create them once:

```sh
xcrun simctl create "EhPanda Visual iPhone Air" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-Air com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl create "EhPanda Visual iPad Pro 11-inch (M5)" \
  com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB com.apple.CoreSimulator.SimRuntime.iOS-27-0
```

The pin also depends on device settings that a new or erased simulator does not have.
Validation detects each one; set them on the visual simulators instead of editing the pin:

| Setting | Pinned value | Set on a booted simulator |
|---|---|---|
| Reduce Motion (both) | on | `xcrun simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` |
| iPhone system appearance | dark | `xcrun simctl ui <udid> appearance dark` |
| iPad multitasking (bottom safe area 25 pt) | Full Screen Apps | `xcrun simctl spawn <udid> defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO`, then reboot |
| Text size of marketing captures (both) | Large | `xcrun simctl ui <udid> content_size large` |

Read each setting back after a reboot: a simulator's first boot can reset Reduce Motion, so set
it again if it reads 0. Return each simulator to its original power state afterwards; the
runner and gate restore only the state they found.

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
      "downloads": [{"gallery": "<gid>", "status": "active", "completedPages": 12},
                    {"gallery": "<gid>", "status": "completed"}]
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
  reader page the reader builds in a scene (the page it shows and the pages it lays out beside
  it), in ascending order, and includes `readerPage` and `liveTextPage`.
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
preview images and what the app's reader requests for the declared pages. Each page the reader
builds loads its image and prefetches a window around it: with the default preload limit of 10,
pages `p-7` to `p-2` and `p+2` to `p+7`, clipped to the gallery, with a side that clips to a
single page skipped, the way `ReadingReducer` computes it. The reader resolves image URLs a
batch at a time, so acquisition saves the preview page `?p=<n>` of every batch that holds a
loaded page (the app's `PreviewConfig` page number), every reader page that preview page lists,
and the image of each loaded page. For each download entry it saves the image of every page the
entry's folder holds: all pages of a `completed` or `updateAvailable` entry, and the first
`completedPages` pages of any other. A download resolves each page on its own, so acquisition
saves the preview page of every batch that holds one of those pages and those pages' reader
pages. An incomplete entry must hold fewer pages than its gallery has, or acquisition fails.
Pages come only from `e-hentai.org`; images only from `ehgt.org` hosts or `*.hath.network`, over
HTTPS, without redirects. Requests are at least one second apart.

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
    records/<gid>/liveText/<page>.json
```

`manifest.json` has `purpose: marketingReal`, the selection identity and digest, generator
source digests and an `assets` list in path order. Each entry records `kind`, `gid`, `index` (the
preview page number, preview ordinal or reader page, otherwise null), the scrubbed source `url`,
relative `path`, `mime`, `bytes`, `sha256` and `retrievedAt`. The version is content-addressed:
the aggregate digest covers the selection bytes and every entry except its timestamp. Acquiring
unchanged content again therefore keeps the same version, while any change to content or
configured order produces a new one. Earlier versions are kept.

A record is made rather than fetched, so its entry has a null `url`. A Live Text record holds what
the app's own Live Text found on a flow's Live Text page: every group and line with its ID, text
and four normalized corners, the page image's SHA-256, the recognition languages and the
recording simulator's model and runtime build. `record-live-text.py` makes it (see Record Live Text)
and `fixtures.publish_records` publishes a new version with the record added, keeping every other
file and the acquisition time; its entry's `retrievedAt` is when it was recorded. A fixture holds
each flow's record or none, so a version acquired again holds no record until the page is recorded
again.

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
- an aggregate digest or directory name that does not match the version;
- a record of a page that no flow shows Live Text on, recognized on other bytes than that page's
  image, or holding no groups, a line without text, a missing, malformed or repeated ID, or a
  line whose corners have no extent or lie outside the page (a corner slightly past the edge,
  as Vision can place one, is kept).

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
download dates in that order. Any problem is listed in the ledger and on standard error, and the
command then exits with status 1. Integrity failures write nothing.

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
configuration cannot read a public fixture or the reverse. A public configuration validates its
fixture and is then refused until 17-11 adds public scenes.

For marketing, `fixtureID` names a selection set and `scenarioID` names one of eight screens,
which the launch opens through the app's own navigation:

| `scenarioID` | Route |
|---|---|
| `home` | Home, the first tab |
| `detail` | The selection's flow gallery, opened from Home |
| `comments` | The flow gallery's comments, from its detail once it loads, as Show All opens them |
| `filters` | Filters, from the Search tab, at the app's defaults |
| `reading` | The reader on the flow's `readerPage`, from the detail, as a preview tap opens it, with its control panel shown, as a tap on the page shows it |
| `reading-live-text` | The reader on the flow's `liveTextPage` with Live Text on, as the reader's Live Text button leaves it, showing the fixture's Live Text record of that page with the control panel hidden |
| `downloads` | The Downloads tab, listing the selection's downloads from capture-owned folders |
| `laboratory` | Laboratory, from the Setting tab |

One more `scenarioID`, `live-text-recording`, exports no screen: it opens the reader as
`reading-live-text` does but lets the reader's own Live Text recognize the page, so
`record-live-text.py` can save what it found (see Record Live Text below).

Before the app builds any state, the launch verifies the whole fixture as
`fixtures.validate_fixtures` does: exact file set, lengths, SHA-256 digests, canonical paths, no
links, media types, the selection digest and identity, and the aggregate digest and version.
It also checks that the scene can be shown as configured, for example that the hero's
`selectedIndex` is Home's starting card, 1, that the Live Text record belongs to the flow's Live
Text page, its image and the languages the reader asks for, and that every download can be shown as
its entry says. Any failure ends the launch with a message that names the check and the
fixture-relative path or identifier involved, never file contents.

## Isolation

A capture launch replaces, before the first store exists:

- settings and other app storage with fresh in-memory stores, so nothing reads or writes the
  device's own values;
- cookies, analytics, clipboard and logs with inert clients, and downloads with a client that only
  lists the scene's seeded download folders and changes nothing;
- the clock with 2025-01-01T00:00:00Z and identifiers with an incrementing sequence;
- the settings with the app's defaults, except that the network bypass is on; the reader is the
  default vertical one (owner decision, 2026-10-13);
- Home's gallery client with the selection's galleries in configured order, parsed by the app's
  own parser from the saved detail pages;
- every HTTP(S) request with an exact replay of the fixture: a `GET` of a listed URL gets that
  file's verified bytes and recorded media type, and anything else fails and is recorded;
- on `reading-live-text`, the reader's Live Text with the fixture's record of the page: the reader
  starts with Live Text on, shows the record's groups on that page through its own overlay, and
  runs no recognition, so Vision never replaces or competes with what the capture shows.

The reader cache, both image libraries' caches and the scene's download folders live in
`EhPandaCapture` under the app's temporary directory, and the caches' memory and background purges
act on those copies. Every capture launch empties that directory first and touches nothing else, so
each launch starts cold and a capture never reads or removes a user's cached files.

A `downloads` scene seeds `EhPandaCapture/Downloads/Default/` with one folder per download entry,
as a download leaves it: the cover, the page files the entry holds (every page of a complete
entry, the first `completedPages` of another) and a manifest that records each held page's
SHA-256 as the app computes it from the written file, with every other page blank. The app's own
scan then reads the folders back. Completeness comes from the manifest alone, as in the app; only
being downloaded (`active`) or waiting (`queued`) comes from the simulated queue, and the active
row shows its run's progress. Entries must come in the order the screen lists them, by status,
and each folder is dated an hour before the one above it, so the app's newest-first order keeps
theirs. An `error` entry cannot be captured, because a capture has no failure to show.

## Diagnostics

UI tests read the capture's state from one invisible accessibility element, identified
`capture_diagnostics`, present only in capture launches. Its value is JSON, computed when read:

| Field | Meaning |
|---|---|
| `screenID` | The screen shown, one of the eight `scenarioID` values, or absent for any other screen |
| `selectionID` | The selection the fixture was acquired from |
| `setID` | The selection set the scene shows |
| `fixtureVersion` | The fixture version directory name |
| `galleryIDs` | The galleries the screen shows, in display order |
| `page` | The reader page shown; absent outside the reader |
| `showsPanel` | Whether the reader shows its control panel; absent outside the reader |
| `readiness` | `loading`, `ready` or `failed` |
| `pendingImages` | Images the replay delivered that no image cache holds yet |
| `unknownRequests` | Requests the replay refused, as `METHOD URL` |
| `blockers` | What the screen still waits for, and what makes it fail; empty once it is ready |
| `rendering` | The app's own `language`, `locale`, `appearance`, `textSize` and device `family` |
| `liveText` | The Live Text the reader shows on the Live Text page: `gid`, `page`, `source` (`fixture` or `recognition`), `recognitionLanguages` and every group and line; absent until it shows any |
| `downloads` | Each Downloads row: `gid`, `status`, the `completedPages` its badge counts, `pageCount` and the `pageFiles` its folder holds; absent on other screens |

The screen comes from the app's navigation state, never from the configuration, so a route that
lands elsewhere reads as that other screen. A screen is `ready` once its content has arrived,
every image it must show is in an image cache (the reader's own cache included), no delivered
image waits for a cache and nothing failed:

- Home waits for all of its lists and the current card's cover, and in dark appearance for that
  cover's color analysis, which the card's gradient shows.
- Detail waits for its detail, its cover and every preview the fixture holds.
- Comments are readable at once, from the top, with no comment highlighted.
- The reader waits until it shows its current page's image. In a launch with Live Text it reads
  as `reading-live-text` once it shows the page's Live Text, and fails on Live Text of another
  gallery or page, or a recognition that found no text.
- Downloads waits for its rows and every row's cover.
- Filters must show the app's defaults, and Laboratory the network bypass on.
- A sheet that leaves its tab visible around it also waits for that tab.

A screen is `failed` as soon as a load fails, the replay refuses a request or the screen shows
something other than its configured state, because it can then never be complete.

## Isolation test

`CaptureIsolationUITests` launches the app on a real fixture, waits for Home, compares the
diagnostics with the selection (screen, selection, version, gallery order, no pending image, no
refused request), and repeats this after a relaunch, which resets the capture's storage. Each
launch attaches its diagnostics and a screenshot to the result bundle. The test copies the fixture
into its own temporary directory and removes the copy when it ends.

The fixture holds real content, so the runner names it through an environment variable instead of
the repository. Without it the test fails rather than skip. Run on a visual simulator, one
destination at a time, and return each simulator to the power state you found:

```sh
TEST_RUNNER_EHPANDA_CAPTURE_SOURCE="$PWD/.capture/marketing/current" \
  xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:EhPandaUITests/CaptureIsolationUITests \
  -resultBundlePath .capture/<new run directory>/result.xcresult
```

The result bundle quotes real content: keep it under `.capture/` and never commit it.

# Marketing captures

## Capture one coordinate in a UI test

`MarketingCaptureUITests/testCaptureCoordinate` captures one coordinate on the actual app. A
coordinate is one JSON object with exactly five keys:

```json
{"screen":"home","set":"nonexplicit","locale":"en","theme":"dark","family":"iphone"}
```

`screen` is a marketing `scenarioID`, `set` a selection set, `locale` one of `en`, `de`, `ja`,
`ko`, `zh-Hans` and `zh-Hant`, `theme` `light` or `dark`, and `family` `iphone` or `ipad`, which
must match the destination. Every marketing capture is portrait at the Large text size. The
launcher sets the coordinate's appearance and portrait orientation on the simulator, launches the
app in the coordinate's language and formatting locale with dates in UTC, and verifies the text
size instead of setting it: a text size the app overrides for its window, while the system setting
differs, renders some toolbar glyphs at the system's size. Set the simulator to Large first with
`xcrun simctl ui "$UDID" content_size large`.

The test passes only when the diagnostics are exactly what the selection expects for the coordinate:
its screen, selection, set, fixture version, galleries and page, ready with no pending image,
refused request or blocker, in the coordinate's rendering, with each gallery shown once. On
`reading-live-text` the Live Text must be exactly the fixture's record, each ID once. On `downloads`
each row must have its entry's status, count its entry's pages as downloaded (every page for a
complete entry) and hold that many page files. It then takes the system's screenshot of the screen,
`XCUIScreen.main.screenshot()`, a second apart until two in a row are byte-identical, and fails if
they never are. Either way it attaches the diagnostics and that screenshot's PNG. The runner names
the coordinate and the fixture version through environment variables:

```sh
TEST_RUNNER_EHPANDA_CAPTURE_SOURCE="$PWD/.capture/marketing/current" \
TEST_RUNNER_EHPANDA_CAPTURE_COORDINATE='{"screen":"home","set":"nonexplicit","locale":"en","theme":"dark","family":"iphone"}' \
  xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:EhPandaUITests/MarketingCaptureUITests/testCaptureCoordinate \
  -resultBundlePath .capture/<new run directory>/result.xcresult
```

The UITests plan retries a failed test, so a result with repetitions counts as failed. The native
runner below runs each launch once.

## Capture natively

`capture-native.py` records the frame a marketing image is made from: the actual app's screen with
the system's own status bar, at the device's native size, identical across independent cold
launches. It takes the tracked rendering pin, the same file the regression runner takes:

```sh
python3 Scripts/visual/capture-native.py \
  --coordinate .capture/<run inputs>/coordinate.json \
  --fixtures .capture/marketing/current \
  --environment Scripts/visual/regression-environment.json \
  --output .capture/<new run directory>
```

The output must be a new directory, separate from the coordinate, the pin and the fixture
version. The runner then:

1. reads the coordinate, which has exactly its five keys with known values, and validates the
   fixture version, whose selection must hold the coordinate's set;
2. validates the pin against fresh measurements on both visual simulators, as
   `environment.py validate` does, into `environment-check/`, whose `environment.json` records
   the pin's SHA-256. A measurement report is not a pin and is refused, and any difference in
   toolchain, runtime, model, geometry or scale stops the run before the app launches. The pin is
   only read;
3. on the coordinate's device, as that validation resolved it, overrides the status bar: 9:41,
   Wi-Fi with 3 bars, cellular with 4 bars, and the battery at 100% and not charging (simctl's
   `discharging`; its `charged` draws the charging bolt). It then opens Settings, waits until
   two screenshots a second apart are identical and quits it: the first app the system shows
   after a boot draws iPad's Wi-Fi glyph half a point left of where every later app draws it, so
   no capture launch may be that first app;
4. launches the test cold twice, each launch once without retries. Each launch must pass exactly
   one test, with no repetition, skip, warning or diagnostic, on the pinned model and runtime. The
   runner then takes the test's two attachments from the result bundle: the diagnostics must name
   the coordinate, and the screenshot, the launch's frame, must be a complete 8-bit RGB PNG at the
   pin's portrait pixel size;
5. clears the status bar, puts back the appearance, portrait orientation, text size and power
   state it found, and checks that the sources, the pin and the fixture version did not change.

The coordinate is captured only when both launches recorded the same bytes, and `outcomes.json`
then names that frame as `capture`. A failed run still writes `outcomes.json`, with its error and
each launch's result bundle, attachments and, once checked, diagnostics and frame.

A frame is the screenshot the system renders, not the display's framebuffer that
`simctl io screenshot` reads. The framebuffer keeps Liquid Glass as the display last composed it,
so one screen's glass could differ by a level between cold launches; the system renders a
screenshot whole, so one screen gives the same bytes every time. The screenshot carries the
overridden status bar and no Dynamic Island capsule, and differs from the framebuffer only by a
level on some glass pixels (owner decision, 2026-10-09). The runner still uses simctl for the
Settings launch, which only has to be shown.

simctl freezes the status bar's date only for a full ISO time, `2026-01-01T09:41:00.000` with the
host's offset, which it reads in the host's time zone like the bar itself, so the bar shows 9:41
on any host. It derives the weekday as if the year were 2000, so iPad's bar reads "9:41 Sat Jan 1"
(the owner's choice of date). The marketing chrome stays in this runner and its outcomes, outside
the shared pin. A simulator whose status bar already carries overrides is refused, since clearing
the runner's own would remove them.

| Output | Contents |
|---|---|
| `outcomes.json` | Status, coordinate, pin SHA-256, fixture version, device, chrome, launches and `capture` |
| `environment-check/` | The pin validation's measurements and attachments |
| `settle/` | The screenshots of the Settings launch before the captures |
| `native/` | Each invocation's command, log, result bundle, attachments and the simulator's lifecycle |
| `launches/<n>/` | Launch n's frame, `frame.png`, the screenshot the test attached |

Every frame and result bundle shows real content: keep the output under `.capture/` and never
commit it.

## Record Live Text

`record-live-text.py` saves the Live Text the `reading-live-text` screen shows. It runs
`MarketingCaptureUITests/testRecordLiveText` once on the pinned iPhone, in English and light
appearance, with the `live-text-recording` scenario: the app opens the fixture's saved page in the
reader and runs Live Text through its own recognizer, request settings and grouping. The test
passes once the reader shows its recognition of the flow's Live Text page, with text, and attaches
the diagnostics, whose `liveText` carries every group and line:

```sh
python3 Scripts/visual/record-live-text.py \
  --fixtures .capture/marketing \
  --set nonexplicit \
  --environment Scripts/visual/regression-environment.json \
  --output .capture/<new run directory>
```

`--fixtures` is the fixture output, not a version: the runner records the version `current` names
and publishes the record into the same output. As `capture-native.py` does, it validates the pin
against fresh measurements first, runs the test once without retries on the pinned model and
runtime, checks the attached diagnostics name the coordinate, and puts back the appearance and
portrait orientation it found. It then builds the record with the page image's SHA-256 and the
pinned model and runtime build, validates it as the fixture tools do, and publishes it with
`fixtures.publish_records`, unless the sources, the pin or the current version changed meanwhile.
`outcomes.json` names the published version. Record again after every acquisition, which starts a
version without a record.
