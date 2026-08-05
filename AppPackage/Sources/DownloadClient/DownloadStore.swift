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

/// The page files a working folder was found to hold, together with the two things `pages` alone
/// cannot say: whether the folder could be listed at all, and which of the files it did list the
/// per-file probe could not answer for.
///
/// All three members exist for one consumer. `pages` alone cannot tell "this folder holds none of
/// the manifest's pages" apart from "this folder could not be read", nor "this page's file is gone"
/// apart from "this page's file is there and unprobeable". Every non-destructive caller is entitled
/// to collapse both pairs — a probe that finds nothing re-fetches, which is harmless either way —
/// but the working-seed reconciliation destroys recorded content hashes on that answer, and
/// destroying state on a non-answer is what G-15-9 and then G-15-13 reported.
///
/// - `scanSucceeded` answers at the DIRECTORY level: false means the enumeration itself failed, so
///   the whole answer is a non-answer (G-15-9).
/// - `unprobedPages` answers one level down, PER FILE: a claimed page whose file the enumeration
///   did list but whose probe could not classify (G-15-13). A page here is neither usable nor
///   positively absent, so it may be re-fetched but never blanked.
///
/// The two are kept apart rather than collapsed into one flag deliberately: they are answers to
/// different questions at different granularities, the reconciliation consumes them independently,
/// and merging them would re-conflate exactly the levels those two gaps separated.
public struct PageFileScan: Equatable, Sendable {
    public let pages: [Int: String]
    public let scanSucceeded: Bool
    public let unprobedPages: Set<Int>

    public init(pages: [Int: String], scanSucceeded: Bool, unprobedPages: Set<Int>) {
        self.pages = pages
        self.scanSucceeded = scanSucceeded
        self.unprobedPages = unprobedPages
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

    public func userFolderURL(name: String) -> URL {
        rootURL.appendingPathComponent(name, isDirectory: true)
    }

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
    /// answer and are unaffected by why it is empty. A caller that acts irreversibly on the answer
    /// must use `pageFileScan(folderURL:manifest:)` instead and honour its `scanSucceeded` flag.
    public func existingPageRelativePaths(folderURL: URL, manifest: DownloadManifest) -> [Int: String] {
        pageFileScan(folderURL: folderURL, manifest: manifest).pages
    }

    /// The same scan, with the enumeration's success surfaced alongside its result (G-15-9) and the
    /// pages whose listed file the probe could not classify surfaced beside both (G-15-13).
    ///
    /// A failed enumeration answers nothing at all, so it reports no unprobed pages either: there is
    /// no listing to have listed them, and the directory-level refusal already covers that whole
    /// answer.
    public func pageFileScan(folderURL: URL, manifest: DownloadManifest) -> PageFileScan {
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

            switch probeAssetFile(at: fileURL) {
            case .usable:
                pages[page] = fileName
                // A usable file settles the page outright, even if an earlier candidate for the
                // same page was the one that could not be probed.
                unprobedPages.remove(page)
            case .rejected:
                continue
            case .unprobeable:
                unprobedPages.insert(page)
            }
        }
        return .init(pages: pages, scanSucceeded: true, unprobedPages: unprobedPages)
    }

    public func imageURLs(folderURL: URL, manifest: DownloadManifest) -> [Int: URL] {
        existingPageRelativePaths(folderURL: folderURL, manifest: manifest)
            .reduce(into: [Int: URL]()) { result, entry in
                result[entry.key] = folderURL.appendingPathComponent(entry.value)
            }
    }

    public func localCoverURL(folderURL: URL, manifest: DownloadManifest) -> URL? {
        existingCoverFileURL(
            folderURL: folderURL,
            gid: manifest.gid,
            token: manifest.token
        )
    }

    public func existingCoverRelativePath(folderURL: URL, manifest: DownloadManifest) -> String? {
        localCoverURL(folderURL: folderURL, manifest: manifest)?
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

    public func existingCoverFileURL(folderURL: URL, gid: String, token: String) -> URL? {
        existingAssetFileURL(
            folderURL: folderURL,
            prefix: coverFilePrefix(gid: gid, token: token)
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
    private func existingAssetFileURL(folderURL: URL, prefix: String) -> URL? {
        existingAssetFileURL(
            in: existingAssetFileURLs(folderURL: folderURL) ?? [],
            prefix: prefix
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

    private func existingAssetFileURL(in fileURLs: [URL], prefix: String) -> URL? {
        fileURLs
            .first(where: {
                $0.lastPathComponent.hasPrefix(prefix)
                    && sanitizeAssetFileIfNeeded(at: $0)
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
    private enum AssetFileProbeOutcome {
        /// The file is there and fit to be reused as this page's content.
        case usable
        /// A positive determination that the file is there and NOT fit: a non-regular item, a
        /// zero-byte file, or a file whose content read reaches end-of-file immediately.
        case rejected
        /// The probe could not answer. Nothing about the file was established, so it may be
        /// re-fetched but its recorded hash may not be destroyed.
        case unprobeable
    }

    /// Whether an asset file is usable, discarding it when the probe positively rejects it.
    ///
    /// The `Bool` forward of `probeAssetFile(at:)`, kept for the callers that re-fetch or re-derive
    /// on a false answer and are unaffected by WHY it is false. Both non-usable outcomes were false
    /// before the classification landed and are false now, so every one of those callers keeps its
    /// behavior byte for byte. A caller that acts irreversibly on the answer must take the
    /// classification instead, through `pageFileScan(folderURL:manifest:)`'s `unprobedPages`.
    @discardableResult
    public func sanitizeAssetFileIfNeeded(at url: URL) -> Bool {
        probeAssetFile(at: url) == .usable
    }

    /// Classifies one asset file, discarding it on the rejections that have always carried that
    /// housekeeping deletion.
    private func probeAssetFile(at url: URL) -> AssetFileProbeOutcome {
        // Not a positive absence. The callers hand this a file a directory listing just produced,
        // so a stat-backed existence check that then denies it is a question left unanswered — a
        // positive absence is a claimed page whose file the successful listing never yielded, and
        // that page never reaches this function at all.
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
            discardRejectedAsset(at: url)
            return .rejected
        }
        // Metadata that answered, but not the size question. That is not a zero-byte determination,
        // so it authorizes neither the discard below nor blanking the page.
        guard let fileSize = (attributes[.size] as? NSNumber)?.intValue else { return .unprobeable }
        guard fileSize > 0 else {
            discardRejectedAsset(at: url)
            return .rejected
        }

        return .usable
    }

    /// Deletes an asset the probe has already rejected. Housekeeping only: the rejection
    /// stands whether or not the file could actually be removed, so a failure is logged rather
    /// than propagated to the caller's answer.
    private func discardRejectedAsset(at url: URL) {
        do {
            try fileManager.operate { try $0.removeItem(at: url) }
        } catch {
            logger.error("Rejected download asset removal failed: \(error, privacy: .private)")
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
    private func probeAssetFileContent(at url: URL) -> AssetFileProbeOutcome {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { closeReadHandle(handle) }
            return try handle.read(upToCount: 1)?.isEmpty == false ? .usable : .rejected
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
