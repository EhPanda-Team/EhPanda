import AppModels
import AppTools
import CryptoKit
import Foundation
import OSLogExt
import Resources

private let logger = Logger(category: .init(describing: DownloadStore.self))

public enum DownloadValidationState: Equatable, Sendable {
    case valid
    case missingFiles(LocalizedStringResource)
}

public struct DownloadFolderRecord: Equatable, Sendable {
    public let relativePath: String
    public let folderURL: URL
    public let manifest: DownloadManifest
    public let localCoverURL: URL?
    public let localPageURLs: [Int: URL]
    public let modificationDate: Date?
    public let parentFolderName: String
    public init(
        relativePath: String,
        folderURL: URL,
        manifest: DownloadManifest,
        localCoverURL: URL? = nil,
        localPageURLs: [Int: URL],
        modificationDate: Date? = nil,
        parentFolderName: String
    ) {
        self.relativePath = relativePath
        self.folderURL = folderURL
        self.manifest = manifest
        self.localCoverURL = localCoverURL
        self.localPageURLs = localPageURLs
        self.modificationDate = modificationDate
        self.parentFolderName = parentFolderName
    }
}

public struct DownloadScanResult: Equatable, Sendable {
    public let records: [DownloadFolderRecord]
    public let userFolders: [String]
    public init(
        records: [DownloadFolderRecord],
        userFolders: [String]
    ) {
        self.records = records
        self.userFolders = userFolders
    }
}

/// Pure filesystem / manifest / hash I/O for downloads. The filesystem is the source of
/// truth (per-folder `manifest.json` + page files), so this type holds no cross-call
/// in-memory state and is race-free by construction: every method reads or writes disk and
/// returns. It is the I/O half of the download subsystem split; the `DownloadCoordinator`
/// actor owns the mutable read model and scheduling on top of it.
public struct DownloadStore: Sendable {
    private static let maxFolderComponentByteCount = 255

    public let rootURL: URL
    public let fileManager: DownloadFileManager

    public init(
        rootURL: URL = FileUtil.downloadsDirectoryURL,
        fileManager: sending FileManager = FileManager()
    ) {
        self.rootURL = rootURL
        self.fileManager = DownloadFileManager(fileManager)
    }

    public func ensureRootDirectory() throws {
        try fileManager.operate {
            try $0.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableRootURL = rootURL
        do {
            try mutableRootURL.setResourceValues(resourceValues)
        } catch {
            // Backup exclusion is advisory metadata; directory creation remains successful if the OS rejects it.
            logger.error("Download root backup exclusion failed: \(error, privacy: .private)")
        }
    }

    public func folderURL(relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath, isDirectory: true)
    }

    // `userFolderURL(name:)` used to live here, appending a caller-supplied user-folder NAME to
    // the root with no confinement guarantee, and it is deliberately gone (CR-02). Four production
    // sites fed its result into a create, a move or a remove, and one of them — `deleteFolder` —
    // reached a gallery folder below a user folder from a name like `"MyFolder/[123_abc] Title"`.
    // Every user-folder mutation now goes through `DownloadStore+Operations`' confined boundary,
    // and the one surviving read-model construction builds its URL from the same relative path it
    // stores, through `folderURL(relativePath:)` above.
    //
    // What the deletion buys is precise, and it is worth stating precisely rather than as
    // "unwritable" (WR-01). `folderURL(relativePath:)` is still public and still joins an arbitrary
    // string to the root — it has to, because the record paths are strings. No SINGLE call turns a
    // caller's name into a mutation any more: this one only resolves, the removal primitive takes a
    // URL, and the string-taking spelling that used to close that gap in one call is deleted. What
    // remains is a two-function composition that both docs refuse — a convention review enforces,
    // not a property the type system does.

    public func rootRelativePath(forFolderURL url: URL) -> String? {
        let rootPath = rootURL.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return nil }
        return String(path.dropFirst(rootPath.count))
    }

    public func parentFolderName(forFolderURL url: URL) -> String? {
        guard let relativePath = rootRelativePath(forFolderURL: url) else { return nil }
        let components = relativePath.split(separator: "/")
        guard components.count >= 2, let parentComponent = components.first else { return nil }
        return String(parentComponent)
    }

    public func validatedChildURL(
        root: URL, relativePath: String
    ) -> URL? {
        let resolved = root
            .appendingPathComponent(relativePath)
            .standardizedFileURL
        guard resolved.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            return nil
        }
        return resolved
    }

    public func manifestURL(relativePath: String) -> URL {
        folderURL(relativePath: relativePath)
            .appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    public func queueURL() -> URL {
        rootURL.appendingPathComponent(".queue.json")
    }

    public func backgroundTaskRegistryURL() -> URL {
        rootURL.appendingPathComponent(".background-tasks.json")
    }

    public func backgroundTransferHoldingDirectoryURL() -> URL {
        rootURL.appendingPathComponent(".background-downloads", isDirectory: true)
    }

    /// Removes the background-transfer holding directory and everything in it.
    ///
    /// The holding dir is hidden, so the launch scan (`.skipsHiddenFiles`) can't see
    /// it, and a process that dies between staging and consuming a file leaves it
    /// stranded. Call this only while no background session exists (e.g. at `.live`
    /// construction) so anything present is definitionally an orphan; the downloader
    /// recreates the directory on the next stage.
    public func purgeBackgroundTransferHoldingDirectory() {
        let holdingDirectory = backgroundTransferHoldingDirectoryURL()
        do {
            try fileManager.operate {
                guard $0.fileExists(atPath: holdingDirectory.path) else { return }
                try $0.removeItem(at: holdingDirectory)
            }
        } catch {
            // Launch cleanup is best-effort; a later staging pass recreates or reuses the directory safely.
            logger.error("Background holding directory purge failed: \(error, privacy: .private)")
        }
    }

    /// The page files present for `manifest`, as a probe: an unlistable folder answers `[:]`.
    ///
    /// Preserved verbatim for its non-destructive callers, which re-fetch or re-derive on an empty
    /// answer and are unaffected by why it is empty. A caller that acts irreversibly on the answer —
    /// or whose answer FEEDS something that does, even one step later and in a DIFFERENT folder —
    /// must use `pageFileScan(folderURL:manifest:)` instead and carry both its `scanSucceeded` flag
    /// and its `unprobedPages` set.
    ///
    /// The second half of that rule is not hypothetical (G-15-19): the retired repair-seed
    /// materialization called this function, and its selection decided which pages a different
    /// folder would afterwards be found to hold — so a page this collapse dropped for want of an
    /// answer arrived there as a positive absence and had its recorded hash destroyed. That caller
    /// has since been retired outright, so no answer of this function's crosses a folder boundary
    /// today; the rule stands for the next one that would.
    ///
    /// `discardingRejected` decides only whether the probe's housekeeping DELETION may fire while
    /// this answer is being formed — see `probeAssetFile(at:discardingRejected:)`. The
    /// classification is identical either way, which is why the default is the non-mutating value
    /// (CR-03): forming an answer is a read, and a caller that means to delete has to say so.
    public func existingPageRelativePaths(
        folderURL: URL,
        manifest: DownloadManifest,
        discardingRejected: Bool = false
    ) -> [Int: String] {
        pageFileScan(
            folderURL: folderURL,
            manifest: manifest,
            discardingRejected: discardingRejected
        ).pages
    }

    /// The same scan, with the enumeration's success surfaced alongside its result (G-15-9), the
    /// pages whose listed file the probe could not classify surfaced beside both (G-15-13), and the
    /// pages whose listed file the probe positively refused and left on disk surfaced beside all
    /// three (CR-01).
    ///
    /// A failed enumeration answers nothing at all, so it reports no unprobed and no rejected pages
    /// either: there is no listing to have listed them, and the directory-level refusal already
    /// covers that whole answer.
    public func pageFileScan(
        folderURL: URL,
        manifest: DownloadManifest,
        discardingRejected: Bool = false
    ) -> PageFileScan {
        let pageNumbers = Set(manifest.pages.keys)
        guard !pageNumbers.isEmpty else {
            return .init(pages: [:], scanSucceeded: true, unprobedPages: [])
        }

        guard let fileURLs = existingAssetFileURLs(folderURL: folderURL) else {
            return .init(pages: [:], scanSucceeded: false, unprobedPages: [])
        }
        let prefix = identityPrefix(gid: manifest.gid, token: manifest.token)

        var pages = [Int: String]()
        var unprobedPages = Set<Int>()
        var rejectedPageRelativePaths = [Int: String]()
        for fileURL in fileURLs {
            let fileName = fileURL.lastPathComponent
            guard fileName.hasPrefix(prefix) else { continue }
            let suffix = fileName.dropFirst(prefix.count)
            guard let dotIndex = suffix.firstIndex(of: ".") else { continue }
            let pageText = String(suffix[..<dotIndex])
            guard let page = Int(pageText),
                  String(page) == pageText,
                  pageNumbers.contains(page),
                  pages[page] == nil
            else { continue }

            switch probeAssetFile(at: fileURL, discardingRejected: discardingRejected) {
            case .usable:
                pages[page] = fileName
                // A usable file settles the page outright, even if an earlier candidate for the
                // same page was the one that could not be probed or was refused.
                unprobedPages.remove(page)
                rejectedPageRelativePaths[page] = nil
            case .rejected(let fileRemains):
                // Only a file that is STILL THERE has an identity worth carrying: a rejection whose
                // housekeeping deletion succeeded leaves a page that is positively absent, which is
                // what every pre-existing caller already reads it as. The first surviving candidate
                // wins, matching `pages`' own first-writer rule over the sorted listing.
                guard fileRemains, rejectedPageRelativePaths[page] == nil else { continue }
                rejectedPageRelativePaths[page] = fileName
            case .unprobeable:
                unprobedPages.insert(page)
            }
        }
        return .init(
            pages: pages,
            scanSucceeded: true,
            unprobedPages: unprobedPages,
            rejectedPageRelativePaths: rejectedPageRelativePaths
        )
    }

    public func imageURLs(
        folderURL: URL,
        manifest: DownloadManifest,
        discardingRejected: Bool = false
    ) -> [Int: URL] {
        existingPageRelativePaths(
            folderURL: folderURL,
            manifest: manifest,
            discardingRejected: discardingRejected
        )
        .reduce(into: [Int: URL]()) { result, entry in
            result[entry.key] = folderURL.appendingPathComponent(entry.value)
        }
    }

    public func localCoverURL(
        folderURL: URL,
        manifest: DownloadManifest,
        discardingRejected: Bool = false
    ) -> URL? {
        existingCoverFileURL(
            folderURL: folderURL,
            gid: manifest.gid,
            token: manifest.token,
            discardingRejected: discardingRejected
        )
    }

    /// The cover half of the same rule the page scan carries: resolving a rendering resource is a
    /// read, so it takes the non-mutating default like every other read. A cover is not a page and
    /// carries no recorded hash, but the read-must-not-mutate property is about the READ rather than
    /// about what it happens to be looking at — which is why a sweep that resolved a cover purely to
    /// delete a refused one was the same defect as its page half (CR-03).
    public func existingCoverRelativePath(
        folderURL: URL,
        manifest: DownloadManifest,
        discardingRejected: Bool = false
    ) -> String? {
        localCoverURL(
            folderURL: folderURL,
            manifest: manifest,
            discardingRejected: discardingRejected
        )?
            .lastPathComponent
    }

    /// Builds the on-disk folder name as `[gid_token] Title`. The readable title is a
    /// deliberate Files-app-integration bet (the app sets `UIFileSharingEnabled` /
    /// `LSSupportsOpeningDocumentsInPlace`), and the `[gid_token]` prefix keeps identity
    /// resolvable from the name alone. The title is truncated to keep the whole component
    /// within the filesystem's per-name byte limit.
    public func makeFolderRelativePath(gid: String, token: String, title: String) -> String {
        let prefix = galleryFolderNamePrefix(gid: gid, token: token)
        let titleByteCount = max(Self.maxFolderComponentByteCount - prefix.utf8.count, 0)
        return "\(prefix)\(normalizedFolderTitle(title, maximumUTF8ByteCount: titleByteCount))"
    }

    public func galleryFolderNamePrefix(gid: String, token: String) -> String {
        "[\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))] "
    }

    /// Finds every folder belonging to a gallery, because folder membership follows
    /// filesystem location, not a stored list. A folder the user moved in the Files app is
    /// still found. The `[gid_token]` name prefix is the fast path; any folder without it is
    /// confirmed by reading its manifest's `gid` / `token`, so a renamed folder still matches.
    public func galleryFolderURLs(gid: String, token: String) -> [URL] {
        guard fileManager.operate({ $0.fileExists(atPath: rootURL.path) }) else {
            return []
        }
        let prefix = galleryFolderNamePrefix(gid: gid, token: token)
        return directoryURLs(in: rootURL)
            .flatMap({ directoryURLs(in: $0) })
            .filter { folderURL in
                guard !folderURL.lastPathComponent.hasPrefix(prefix) else {
                    return true
                }
                // A manifest read is an identity probe here; unreadable unrelated folders are not gallery matches.
                guard let manifest = probeManifest(folderURL: folderURL) else {
                    return false
                }
                return manifest.gid == gid && manifest.token == token
            }
    }

    public func galleryFolderRecords(gid: String, token: String) -> [DownloadFolderRecord] {
        galleryFolderURLs(gid: gid, token: token).compactMap { folderURL in
            // Filesystem discovery intentionally skips unreadable or mismatched gallery folders.
            guard let manifest = probeManifest(folderURL: folderURL),
                  manifest.gid == gid,
                  manifest.token == token
            else {
                return nil
            }
            return galleryFolderRecord(
                folderURL: folderURL,
                manifest: manifest,
                parentFolderName: parentFolderName(forFolderURL: folderURL) ?? ""
            )
        }
    }

    public static func isGalleryFolderLikeName(_ name: String) -> Bool {
        name.range(of: #"^\[[^\]]*_[^\]]*\] "#, options: .regularExpression) != nil
    }

    public static func normalizedUserFolderName(_ name: String) -> String? {
        guard let limitedName = normalizedFolderName(
            name,
            trimsLeadingDots: true,
            fallback: nil,
            maximumUTF8ByteCount: maxFolderComponentByteCount
        ) else {
            return nil
        }
        guard !limitedName.isEmpty, !isGalleryFolderLikeName(limitedName) else {
            return nil
        }
        return limitedName
    }

    public func normalizedUserFolderName(_ name: String) -> String? {
        Self.normalizedUserFolderName(name)
    }

    private func normalizedFolderTitle(
        _ title: String,
        maximumUTF8ByteCount: Int
    ) -> String {
        Self.normalizedFolderName(
            title,
            trimsLeadingDots: false,
            fallback: "Gallery",
            maximumUTF8ByteCount: maximumUTF8ByteCount
        ) ?? "Gallery"
    }

    private static func normalizedFolderName(
        _ name: String,
        trimsLeadingDots: Bool,
        fallback: String?,
        maximumUTF8ByteCount: Int
    ) -> String? {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
            .union(.controlCharacters)
        let sanitizedScalars = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { invalidCharacters.contains($0) ? " " : String($0) }
            .joined()
        let collapsedWhitespace = sanitizedScalars.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        let trimPattern = trimsLeadingDots
            ? "^[\\s.]+|[\\s.]+$"
            : "^\\s+|[\\s.]+$"
        let trimmedName = collapsedWhitespace.replacingOccurrences(
            of: trimPattern,
            with: "",
            options: .regularExpression
        )
        let limitedName = trimmedName
            .truncatedToUTF8ByteCount(maximumUTF8ByteCount)
            .replacingOccurrences(
                of: "[\\s.]+$",
                with: "",
                options: .regularExpression
            )
        if limitedName.isEmpty {
            return fallback
        }
        return limitedName
    }

    private func normalizedIdentityComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\[]:")
            .union(.controlCharacters)
            .union(.whitespacesAndNewlines)
        let sanitized = value.unicodeScalars
            .map { invalidCharacters.contains($0) ? "_" : String($0) }
            .joined()
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    private func identityPrefix(gid: String, token: String) -> String {
        "\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))_"
    }

    public func makePageRelativePath(gid: String, token: String, index: Int, fileExtension: String) -> String {
        "\(identityPrefix(gid: gid, token: token))\(index).\(fileExtension.lowercased())"
    }

    public func makeCoverRelativePath(gid: String, token: String, fileExtension: String) -> String {
        "\(identityPrefix(gid: gid, token: token))cover.\(fileExtension.lowercased())"
    }

    public func existingPageFileURL(folderURL: URL, gid: String, token: String, index: Int) -> URL? {
        existingAssetFileURL(
            folderURL: folderURL,
            prefix: pageFilePrefix(gid: gid, token: token, index: index)
        )
    }

    public func existingCoverFileURL(
        folderURL: URL,
        gid: String,
        token: String,
        discardingRejected: Bool = false
    ) -> URL? {
        existingAssetFileURL(
            folderURL: folderURL,
            prefix: coverFilePrefix(gid: gid, token: token),
            discardingRejected: discardingRejected
        )
    }

    /// Finds one named asset, collapsing a failed listing into "not found".
    ///
    /// **The binding rule this collapse rests on: a probe consumer may flatten a failed listing
    /// into an empty answer only while NONE of its own consumers acts irreversibly on that
    /// answer.** The moment one does, it must stop asking here and consume the surfaced-signal
    /// scan instead — `pageFileScan(...)`, whose `scanSucceeded` and `unprobedPages` say
    /// "unlistable" and "unprobeable" out loud rather than as an absence.
    ///
    /// G-15-9 is the recorded cost of losing that property silently: a consumer that blanked
    /// recorded content hashes on an empty answer was reading a failed listing as an empty folder,
    /// so a transient `contentsOfDirectory` failure — descriptor exhaustion, `EBUSY`, a
    /// data-protection denial while the device is locked — destroyed real state. Nothing about
    /// this function's answer distinguishes those cases; only its callers' restraint does.
    ///
    /// The audited-safe set at this HEAD is exactly the two lookups below it —
    /// `existingPageFileURL(folderURL:gid:token:index:)` and
    /// `existingCoverFileURL(folderURL:gid:token:)` — verified exhaustive by grepping this
    /// function's name over `AppPackage/Sources`. Their own consumers all treat a nil answer as
    /// "redo the work": the page lookup reaches `refreshManifestPageFileHash`, which returns the
    /// manifest unchanged when it resolves nothing, and the cover lookup reaches `localCoverURL`
    /// and `existingCoverRelativePath`, whose nil means the online cover is shown or the cover is
    /// fetched again. Nothing on either route deletes or overwrites recorded state. Adding a third
    /// caller means re-running that audit, not extending its conclusion.
    private func existingAssetFileURL(
        folderURL: URL,
        prefix: String,
        discardingRejected: Bool = false
    ) -> URL? {
        existingAssetFileURL(
            in: existingAssetFileURLs(folderURL: folderURL) ?? [],
            prefix: prefix,
            discardingRejected: discardingRejected
        )
    }

    /// Lists a folder's assets, or answers nil when the listing itself failed.
    ///
    /// Absence is the normal case here — most callers ask about folders that may not exist — so the
    /// error is still not logged. What changed for G-15-9 is that the failure is no longer flattened
    /// into an empty array: `contentsOfDirectory` fails for transient reasons too (descriptor
    /// exhaustion, `EBUSY`, a data-protection denial while the device is locked), and one caller
    /// destroys recorded content hashes on an empty answer. Interpreting the failure is now the
    /// caller's, so a probe keeps its empty fallback while the destructive consumer can refuse.
    private func existingAssetFileURLs(folderURL: URL) -> [URL]? {
        let fileURLs: [URL]
        do {
            fileURLs = try fileManager.operate {
                try $0.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
                )
            }
        } catch {
            return nil
        }

        return fileURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    private func existingAssetFileURL(
        in fileURLs: [URL],
        prefix: String,
        discardingRejected: Bool = false
    ) -> URL? {
        fileURLs
            .first(where: {
                $0.lastPathComponent.hasPrefix(prefix)
                    && sanitizeAssetFileIfNeeded(at: $0, discardingRejected: discardingRejected)
            })
    }

    private func pageFilePrefix(gid: String, token: String, index: Int) -> String {
        "\(identityPrefix(gid: gid, token: token))\(index)."
    }

    private func coverFilePrefix(gid: String, token: String) -> String {
        "\(identityPrefix(gid: gid, token: token))cover."
    }

    public func writeManifest(_ manifest: DownloadManifest, folderURL: URL) throws {
        try writeJSON(manifest, to: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest))
    }

    public func readManifest(folderURL: URL) throws -> DownloadManifest {
        let manifest = try readJSON(
            DownloadManifest.self,
            from: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        )
        try validateDecodedManifest(manifest)
        return manifest
    }

    /// Reads a manifest as an *identity probe*, answering only "is this a readable gallery
    /// folder?".
    ///
    /// Filesystem discovery walks arbitrary user-visible folders — the Files-app integration
    /// lets the user create, move and rename anything under the download root — so a folder
    /// without a decodable manifest is the ordinary negative answer, not a failure. The error
    /// is therefore discarded rather than logged: logging it would emit a line per unrelated
    /// folder on every scan. Callers that treat an unreadable manifest as corruption (e.g.
    /// `validate(download:verifiesContentHashes:)`) read and handle the error themselves.
    func probeManifest(folderURL: URL) -> DownloadManifest? {
        do {
            return try readManifest(folderURL: folderURL)
        } catch {
            return nil
        }
    }

    private func validateDecodedManifest(_ manifest: DownloadManifest) throws {
        guard manifest.pages.isEmpty == false else {
            throw manifestCorruptedError()
        }
        guard manifest.pages.keys.sorted() == Array(1...manifest.pages.count) else {
            throw manifestCorruptedError()
        }
    }

    private func manifestCorruptedError() -> AppError {
        .fileOperationFailed(String(localized: .RLocalizable.downloadStoreManifestCorrupted))
    }

    public func scanDownloadFolders() throws -> [DownloadFolderRecord] {
        try scanDownloads().records
    }

    public func scanDownloads() throws -> DownloadScanResult {
        guard fileManager.operate({ $0.fileExists(atPath: rootURL.path) }) else {
            return .init(records: [], userFolders: [])
        }

        var records = [DownloadFolderRecord]()
        var userFolders = [String]()
        for folderURL in directoryURLs(in: rootURL) {
            let folderName = folderURL.lastPathComponent
            // Gallery folders dropped directly under the root, including broken
            // manifest-less ones, are invisible to the app and never become
            // user folders.
            // This manifest read distinguishes gallery folders from user folders; failure means "not a gallery".
            guard probeManifest(folderURL: folderURL) == nil else { continue }
            guard !Self.isGalleryFolderLikeName(folderName) else { continue }

            userFolders.append(folderName)
            for galleryFolderURL in directoryURLs(in: folderURL) {
                // Corrupt or incomplete gallery folders stay invisible until their manifest becomes readable.
                guard let manifest = probeManifest(folderURL: galleryFolderURL) else {
                    continue
                }
                records.append(
                    galleryFolderRecord(
                        folderURL: galleryFolderURL,
                        manifest: manifest,
                        parentFolderName: folderName
                    )
                )
            }
        }
        return .init(
            records: records,
            userFolders: userFolders.sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        )
    }

    private func directoryURLs(in parentURL: URL) -> [URL] {
        let contents: [URL]
        do {
            contents = try fileManager.operate {
                try $0.contentsOfDirectory(
                    at: parentURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
            }
        } catch {
            // Filesystem discovery treats an absent or unreadable parent as containing no visible
            // directories. Scans run against arbitrary user folders, so this is not logged.
            return []
        }
        return contents.filter { url in
            do {
                return try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            } catch {
                // Entries whose directory metadata cannot be read are excluded from the result.
                return false
            }
        }
    }

    public func galleryFolderRecord(
        folderURL: URL,
        manifest: DownloadManifest,
        parentFolderName: String
    ) -> DownloadFolderRecord {
        // Modification time is display metadata; an unavailable value is represented by nil.
        let modificationDate: Date?
        do {
            modificationDate = try folderURL
                .resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
        } catch {
            modificationDate = nil
        }
        // Both resolutions are RENDERING resources and nothing else after D-SSOT-07 — the record's
        // completeness comes from `manifest`, three lines up — so the index scan reads without
        // discarding. `reloadDownloadIndex` is the pull-to-refresh and foreground-return route, so a
        // discarding probe here would let a routine refresh delete a zero-byte or non-regular page
        // file while the manifest goes on claiming that page, with nothing displayed moving to say
        // so. Since CR-03 that is the DEFAULT rather than this site's opt-out, so no argument is
        // written here at all; the only sites still discarding are the two COVER resolutions, and a
        // cover carries no recorded hash to diverge from.
        return DownloadFolderRecord(
            relativePath: "\(parentFolderName)/\(folderURL.lastPathComponent)",
            folderURL: folderURL,
            manifest: manifest,
            localCoverURL: localCoverURL(folderURL: folderURL, manifest: manifest),
            localPageURLs: imageURLs(folderURL: folderURL, manifest: manifest),
            modificationDate: modificationDate,
            parentFolderName: parentFolderName
        )
    }

    public func fileHash(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { closeReadHandle(handle) }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024)
            guard let data, !data.isEmpty else { break }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "sha256:\(hex)"
    }

    /// What a per-file asset probe was able to determine.
    ///
    /// The distinction exists because ONE consumer acts irreversibly on the answer: the working-seed
    /// reconciliation destroys a recorded content hash for a claimed page the probe did not account
    /// for. Only a POSITIVE determination may ever authorize that. `unprobeable` is the answer that
    /// says the question went unanswered, and a non-answer is never authority to destroy state
    /// (G-15-13, fixed as D-G13-01).
    ///
    /// It is an exhaustively switched enum rather than a second `Bool` for SCOPE, and the scope is
    /// the point. This is the fifth consecutive round in which a fix scoped to the exact branch its
    /// regression staged left a sibling branch open — here the sibling is any probe exit nobody has
    /// enumerated yet. Classifying the whole function instead means a new exit cannot default into
    /// "positively absent": it has to be named, and every reader switches over the full set.
    private enum AssetFileProbeOutcome: Equatable {
        /// The file is there and fit to be reused as this page's content.
        case usable
        /// A positive determination that the file is there and NOT fit: a non-regular item, a
        /// zero-byte file, or a file whose content read reaches end-of-file immediately.
        ///
        /// `fileRemains` is whether the refused file is still on disk when the probe returns — false
        /// exactly when a discarding caller's housekeeping deletion succeeded. It rides on the
        /// outcome rather than being re-derived by the caller because only the probe knows which of
        /// the rejection exits carries a deletion at all (the content-read exit never has) and
        /// whether that deletion worked; a caller re-asking `fileExists` afterwards would be racing
        /// the same filesystem it is trying to describe.
        case rejected(fileRemains: Bool)
        /// The probe could not answer. Nothing about the file was established, so it may be
        /// re-fetched but its recorded hash may not be destroyed.
        case unprobeable
    }

    /// Whether an asset file is usable — and, for a caller that opts in, discarding it when the
    /// probe positively rejects it. The name describes the opt-in half; the answer is identical
    /// without it, which is why the default withholds the deletion (CR-03).
    ///
    /// The `Bool` forward of `probeAssetFile(at:discardingRejected:)`, kept for the callers that
    /// re-fetch or re-derive on a false answer and are unaffected by WHY it is false. Both
    /// non-usable outcomes were false before the classification landed and are false now, so every
    /// one of those callers reads the same answer either way. A caller that acts irreversibly on the
    /// answer must take the classification instead, through
    /// `pageFileScan(folderURL:manifest:discardingRejected:)`'s `unprobedPages`.
    @discardableResult
    public func sanitizeAssetFileIfNeeded(at url: URL, discardingRejected: Bool = false) -> Bool {
        probeAssetFile(at: url, discardingRejected: discardingRejected) == .usable
    }

    /// Classifies one asset file, discarding it on the rejections that have always carried that
    /// housekeeping deletion — unless the caller is only READING.
    ///
    /// **Withholding that deletion is what a display path needs, and the reason it became necessary
    /// is D-SSOT-07.** While a page's status came from presence, discarding a rejected
    /// file was self-consistent: the page immediately read `.pending`, so the record and the screen
    /// agreed about what had just happened. The status now comes from the manifest hash, so a
    /// display read that deletes a zero-byte or non-regular page file leaves the page reading
    /// `.downloaded` over a file the READ destroyed — a record/disk divergence created by looking,
    /// licensed by no reconciliation, and invisible until the user runs Validate. A read may
    /// classify; only a reconciliation may act.
    ///
    /// **CR-01 is the same rule one step further in, and it is why VALIDATION opts out too.** A
    /// display read had no business acting; validation does have business acting, but not yet — its
    /// scan is evidence GATHERING, and the authority to destroy anything belongs to the combined
    /// wholesale guard that runs after all the evidence is in. While validation scanned with the
    /// default, a one-page gallery whose only page file was zero bytes had that file deleted by the
    /// probe, and the guard then refused to blank the hash it was deleted for: the pass mutated the
    /// disk in exactly the case it decided it must not touch the record. Classification and mutation
    /// are separated by this flag; the ordering that keeps them separated is the caller's.
    ///
    /// **CR-03 turned the default around, because a DEFAULT is an exit path.** While the mutating
    /// value was the default, every caller nobody had enumerated was a mutator — which is how this
    /// deletion survived CR-01's fix on the routes it was reported against and reappeared under an
    /// ordinary reader open, a `resumeMode` resolution and the coordinator's folder sweep. Reading
    /// is now what a caller gets for saying nothing, so the property holds for callers that do not
    /// exist yet, and deleting has to be written down.
    ///
    /// Exactly one production site writes it, and it is a COVER: the working folder's cover
    /// resolution in `prepareWorkingSeed`. The entitlement is the rule rather than the position, and
    /// the rule is that an act may delete only if the same act durably blanks the record for the
    /// page it destroyed. A cover carries no recorded hash at all, so its removal has nothing to
    /// diverge from and the run re-fetches it.
    /// That population is CENSUSED rather than described:
    /// `DownloadSourceInventoryTests.testDiscardingRejectedSitesMatchTheEntitlementCensus` counts it
    /// over this module, so a third site cannot ship without a recorded per-site verdict.
    ///
    /// Two sites left this set, each failing the rule from a different side. `prepareWorkingSeed`'s
    /// destination page scan left it in WR-02: the deletion and the blanking were about the same
    /// folder, and discarding during classification is precisely wrong there, because the wholesale
    /// guard may still refuse and a refusal that had already destroyed the file leaves the record
    /// claiming a page whose bytes the asking removed. It now classifies without discarding and
    /// removes what the guard authorizes through `removeRefutedPageFiles`, which also covers the
    /// refutations this probe never deletes for anyone — see `probeAssetFileContent`. The retired
    /// repair-seed materialization's SOURCE page scan left it for the opposite reason: the folder it
    /// deleted in was the gallery's currently indexed one and the record the route blanked belonged
    /// to the copy, so no act on that route was ever going to reconcile what it destroyed. It was
    /// made a read, and the whole route has since been retired with the completion sweep.
    private func probeAssetFile(at url: URL, discardingRejected: Bool) -> AssetFileProbeOutcome {
        // Not a positive absence — for the LISTING-DERIVED callers, which is what this outcome is
        // stated for. `pageFileScan` and `existingAssetFileURL(in:prefix:)` hand this a file an
        // enumeration has just yielded, so a stat-backed existence check that then denies it is a
        // question left unanswered; for them a positive absence is a claimed page whose file the
        // successful listing never yielded, and that page never reaches this function at all.
        //
        // One route constructs its path instead of reading it off a listing: a just-written page
        // file's own relative path, through `hashReadableAsset` from `refreshManifestPageFileHashes`
        // (the retired repair-seed materialization's manifest copy was the other). For it a missing
        // file IS a positive absence, and this function still answers `unprobeable`.
        // The licensing condition is therefore on the consumer rather than on the path: a caller
        // holding a constructed path may keep reading the collapsed `Bool` only while its answer can
        // never reach a decision that destroys recorded state. It throws instead — a
        // recoverable failed operation — and after G-15-19 no caller of the collapsed forward feeds
        // an absence into a destructive decision at all. One that needed to would have to take a
        // classification of its own, through `pageFileScan(folderURL:manifest:)`, rather than read a
        // non-answer this comment has licensed for someone else's callers.
        guard fileManager.operate({ $0.fileExists(atPath: url.path) }) else { return .unprobeable }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.operate { try $0.attributesOfItem(atPath: url.path) }
        } catch {
            // The narrowed G-15-13 trigger: the metadata read itself is unavailable — an I/O error,
            // a permission change, a volume going away mid-scan. Content is the only question left
            // to put to the file.
            return probeAssetFileContent(at: url)
        }

        let isRegularFile = (attributes[.type] as? FileAttributeType).map({ $0 == .typeRegular }) ?? true
        guard isRegularFile else {
            return .rejected(
                fileRemains: discardRejectedAssetIfPermitted(at: url, discardingRejected: discardingRejected)
            )
        }
        // Metadata that answered, but not the size question. That is not a zero-byte determination,
        // so it authorizes neither the discard below nor blanking the page.
        guard let fileSize = (attributes[.size] as? NSNumber)?.intValue else { return .unprobeable }
        guard fileSize > 0 else {
            return .rejected(
                fileRemains: discardRejectedAssetIfPermitted(at: url, discardingRejected: discardingRejected)
            )
        }

        return .usable
    }

    /// The discard, gated on the caller having said it may mutate.
    ///
    /// The REJECTION is unaffected either way — a zero-byte or non-regular file is unusable whether
    /// or not it is deleted — so a non-discarding caller gets the identical classification and only
    /// forgoes the housekeeping. That separation is the whole point: the answer is a read, the
    /// deletion is an act, and only a reconciliation is entitled to the second one.
    ///
    /// - Returns: whether the refused file is still on disk. That is the one thing the rejection
    ///   verdict alone cannot say and the scan above must know, since a page whose refuted file
    ///   survived may not be blanked without removing it in the same authorized act.
    private func discardRejectedAssetIfPermitted(at url: URL, discardingRejected: Bool) -> Bool {
        guard discardingRejected else { return true }
        return !discardRejectedAsset(at: url)
    }

    /// Deletes an asset the probe has already rejected. Housekeeping only: the rejection
    /// stands whether or not the file could actually be removed, so a failure is logged rather
    /// than propagated to the caller's answer.
    ///
    /// - Returns: whether the file is gone. A failure keeps the page's refuted identity visible to
    ///   the scan instead of laundering it into a positive absence the record would then blank.
    private func discardRejectedAsset(at url: URL) -> Bool {
        do {
            try fileManager.operate { try $0.removeItem(at: url) }
            return true
        } catch {
            logger.error("Rejected download asset removal failed: \(error, privacy: .private)")
            return false
        }
    }

    /// Closes a handle opened purely to read bytes. The read's own result or error stays
    /// primary — these calls sit in `defer`, after the value the caller wants is already
    /// produced — so an unexpected close failure is logged instead of replacing that result.
    func closeReadHandle(_ handle: FileHandle) {
        do {
            try handle.close()
        } catch {
            logger.error("Download read handle close failed: \(error, privacy: .private)")
        }
    }

    /// The probe's last resort when metadata is unavailable: ask the file itself for a byte.
    ///
    /// An immediate end-of-file is a POSITIVE empty-content determination, so it rejects — without
    /// discarding, which is the behavior this path has always had and keeps deliberately: metadata
    /// never confirmed a zero-byte regular file here, so the housekeeping deletion the metadata
    /// path performs is not warranted. A throw from the open or the read establishes nothing at
    /// all, which is the exit the whole classification exists for.
    ///
    /// **The behaviour stays; what changed is who is responsible for the file (WR-02).** Because
    /// this exit reports `fileRemains: true` for every caller alike, `discardingRejected` does not
    /// make `PageFileScan.rejectedPageRelativePaths` empty, and a consumer that reasoned "a
    /// discarding caller sees no rejections" was wrong for exactly this population — which is how a
    /// page refused here kept its claimed hash beside its refuted bytes on the automatic route.
    /// Removing such a file is a reconciliation's act, taken under its own guard, never this
    /// probe's.
    private func probeAssetFileContent(at url: URL) -> AssetFileProbeOutcome {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { closeReadHandle(handle) }
            return try handle.read(upToCount: 1)?.isEmpty == false ? .usable : .rejected(fileRemains: true)
        } catch {
            return .unprobeable
        }
    }
}

private extension String {
    func truncatedToUTF8ByteCount(_ maximumByteCount: Int) -> String {
        guard maximumByteCount > 0 else { return "" }
        var byteCount = 0
        var result = ""
        for character in self {
            let characterByteCount = character.utf8.count
            guard byteCount + characterByteCount <= maximumByteCount else {
                break
            }
            result.append(character)
            byteCount += characterByteCount
        }
        return result
    }
}
