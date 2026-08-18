import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Working Manifest Reconciliation
extension DownloadCoordinator {
    /// Blanks the recorded hash of every page the working manifest claims but whose file is not in
    /// the working folder, persisting and re-indexing the manifest only when something changed.
    ///
    /// **D-G5-01: a working manifest never claims a page whose file is not in the working folder.**
    ///
    /// It closes the RUN-TIME half of G-15-5: a record that goes on reading complete while a repair
    /// run is fetching the very pages it claims. That is a distinct hole from the VALIDATE-TIME one
    /// D-G5B-01 closes in `validateImageData` — a record that goes on reading complete after the
    /// user's own integrity check has proved files missing, with no run in sight — and this
    /// paragraph is not to be read as covering it. The two share this loop deliberately: the second
    /// caller reuses these refusal lines rather than growing a laxer blanking rule of its own.
    /// A `.repair` exists precisely because files are missing, yet nothing lowered
    /// the record's finished-page count for them: `shouldReuseWorkingFolder` returns `true`
    /// unconditionally for `.repair`, so the folder survives, and `ensureWorkingManifest` finds a
    /// valid manifest and returns it verbatim. The record went on reading complete for the whole
    /// run, `isIncomplete` stayed false, so D-G4-01's basis counted zero session pages for the
    /// gallery from its first push to its untrusted departure, and the session finished a terminal
    /// `0 / N pages · 0 galleries` card over real repair work. That is the maximally stalled reading
    /// the scheduler force-expires first, and D-11 turns that expiration into a pause of every
    /// schedulable download — so the lie costs liveness, not just honesty.
    ///
    /// This is the single point every start mode's run converges on, which is why one reconciliation
    /// covers them all rather than patching the branch a report named. `.redownload` and `.update`
    /// delete the working folder and arrive with a fresh all-empty manifest, and a fresh `.initial`
    /// does too, so this is a no-op for them. The modes it does work for are the ones that reuse a
    /// manifest they did not write: `.repair`, and the `.initial` reuse of a matching complete
    /// manifest. A third one used to reach here — the repair-seed materialization, which copied a
    /// manifest whole while copying the pages selectively and therefore had to hand its SOURCE-side
    /// non-answers across for `prepareWorkingSeed` to union in (G-15-19) — and it is retired, so
    /// every classification this loop reads is now about the very folder it is reconciling.
    ///
    /// Deliberate consequence, recorded because it looks like a regression and is not: an
    /// interrupted repair's record now honestly reads incomplete, so its `displayStatus` is
    /// `.inactive` rather than `.completed`. `resumeMode`'s incomplete-inactive branch resolves
    /// `.repair` for it exactly as its missingFiles branch did before, so no route is lost — the
    /// files really are missing, and the record finally says so.
    ///
    /// The same movement reaches `storage.validate`, and that consequence was considered rather
    /// than missed. `validatePage` (`DownloadStore+Operations.swift`) returns nil for an empty
    /// expected hash — nothing claimed, nothing to check — so a blanked page that previously
    /// produced `.missingFiles` now leaves the record reporting `.valid`. Two consumers see it:
    /// `validateImageData(gid:)`, the inspector's user-initiated integrity check, and
    /// `loadManifest(gid:)`, whose missingFiles gate decides whether the offline reader opens the
    /// gallery or falls back to remote. Both answer differently for an interrupted repair, and
    /// that is correct rather than lost coverage: the manifest genuinely no longer claims those
    /// pages, which is the exact state an interrupted `.initial` download has always presented,
    /// and mode resolution still reaches `.repair` through `isIncomplete` so the missing pages are
    /// still fetched. Validation reports what the record claims; it is not a second source of
    /// truth about what the gallery ought to contain.
    ///
    /// This function does no basis accounting of its own, deliberately. Its index write is one of
    /// several deliberate downward movers inside `prepareWorkingSeed`, and all of them are enclosed
    /// by that function's D-G7-01 bracket, which withdraws each movement's counted portion from the
    /// monotonic floor keyed on the pre/post index-record delta. Attaching the withdrawal to this
    /// blanking loop instead is what produced G-15-7: an all-empty manifest blanks nothing, so the
    /// early return above fires and a `.redownload` that had just wiped the same record from C of N
    /// to 0 of N withdrew nothing. The rule belongs to the movement, not to the mechanism.
    ///
    /// No suspension is introduced: `pageFileScan` is a scan the caller already took, so no disk
    /// scan happens here, and `writeManifest` / `updateDownloadIndex` are same-actor synchronous
    /// calls.
    ///
    /// **Positive-signal rule: a best-effort probe's non-answer is never authority for destroying
    /// recorded hashes.** The scan swallows failure at three levels — `existingAssetFileURLs` on any
    /// `contentsOfDirectory` failure, the per-file probe's metadata read, and that probe's
    /// content-read fallback on any open or read failure. Every one of them fails for transient
    /// reasons, and while an empty answer only caused a re-fetch it was harmless; D-G5-01 made it
    /// destructive. So this consumer is defended in three lines, in this order:
    ///
    /// 1. **The directory-level positive signal (G-15-9).** `scanSucceeded` false means the
    ///    enumeration itself failed, so the whole answer is a non-answer and nothing is blanked. One
    ///    failed enumeration used to blank every claimed page of the gallery in a single pass,
    ///    rewrite the manifest, publish a 0-of-N record and — through the enclosing D-G7-01
    ///    bracket — withdraw the full count from the floor, all unlogged.
    /// 2. **The per-file positive signal (G-15-13, fixed as D-G13-01).** `unprobedPages` carries one
    ///    population, and no page in it is blanked: the pages whose file THIS folder's successful
    ///    listing did yield but whose probe could not classify. It carried a second until the
    ///    repair-seed materialization was retired — the pages that route reported unanswerable in
    ///    the SOURCE folder it copied from, unioned in by `prepareWorkingSeed`, because this
    ///    folder's listing could not see them: a page the copy never landed is honestly absent here,
    ///    so the classification had to travel with the copy rather than be re-derived. With no
    ///    caller crossing a folder boundary there is nothing left to carry. The trigger is narrow
    ///    and real: the metadata read itself throwing for many-but-not-all files — an I/O error, a
    ///    permission change, a volume going away mid-scan. It is not descriptor exhaustion and not
    ///    a locked device, since a metadata read needs no descriptor and still answers under data
    ///    protection. Line 1 cannot reach this population, because the listing succeeded, and line
    ///    3 cannot either, because it disables itself as soon as one claimed page survives: a
    ///    gallery with 100 claimed pages and 99 failed probes passed `99 < 100` and lost 99
    ///    recorded hashes irreversibly.
    /// 2b. **The per-file REFUTATION signal (CR-01).** `rejectedPageRelativePaths` names a claimed
    ///    page whose file the listing yielded, the probe positively refused, and which is STILL ON
    ///    DISK. Such a page is not blanked here, and the reason is the mirror image of line 2's: not
    ///    that nothing was established, but that acting on what was established means removing the
    ///    file as well, and this loop does not remove files. Blanking it alone would leave the
    ///    D-SSOT-04 laundering shape — a blank hash beside bytes `finalizeDownload`'s merge would
    ///    re-record as truth.
    ///
    ///    **The removal belongs to the CALLER, and since WR-02 BOTH callers perform it.** A caller
    ///    that removed the file first sees the page as a positive absence on its own fresh scan and
    ///    gets the blanking through line 2's path. `reconcileValidatedRecordAgainstPageFiles` has
    ///    done that since CR-01; `prepareWorkingSeed` does it now, through the same
    ///    `removeRefutedPageFiles` primitive under the same combined guard. Whatever survives a
    ///    caller's removal — a `removeItem` that threw, a relative path that would escape the folder
    ///    — arrives here still refuted and still present, and keeps its hash AND its file, which is
    ///    what a hold has to mean on disk.
    ///
    ///    Membership is conditional on the file SURVIVING, so a discarding scan whose housekeeping
    ///    deletion succeeded reports nothing here. It is NOT conditional on the caller having
    ///    declined to discard: the probe's content-read exit refuses without deleting for every
    ///    caller alike (WR-02). That population is exactly the one that used to keep a claimed hash
    ///    beside positively refuted bytes indefinitely on the automatic route, because nothing on
    ///    that route ever removed it.
    /// 3. **The all-or-nothing guard, as the residual second line.** A refusal is still taken when a
    ///    nominally successful listing that answered for every file it did probe would nonetheless
    ///    account destructively for every claimed page. The manifest was just read out of this very
    ///    folder, so that is more likely a shape neither signal above caught than proof that every
    ///    page vanished at once. Its reach is narrow ON PURPOSE, and narrower since line 2 grew: one
    ///    claimed page held as unprobed already puts the gallery outside this guard, because the
    ///    guard exists to catch a shape the per-page signals explained NOTHING about, and a page
    ///    they did explain is evidence they were answering. A mixed absent-plus-unprobed shape is
    ///    line 2's, one page at a time, not this line's wholesale.
    ///
    ///    **Its basis is the COMBINED positively-refuted population — blankable absences PLUS
    ///    surviving refutations — and that is what makes line 2b a hold rather than a relaxation
    ///    (WR-01).** The comparison decides what "every claimed page" means, so any per-page rule
    ///    that removes a page from its left-hand side changes the threshold for every OTHER page.
    ///    Line 2b was introduced as something that "can only blank less"; measured over
    ///    `blankedPageCount` alone it can blank MORE. Two claimed pages, one refuted-and-surviving
    ///    and one positively absent: `1 < 2` licenses blanking the absence, where before the fix a
    ///    pass that had explained away the entire record refused. A refutation is a positive
    ///    determination that the recorded hash describes nothing reusable — the same evidence class
    ///    as an absence, licensing the same correction — so it belongs on this side of the
    ///    comparison whether or not THIS function is the thing that acts on it.
    ///
    ///    Unprobed pages stay out, and that asymmetry is the point rather than an inconsistency:
    ///    they are non-answers, and counting them would refuse genuine absences because some OTHER
    ///    page went unanswered — the opposite of the per-page rule line 2 states.
    ///
    ///    Measured HERE rather than at the callers, because a threshold restated at a call site is
    ///    a threshold the next call site can forget. Both entry points inherit it, and so does any
    ///    third one.
    ///
    ///    **The comparison is invariant under a caller's authorized removal, which is why the
    ///    caller's guard and this one cannot disagree.** A removal converts a member of the
    ///    surviving-refutation term into a member of the blankable-absence term and leaves the sum
    ///    unchanged, so a caller that classified, measured `absences ∪ refutations` against the same
    ///    completed count and then removed reaches this loop with the same quantity it authorized.
    ///    A rescan that disagrees can only do so by demoting a page to a non-answer or by catching a
    ///    file that vanished in the race, and both of those move the sum DOWN or leave the loop
    ///    refusing a page it may not blank anyway.
    ///
    ///    Note the shape of the expression as written: the early return above means this comparison
    ///    is only ever evaluated where at least one page WOULD be blanked. It is a guard on an act,
    ///    not a property of the scan, and a folder whose every claimed page is a surviving
    ///    refutation returns unchanged one line earlier without consulting it at all.
    ///
    /// A refusal at any of the three moves no index record, so D-G7-01's delta-keyed bracket
    /// withdraws exactly zero from the floor by construction, without coordination here.
    ///
    /// **What the defence deliberately costs.** A genuinely all-pages-vanished repair is no longer
    /// reconciled: it falls back to the pre-D-G5-01 arc, where the seed's empty `existingPages`
    /// makes the run re-fetch every page, and `resumeMode`'s `storage.validate` branch remains the
    /// route that resolves `.repair` for such a record — re-verified, and its (a)/(b) doc still
    /// reads true, since a refusal is exactly its case (a). An unprobed page pays the same way, one
    /// page at a time. That is accepted against the alternative — letting a transient failure
    /// destroy recorded hashes. Genuine absence is untouched and stays fully blankable: a claimed
    /// page whose file a SUCCESSFUL listing simply did not yield is a positive absence, and a scan
    /// that finds K of them blanks exactly those K, provided K plus the surviving refutations is
    /// short of the whole record.
    ///
    /// What the cost is NOT is a merely delayed honesty. This paragraph used to close by claiming
    /// the flush restores the record, and for the refusal family that claim is refuted: the flush
    /// path is monotone upward — `refreshManifestPageFileHashes` only ever assigns non-empty
    /// hashes — so a record that reads COMPLETE when a refusal hands the manifest back never becomes
    /// incomplete during the run, and the session's observation set, sourced from `isIncomplete`,
    /// can never admit it. What covers that family is the run's own measured basis, announced in
    /// `prepareWorkingSeedAnnouncingProgress` without consulting the record at all (G-15-23). A
    /// record already reading incomplete when a refusal fires is the other case, and for it the
    /// flush really is enough — which is what the sibling refusal cases in
    /// `DownloadContinuedSessionReconciliationTests` stage.
    ///
    /// **Second caller: `validateImageData(gid:)` (D-G5B-01).** The name still holds there, because
    /// a repair's working folder IS the gallery's own folder — `shouldReuseWorkingFolder` returns
    /// true unconditionally for `.repair` — so validate-time reconciliation runs this identical loop
    /// over the identical folder shape, against a manifest read out of that same folder. What the
    /// second caller must supply is what `prepareWorkingSeed` supplies: a scan of that folder taken
    /// fresh (never a verdict — `storage.validate` returns at its FIRST failing page, so its message
    /// names one page rather than the missing set), and an enclosing `withdrawingCountedBasisMovement`
    /// bracket, since this function still does no basis accounting of its own. Module-internal rather
    /// than file-private for exactly that caller: one implementation is what stops the blanking
    /// evidence rule from forking between repair-preparation time and validate time.
    func reconcileWorkingManifestAgainstPageFiles(
        manifest: DownloadManifest,
        pageFileScan: PageFileScan,
        folderURL: URL
    ) throws -> DownloadManifest {
        guard pageFileScan.scanSucceeded else { return manifest }

        var pages = manifest.pages
        var blankedPageCount = 0
        var refutedSurvivingPageCount = 0
        for page in manifest.pages.keys.sorted() {
            // A non-answer is neither blanked nor counted, at either granularity: it explains
            // nothing about the page, so it may not license an act here or move the threshold for
            // any other page. Checked first because a page can carry BOTH signals — one candidate
            // file unprobeable, another refused — and the non-answer wins, exactly as it does in
            // `reconcileValidatedRecordAgainstPageFiles`' own refuted-set derivation.
            guard pages[page]?.isEmpty == false,
                  !pageFileScan.unprobedPages.contains(page)
            else { continue }
            // Line 2b: held here, counted for the guard. The scan's own first-writer rules make a
            // usable page exclusive of this member, so no page is counted twice.
            guard pageFileScan.rejectedPageRelativePaths[page] == nil else {
                refutedSurvivingPageCount += 1
                continue
            }
            guard pageFileScan.pages[page] == nil else { continue }
            pages[page] = ""
            blankedPageCount += 1
        }
        guard blankedPageCount > 0 else { return manifest }
        guard blankedPageCount + refutedSurvivingPageCount < manifest.completedPageCount else {
            return manifest
        }

        var reconciledManifest = manifest
        reconciledManifest.pages = pages
        try storage.writeManifest(reconciledManifest, folderURL: folderURL)
        updateDownloadIndex(folderURL: folderURL, manifest: reconciledManifest)
        // Destroying recorded hashes is irreversible, so it leaves a trail a device archive can show:
        // a real blanking and a refused one are otherwise indistinguishable after the fact. The count
        // is an operational scalar; the gid follows the module's hash-masked identity pattern.
        logger.notice(
            """
            Working manifest reconciled, blanked page count: \
            \(blankedPageCount, privacy: .public), \
            gid: \(manifest.gid, privacy: .private(mask: .hash)).
            """
        )
        return reconciledManifest
    }
}
