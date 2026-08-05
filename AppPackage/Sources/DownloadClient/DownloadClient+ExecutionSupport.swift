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
    /// counted portion from the monotonic floor, keyed on the pre/post `downloadIndex[gid]` delta —
    /// never on a named mechanism.**
    ///
    /// It closes G-15-7, and the key is the whole of the fix. D-G6-01 attached the withdrawal to the
    /// blanking loop in `reconcileWorkingManifestAgainstPageFiles` and wrote down that the blanking
    /// was the basis's sole deliberate downward mover. Source held at least four, three of them
    /// inside the very function that withdrawal ran in: `setupWorkingFolder`'s folder deletion on
    /// `.redownload` / `.update`, `ensureWorkingManifest`'s fresh all-empty manifest and re-index,
    /// the blanking itself, and `writeInitialManifest`'s fresh branch on the enqueue route. A
    /// `.redownload` of a counted record therefore dropped it from C of N to 0 of N and withdrew
    /// nothing — the blanking loop finds nothing to blank in an all-empty manifest and returns
    /// before the withdrawal — so the floor kept holding C while C pages of real work downloaded
    /// invisibly. Enumerating movers is what failed, four rounds running, so nothing here names one:
    /// the bracket reads the record before and after and withdraws the difference, which makes
    /// "whoever lowers the basis withdraws" true by construction for movers nobody has enumerated
    /// yet.
    ///
    /// Both readings are of the INDEX record, the value the numerator is actually summed from
    /// (`schedulableSnapshot` → `schedulableDownloads()` → `indexedDownloads(gids:)`). That subsumes
    /// WR-05: the working manifest and the index record no longer have to agree — the
    /// re-slot-after-title-change path included — because the amount withdrawn is measured on
    /// exactly what the basis was counting.
    ///
    /// The counted-basis test is evaluated on the BEFORE reading, and that is D-G4-01's ceiling
    /// guarantee rather than a refinement of it. Only a record the basis was actually counting
    /// withdraws: one that read incomplete before the movement, or whose gid this session has
    /// already observed incomplete. An untrusted complete-reading record contributed zero to the
    /// numerator and to the floor, so it withdraws zero — withdrawing there would push the floor
    /// below other galleries' legitimately pushed work and weaken the mask for all of them.
    ///
    /// Deletions never withdraw. A record that vanished between the two readings is a DEPARTURE,
    /// which `reconcileRetiredSessionPages` already values from the honest record on the next push;
    /// withdrawing on top of that would count the same correction twice. So an absent after-reading
    /// is read as the before-count rather than as zero, leaving a delta of zero. Neither call site
    /// deletes a record at all — the exclusion is stated here because it is the invariant every
    /// other `downloadIndex[gid]` writer is dispositioned against.
    ///
    /// The delta is clamped at zero so an upward movement withdraws nothing, while the floor
    /// subtraction itself is unclamped on purpose. Inside `ensureContinuedSession`'s client-start
    /// main-actor hop the scalar has just been reset to zero, so a withdrawal landing there drives
    /// it negative — "zero minus corrections the seed has not yet absorbed" — which is exactly what
    /// that seed's additive merge folds into the pre-hop snapshot. Outside the hop a negative floor
    /// is inert, because the push's `max()` compares it against a `displayCompletedPageCount` that
    /// is never negative.
    ///
    /// The whole stretch is synchronous — this function does not suspend, and neither of the two
    /// bodies it wraps does — so no interleaved push can observe a lowered basis under an un-lowered
    /// floor or the reverse. Two withdrawals in one session compose in either order, because each
    /// computes its own local delta and subtracts it.
    ///
    /// Module-internal rather than file-private because the second call site lives in
    /// `DownloadClient+PublicAPI.swift`. One implementation is what stops the withdrawal rule from
    /// forking between the run route and the enqueue route.
    func withdrawingCountedBasisMovement<T>(
        gid: String,
        _ movement: () throws -> T
    ) rethrows -> T {
        let beforeManifest = downloadIndex[gid]?.manifest
        let beforeCount = beforeManifest?.completedPageCount ?? 0
        let wasCountedBasis = beforeCount < (beforeManifest?.pageCount ?? 0)
            || observedIncompleteSessionGIDs.contains(gid)
        let result = try movement()
        let afterCount = downloadIndex[gid]?.manifest.completedPageCount ?? beforeCount
        if continuedSessionID != nil, wasCountedBasis {
            lastPushedCompletedPageCount -= max(beforeCount - afterCount, 0)
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
                coverRelativePath: coverRelativePath
            )
        }
    }

    /// Prepares the working seed and then tells the live session what basis the run starts from.
    ///
    /// Record honesty alone does not reach the card. Session trust is admitted in exactly one
    /// place — the `formUnion` inside a push's `reconcileRetiredSessionPages` — and no pre-existing
    /// push is guaranteed to run while a repaired record reads incomplete. The tap-time convergence
    /// push takes its snapshot before the spawned run can prepare its seed (the core spawns the task
    /// and returns without suspending, and the reconcile's snapshot reads are same-actor), and the
    /// flush push runs only after `flushManifestPageProgress` has written the repaired pages — so
    /// whenever one flush batch carries every remaining missing page, which is always true for a
    /// single missing page, completeness is restored before that push's snapshot is taken. The
    /// incomplete window would then exist on disk and be observed by nobody, and the gallery would
    /// finish a terminal `0 / N` card: the maximally stalled reading D-11's expiration policy
    /// punishes by pausing every schedulable download (G-15-5).
    ///
    /// So the run announces its own post-preparation basis before any page work. The push's
    /// reconcile records the observation even when the client start is still in flight, because that
    /// reconcile deliberately runs ahead of the nil-client guard; `ensureContinuedSession`'s seed
    /// merges rather than overwrites, so the recording survives the start's main-actor hop.
    ///
    /// The suspension this adds is named: the `updateProgress` main-actor hop to
    /// `ContinuedProcessingSession` inside `pushContinuedSessionProgress`. It is issued from the run
    /// body, which is already reentrant at its payload fetch, cover download and source resolution
    /// and holds no coordinator invariant across the call, and every guard-sensitive re-check lives
    /// inside that push. `prepareWorkingSeed` itself therefore stays synchronous.
    func prepareWorkingSeedAnnouncingProgress(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        folderURL: URL
    ) async throws -> WorkingSeed {
        let workingSeed = try prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL
        )
        if let continuedSessionID, !workingSeed.manifest.isComplete {
            await pushContinuedSessionProgress(sessionID: continuedSessionID)
        }
        return workingSeed
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
    /// makes the run re-fetch every page and the record's honesty catches up at flush time, and
    /// `resumeMode`'s `storage.validate` branch remains the route that resolves `.repair` for such a
    /// record. An unprobed page pays the same way, one page at a time. That is accepted against the
    /// alternative — letting a transient failure destroy recorded hashes. Genuine absence is
    /// untouched and stays fully blankable: a claimed page whose file a SUCCESSFUL listing simply
    /// did not yield is a positive absence, and a scan that finds K of them blanks exactly those K.
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
