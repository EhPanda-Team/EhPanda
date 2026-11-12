# Shared book-cover proportion and refreshed review — 2026-10-29

> Workspace retirement notice (2026-11-02): The owner plans to delete the historical
> `ehpanda-screenshot-review` workspace. Paths and localhost links below describe evidence
> available at the time of this report; they are not current reproduction dependencies and
> may no longer resolve after deletion. Current capture instructions are in the app repository
> `Scripts/visual/README.md`; the private fixture repository
> `active-fixtures.json.websiteCaptureIndex` identifies the approved inputs. This notice does
> not claim that historical screenshots, scripts or QA evidence have been migrated.


## Scope and disposition

The owner requested exact width:height **0.707:1** throughout cover frames, removal of active screenshot galleries losing more than **10%** of their area to aspect-fill cropping, and anonymous nonexplicit replacements. App changes and data preparation proceeded in parallel. This is a provisional local review delivery: no visual acceptance, baseline promotion, 17-07 execution or change to Phase 17's **6/24** completion count. Deferred runner-serialization decisions and release/publication holds remain unchanged.

## App change

`Defaults.ImageSize.coverAspect` is the one shared 0.707 constant. Implementation commit: `428602283` (signature verified). Row/header aliases, `GalleryCoverStyle` and `GalleryThumbnailCell` use it; the former fixed-cover 8/11 and grid 2117/3000 proportions are replaced. Cover heights, capped Dynamic Type scaling, native-pixel rounding and existing fit/fill behavior are preserved. Reader and page-preview proportions are unchanged.

Regression assertions cover every fixed-cover role at both display scales and multiple text scales, shared aliases, half-pixel proportional rounding and the existing height cap. Artwork tests use the updated exact expected dimensions.

## Active selection and acquisition

- Sixteen of the previous 32 gallery covers exceeded the strict 10% limit; those galleries were removed from every active scene assignment. Sixteen replacement covers were selected from 26 ratio-eligible candidates among 34 acquired metadata/cover candidates.
- Final scene: 32 galleries, 31 distinct Home galleries (3 hero, 16 Frontpage, four rankings of 3), a separate Live Text gallery, and seven truthful Downloads states. No empty Home slots remain.
- Crop loss is `1 - min(sourceRatio / (707/1000), (707/1000) / sourceRatio)`, evaluated with exact rational arithmetic. Every exported cover passes; maximum loss is **9.2212%**. The final fixture's cover bytes were independently matched against the audit's hashes.
- Active selection: `review-book-ratio-20261029`. Immutable fixture: `marketing-1351afc0b99a3870`, **568 validated assets**. The inherited `explicit` scene identifier is not a safety classification; this replacement acquisition is nonexplicit, not an explicit-content set.
- Flow: Magical Mirai 2026 Visual book (`4194047`), reader page 6, acquired window 1–11. Cuphead was not used for visible comments because its comment text was unsuitable for this review.
- Live Text: The Art of Overwatch (`1487337`), page 11, window 6–16. The app recognized 4 groups/15 lines; that actual result was saved once and replayed, with reader controls hidden. **An alternate-language reference is unverified**, so this does not satisfy the final multilingual requirement.
- Downloads use actual page files and manifest counts: active 6/273, queued 0/147, update-available 28/28, inactive 25/356 and complete 15/15, 36/36, 101/101. Partial files do not become complete through display labels.
- Static data stays in the sibling fixture repository. Earlier root selections/status/README/archive records are retained under its `history/book-ratio-20261029/`; all earlier immutable fixture versions and screenshots remain. The historical archive contains 44 galleries, **23 explicitly incomplete**. All 6,393 referenced resource lengths and hashes match; this integrity result is not a whole-book completeness claim. Newly selected whole books were not reviewed.

## Verification

- Focused cover/layout/artwork tests: iPhone and iPad each pass 15 test identities / 30 executions, with no failures, skips or runtime warnings.
- Fixture/selection/Live Text Python tests: 75 pass.
- The main app also archives successfully (60.742 seconds, no compiler warnings), installs and launches in the managed simulator using its unchanged local configuration. Its five changed Swift files exactly match signed implementation commit `428602283`. The existing live Home was not copied into shared screenshots; only the controlled review captures are delivered.
- Unsigned review archive succeeds; the five changed Swift files are SHA-256 identical between the tested main checkout and built review checkout. Review base is `8b9a9744d` plus the cover patch and existing private diagnostics-export patch; main base is `243badb22` plus the cover patch.
- **32 native screenshots**: eight screens × iPhone/iPad × light/dark, English, Large, portrait; 1260×2736 and 1668×2420. All pass expected scene/fixture identity, complete gallery order, before/after readiness, zero unknown requests/pending images, real download-file checks, source/output byte equality, native dimensions and two consecutive byte-identical frames. Both contact sheets were visually inspected.
- The first iPad reader waits expired at 10 seconds; the bounded wait was increased to 40 seconds without relaxing tree stability or identical-frame checks. The complete subsequent capture passes. Earlier failed attempts remain as evidence.
- The same two additional UI tests pass on iPad (iOS 27.0): grid/title checks at all four sizes and the complete row/grid download-management flow, including relaunch. No failures, skips or runtime warnings.
- Additional grid/title UI coverage passes on iPhone Duo at Large, AX1, AX3 and AX5. The additional download-management test failed on initial launch or relaunch: its captured hierarchy shows Favorites rather than the requested Downloads. One attempt completed row/grid inspection, move, reading and deletion before failing the relaunch assertion. This is not reported as an all-green UI suite.
- An unchanged `243badb22` checkout reproduced the Duo problem under the same two-test command and normal parallel plan: grid/title passed; all three Downloads attempts failed at launch (lines 150/151), with captured hierarchies showing Favorites. Thus the launch-test failure predates this cover patch. The isolated comparison checkout was removed after exporting its evidence; the original review checkout remains intact. No navigation workaround, test suppression or serialization change was introduced. This pre-existing issue remains unresolved, separate from the completed cover request.

## Evidence and handoff

Private local evidence is under `.airbuild/book-ratio-20261029/`: focused-test summaries, additional UI failure summaries/activities/attachments, `verification.json`, `source-parity.json`, `final-fixture-crop-audit.json`, `archive-integrity.json`, `main-build-receipt.json`, `before-change-ui-summary.json`, `before-change-ui-tests.json`, exported unchanged-source attachments, selection review and contact sheets.

Acquisition/export/audit tools and the website handoff are under `$HOME/Fork/ehpanda-screenshot-review/work/book-ratio-20261029/`. New native images are under its `review/assets/20261029-book-ratio/`; timestamped original frames, diagnostics and settlement records remain in `captures/`.

The website owner received all 32 verified items and the instruction to add a separate default batch, namespace its review identities and preserve both previous batches and notes. Website testing is separate from app testing; no publication or deployment is authorized.

### Final website-owner handoff

The local review at `http://127.0.0.1:8766/review/` now contains three complete 32-image batches (96 total), defaulting to the new 0.707-cover batch. Earlier item objects, links, notes and statuses retain separate identities, including when screenshots have identical pixels. The linked archive display was refreshed from the saved static data: 44 historical galleries, 23 incomplete; its previous generated page is retained and gallery files were not changed.

The website owner's reports record **22/22 data checks** and **46/46 isolated local Chrome checks**, including all image hashes/native sizes, historical preservation, cross-batch comparison, reload-persistent notes, distinct accessible labels and narrow-phone layout. Actual VoiceOver was not tested. Synthetic QA notes/statuses are not owner decisions. Evidence lives under the review workspace's `review/qa/checks-book-ratio-20261029.json` and `review/qa/browser-check-book-ratio-20261029.json`; the corresponding browser script and desktop/mobile/comparison images are retained alongside them.

On receipt, the report contents and seven supplied preservation hashes were independently checked: current review manifest/page, both historical manifests, previous/current archive pages and the archive source. All matched. The current 96-image manifest hash is `dda9fd8e0dc9aceb2a4b6b17635749bb8801a35bd526001672ea46d092af3773`; the exact previous 64-image manifest is retained as `review/captures-20261029.pre-book-ratio.history.json` with hash `bc09bab30ad355ba23a4618c9cba12e617d6e564bba94e5a6d2add61330c4d23`. These website checks are not app-suite coverage or baseline approval. Nothing was published, and the phase gate remains unchanged.

## Remaining limits

Full feature suites, VoiceOver operation, other locales, the complete text-size/orientation matrix and all 384 Phase 17 coordinates were not run. Consecutive identical frames are not cross-launch determinism evidence and do not replace the pinned system-screenshot baseline gate. Historical acceptance, final gallery selection, the replacement Live Text language reference and existing schema/pin reconciliation remain pending.
