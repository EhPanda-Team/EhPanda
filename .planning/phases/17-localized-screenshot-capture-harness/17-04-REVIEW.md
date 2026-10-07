# Phase 17 Plan 04: Inline review

Scope: every source and test change of 17-04, from `72f29f5f88` to the cache-isolation fix
(`2ea65ac65f`), reread after T2 was committed, against the plan's truths (only the selected
offline fixture is consumed, capture state cannot reach personal settings or downloads, unknown
routes and missing assets fail), AGENTS.md and the root SwiftLint rules.

## Findings

All findings are fixed: R-1 to R-3 in `2ea65ac65f`, R-4 in `74159f1861`, R-5 in `fbd71f24bc`.
Nothing is open.

### R-1: SDWebImage's shared cache was the user's

`CaptureScenePreparation.install` (`2c63c45c27`) moved Kingfisher's cache into capture storage
but left SDWebImage's shared cache at its default, the app's own `Library/Caches`. The capture
diagnostics read image readiness through `LibraryClient.isCached`, which also asks SDWebImage's
memory and disk cache, so an image the user's cache happened to hold could read as delivered.
Later capture scenes that show the cache size (Setting) would also have shown the user's.
Fix: before anything creates the shared cache, `SDImageCache.defaultDiskCacheDirectory` points
into the capture's `SDWebImageCache` directory, which every launch empties.

### R-2: The reader cache's purge observers guarded the user's cache

`LibraryClient.initializeWebImage` called `DataCache.installSystemPurgeObservers()`, a static
that always observed the app's canonical `DataCache`. A capture launch therefore swept the
user's reader cache when it entered the background, although its own reader cache is the
capture's. Fix: the observers are installed per cache instance, and `initializeWebImage` installs
them for the injected `dataCache`. Production resolves the same canonical cache at the same moment,
so its behavior is unchanged; capture preparation now calls `initializeWebImage` after isolating
the dependencies, so the observed cache is the capture's.

### R-3: Kingfisher's default cache kept its housekeeping

Reaching `KingfisherManager.shared` creates `ImageCache.default`, the user's cache, which Kingfisher
keeps for the process and which registers memory, background and termination cleanup. Replacing
the manager's cache does not unregister it, so a capture launch could prune the user's expired
entries. Fix: capture preparation removes that cache's notification observers, as Kingfisher's own
`deinit` does for a released cache.

### R-4: An unused replay accessor was committed

`UITestStubURLProtocol.installedReplay` (`2c63c45c27`) had no caller. T2 (`74159f1861`) replaces it
with `CaptureScenePreparation.installed`, one record of the installed scene and its replay.

### R-5: A production request outside every fixture (owner decision)

The first actual-app capture failed closed on `GET` of a GitHub image: Home's Toplists skeleton
used `Gallery.preview`, whose cover is that image, so every Home load requested it. The owner
chose blank skeleton galleries without a cover, like Frontpage's (`c961dacdf4`, `fbd71f24bc`).

## Checked without findings

- Validation runs completely before installation, and installation before the first store or
  shared key; refusal ends the launch with a nonsecret message and no fallback.
- The replay answers only a `GET` of an exact listed URL, with the verified bytes and recorded
  media type; every other request fails and is recorded. Kingfisher's session and the shared
  loading system both pass through it; downloads, DF and cookies are inert.
- Shared settings are bound to fresh in-memory stores before any state exists; the unit test
  proves personal values are neither read nor written.
- Storage reset removes only the capture's own directory under the app's temporary directory,
  never a download folder (AGENTS.md deletion invariant).
- The diagnostics element exists only in capture launches, renders nothing and computes its value
  on read; Release builds compile none of it.
- Lint: strict SwiftLint passes on every touched path with no suppression.

## Carried to 17-05 (not 17-04 defects)

- **Dark Home card colors vary between launches.** On iPhone (dark appearance) the first launch
  and the relaunch settle the focused card's gradient on different colors from the same cover,
  while both iPad (light) screenshots are byte-identical. A likely cause: `ImageColors` counts
  colors in a `[Double: Int]` dictionary and orders them by count alone, so equal counts follow
  the per-process hash order. Making it deterministic changes production output and needs an
  owner decision; 17-05's byte-identical cold-rerun gate depends on it.
- **Readiness does not cover the dark card's color analysis and cross-fade.** Home readiness waits
  for lists and images. 17-05 owns the per-frame settle rule and should extend readiness there.
