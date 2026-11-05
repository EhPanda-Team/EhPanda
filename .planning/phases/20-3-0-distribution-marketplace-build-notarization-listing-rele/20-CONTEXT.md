# Phase 20: 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks - Context

**Gathered:** 2026-11-05 (owner decisions recorded during the Phase 18 discussion)
**Status:** Discussion not yet run; owner decisions recorded. Run `/gsd-discuss-phase 20` before planning.

<domain>
## Phase Boundary

This phase makes 3.0 distributable on the GitHub/AltStore Classic channel and on AltStore PAL. It covers:

- the marketplace build flavor (DIST-18-01, flavor part);
- the PAL source JSON and listing (DIST-18-02);
- store screenshots and promotional images (MKT-18-01 promotional part, CAP-17-05, from 17-22);
- the notarization pipeline (DIST-18-03);
- the website dependencies: privacy policy, support page, and the published contact link (UGC-18-01, contact part);
- the release mechanics (REL-18-01);
- the real-device checks (DEV-18-01);
- last, the analytics revision with the install source (ANALYTICS-02).

The closing gate repeats the Release isolation scan on that final build.

**Not here:** in-app features (Phase 18) and visual regression and the 384 export (Phase 19). Tag creation and release
order are in no phase.

</domain>

<decisions>
## Owner decisions that apply (recorded 2026-11-05)

- **D-01:** Three phases, with all waiting on outside parties in this one: the App Store Connect collaborator, the
  website and Apple (owner msg 1753).
- **D-02:** **The marketplace build has the same features as the GitHub IPA and is listed on AltStore PAL only**
  (owner msg 1753). Something is hidden only if Apple objects. The ADP pipeline stays generic, so other marketplaces
  can be added later (prep L2; owner msg 1287).
- **D-03:** **"Tagging is not your business"** (owner msg 1753). No tag-style decision, no plan to remove or rename
  the existing `3.0.0` tag, no tag creation and no release-order planning. Prep L22 and L23 and GA-7 are dropped. The
  AltStore download URL must still resolve to the release's actual asset; how, without choosing a tag style, is for
  this phase's discussion.
- **D-04:** **Store screenshots** are the website screenshots plus extra decorations (owner msg 1753). The designer
  Colo does the decorations when this phase starts (msg 1757). An AltStore listing can use only non-adult pictures
  (Ampo msg 1751, guideline 2.3.8). These are the AltStore promotional images moved from Phase 17 (17-22). The listing
  icon is all-ages (prep L28), and no "Apple-approved" wording appears anywhere (prep L8).
- **D-05:** **Published contact link:** there is no in-app contact option for now (Ampo msg 1774, after the owner's
  question in msg 1760). A published contact link, GitHub Issues on the website, is needed before the AltStore build
  goes to Apple. The website owner is Leto. The privacy policy and support URLs are website work too (prep L7).
- **D-06:** **The final analytics revision is the last plan of this phase** (ANALYTICS-02; owner msgs 1289, 1753). It
  sits here because the install source needs the marketplace build, which first exists in this phase. It adds the
  install source to Basic, as the approved level description already promises (Phase 18 copy, msg 1767), and the
  signals for every 3.0 flow under the consent levels, within ANALYTICS-01's rules.
- **D-07:** **Apple-service actions** (App IDs, the app record, certificates, API keys, marketplace registration,
  trader status) happen in the collaborator's App Store Connect account. The collaborator does them, or the owner OKs
  them explicitly at the time. Agents never create them on their own (prep L6).
- **D-08:** The real-device checks on owner hardware (prep L43): the iPad Gallery Detail stall on a Release build, and
  continued background downloads on an iPhone.
- **D-09:** The closing gate repeats the Release isolation scan on the final build, which includes the analytics
  revision (prep L41). IN-02 and IN-03 are closed in Phase 18 first.
- **D-10:** The website privacy page is rewritten for the three analytics levels when 3.0 ships, not before (Phase 18
  copy file, "Knock-on for the website").

## Open questions for this phase's discussion

- **GA-6 Q3:** must the marketplace build's own primary icon be all-ages, or only the listing icon?
- **Privacy manifest:** does notarization through App Store Connect require a `PrivacyInfo.xcprivacy`? This reopens
  Phase 14 D-04.
- **The download URL:** how it matches the release asset without a tag decision (D-03).
- **Ordering of analytics and notarization:** the analytics revision comes after the notarization pipeline and the
  device checks, but before the final build that is scanned.

## Developer defaults (changeable)

These were not put to the owner (prep section 3):

- **Marketplace bundle suffix:** `.marketplace`, channel-neutral, for the app and the share extension through
  `BUNDLE_ID_SUFFIX`. — **Reversibility:** one-way — it becomes a permanent App ID in the collaborator's account.
- **Marketplace flavor:** `Config/Marketplace.xcconfig` (or a build configuration) with a compilation condition. The
  unsigned IPA build and private local signing stay unchanged.
- **Install source:** a closed enum from MarketplaceKit `AppDistributor.current`, cross-checked with the build-flavor
  flag. No free-form marketplace strings.
- **PAL source:** a separate JSON in the repo with the same version-history logic, written by the notarization job.
  The hosting URL is agreed with Leto.
- **Notarization CI:** a separate `workflow_dispatch` job behind a protected GitHub environment with a required
  reviewer. It submits, polls and downloads the ADP, then publishes, and records the App Manager key test.
- **Classic `AltStore.json`:** each new version is prepended, and older entries are kept.

</decisions>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md`, Phase 20, and the split map at the end of the Phase 18 section.
- `.planning/REQUIREMENTS.md`: REL-18-01, DIST-18-01, DIST-18-02, DIST-18-03, DEV-18-01, MKT-18-01, UGC-18-01,
  ANALYTICS-02 and their 2026-11-05 amendments.
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-DISCUSSION-PREP.md`: L2, L6 to
  L8, L22 to L29, L35, L41, L43, GA-6, GA-7 (dropped), GA-8, and section 4 (outside parties).
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-FIRST-LAUNCH.md`: the
  level descriptions that ANALYTICS-02 must keep true, and the website knock-on.
- `.planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-CONTEXT.md`: D-04 and D-06 to
  D-14.
- `.github/workflows/deploy.yml`, `.github/workflows/deploy-pre-release.yml`, `AltStore.json`,
  `Scripts/bump-version.sh`, `Config/Signing.xcconfig`, `Scripts/visual/verify-release.py`.

</canonical_refs>

<deferred>
## Deferred Ideas

- **Hiding features in the marketplace build:** only if Apple objects (D-02).
- **A second marketplace listing:** not for 3.0 (PAL only).

</deferred>

---

*Phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele*
*Owner decisions recorded: 2026-11-05; discussion not yet run*
