import AppModels
import AppTools
import Foundation
import NetworkingFeature
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Execution Support
extension DownloadCoordinator {
    public func makeInitialManifest(payload: DownloadRequestPayload) -> DownloadManifest {
        let pageCount = payload.galleryDetail.pageCount
        let pages = pageCount > 0
            ? Dictionary(uniqueKeysWithValues: (1...pageCount).map { ($0, "") })
            : [:]
        return DownloadManifest(
            gid: payload.gallery.gid,
            host: payload.host,
            token: payload.gallery.token,
            title: payload.gallery.title,
            jpnTitle: payload.galleryDetail.jpnTitle,
            category: payload.gallery.category,
            language: payload.galleryDetail.language,
            remoteCoverURL:
                payload.galleryDetail.coverURL ?? payload.gallery.coverURL,
            uploader: payload.galleryDetail.uploader,
            tags: payload.gallery.tags,
            postedDate: payload.galleryDetail.postedDate,
            rating: payload.galleryDetail.rating,
            pages: pages
        )
    }

    public func folderRelativePath(
        for payload: DownloadRequestPayload,
        parentFolderName: String
    ) -> String {
        let galleryFolderName = storage.makeFolderRelativePath(
            gid: payload.gallery.gid,
            token: payload.gallery.token,
            title: payload.galleryDetail.trimmedTitle.isEmpty
                ? payload.gallery.title
                : payload.galleryDetail.trimmedTitle
        )
        return "\(parentFolderName)/\(galleryFolderName)"
    }

    public func downloadCoverImage(
        payload: DownloadRequestPayload,
        options: DownloadRequestOptions,
        folderURL: URL,
        existingCoverRelativePath: String?
    ) async throws -> String? {
        if let coverRelativePath = existingCoverRelativePath,
           !coverRelativePath.isEmpty {
            let localCoverURL = folderURL
                .appendingPathComponent(coverRelativePath)
            if fileManager.operate({ $0.fileExists(atPath: localCoverURL.path) }) {
                return coverRelativePath
            }
        }
        guard let coverURL =
                payload.galleryDetail.coverURL
                ?? payload.gallery.coverURL
        else {
            return nil
        }
        if let cachedData = await validatedCachedAssetData(
            for: [coverURL]
        ) {
            return try saveCoverFromCache(
                cachedData: cachedData,
                coverURL: coverURL,
                payload: payload,
                folderURL: folderURL
            )
        }
        return try await downloadCoverFromNetwork(
            coverURL: coverURL,
            payload: payload,
            folderURL: folderURL,
            allowsCellular: options.allowCellular
        )
    }

    private func saveCoverFromCache(
        cachedData: Data,
        coverURL: URL,
        payload: DownloadRequestPayload,
        folderURL: URL
    ) throws -> String {
        let ext = fileExtension(
            for: coverURL,
            response: nil,
            prefixData: cachedData
        )
        let relativePath = storage
            .makeCoverRelativePath(
                gid: payload.gallery.gid,
                token: payload.gallery.token,
                fileExtension: ext
            )
        let fileURL = folderURL
            .appendingPathComponent(relativePath)
        try write(data: cachedData, to: fileURL)
        return relativePath
    }

    private func downloadCoverFromNetwork(
        coverURL: URL,
        payload: DownloadRequestPayload,
        folderURL: URL,
        allowsCellular: Bool
    ) async throws -> String {
        let (downloadedFileURL, response) =
            try await downloadResponse(
                url: coverURL,
                allowsCellular: allowsCellular
            )
        let prefixData = try readResponsePrefixData(
            at: downloadedFileURL
        )
        let ext = fileExtension(
            for: coverURL,
            response: response,
            prefixData: prefixData
        )
        let relativePath = storage
            .makeCoverRelativePath(
                gid: payload.gallery.gid,
                token: payload.gallery.token,
                fileExtension: ext
            )
        let fileURL = folderURL
            .appendingPathComponent(relativePath)
        try moveDownloadedFile(
            from: downloadedFileURL,
            to: fileURL
        )
        return relativePath
    }

    public func cleanupCachedRemoteAssetsAfterSuccessfulDownload(
        payload: DownloadRequestPayload,
        pages: [PageResult],
        existingDownload: DownloadedGallery
    ) async {
        let previewURLs = Array(payload.previewURLs.values)
            .flatMap({ $0.previewCacheCleanupURLs() })
        let pageURLs = pages.compactMap(\.imageURL)
        let coverURLs = [
            payload.galleryDetail.coverURL,
            payload.gallery.coverURL,
            existingDownload.onlineCoverURL
        ]
        .compactMap(\.self)

        let urls = Array(Set(previewURLs + pageURLs + coverURLs))
            .map(Optional.some)
        await removeCachedImages(for: urls)
    }

    public func resolveSource(
        payload: DownloadRequestPayload,
        options: DownloadRequestOptions,
        requiredPageIndices: [Int]
    ) async throws -> ResolvedSource {
        // The only producer of a payload that reaches here, `fetchLatestPayload`, already guards this
        // optional with the same error, so restating the contract where it is consumed states it
        // locally instead of trapping on it. The sibling `resolvedImageSource`'s `?? payload.host.url`
        // fallback is deliberately not copied: retargeting a thumbnail request at the host root is a
        // behavior change, and this guard is behavior-identical.
        guard let galleryURL = payload.gallery.galleryURL else { throw AppError.notFound }
        let requiredPageNumbers = Array(
            Set(requiredPageIndices.map {
                payload.previewConfig.pageNumber(index: $0)
            })
        )
        .sorted()
        var thumbnailURLs = [Int: URL]()
        for pageNumber in requiredPageNumbers {
            let pageURLs = try await ThumbnailURLsRequest(
                galleryURL: galleryURL,
                pageNum: pageNumber,
                urlSession: urlSession,
                allowsCellular: options.allowCellular
            )
            .response()
            thumbnailURLs
                .merge(pageURLs, uniquingKeysWith: { _, new in new })
        }
        guard let firstURL = requiredPageIndices.lazy
                .compactMap({ thumbnailURLs[$0] }).first
                ?? thumbnailURLs.values.first
        else {
            throw AppError.notFound
        }
        if GalleryURLParser.isMPVURL(firstURL) {
            let (mpvKey, imageKeys) = try await MPVKeysRequest(
                mpvURL: firstURL,
                urlSession: urlSession,
                allowsCellular: options.allowCellular
            )
            .response()
            return .mpv(key: mpvKey, imageKeys: imageKeys)
        } else {
            return .normal(thumbnailURLs)
        }
    }

    /// Runs one movement of the session accounting basis and gives back whatever counted portion of
    /// it the numerator was holding.
    ///
    /// **D-G7-01: every deliberate downward movement of the session accounting basis withdraws its
    /// counted portion from the monotonic floor, measured on the credited-pages definition around
    /// the movement — never on a named mechanism.**
    ///
    /// It closes G-15-7, and the measurement is the whole of the fix. D-G6-01 attached the
    /// withdrawal to the blanking loop in `reconcileWorkingManifestAgainstPageFiles` and wrote down
    /// that the blanking was the basis's sole deliberate downward mover. Source held at least four,
    /// three of them inside the very function that withdrawal ran in: `setupWorkingFolder`'s folder
    /// deletion on `.redownload` / `.update`, `ensureWorkingManifest`'s fresh all-empty manifest
    /// and re-index, the blanking itself, and `writeInitialManifest`'s fresh branch on the enqueue
    /// route. A `.redownload` of a counted record therefore dropped it from C of N to 0 of N and
    /// withdrew nothing, so the floor kept holding C while C pages of real work downloaded
    /// invisibly. Enumerating movers is what failed, four rounds running, so nothing here names
    /// one: the bracket reads the credited count before and after and withdraws the difference,
    /// which makes "whoever lowers the counted basis withdraws" true by construction for movers
    /// nobody has enumerated yet.
    ///
    /// Both readings are of `sessionCreditedPages(gid:)` — the very definition the numerator is
    /// summed from — rather than of the raw index record. That closes the gate the record-delta
    /// form needed and could only approximate: a record movement withdraws only in the regimes
    /// where the record is what the numerator reads (an uncounted record credits zero before and
    /// after, so its movement withdraws zero with no trust predicate), and a movement of the
    /// MEASUREMENT itself — a successor run announcing over a superseded predecessor's basis —
    /// withdraws exactly the credited gap, which no record reading could see at all. It also still
    /// subsumes WR-05: the working manifest and the index record need not agree, because the
    /// amount withdrawn is measured on exactly what the numerator was counting.
    ///
    /// Deletions never withdraw. A gallery whose basis AND record are both gone after the movement
    /// is a DEPARTURE, which `reconcileRetiredSessionPages` already values on the next push;
    /// withdrawing on top of that would count the same correction twice. So a vanished reading is
    /// read as the before-count rather than as zero, leaving a delta of zero. Neither call site
    /// deletes — the exclusion is stated here because it is the invariant every other writer is
    /// dispositioned against.
    ///
    /// The delta is clamped at zero so an upward movement withdraws nothing, while the floor
    /// subtraction itself is unclamped on purpose. Inside `ensureContinuedSession`'s client-start
    /// main-actor hop the scalar has just been reset to zero, so a withdrawal landing there drives
    /// it negative — "zero minus corrections the seed has not yet absorbed" — which is exactly what
    /// that seed's additive merge folds into the pre-hop snapshot. Outside the hop a negative floor
    /// is inert, because the push's `max()` compares it against a `displayCompletedPageCount` that
    /// is never negative.
    ///
    /// The whole stretch is synchronous — this function does not suspend, and none of the bodies
    /// it wraps does — so no interleaved push can observe a lowered basis under an un-lowered
    /// floor or the reverse. Two withdrawals in one session compose in either order, because each
    /// computes its own local delta and subtracts it. **They compose as SIBLINGS only: never nest
    /// one bracket inside another.** The inner movement's delta would be measured twice — once by
    /// its own bracket and again inside the outer one's span — and withdrawn twice, which is why
    /// the preparation bracket and the announce bracket in
    /// `prepareWorkingSeedAnnouncingProgress` run one after the other rather than one inside the
    /// other.
    ///
    /// Module-internal rather than file-private because one call site lives in
    /// `DownloadClient+PublicAPI.swift`. One implementation is what stops the withdrawal rule from
    /// forking between the run route and the enqueue route.
    func withdrawingCountedBasisMovement<T>(
        gid: String,
        _ movement: () throws -> T
    ) rethrows -> T {
        let creditedBefore = sessionCreditedPages(gid: gid)
        let result = try movement()
        let creditedAfter = hasSessionCreditReading(gid: gid)
            ? sessionCreditedPages(gid: gid)
            : creditedBefore
        if continuedSessionID != nil {
            lastPushedCompletedPageCount -= max(creditedBefore - creditedAfter, 0)
        }
        return result
    }

    /// Prepares the working seed silently — private so no caller outside this file can prepare one
    /// without announcing it.
    ///
    /// The announcing wrapper below is the only public preparation, which is what turns a revert of
    /// `performDownload`'s call site back to the silent variant into a compile error rather than a
    /// suite-green regression: D-G5-01's whole liveness half rests on that one line, and both
    /// functions being public left it unguarded (the post-15-25 review's WR-02).
    ///
    /// The whole preparation runs inside one D-G7-01 bracket, keyed on the payload's gid. Every
    /// mover that converges here — the folder deletion, the fresh manifest, the blanking, and any
    /// sibling a later round adds — is enclosed by construction rather than instrumented one at a
    /// time.
    private func prepareWorkingSeed(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        folderURL: URL
    ) throws -> WorkingSeed {
        try withdrawingCountedBasisMovement(gid: payload.gallery.gid) {
            let shouldReuseFolder = shouldReuseWorkingFolder(
                payload: payload,
                folderURL: folderURL
            )
            let seedContext = RepairSeedContext(
                existingDownload: existingDownload,
                payload: payload
            )
            let carriedUnprobedPages = try setupWorkingFolder(
                folderURL: folderURL,
                shouldReuse: shouldReuseFolder,
                seedContext: seedContext
            )

            let manifest = try ensureWorkingManifest(
                payload: payload,
                folderURL: folderURL
            )
            let destinationScan = storage.pageFileScan(
                folderURL: folderURL,
                manifest: manifest
            )
            // The seed copy's non-answers, folded into the destination's own before the single
            // destructive consumer reads them (G-15-19). No new refusal mechanism: the existing
            // per-file line covers the carried population exactly as it covers the destination's.
            // `pages` and `scanSucceeded` pass through untouched — an uncopied page is re-fetched,
            // never reused, so the seed still reports only what this folder actually holds. The
            // union is synchronous and lands inside the enclosing D-G7-01 bracket, so it adds no
            // suspension and no window.
            let reconciliationScan = PageFileScan(
                pages: destinationScan.pages,
                scanSucceeded: destinationScan.scanSucceeded,
                unprobedPages: destinationScan.unprobedPages.union(carriedUnprobedPages)
            )
            let existingPages = destinationScan.pages
            let reconciledManifest = try reconcileWorkingManifestAgainstPageFiles(
                manifest: manifest,
                pageFileScan: reconciliationScan,
                folderURL: folderURL
            )
            let coverRelativePath = storage.existingCoverRelativePath(
                folderURL: folderURL,
                manifest: reconciledManifest
            )
            return .init(
                folderURL: folderURL,
                manifest: reconciledManifest,
                existingPages: existingPages,
                coverRelativePath: coverRelativePath,
                // The announcement's evidence, carried out of the one scan this preparation took:
                // the same classification the destructive consumer above just read, so the credit
                // rule and the blanking rule can never answer from different probes.
                unprobedPages: reconciliationScan.unprobedPages,
                scanSucceeded: destinationScan.scanSucceeded
            )
        }
    }

    /// Prepares the working seed and announces the run's own progress measurement — the
    /// `RunProgressBasis` the session numerator reads for this gallery from here to the run's
    /// exit — when this run really does have pages to fetch.
    ///
    /// Record honesty alone does not reach the card, and no pre-existing push is guaranteed to run
    /// while a repaired record reads incomplete. The tap-time convergence push takes its snapshot
    /// before the spawned run can prepare its seed (the core spawns the task and returns without
    /// suspending, and the reconcile's snapshot reads are same-actor), and the flush push runs only
    /// after `flushManifestPageProgress` has written the repaired pages — so whenever one flush
    /// batch carries every remaining missing page, which is always true for a single missing page,
    /// completeness is restored before that push's snapshot is taken. The incomplete window would
    /// then exist on disk and be observed by nobody, and the gallery would finish a terminal
    /// `0 / N` card: the maximally stalled reading D-11's expiration policy punishes by pausing
    /// every schedulable download (G-15-5). The announcement is what makes the run's progress
    /// independent of flush cadence and of record honesty alike — including the refusal family,
    /// whose record reads complete for the entire run (G-15-23) — because the measurement never
    /// consults the record at all.
    ///
    /// **The measurement is a fact about the RUN, so it is recorded in the run-scoped collection
    /// and nowhere else (G-15-26).** A session boundary does not touch it: a session already live
    /// credits it from this announcement's own push below, and every later session start credits
    /// it through the same basis-first definition, so the two orderings where the session
    /// lifecycle does not bracket the run — an `.unavailable` teardown while the queue keeps
    /// running, and a queue resumed at launch, where D-07 forbids a session at all — need no
    /// second route. The collection is retired at `processDownload`'s `defer`, so the measurement
    /// does not outlive the run either.
    ///
    /// **The gate is the work THIS RUN will actually do.** It is the run's own pending page
    /// list — the list `performDownload` feeds straight to the page loop — being non-empty.
    ///
    /// It used to be the working folder's shortfall against its manifest — the seed's existing-page
    /// count compared against the manifest's page count — justified here as equivalent to "this run
    /// has pages to fetch". **The two are not equivalent, and G-15-27 is the difference.** The pending
    /// list reads `payload.pageSelection` FIRST and drops every page outside it before it ever tests
    /// whether a file is there, so the folder's shortfall and the run's own work are different sets
    /// whenever a selection is live: the folder can be short on pages this run was never asked to
    /// fetch. `normalizeFetchedPayload` preserves a non-empty in-range selection for every mode but
    /// the update mode, and `performRetryPages` stores one alongside the repair mode, so the
    /// difference is real on exactly the route a user's page-level retry takes. Gating on the
    /// shortfall therefore admitted a selected-page retry whose selected pages are all present — a
    /// run that fetches nothing, whose record's full completed page count then entered the numerator
    /// and was retired into both sides of the fraction. That is the ceiling D-G4-01 closed, reopened
    /// through the gate that replaced it.
    ///
    /// Three conditions fold into that emptiness, and the shortfall accounted for only one and a
    /// half of them. The zero-page guard: the shortfall also refuses there, both quantities being
    /// zero for an empty manifest. The selection membership test: the shortfall never consulted
    /// `payload.pageSelection` at all. The per-page file existence test: the shortfall saw it only
    /// in aggregate — a count against a count cannot say WHICH pages are missing, so it could not
    /// intersect them with the selection even in principle.
    ///
    /// The narrowed gate still fires everywhere the old one legitimately did. `existingPages` is the
    /// destination scan's `pages` — the manifest-claimed page numbers whose file this folder yielded
    /// and probed usable — so the list is non-empty on every refusal over a complete-reading record,
    /// on the proceeding branch whenever a claimed page's file is gone and no selection excludes it,
    /// and for the fresh all-empty manifest an update, a redownload or an initial run arrives with.
    /// It is empty exactly where this run's pages are already present, which is the redo that will
    /// download nothing.
    ///
    /// Two consequences are deliberate rather than oversights, and they are the same rule twice. A
    /// record that reads incomplete while its folder holds every page it claims — an interruption
    /// between a page write and its manifest flush — does not announce, because that run fetches
    /// nothing; neither does a selected-page retry whose selected pages are all present. In both the
    /// record's own reading is what the basis counts, raw, for as long as it reads incomplete, and
    /// the hashes such a run re-records are for pages an earlier session downloaded. Under-reporting
    /// there is the direction D-G4-01 and the retirement ledger both choose on purpose;
    /// over-reporting is the defect.
    ///
    /// **The announcement is its own D-G7-01 bracket, a SIBLING of the preparation's, and the
    /// order is load-bearing.** `prepareWorkingSeed` opens and closes
    /// `withdrawingCountedBasisMovement` around its own record movements and has already returned
    /// by the time the announcement runs, so those movements are measured in the record regimes
    /// they occur in. The announcement then moves the counted basis itself — from the record's
    /// reading to the run's measurement — and its bracket withdraws whatever counted portion that
    /// handoff loses. For an honest record the handoff is level or upward, because the inherited
    /// set is valued by the same evidence the record just reconciled against; the one downward
    /// case is a COMPLETE-reading record forfeiting the owed claims its own route refuted. And
    /// when a superseded predecessor's basis still lingers — the overlapping-run disposition
    /// `retireRunProgressBasis` records — the replacement's credited gap is withdrawn exactly,
    /// which no record-delta reading could see at all. Nesting the announcement inside the
    /// preparation's bracket instead would measure the preparation's movements twice; the
    /// non-nesting rule lives on the bracket itself.
    ///
    /// Announced at the RUN's own preparation and nowhere earlier is what keeps the queued window
    /// at zero. Nothing here runs at queue time, so a complete gallery queued for an update still
    /// opens the card at zero and a redo that never ran still retires nothing.
    ///
    /// **The measurement carries the quantity, not merely the fact of membership (G-15-30).** The
    /// gate is the pending list being non-empty, and the same single evaluation that opens the
    /// gate supplies everything behind it: the outstanding pages every manifest page flush shrinks
    /// by what it actually wrote, and the inherited count summed from the very seed the page loop
    /// is handed. No second evaluation appears, and nothing is derived here that the page loop is
    /// not also given — which is the whole of T-15-47-03's mitigation: one evaluation per run
    /// means the progress announced and the work performed cannot come apart.
    ///
    /// The suspension this adds is named: the `updateProgress` main-actor hop to
    /// `ContinuedProcessingSession` inside `pushContinuedSessionProgress`. It is issued from the run
    /// body, which is already reentrant at its payload fetch, cover download and source resolution
    /// and holds no coordinator invariant across the call, and every guard-sensitive re-check lives
    /// inside that push. The pending-list evaluation and the recording are synchronous same-actor
    /// work taken before that hop, so no push can observe the announcement without the measurement
    /// it announces, and no page the loop is about to fetch can have been decided after it.
    /// `prepareWorkingSeed` itself therefore stays synchronous. The push's reconcile records the
    /// observation even when the client start is still in flight, because that reconcile
    /// deliberately runs ahead of the nil-client guard; `ensureContinuedSession`'s seed merges
    /// rather than overwrites, so the recording survives the start's main-actor hop.
    func prepareWorkingSeedAnnouncingProgress(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        folderURL: URL
    ) async throws -> PreparedWorkingRun {
        let workingSeed = try prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL
        )
        let pendingPages = pendingPageIndices(
            payload: payload,
            folderURL: folderURL,
            existingPageRelativePaths: workingSeed.existingPages
        )
        if !pendingPages.isEmpty {
            let outstandingPages = Set(pendingPages)
            withdrawingCountedBasisMovement(gid: payload.gallery.gid) {
                runProgressBases[payload.gallery.gid] = RunProgressBasis(
                    inheritedPages: inheritedPages(
                        workingSeed: workingSeed,
                        pendingPages: outstandingPages
                    ),
                    initialPendingPages: outstandingPages,
                    outstandingPages: outstandingPages
                )
            }
            if let continuedSessionID {
                await pushContinuedSessionProgress(sessionID: continuedSessionID)
            }
        }
        return PreparedWorkingRun(
            workingSeed: workingSeed,
            pendingPageIndices: pendingPages
        )
    }

    /// The pages a run inherits rather than performs — `RunProgressBasis.inheritedPages`'s one
    /// derivation, read from the very scan the preparation's destructive consumer read, so the
    /// credit rule and the blanking rule can never answer from different probes.
    ///
    /// Evidence, in order of authority. A successful listing is authoritative both ways: it yields
    /// the probed files, plus the claimed pages the per-file probe could not answer for — the same
    /// population the blanking loop refuses to blank, presumed done here for the same
    /// positive-signal reason it is preserved there. A failed listing is a non-answer, so the
    /// record's claims stand whole; only a POSITIVE absence — a successful listing that simply did
    /// not yield a claimed page's file — zeroes a claim. A COMPLETE-reading record then forfeits
    /// the claims the run was asked to fetch, because a repair or retry of a "finished" gallery is
    /// itself the route's assertion that those claimed pages are bad; an incomplete record's
    /// claims carry no such refutation — its to-do overlap comes only from the scan's own failure
    /// — so they stand, and the credited count's union is what keeps the overlap from ever
    /// counting twice.
    private func inheritedPages(
        workingSeed: WorkingSeed,
        pendingPages: Set<Int>
    ) -> Set<Int> {
        let manifest = workingSeed.manifest
        let claimedPages = Set(manifest.pages.filter({ $0.value.isEmpty == false }).keys)
        let presumedDonePages: Set<Int>
        if workingSeed.scanSucceeded {
            presumedDonePages = Set(workingSeed.existingPages.keys)
                .union(claimedPages.intersection(workingSeed.unprobedPages))
        } else {
            presumedDonePages = Set(workingSeed.existingPages.keys).union(claimedPages)
        }
        guard manifest.completedPageCount >= manifest.pageCount else { return presumedDonePages }
        return presumedDonePages.subtracting(pendingPages)
    }

    /// Blanks the recorded hash of every page the working manifest claims but whose file is not in
    /// the working folder, persisting and re-indexing the manifest only when something changed.
    ///
    /// **D-G5-01: a working manifest never claims a page whose file is not in the working folder.**
    ///
    /// It closes G-15-5. A `.repair` exists precisely because files are missing, yet nothing lowered
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
    /// manifest they did not write: `.repair`, the `.initial` reuse of a matching complete manifest,
    /// and the repair-seed materialization, which copies the manifest whole while copying the pages
    /// selectively — and therefore hands back the claimed pages its SOURCE-side probe could not
    /// answer for, which `prepareWorkingSeed` unions into the scan below so this reconciliation
    /// sees them as unprobed rather than absent (G-15-19). That route needs the carry because
    /// nothing here can derive it: the destination listing is entirely honest about a page the copy
    /// never landed, `scanSucceeded` is true and `unprobedPages` is empty, so a source-side
    /// non-answer and a source-side positive absence arrive indistinguishable. This paragraph used
    /// to classify that route as safe on the grounds that it copied every page whose source file
    /// had been sanitized — which is precisely where `.unprobeable` and `.rejected` collapse back
    /// together, one layer below the defence, and is the written premise the gap hid behind.
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
    /// No suspension is introduced: `pageFileScan` is the scan `prepareWorkingSeed` already took, so
    /// no second disk scan happens here, and `writeManifest` / `updateDownloadIndex` are same-actor
    /// synchronous calls.
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
    /// 2. **The per-file positive signal (G-15-13, fixed as D-G13-01; extended across the copy by
    ///    G-15-19).** `unprobedPages` carries TWO populations by the time it reaches here, and no
    ///    page in either is blanked: the pages whose file THIS folder's successful listing did
    ///    yield but whose probe could not classify, and the pages the repair-seed materialization
    ///    reported unanswerable in the SOURCE folder it copied from, unioned in by
    ///    `prepareWorkingSeed`. The second exists because this folder's listing cannot see it — a
    ///    page the copy never landed is honestly absent here — so the classification has to travel
    ///    with the copy rather than be re-derived. The trigger is narrow and real: the metadata
    ///    read itself throwing for many-but-not-all files — an I/O error, a permission change, a
    ///    volume going away mid-scan. It is not descriptor exhaustion and not a locked device, since
    ///    a metadata read needs no descriptor and still answers under data protection. Line 1 cannot
    ///    reach this population, because the listing succeeded, and line 3 cannot either, because it
    ///    disables itself as soon as one claimed page survives: a gallery with 100 claimed pages and
    ///    99 failed probes passed `99 < 100` and lost 99 recorded hashes irreversibly.
    /// 3. **The all-or-nothing guard, as the residual second line.** A refusal is still taken when a
    ///    nominally successful listing that answered for every file it did probe would nonetheless
    ///    blank every claimed page. The manifest was just read out of this very folder, so that is
    ///    more likely a shape neither signal above caught than proof that every page vanished at
    ///    once. Its reach is narrow ON PURPOSE, and narrower since line 2 grew: one claimed page
    ///    held as unprobed already puts the gallery outside this guard, because the guard exists to
    ///    catch a shape the per-page signals explained NOTHING about, and a page they did explain is
    ///    evidence they were answering. The mixed shape is line 2's, one page at a time, not this
    ///    line's wholesale.
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
    /// that finds K of them blanks exactly those K.
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
    private func reconcileWorkingManifestAgainstPageFiles(
        manifest: DownloadManifest,
        pageFileScan: PageFileScan,
        folderURL: URL
    ) throws -> DownloadManifest {
        guard pageFileScan.scanSucceeded else { return manifest }

        var pages = manifest.pages
        var blankedPageCount = 0
        for page in manifest.pages.keys.sorted() {
            guard pages[page]?.isEmpty == false,
                  pageFileScan.pages[page] == nil,
                  !pageFileScan.unprobedPages.contains(page)
            else { continue }
            pages[page] = ""
            blankedPageCount += 1
        }
        guard blankedPageCount > 0 else { return manifest }
        // The loop skips every claimed page the scan ACCOUNTED for — one the listing yielded, or one
        // line 2 holds as unprobed — so this equality is reachable only where it accounted for none
        // of them: the residual fires on the shape where a nominally successful listing explains no
        // claimed page at all. On a MIXED shape it deliberately does not fire, and that is not a
        // gap: line 2 has already refused the unprobed portion one page at a time, and the rest is
        // the positive absence this reconciliation exists to record. Widening the comparison to the
        // blankable population would refuse those genuine absences because some OTHER page went
        // unanswered, which is the opposite of the per-page rule line 2 states.
        guard blankedPageCount < manifest.completedPageCount else { return manifest }

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

    // The disk index drops manifest-less folders and progress flushes skip
    // them, so the working folder must carry a manifest before any page
    // lands; otherwise an interruption strands the folder invisibly.
    private func ensureWorkingManifest(
        payload: DownloadRequestPayload,
        folderURL: URL
    ) throws -> DownloadManifest {
        if let manifest = validatedManifest(
            at: folderURL,
            gid: payload.gallery.gid,
            pageCount: payload.galleryDetail.pageCount
        ) {
            return manifest
        }
        let manifest = makeInitialManifest(payload: payload)
        try storage.writeManifest(manifest, folderURL: folderURL)
        updateDownloadIndex(folderURL: folderURL, manifest: manifest)
        return manifest
    }

    private func shouldReuseWorkingFolder(
        payload: DownloadRequestPayload,
        folderURL: URL
    ) -> Bool {
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return false
        }
        switch payload.mode {
        case .initial:
            // Manifest decoding is a reuse probe; an unreadable manifest keeps the
            // existing folder so ensureWorkingManifest can replace it safely.
            guard let manifest = storage.probeManifest(folderURL: folderURL) else {
                return true
            }
            return manifest.gid == payload.gallery.gid
                && manifest.token == payload.gallery.token
                && manifest.pageCount == payload.galleryDetail.pageCount
        case .repair:
            return true
        case .redownload, .update:
            return false
        }
    }

    private struct RepairSeedContext {
        let existingDownload: DownloadedGallery
        let payload: DownloadRequestPayload
    }

    /// Prepares the working folder, and hands back the claimed pages whose SOURCE-side
    /// classification was a non-answer (G-15-19).
    ///
    /// Empty on every path but the materialization, by construction rather than by omission: a
    /// reused folder, an already-existing one and a freshly created empty one are all judged by a
    /// scan of the very folder `reconcileWorkingManifestAgainstPageFiles` will scan, so no
    /// classification crossed a folder boundary and there is nothing to carry.
    private func setupWorkingFolder(
        folderURL: URL,
        shouldReuse: Bool,
        seedContext: RepairSeedContext
    ) throws -> Set<Int> {
        if !shouldReuse {
            // Removing a stale working folder is best-effort preparation; the
            // existence check below preserves the established reuse fallback.
            do {
                try fileManager.operate {
                    try $0.removeItem(at: folderURL)
                }
            } catch {
                logger.error("Stale working folder removal failed: \(error, privacy: .private)")
            }
        }
        if !fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) {
            if let seed = repairSeed(
                for: seedContext.existingDownload,
                payload: seedContext.payload
            ) {
                return try storage.materializeRepairSeed(
                    from: seed.folderURL,
                    manifest: seed.manifest,
                    to: folderURL
                )
            }
            try createDirectory(at: folderURL)
        }
        return []
    }

    /// - Parameter page: the 1-based page number, which is also the key space of the
    ///   `thumbnailURLs` / `imageKeys` maps and of the requests' `index:` labels.
    public func resolvedImageSource(
        index page: Int,
        payload: DownloadRequestPayload,
        options: DownloadRequestOptions,
        source: ResolvedSource,
        failover: ResolvedImageSource? = nil
    ) async throws -> ResolvedImageSource {
        switch source {
        case .normal(let thumbnailURLs):
            guard let thumbnailURL = thumbnailURLs[page] else {
                throw AppError.notFound
            }
            if let failover {
                let (imageURLs, _) = try await GalleryNormalImageURLRefetchRequest(
                    host: payload.host,
                    index: page,
                    pageNum: 0,
                    galleryURL: payload.gallery.galleryURL ?? payload.host.url,
                    thumbnailURL: thumbnailURL,
                    storedImageURL: failover.imageURL,
                    urlSession: urlSession,
                    allowsCellular: options.allowCellular
                )
                .response()
                guard let imageURL = imageURLs[page] else {
                    throw AppError.notFound
                }
                return .init(imageURL: imageURL, mpvSkipServerIdentifier: nil)
            }
            let (imageURLs, _) = try await GalleryNormalImageURLsRequest(
                thumbnailURLs: [page: thumbnailURL],
                urlSession: urlSession,
                allowsCellular: options.allowCellular
            )
            .response()
            guard let imageURL = imageURLs[page] else {
                throw AppError.notFound
            }
            return .init(imageURL: imageURL, mpvSkipServerIdentifier: nil)

        case .mpv(let mpvKey, let imageKeys):
            guard let gid = Int(payload.gallery.gid) else {
                throw AppError.notFound
            }
            guard let imageKey = imageKeys[page] else {
                throw AppError.notFound
            }
            let response = try await GalleryMPVImageURLRequest(
                host: payload.host,
                gid: gid,
                index: page,
                mpvKey: mpvKey,
                mpvImageKey: imageKey,
                skipServerIdentifier: failover?.mpvSkipServerIdentifier,
                urlSession: urlSession,
                allowsCellular: options.allowCellular,
                requiresSkipServerIdentifier: failover != nil
            )
            .response()
            return .init(
                imageURL: response.imageURL,
                mpvSkipServerIdentifier: response.skipServerIdentifier
            )
        }
    }

    public func repairSeed(
        for download: DownloadedGallery,
        payload: DownloadRequestPayload
    ) -> RepairSeed? {
        let folderURL = download.folderURL
        guard payload.mode == .repair,
              fileManager.operate({
                  $0.fileExists(atPath: folderURL.path)
              }),
              // Repair seeding is optional; an unreadable manifest leaves the current
              // working folder for ensureWorkingManifest to refresh instead.
              let manifest = storage.probeManifest(folderURL: folderURL),
              manifest.gid == download.gid,
              manifest.pageCount ==
                payload.galleryDetail.pageCount
        else {
            return nil
        }
        return .init(folderURL: folderURL, manifest: manifest)
    }

    public func pendingPageIndices(
        payload: DownloadRequestPayload,
        folderURL: URL,
        existingPageRelativePaths: [Int: String]
    ) -> [Int] {
        // G-15-14. The invariant is the whole class, not this site: no range in this module is
        // built from an unguarded page count. `makeInitialManifest` and `reusableExistingManifest`
        // already branch on the same value, so zero is a modeled input here too — and `1...0` is an
        // invalid ClosedRange that traps the process rather than failing the download. The guard
        // sits ahead of the selection branch because a selected page cannot rescue a range that
        // never formed.
        guard payload.galleryDetail.pageCount > 0 else { return [] }
        let selectedIndices = payload.pageSelection
        return (1...payload.galleryDetail.pageCount).filter { page in
            if let selectedIndices,
               !selectedIndices.contains(page) {
                return false
            }
            guard let relativePath =
                    existingPageRelativePaths[page] else {
                return true
            }
            let fileURL = folderURL
                .appendingPathComponent(relativePath)
            return !fileManager.operate {
                $0.fileExists(atPath: fileURL.path)
            }
        }
    }
}
