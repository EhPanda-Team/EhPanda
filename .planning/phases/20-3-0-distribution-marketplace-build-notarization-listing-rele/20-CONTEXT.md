# Phase 20: 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks - Context

**Gathered:** 2026-11-09 (discussion refresh; owner decisions first recorded 2026-11-05 during the Phase 18 discussion)
**Status:** Discussion done, with one owner question open (OQ-1, the marketplace build's primary icon). Planning can
start: OQ-1 changes one asset at most, and its recommended answer needs no work. The planner makes OQ-1 a checkpoint
before the first marketplace build goes to Apple.
**Branch:** `feature/gsd-phase-20`, from `e2c6acb5b` (the `feature/gsd-phase-19` tip), in parallel with Phase 19
(D-13).

<domain>
## Phase Boundary

This phase makes 3.0 distributable on the GitHub, AltStore Classic and SideStore channels and on AltStore PAL. It
covers:

- the marketplace build flavor (DIST-18-01, flavor part) and the remaining release mechanics fixes (REL-18-01);
- the PAL source JSON (DIST-18-02);
- the notarization pipeline through the collaborator's App Store Connect account (DIST-18-03);
- the website dependencies: privacy policy, support page, the published contact link (UGC-18-01, contact part) and
  the PAL source's public URL;
- the real-device checks (DEV-18-01);
- the PAL listing assets and store screenshots built from Phase 19's approved reference set (MKT-18-01 remaining
  part, CAP-17-05, from 17-22), and the release's reliance on Phase 19's screenshot check;
- the analytics revision (ANALYTICS-02);
- last, the Release isolation scan on the final build.

**Not here:** in-app features (Phases 18 and 18.1) and the screenshot check itself (Phase 19). Tag creation and
release order are in no phase (D-03).

**Already landed before this discussion** (on `feature/gsd-phase-18`, merged in `fc8a075f7` and `ed9ba9a7d`, so on
this branch): one IPA per channel with the `EhPandaDistributionChannel` stamp, the distribution channel in the install
signal, the beta flavor and its source, `SideStore.json`'s template, per-language release notes files, the website
copy in the sources and the seven decorated iPhone screenshots (D-11, D-12, D-15 to D-17). Phase 20 builds on them and
does not redo them.

</domain>

<decisions>
## Implementation Decisions

### Owner decisions recorded 2026-11-05 (kept; amendments marked)

- **D-01:** Three phases, with all waiting on outside parties in this one: the App Store Connect collaborator, the
  website and Apple (owner msg 1753).
- **D-02:** **The marketplace build has the same features as the GitHub IPA and is listed on AltStore PAL only**
  (owner msg 1753). Something is hidden only if Apple objects. The ADP pipeline stays generic, so other marketplaces
  can be added later (prep L2; owner msg 1287).
- **D-03:** **"Tagging is not your business"** (owner msg 1753). No tag-style decision, no plan to remove or rename
  the existing `3.0.0` tag, no tag creation and no release-order planning. Prep L22 and L23 and GA-7 are dropped. The
  AltStore download URL must still resolve to the release's actual asset.
  *Amended 2026-11-09:* answered by D-19; for Classic, SideStore and the beta it is already true in the workflows.
- **D-04:** **Store screenshots** are the website screenshots plus extra decorations (owner msg 1753). An AltStore
  listing can use only non-adult pictures (Ampo msg 1751, guideline 2.3.8). These are the AltStore promotional
  images moved from Phase 17 (17-22). The listing icon is all-ages (prep L28), and no "Apple-approved" wording
  appears anywhere (prep L8).
  *Partly superseded 2026-11-09:*
  - The Classic and SideStore screenshots are done (D-17). The designer Colo (msg 1757) no longer makes them: the
    owner stopped that (owner msg 2614) and had an outside designer do the decorated set (owner msg 2618).
  - Still open for the **PAL listing**, all in step (f) and none decided here:
    - **Sizes.** App Store Connect requires at least one iPhone screenshot in the "iPhone with Dynamic Island (medium
      display)" class (1179 x 2556 or 1206 x 2622), with scaled fallbacks from the larger classes, and, because
      EhPanda runs on iPad, at least one iPad 13-inch screenshot (2064 x 2752 or 2048 x 2732). The existing
      1260 x 2736 set is an accepted "Dynamic Island (large display)" size. Whether it alone satisfies the iPhone
      requirement through scaling is confirmed at the first upload. No iPad set exists. The PAL source itself can
      list iPhone screenshots only; any iPad screenshot there needs an explicit width and height.
    - **The all-ages icon:** OQ-1.
    - **The PAL listing screenshot set:** built from Phase 19's approved reference set (D-14). Who decorates it and
      which screens it shows are decided at step (f)'s owner checkpoint. Notarization data, screenshots included,
      feeds iOS's install sheet, so App Store Connect's screenshots must also be all-ages. The current Classic
      set's first picture is headed "Over a million adult comics and doujinshi"; whether that wording suits an
      all-ages listing is for the same checkpoint.
- **D-05:** **Published contact link:** there is no in-app contact option for now (Ampo msg 1774, after the owner's
  question in msg 1760). A published contact link, GitHub Issues on the website, is needed before the AltStore build
  goes to Apple. The website owner is Leto. The privacy policy and support URLs are website work too (prep L7).
- **D-06:** **The analytics revision is the last plan before the closing scan** (ANALYTICS-02; owner msgs 1289,
  1753). It adds the signals for every 3.0 flow under the consent levels, within ANALYTICS-01's rules.
  *Amended 2026-11-09:* the install-source part is done. Owner msg 2552 replaced the install source with the
  distribution channel. The install signal, sent once at every level (Minimal, Basic and Full), carries
  `App.distributionChannel` (`dd20d675e`). `altstorePAL` is already on the closed list. So the revision no longer
  waits for a PAL build to exist (D-20). What remains: the signal vocabulary for the 3.0 flows (age wall,
  analytics choice, comment moderation, the native Report form, the marketplace build) and keeping the approved
  level descriptions true (`18-COPY-MINIMAL.md` Revision 7).
- **D-07:** **Apple-service actions** (App IDs, the app record, certificates, API keys, marketplace registration,
  trader status) happen in the collaborator's App Store Connect account. The collaborator does them, or the owner OKs
  them explicitly at the time. Agents never create them on their own (prep L6). Product lead msg 2771 restates this
  for Phase 20: anything that touches Apple accounts waits for the owner's OK at that time.
- **D-08:** The real-device checks on owner hardware (prep L43): the iPad Gallery Detail stall on a Release build, and
  continued background downloads on an iPhone.
- **D-09:** The closing gate repeats the Release isolation scan on the final build, which includes the analytics
  revision (prep L41). IN-02 and IN-03 were closed in Phase 18 (18-01).
- **D-10:** The website privacy page is rewritten for the three analytics levels when 3.0 ships, not before (Phase 18
  copy file, "Knock-on for the website").
- **D-11:** **The beta is a separate install** (owner msgs 2513, 2518, 2525). Pre-releases are built as a beta flavor
  with its own bundle IDs, `app.ehpanda.beta` and `app.ehpanda.beta.shareExtension` (`BUNDLE_ID_SUFFIX = .beta`), the
  Home Screen name "EhPanda Beta", the regular icon and its own URL scheme `ehpanda-beta`, all from
  `Config/Beta.xcconfig`, which only `deploy-beta.yml` passes to `xcodebuild`. The workflow publishes one file,
  `EhPanda-Beta.ipa`, stamped `beta` (D-12). The beta's AltStore Classic source is `altstore-beta.json` on `main`,
  created by that workflow from `actions-tool/altstore-beta.template.json` on its first run. It lists only betas newer
  than the latest regular release, and always at least the newest beta. Each beta needs a build number above every
  build in both sources; the workflow fails otherwise.
  *Landed:* `145cee6ac`, `224b0ca94` (rename to `deploy-beta.yml`, owner msg 2551).
- **D-12:** **One file per channel** (owner msgs 2533, 2537; the channel in each file name, website owner msg 2538).
  - **The stamp.** The app's Info.plist key `EhPandaDistributionChannel` names the channel, from a closed allow-list:
    `github`, `altstore`, `sidestore`, `altstorePAL`, `beta`, `source`. The committed `App/Info.plist` says `source`,
    so any build no release workflow made says so. The workflows build once, unsigned, and
    `actions-tool/package-channel.sh` copies the app once per channel and overwrites the value in each copy, so the
    copies differ only in the stamp and no channel needs its own build. Only the app is stamped; the share extension
    sends nothing.
  - **The files.** `deploy.yml` publishes `EhPanda-GitHub.ipa`, `EhPanda-AltStore.ipa` and `EhPanda-SideStore.ipa` on
    the GitHub release. `AltStore.json` (repo root, where ehpanda.app/AltStore.json redirects) points at
    `EhPanda-AltStore.ipa`, and the new `SideStore.json` (repo root) at `EhPanda-SideStore.ipa`, each with that
    file's own size and SHA-256. Both are updated by the same filter, `actions-tool/altstore-add-version.jq`, newest
    first with history kept. `SideStore.json` is created by the first 3.0 release from
    `actions-tool/sidestore.template.json` (the same wording, structure and `nsfw: true` as `AltStore.json`, its own
    `identifier`), so it is never written with zero versions. `deploy-beta.yml` publishes `EhPanda-Beta.ipa`
    (D-11).
  - **AltStore PAL** is not built yet. *Amended 2026-11-09:* the PAL build cannot be stamped by `package-channel.sh`.
    The script refuses a signed app, and the PAL build must be signed before it is uploaded to Apple; editing the
    Info.plist after signing would break the signature. So the marketplace flavor sets `altstorePAL` at build time
    (developer defaults below). The script and the unsigned channels stay as they are.
  - **Distribution channel** (owner msg 2552; replaces the install source). The install signal reports the stamp as
    is under the payload key `App.distributionChannel`: `github`, `altstore`, `sidestore`, `altstorePAL`, `beta` or
    `source`. A missing stamp, a value that is not a string, or a string not on the list (compared exactly) reports
    `source`. MarketplaceKit is not used, so `appStore`, `testFlight`, `marketplace:<id>`, `web`, `other` and
    `unknown` are no longer sent; the enum is `DistributionChannel` in AppModels, and the `InstallSourceClient`
    module is gone. Raw values are dashboard values: a channel may be added, never respelled.
  - **SideStore source format.** SideStore reads AltStore sources ("SideStore is fully compatible with AltStore
    Sources", docs.sidestore.io/docs/advanced/app-sources). Checked against the SideStore source at 4f3d18d (Nov 2026):
    an app with `marketplaceID` is rejected as notarized (`SourceError.marketplaceNotSupported`), so none is set;
    `identifier` is read as a group ID and the source's identity is its normalized URL; `marketingVersion` is not read;
    a source with no versions is rejected (`MergeError.noVersions`); a download is checked against the listed bundle
    ID, `size`, `sha256`, `version` and `buildVersion` (`VerifyAppOperation`), and every entitlement and usage
    description in the app must be declared in `appPermissions`; an update is offered when the listed version is
    semantically newer (`InstalledApp.hasUpdate`), where AltStore Classic only compares for equality.
  - *Landed:* `ff08ca11b` (one IPA per channel), `74ef28a5d` (stamp key name, owner msg 2549), `dd20d675e` (channel in
    the install signal), `03f2967c1` (share extension keeps its name, owner msg 2555).

### New decisions since 2026-11-05

- **D-13:** **Phase 20 runs now, without waiting for Phase 19** (owner msg 2770, 2026-11-09). It runs on its own
  branch, `feature/gsd-phase-20`, created from `e2c6acb5b`. Phase 19 work continues on `feature/gsd-phase-19` in the
  main checkout and is not touched from here.
- **D-14:** **"Depends on Phase 19" is relaxed by owner msg 2770** (product lead Ato, msg 2771). Only two parts
  truly need Phase 19 finished:
  1. the store screenshots built from Phase 19's approved reference set;
  2. a release that relies on Phase 19's screenshot check.

  Both go last in Phase 20's order, before only the analytics revision and the closing scan. The phase starts with
  the marketplace build, the release fixes, the PAL source and the notarization job. Anything that touches Apple
  accounts waits for the owner's OK at that time (D-07). The plan order is fixed below.
- **D-15:** **Release notes come from a committed file per release** (owner msgs 2561, 2564, 2567, 2569, 2579, 2582).
  The file is `ReleaseNotes/<version>.md`, with one section per language (English, Deutsch, 日本語, 한국어, 简体中文,
  繁體中文). Items are plain lines, with no numbers or bullets (owner msg 2591). The `Release Notes` PR check
  (`release-notes.yml`) and `deploy.yml` both run `actions-tool/release_notes.py check`. The PR description is no
  longer read. *Landed:* `624192ebc`, `9e5dfc9f4`, `982305386`, `df3d04feb`.
- **D-16:** **The sources' metadata matches the website** (owner msg 2591). The subtitle and description are the
  website copy from Leto's msg 2606, in six languages, with English in the plain fields (`d9ad08bd8`, `751235a23`).
  The website link is https://ehpanda.app (`269cb08e5`). The tint color is `#557F72` (designer msg 2593, owner msg
  2594; `17eb08125`, `1aef4a243`, `1d2351ada`). The PAL source reuses all of this (developer defaults).
- **D-17:** **Classic and SideStore screenshots** (owner msgs 2600, 2608, 2610, 2614, 2618, 2623, 2628).
  - **Content.** Non-explicit, English, iPhone (owner msg 2608), and decorated, not plain (owner msg 2610). An
    outside designer, dispatched by the owner, made the decorated set (owner msg 2618). The light originals came
    first (owner msg 2608); owner msg 2623 asked for the dark originals, and the delivered set is dark (owner msg
    2628).
  - **Format.** Seven 1260 x 2736 PNGs: home, detail, reading, comments, downloads, filters, more. `AltStore.json`
    and the SideStore and beta templates list them in order, as `{imageURL, width, height}`, by their raw URLs in
    `EhPanda-Team/ehpanda-assets` (`c9dec54d7`). `check_source` checks them (`9506d4d8b`). The repository name is
    the owner's choice (owner msg 2600).
  - **Where they live.** That repository exists only as a local checkout (commit `d69b30a`) and is not on GitHub. So
    the seven screenshot URLs do not resolve yet. Creating the GitHub repository and pushing to it need the owner's
    OK (step (a) checkpoint).

### Answers to the discussion's open questions (developer research, 2026-11-09; sources in canonical refs)

- **D-18:** **Privacy manifest: required. Add `PrivacyInfo.xcprivacy` to the app, in every build.**
  - **Why it is required.** Notarization runs through App Store Connect: the build is uploaded there and submitted
    with the review type "Notarization" (Apple, "Submit for Notarization"; "Changes for apps in the EU"). App Store
    Connect has not accepted apps that use required-reason APIs without declaring them since May 1, 2024 (Apple,
    "Describing use of required reason API").
  - **What the app uses.** Its own code uses `UserDefaults` (`AppTools/AppUserDefaults.swift`,
    `UserDefaultsClient`) and file timestamps (`contentModificationDateKey` in `AppComponents/PreviewImageView.swift`,
    creation and modification dates in `AppTools/DataCache.swift`).
  - **What the dependencies ship.** Kingfisher and SDWebImage are on Apple's list of SDKs that need their own
    privacy manifest. They, TelemetryDeck, Kanna, SDWebImageSwiftUI, swift-composable-architecture and
    swift-sharing ship one (checked in a local package checkout). All are source dependencies, so no SDK signature
    is needed.
  - **Every build, not only the marketplace one.** This keeps every channel's app identical apart from the stamp,
    and AltStore Classic and SideStore ignore the file.
  - **Scope.** The manifest declares the app's own required-reason uses and the data collected through
    TelemetryDeck, as the README's Analytics section describes it, with `NSPrivacyTracking` false. The share
    extension (`ShareViewController.swift`) uses no required-reason API, so it gets none unless research finds one.
  - **Phase 14.** This amends Phase 14 D-04 ("No `PrivacyInfo.xcprivacy`"), whose own revisit condition, "if
    distribution changes", is now met.
- **D-19:** **The download URL is whatever the release really has, whatever the tag (D-03).**
  - **Classic, SideStore and beta: already true.** `deploy.yml` and `deploy-beta.yml` take the named file's
    `browser_download_url` from the release's asset list (`steps.release.outputs.assets`), check that it resolves
    (`curl -sSfIL`) and only then write it into the source (`ff08ca11b`). The old `v<version>` link pattern is gone.
  - **PAL.** An ADP is a folder (`manifest.json`, `signature` and one IPA per variant) that must be served unchanged.
    AltStore's `downloadURL` for PAL is the manifest's URL, and its `assetURLs` field maps each ADP file to its own
    URL, which "allows you to host ADPs using GitHub Releases" (AltStore, "Make a Source"). So the PAL job uploads
    the ADP's files as assets of the GitHub release that `deploy.yml` already made for that version. It writes the
    URLs the upload returns into `assetURLs`, with `downloadURL` set to the manifest's asset URL.
  - **No tags.** The PAL job never creates, moves or renames a tag or a release. If no release exists for the
    version, it fails.
- **D-20:** **Order of the analytics revision and notarization: the pipeline first, the analytics revision before
  the final submission.**
  - The notarization job (step (c)) is built and proven first. Its first live submission is an owner checkpoint
    (D-07). It may use a build without the analytics revision; that gets Apple's first verdict early.
  - The analytics revision (step (g)) does not depend on PAL existing: `altstorePAL` is already a channel value
    (D-06 amended).
  - Every code change after a notarized build needs a new submission. So the build that becomes 3.0 on PAL is the
    final one: it contains (g) and passes (h).
  - When that final submission and the Classic release happen is release order, which no plan sets (D-03).
- **D-21:** **App Manager API key: yes on paper; the live test stays a step (c) checkpoint** (DIST-18-03 asks to test
  and record it).
  - **The paper case.** Apple lists "Account Holder, Admin, or App Manager" as the roles that can submit for
    notarization, and Account Holder, Admin, App Manager or Marketing for reading the ADP ID. A team API key carries
    one of the same roles as a user. The App Store Connect API (OpenAPI spec 4.6) lets a client create or update an
    App Store version with `reviewType: NOTARIZATION`, create review submissions and their items, and read
    `/v1/appStoreVersions/{id}/alternativeDistributionPackage`.
  - **What a key cannot do.** Adding AltStore PAL as a marketplace (Users and Access → Integrations → Marketplace)
    needs the Account Holder or an Admin, in the web UI. Agreeing to the Developer Program License Agreement needs
    the Account Holder. Individual keys cannot call the provisioning endpoints. These stay with the collaborator
    (D-07).
  - **Recorded at the test.** The test records which key type and role made each call, and whether creating the
    version, attaching the build and submitting worked with an App Manager key alone.

### Remaining owner question (product lead relays it to the owner)

- **OQ-1 (GA-6 Q3):** Must the marketplace build's own primary icon be all-ages, or only the listing icon?
  - **What the research found.** Guideline 2.3.8 is in the notarization subset: "make sure your app and in-app
    purchase icons, screenshots, and previews adhere to a 4+ age rating even if your app is rated higher". Apple
    takes the app's store icon from the build's asset catalog, and notarization data feeds the install sheet. So the
    marketplace build's primary icon *is* the icon Apple reviews and shows. In practice the question becomes: is
    the current primary icon all-ages?
  - **The icons today.** `App/EhPanda.icon` is the panda holding a rose, with light and dark variants. The listing
    icon `docs/altstore/appicon-512.png` is the same picture.
  - **Options:**
    - A. Keep the current primary icon in every build and on every listing, if the owner judges it all-ages. No
      new asset; the alternate icons stay as they are (D-02).
    - B. Have a designer make an all-ages primary icon for the marketplace build only, set by the marketplace
      flavor. Safest if the owner has doubts, but it is a second icon to keep in sync.
  - **Recommendation: A.** The icon shows a cartoon panda and a flower and nothing adult, and one icon everywhere
    needs no flavor-specific asset. If the owner chooses B, the asset is a step (f) item and the flavor points
    `ASSETCATALOG_COMPILER_APPICON_NAME` at it.

### Plan order (D-14; product lead msg 2771)

- **(a) Marketplace build flavor and release mechanics fixes** (DIST-18-01 flavor part, REL-18-01).
  - The `Config/Marketplace.xcconfig` flavor with the channel stamp set at build time (D-12 amended).
  - `PrivacyInfo.xcprivacy` (D-18).
  - The build-number check in `deploy.yml`, and the bump above 158.
  - Checks that the Classic history and download URLs stay as they are.
  - **Checkpoint (owner):** creating `EhPanda-Team/ehpanda-assets` on GitHub and pushing it (D-17).
- **(b) PAL source JSON** (DIST-18-02): the template, the filter's `assetURLs` support and the checks, with no live
  ADP yet.
- **(c) Notarization CI job** (DIST-18-03): signed marketplace archive, upload, version with
  `reviewType: NOTARIZATION`, submit, poll, ADP, AltStore processing, release assets, PAL source update.
  - **Checkpoints (collaborator and owner, D-07), each at its own time:**
    - the App IDs, with the suffix confirmed;
    - the certificate and profiles;
    - the API key, with its type and role;
    - agreeing to the DPLA and adding AltStore PAL as a marketplace;
    - the trader-status declaration;
    - the age-rating answers and the App Privacy answers;
    - the countries or regions the app is offered in (AltStore PAL serves the EU, Japan and Brazil);
    - the GitHub environment secrets;
    - the first submission, including the App Manager key test (D-21).
- **(d) Website dependencies check** (Leto):
  - the privacy policy URL;
  - the support URL;
  - the published contact link (GitHub Issues), live before the build goes to Apple (D-05);
  - the PAL source's public URL.
  The privacy page rewrite stays at 3.0 ship (D-10).
- **(e) Real-device checks** (DEV-18-01). **Checkpoint (owner hardware).**
- **(f) The parts that need Phase 19** (D-14):
  1. the PAL listing assets and store screenshots from Phase 19's approved reference set: sizes, iPad 13-inch,
     OQ-1's icon, all-ages content (D-04 amended);
  2. the release relying on Phase 19's screenshot check.
  - **Checkpoint (owner):** the screenshots and listing assets.
- **(g) Analytics revision** (ANALYTICS-02; D-06 amended).
- **(h) Closing Release isolation scan** on the final build (D-09), with `Scripts/visual/verify-release.py`.

### Developer defaults (changeable; updated 2026-11-09 with evidence)

These were not put to the owner (prep section 3).

- **Marketplace bundle suffix:** `.marketplace` (channel-neutral), for the app and the share extension through
  `BUNDLE_ID_SUFFIX`: `app.ehpanda.marketplace` and `app.ehpanda.marketplace.shareExtension`. The owner sees it again
  at the App ID checkpoint (D-07). — **Reversibility:** one-way — once a build is uploaded, the explicit App ID in the
  collaborator's account cannot be deleted, and moving PAL users to another ID means a reinstall and lost data.
- **Marketplace flavor:** `Config/Marketplace.xcconfig`, passed with `-xcconfig` by the notarization job only, like
  `Config/Beta.xcconfig`.
  - **What it sets:** `BUNDLE_ID_SUFFIX = .marketplace`, the Home Screen name "EhPanda", the regular icon (unless
    OQ-1 says B) and its own URL scheme, so its share extension never hands a link to another installed flavor
    (D-11's reason). The planner checks that nothing public links with the `ehpanda://` scheme; if something does,
    the flavor registers both schemes.
  - **The stamp:** a build setting, for example `EHPANDA_DISTRIBUTION_CHANNEL`, defaulting to `source` in
    `Config/Flavor.xcconfig` and set to `altstorePAL` by the marketplace flavor. `App/Info.plist` reads its
    `EhPandaDistributionChannel` value from that setting. `package-channel.sh` keeps working unchanged, because
    unsigned builds still say `source`.
  - **Unchanged:** the unsigned IPA build and private local signing. No compilation condition is needed, because
    there is no feature difference (D-02).
- **Build number (REL-18-01):**
  - **The gap.** The project is still at `CURRENT_PROJECT_VERSION = 158`. That is the build of 2.8.1 in
    `AltStore.json`, and the published 3.0.0 beta used it too. `deploy-beta.yml` runs
    `actions-tool/check-build-number.sh`; `deploy.yml` does not.
  - **The fix.** Add the same check to `deploy.yml`, against `AltStore.json`, `SideStore.json` and
    `altstore-beta.json` as published on `main`, and bump with `Scripts/bump-version.sh` to above 158 in step (a).
    The notarization job runs the same check against the PAL source.
- **Classic `AltStore.json` history:** done. `actions-tool/altstore-add-version.jq` prepends each version and keeps
  the older ones (`8d02c3e6d`); an entry with the same version and build, or the same URL, is replaced. Step (a)
  only keeps tests on it.
- **PAL source:**
  - **The file.** `AltStorePAL.json` in the repo root, next to `AltStore.json` and `SideStore.json`. The first PAL
    run creates it from `actions-tool/altstore-pal.template.json`, so it is never written with zero versions.
  - **The template.** It carries D-16's metadata, `nsfw: true` and `marketplaceID`: the App Store Connect app's
    Apple ID, from the collaborator, kept as a repository variable.
  - **The entries.** `appPermissions` are read from the signed build, not copied from `AltStore.json`. Each version
    entry has `downloadURL` (the manifest), `assetURLs` and `size` (one variant's size, as AltStore advises) and no
    single-IPA `sha256`. `altstore-add-version.jq` is extended for that rather than forked.
  - **Not yet.** Screenshots are added in step (f). The public URL (an ehpanda.app redirect like `AltStore.json`'s)
    is agreed with Leto in step (d). Making the source discoverable is deferred.
- **Notarization CI:**
  - **The workflow.** A separate `workflow_dispatch` workflow behind a protected GitHub environment with a
    required reviewer. The collaborator's signing material and API key live only in that environment's secrets.
  - **Two jobs.** Notarization includes human review that can take hours, so the workflow has a *submit* job (signed
    archive, upload, version, review type, submission) and a *publish* job that can be re-dispatched for a version.
    The publish job reads the ADP ID, asks AltStore to process it (`POST api.altstore.io/adps` when marketplace
    notifications are off), waits for AltStore's `downloadURL`, downloads the ADP unchanged, uploads it to the
    release (D-19) and commits the PAL source to `main`.
  - **The key test.** The workflow records D-21's App Manager key test result.
- **App Store Connect metadata** (description, screenshots, privacy policy URL, support URL, age rating, App Privacy):
  entered by hand by the collaborator, or with the owner's OK at the first submission. Later versions may set it
  through the API once the D-21 test shows the key can.

### Claude's Discretion

- The exact required-reason codes and the collected-data entries in `PrivacyInfo.xcprivacy`, checked against
  Xcode's privacy report for the archive.
- The names of the marketplace URL scheme, the build setting and the PAL workflow file.
- How the PAL job's asset names avoid confusing GitHub-release visitors, for example an `EhPanda-AltStorePAL-`
  prefix. `assetURLs` maps file names to any URL, so the uploaded names are free.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirements
- `.planning/ROADMAP.md`: Phase 20, and the split map at the end of the Phase 18 section.
- `.planning/REQUIREMENTS.md`: REL-18-01, DIST-18-01, DIST-18-02, DIST-18-03, DEV-18-01, MKT-18-01, UGC-18-01,
  ANALYTICS-02 and CAP-17-05, with their amendments.

### Earlier phase decisions
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-DISCUSSION-PREP.md`: L2, L6 to
  L8, L22 to L29, L35, L41, L43, GA-6, GA-7 (dropped), GA-8, section 3 (defaults) and section 4 (outside parties).
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-FIRST-LAUNCH.md` and
  `18-COPY-MINIMAL.md` (Revision 7): the level descriptions ANALYTICS-02 must keep true, and the website knock-on.
- `.planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-CONTEXT.md`: D-04 (amended by
  D-18) and D-06 to D-14.
- `.planning/phases/19-visual-regression-marketing-export/19-CONTEXT.md`: the screenshot check and the approved
  reference set that step (f) waits for.

### Code and workflows
- `.github/workflows/deploy.yml`, `.github/workflows/deploy-beta.yml`, `.github/workflows/release-notes.yml`.
- `actions-tool/package-channel.sh`, `actions-tool/check-build-number.sh`, `actions-tool/altstore-add-version.jq`,
  `actions-tool/release_notes.py`, `actions-tool/altstore_languages.py`, `actions-tool/sidestore.template.json`,
  `actions-tool/altstore-beta.template.json`, `actions-tool/tests/`.
- `AltStore.json`, `ReleaseNotes/README.md`, `docs/altstore/appicon-512.png`, `App/EhPanda.icon`.
- `Config/Signing.xcconfig`, `Config/Flavor.xcconfig`, `Config/Beta.xcconfig`, `Config/Analytics.xcconfig`.
- `App/Info.plist` (`EhPandaDistributionChannel`, `MKSellsDigitalGoods`, `CFBundleAlternateIcons`).
- `AppPackage/Sources/AppModels/Utilities/DistributionChannel.swift`,
  `AppPackage/Sources/AnalyticsClient/InstallSignalSender.swift`.
- `Scripts/bump-version.sh`, `Scripts/visual/verify-release.py`.

### External sources (read 2026-11-09)
- Apple, Changes for apps in the EU (notarization goes through App Store Connect's alternative distribution option):
  https://developer.apple.com/support/dma-and-apps-in-the-eu/
- App Store Connect Help, Submit for Notarization (roles; steps; ADP generated on acceptance; required properties):
  https://developer.apple.com/help/app-store-connect/managing-alternative-distribution/submit-for-notarization
- App Store Connect Help, Get an alternative distribution package ID:
  https://developer.apple.com/help/app-store-connect/managing-alternative-distribution/get-an-alternative-distribution-package-id
- App Store Connect Help, Manage distribution on an alternative app marketplace (Account Holder or Admin):
  https://developer.apple.com/help/app-store-connect/managing-alternative-distribution/manage-distribution-on-an-alternative-app-marketplace
- Apple, Describing use of required reason API (not accepted by App Store Connect since May 1, 2024):
  https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Apple, Third-party SDK requirements (Kingfisher and SDWebImage listed):
  https://developer.apple.com/support/third-party-SDK-requirements/
- Apple, Creating API keys for the App Store Connect API (team keys carry roles; individual keys' limits):
  https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api
- App Store Connect API OpenAPI specification 4.6 (`reviewType` `APP_STORE` / `NOTARIZATION`; alternative
  distribution package endpoints):
  https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip
- App Store Connect Help, Screenshot specifications:
  https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- App Review Guidelines, 2.3.8 and 2.3.6 (marked as Notarization guidelines):
  https://developer.apple.com/app-store/review/guidelines/
- Apple, Configuring your app icon (the store icon comes from the asset catalog):
  https://developer.apple.com/documentation/xcode/configuring-your-app-icon
- AltStore, Distribute with AltStore PAL: https://faq.altstore.io/developers/distribute-with-altstore-pal
- AltStore, Make a Source (`marketplaceID`, PAL `downloadURL`, `assetURLs`, screenshots, `appPermissions`):
  https://faq.altstore.io/developers/make-a-source
- AltStore, REST API (register, process and download ADPs): https://faq.altstore.io/developers/rest-api
- AltStore, Updating Apps: https://faq.altstore.io/developers/updating-apps
- AltStore, App Guidelines: https://faq.altstore.io/developers/app-guidelines

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `actions-tool/package-channel.sh`: stamps unsigned copies; reused unchanged for the unsigned channels, not usable
  for the signed PAL build (D-12 amended).
- `actions-tool/check-build-number.sh`: already used by `deploy-beta.yml`; reused in `deploy.yml` and the PAL job.
- `actions-tool/altstore-add-version.jq`: newest-first history with replacement rules; extend for PAL `assetURLs`.
- `actions-tool/release_notes.py`: produces the English and per-language notes for every source; the PAL source
  takes the same `localizedDescriptions` as `AltStore.json`.
- `actions-tool/altstore_languages.py` and `actions-tool/tests/`: the source checks (`check_source`, screenshots,
  languages) to extend to the PAL source.
- `Config/Beta.xcconfig`: the pattern for `Config/Marketplace.xcconfig`.

### Established Patterns
- One unsigned build, one stamped copy per channel. Release URLs come from the release's asset list and are checked
  before they are written.
- Sources on `main` are created from a template by their first run, never with zero versions.
- Workflows fail fast on any mismatch (bundle ID, build number, missing notes, unresolved URL).

### Integration Points
- `App/Info.plist`: the stamp's value becomes a build setting.
- `deploy.yml`: the build-number check; later, the reliance on Phase 19's screenshot check (step (f)).
- The new PAL workflow's publish job attaches to the GitHub release that `deploy.yml` made for the same version.
- `ReleaseNotes/3.0.0.md` does not exist yet, so a 3.0.0 release PR fails its notes check until it is added.

</code_context>

<specifics>
## Specific Ideas

- AltStore PAL reads ADPs byte for byte: never reformat `manifest.json` (AltStore, "Distribute with AltStore PAL").
- Apple's EU terms changed on 1 Oct 2026 (Attachment 14 of the DPLA and a 5% Core Technology Commission on
  digital-goods sales). EhPanda sells nothing (`MKSellsDigitalGoods = NO`), so nothing is owed. AltStore charges 0%
  (AltStore, "Fees").
- The AltStore PAL listing's `developerName` is free text in the source, but it must be accurate (guideline 5.6.2;
  AltStore guideline 2). iOS's install sheet shows the developer name from the collaborator's account.

</specifics>

<deferred>
## Deferred Ideas

- **Hiding features in the marketplace build:** only if Apple objects (D-02).
- **A second marketplace listing:** not for 3.0 (PAL only).
- **Making the PAL source discoverable** on explore.alt.store: optional, and its `fediUsername` cannot be changed
  later; not planned for 3.0.

</deferred>

---

*Phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele*
*Owner decisions first recorded: 2026-11-05; context gathered: 2026-11-09*
