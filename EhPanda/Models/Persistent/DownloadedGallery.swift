//
//  DownloadedGallery.swift
//  EhPanda
//

import SwiftUI
import CryptoKit

enum DownloadThreadMode: Codable, CaseIterable, Identifiable, Sendable {
    case single
    case double
    case triple
    case quadruple
    case quintuple

    var id: Int { workerCount }

    var value: String {
        switch self {
        case .single:
            return L10n.Localizable.Enum.DownloadThreadMode.Value.single
        case .double:
            return L10n.Localizable.Enum.DownloadThreadMode.Value.double
        case .triple:
            return L10n.Localizable.Enum.DownloadThreadMode.Value.triple
        case .quadruple:
            return L10n.Localizable.Enum.DownloadThreadMode.Value.quadruple
        case .quintuple:
            return L10n.Localizable.Enum.DownloadThreadMode.Value.quintuple
        }
    }

    var workerCount: Int {
        switch self {
        case .single:
            return 1
        case .double:
            return 2
        case .triple:
            return 3
        case .quadruple:
            return 4
        case .quintuple:
            return 5
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let storedValue = (try? container.decode(String.self)) ?? ""
        switch storedValue {
        case "single":
            self = .single
        case "double":
            self = .double
        case "triple":
            self = .triple
        case "quadruple":
            self = .quadruple
        case "quintuple":
            self = .quintuple
        default:
            self = .single
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single:
            try container.encode("single")
        case .double:
            try container.encode("double")
        case .triple:
            try container.encode("triple")
        case .quadruple:
            try container.encode("quadruple")
        case .quintuple:
            try container.encode("quintuple")
        }
    }
}

struct DownloadOptionsSnapshot: Codable, Equatable, Sendable {
    var threadMode: DownloadThreadMode = .single
    var allowCellular = true
    var autoRetryFailedPages = true

    var workerCount: Int {
        threadMode.workerCount
    }

    private enum CodingKeys: String, CodingKey {
        case threadMode
        case allowCellular
        case autoRetryFailedPages
    }

    init(
        threadMode: DownloadThreadMode = .single,
        allowCellular: Bool = true,
        autoRetryFailedPages: Bool = true
    ) {
        self.threadMode = threadMode
        self.allowCellular = allowCellular
        self.autoRetryFailedPages = autoRetryFailedPages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        threadMode = try container.decodeIfPresent(DownloadThreadMode.self, forKey: .threadMode) ?? .single
        allowCellular = try container.decodeIfPresent(Bool.self, forKey: .allowCellular) ?? true
        autoRetryFailedPages = try container.decodeIfPresent(Bool.self, forKey: .autoRetryFailedPages) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(threadMode, forKey: .threadMode)
        try container.encode(allowCellular, forKey: .allowCellular)
        try container.encode(autoRetryFailedPages, forKey: .autoRetryFailedPages)
    }
}

enum DownloadStatus: String, Codable, Equatable, CaseIterable, Sendable {
    case queued
    case downloading
    case paused
    case partial
    case completed
    case failed
    case updateAvailable
    case missingFiles
}

enum DownloadFailureCode: String, Codable, Equatable, Sendable {
    case quotaExceeded
    case authenticationRequired
    case fileOperationFailed
    case ipBanned
    case networkingFailed
    case parseFailed
    case notFound
    case unknown
}

struct DownloadFailure: Codable, Equatable, Sendable {
    var code: DownloadFailureCode
    var message: String

    init(code: DownloadFailureCode, message: String) {
        self.code = code
        self.message = message
    }

    init(error: AppError) {
        switch error {
        case .quotaExceeded:
            self = .init(code: .quotaExceeded, message: error.alertText)
        case .authenticationRequired:
            self = .init(code: .authenticationRequired, message: error.alertText)
        case .fileOperationFailed(let reason):
            self = .init(code: .fileOperationFailed, message: reason)
        case .ipBanned(let interval):
            self = .init(code: .ipBanned, message: interval.description)
        case .networkingFailed:
            self = .init(code: .networkingFailed, message: error.alertText)
        case .parseFailed:
            self = .init(code: .parseFailed, message: error.alertText)
        case .notFound:
            self = .init(code: .notFound, message: error.alertText)
        default:
            self = .init(code: .unknown, message: error.alertText)
        }
    }

    var appError: AppError {
        switch code {
        case .quotaExceeded:
            return .quotaExceeded
        case .authenticationRequired:
            return .authenticationRequired
        case .fileOperationFailed:
            return .fileOperationFailed(message)
        case .ipBanned:
            return .ipBanned(.unrecognized(content: message))
        case .networkingFailed:
            return .networkingFailed
        case .parseFailed:
            return .parseFailed
        case .notFound:
            return .notFound
        case .unknown:
            return .unknown
        }
    }
}

enum DownloadStartMode: String, Codable, Equatable, Sendable {
    case initial
    case update
    case redownload
    case repair
}

struct DownloadManifest: Codable, Equatable {
    struct Page: Codable, Equatable, Identifiable {
        var id: Int { index }

        let index: Int
        let relativePath: String
    }

    let gid: String
    let host: GalleryHost
    let token: String
    let title: String
    let jpnTitle: String?
    let category: Category
    let language: Language
    let uploader: String?
    let tags: [GalleryTag]
    let postedDate: Date
    let pageCount: Int
    let coverRelativePath: String?
    let galleryURL: URL
    let rating: Float
    let downloadOptions: DownloadOptionsSnapshot
    let versionSignature: String
    let downloadedAt: Date
    let pages: [Page]

    func imageURLs(folderURL: URL) -> [Int: URL] {
        Dictionary(uniqueKeysWithValues: pages.map {
            ($0.index, folderURL.appendingPathComponent($0.relativePath))
        })
    }
}

struct DownloadFailedPagesSnapshot: Codable, Equatable, Sendable {
    struct Page: Codable, Equatable, Identifiable, Sendable {
        var id: Int { index }

        let index: Int
        let relativePath: String?
        let failure: DownloadFailure
    }

    var pages: [Page]

    var map: [Int: Page] {
        Dictionary(uniqueKeysWithValues: pages.map { ($0.index, $0) })
    }
}

enum DownloadPageStatus: String, Equatable, Sendable {
    case pending
    case downloaded
    case failed
}

struct DownloadPageInspection: Equatable, Identifiable, Sendable {
    var id: Int { index }

    let index: Int
    let status: DownloadPageStatus
    let relativePath: String?
    let fileURL: URL?
    let failure: DownloadFailure?
}

struct DownloadInspection: Equatable, Sendable {
    let download: DownloadedGallery
    let coverURL: URL?
    let pages: [DownloadPageInspection]

    var failedPageIndices: [Int] {
        pages.filter { $0.status == .failed }.map(\.index)
    }
}

enum DownloadBadge: Equatable {
    case none
    case queued
    case downloading(Int, Int)
    case paused(Int, Int)
    case partial(Int, Int)
    case downloaded
    case failed
    case updateAvailable
    case missingFiles
}

extension DownloadBadge {
    var text: String {
        switch self {
        case .none:
            return ""
        case .queued:
            return L10n.Localizable.Struct.DownloadBadge.Text.queued
        case .downloading(let completed, let total):
            return L10n.Localizable.Struct.DownloadBadge.Text.downloading(completed, max(total, 1))
        case .paused(let completed, let total):
            return L10n.Localizable.Struct.DownloadBadge.Text.paused(completed, max(total, 1))
        case .partial(let completed, let total):
            return L10n.Localizable.Struct.DownloadBadge.Text.needsAttentionProgress(
                completed,
                max(total, 1)
            )
        case .downloaded:
            return L10n.Localizable.Struct.DownloadBadge.Text.downloaded
        case .failed:
            return L10n.Localizable.Struct.DownloadBadge.Text.needsAttention
        case .updateAvailable:
            return L10n.Localizable.Struct.DownloadBadge.Text.updateAvailable
        case .missingFiles:
            return L10n.Localizable.Struct.DownloadBadge.Text.needsRepair
        }
    }

    var color: Color {
        switch self {
        case .none:
            return .clear
        case .queued:
            return .orange
        case .downloading:
            return .blue
        case .paused:
            return .indigo
        case .partial:
            return .orange
        case .downloaded:
            return .green
        case .failed:
            return .orange
        case .updateAvailable:
            return .yellow
        case .missingFiles:
            return .pink
        }
    }
}

enum DownloadListFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case completed
    case failed
    case update

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.Localizable.Enum.DownloadListFilter.Title.all
        case .active:
            return L10n.Localizable.Enum.DownloadListFilter.Title.active
        case .completed:
            return L10n.Localizable.Enum.DownloadListFilter.Title.completed
        case .failed:
            return L10n.Localizable.Enum.DownloadListFilter.Title.failed
        case .update:
            return L10n.Localizable.Enum.DownloadListFilter.Title.update
        }
    }
}

struct DownloadGalleryFilter: Equatable {
    var excludedCategories = Set<Category>()
    var minimumRatingActivated = false
    var minimumRating = 2
    var pageRangeActivated = false
    var pageLowerBound = ""
    var pageUpperBound = ""

    mutating func fixInvalidData() {
        if !pageLowerBound.isEmpty && Int(pageLowerBound) == nil {
            pageLowerBound = ""
        }
        if !pageUpperBound.isEmpty && Int(pageUpperBound) == nil {
            pageUpperBound = ""
        }
    }

    mutating func reset() {
        self = .init()
    }

    var hasActiveValues: Bool {
        !excludedCategories.isEmpty
            || minimumRatingActivated
            || pageRangeActivated
            || pageLowerBound.notEmpty
            || pageUpperBound.notEmpty
    }
}

struct DownloadRequestPayload: Equatable, @unchecked Sendable {
    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let previewURLs: [Int: URL]
    let previewConfig: PreviewConfig
    let host: GalleryHost
    let versionMetadata: DownloadVersionMetadata?
    let options: DownloadOptionsSnapshot
    let mode: DownloadStartMode
    let pageSelection: Set<Int>?

    init(
        gallery: Gallery,
        galleryDetail: GalleryDetail,
        previewURLs: [Int: URL],
        previewConfig: PreviewConfig,
        host: GalleryHost,
        versionMetadata: DownloadVersionMetadata? = nil,
        options: DownloadOptionsSnapshot,
        mode: DownloadStartMode,
        pageSelection: Set<Int>? = nil
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.previewURLs = previewURLs
        self.previewConfig = previewConfig
        self.host = host
        self.versionMetadata = versionMetadata
        self.options = options
        self.mode = mode
        self.pageSelection = pageSelection
    }
}

struct DownloadedGallery: Identifiable, Equatable {
    var id: String { gid }

    let gid: String
    let host: GalleryHost
    let token: String
    let title: String
    let jpnTitle: String?
    let uploader: String?
    let category: Category
    let tags: [GalleryTag]
    let pageCount: Int
    let postedDate: Date
    let rating: Float
    let onlineCoverURL: URL?
    let folderRelativePath: String
    let coverRelativePath: String?
    let status: DownloadStatus
    let completedPageCount: Int
    let lastDownloadedAt: Date?
    let lastError: DownloadFailure?
    let downloadOptionsSnapshot: DownloadOptionsSnapshot
    let remoteVersionSignature: String
    let latestRemoteVersionSignature: String?
    let pendingOperation: DownloadStartMode?

    init(
        gid: String,
        host: GalleryHost,
        token: String,
        title: String,
        jpnTitle: String?,
        uploader: String?,
        category: Category,
        tags: [GalleryTag],
        pageCount: Int,
        postedDate: Date,
        rating: Float,
        onlineCoverURL: URL?,
        folderRelativePath: String,
        coverRelativePath: String?,
        status: DownloadStatus,
        completedPageCount: Int,
        lastDownloadedAt: Date?,
        lastError: DownloadFailure?,
        downloadOptionsSnapshot: DownloadOptionsSnapshot,
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        pendingOperation: DownloadStartMode? = nil
    ) {
        self.gid = gid
        self.host = host
        self.token = token
        self.title = title
        self.jpnTitle = jpnTitle
        self.uploader = uploader
        self.category = category
        self.tags = tags
        self.pageCount = pageCount
        self.postedDate = postedDate
        self.rating = rating
        self.onlineCoverURL = onlineCoverURL
        self.folderRelativePath = folderRelativePath
        self.coverRelativePath = coverRelativePath
        self.status = status
        self.completedPageCount = completedPageCount
        self.lastDownloadedAt = lastDownloadedAt
        self.lastError = lastError
        self.downloadOptionsSnapshot = downloadOptionsSnapshot
        self.remoteVersionSignature = remoteVersionSignature
        self.latestRemoteVersionSignature = latestRemoteVersionSignature
        self.pendingOperation = pendingOperation
    }

    var displayTitle: String {
        jpnTitle?.notEmpty == true ? jpnTitle.forceUnwrapped : title
    }

    var searchableText: String {
        [
            title,
            jpnTitle ?? "",
            uploader ?? "",
            category.value,
            tags.flatMap(\.contents).map(\.text).joined(separator: " ")
        ]
        .joined(separator: " ")
    }

    func resolvedFolderURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        rootURL?.appendingPathComponent(folderRelativePath, isDirectory: true)
    }

    func resolvedManifestURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        resolvedFolderURL(rootURL: rootURL)?
            .appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    func resolvedLocalCoverURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        guard let folderURL = resolvedFolderURL(rootURL: rootURL),
              let coverRelativePath,
              coverRelativePath.notEmpty
        else { return nil }
        let coverURL = folderURL.appendingPathComponent(coverRelativePath)
        guard isReadableLocalAssetFile(coverURL) else {
            return nil
        }
        return coverURL
    }

    func resolvedTemporaryCoverURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        guard shouldPreserveTemporaryWorkingSet,
              let rootURL
        else {
            return nil
        }

        let temporaryFolderURL = rootURL.appendingPathComponent(".tmp-\(gid)", isDirectory: true)
        guard FileManager.default.fileExists(atPath: temporaryFolderURL.path) else {
            return nil
        }

        if let coverRelativePath,
           coverRelativePath.notEmpty
        {
            let coverURL = temporaryFolderURL.appendingPathComponent(coverRelativePath)
            if isReadableLocalAssetFile(coverURL) {
                return coverURL
            }
        }

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: temporaryFolderURL,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        return fileURLs.first(where: {
            $0.lastPathComponent.hasPrefix("cover.") && isReadableLocalAssetFile($0)
        })
    }

    func resolvedCoverURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        resolvedLocalCoverURL(rootURL: rootURL)
            ?? resolvedTemporaryCoverURL(rootURL: rootURL)
            ?? onlineCoverURL
    }

    var folderURL: URL? {
        resolvedFolderURL()
    }

    var manifestURL: URL? {
        resolvedManifestURL()
    }

    var localCoverURL: URL? {
        resolvedLocalCoverURL()
    }

    var coverURL: URL? {
        resolvedCoverURL()
    }

    var badge: DownloadBadge {
        if isQueuedWorkItem {
            return .queued
        }
        switch status {
        case .queued:
            return .queued
        case .downloading:
            return .downloading(completedPageCount, pageCount)
        case .paused:
            return .paused(completedPageCount, pageCount)
        case .partial:
            return .partial(completedPageCount, pageCount)
        case .completed:
            return .downloaded
        case .failed:
            return .failed
        case .updateAvailable:
            return .updateAvailable
        case .missingFiles:
            return .missingFiles
        }
    }

    var sortPriority: Int {
        if isQueuedWorkItem {
            return 1
        }

        switch status {
        case .downloading:
            return 0
        case .paused:
            return 1
        case .queued:
            return 2
        case .partial:
            return 3
        case .updateAvailable:
            return 4
        case .missingFiles:
            return 5
        case .failed:
            return 6
        case .completed:
            return 7
        }
    }

    var gallery: Gallery {
        Gallery(
            gid: gid,
            token: token,
            title: displayTitle,
            rating: rating,
            tags: tags,
            category: category,
            uploader: uploader,
            pageCount: pageCount,
            postedDate: postedDate,
            coverURL: coverURL,
            galleryURL: host.url
                .appendingPathComponent("g")
                .appendingPathComponent(gid)
                .appendingPathComponent(token)
        )
    }

    var canRetry: Bool {
        [.partial, .failed, .missingFiles].contains(status)
    }

    var canPauseOrResume: Bool {
        [.downloading, .paused].contains(status)
    }

    var shouldPreserveTemporaryWorkingSet: Bool {
        pendingOperation != nil
            || [.queued, .downloading, .paused, .partial].contains(status)
    }

    var isPendingQueue: Bool {
        badge == .queued
    }

    var canCancelFromDetailAction: Bool {
        isPendingQueue || canPauseOrResume || [.partial, .completed].contains(status)
    }

    var canTriggerUpdate: Bool {
        guard !isQueuedWorkItem, !canPauseOrResume else { return false }
        return status == .updateAvailable || ([.completed, .missingFiles].contains(status) && hasUpdate)
    }

    var isQueuedWorkItem: Bool {
        status == .queued || pendingOperation != nil
    }

    var hasUpdate: Bool {
        DownloadSignatureBuilder.hasUpdateComparison(
            remoteVersionSignature: remoteVersionSignature,
            latestRemoteVersionSignature: latestRemoteVersionSignature,
            gid: gid,
            token: token
        ) == .different
    }

    func needsInterruptedDownloadNormalization(
        activeGalleryID: String?,
        hasActiveTask: Bool
    ) -> Bool {
        status == .downloading && !(hasActiveTask && activeGalleryID == gid)
    }

    func matches(filter: DownloadListFilter) -> Bool {
        if isQueuedWorkItem {
            return filter == .all || filter == .active
        }

        switch filter {
        case .all:
            return true
        case .active:
            return [.downloading, .paused].contains(status)
        case .completed:
            return status == .completed
        case .failed:
            return [.partial, .failed, .missingFiles].contains(status)
        case .update:
            return status == .updateAvailable || hasUpdate
        }
    }

    func matches(queryFilter: DownloadGalleryFilter) -> Bool {
        if queryFilter.excludedCategories.contains(category) {
            return false
        }

        if queryFilter.minimumRatingActivated && rating < Float(queryFilter.minimumRating) {
            return false
        }

        guard queryFilter.pageRangeActivated else { return true }

        if let lowerBound = Int(queryFilter.pageLowerBound), pageCount < lowerBound {
            return false
        }
        if let upperBound = Int(queryFilter.pageUpperBound), pageCount > upperBound {
            return false
        }

        return true
    }
}

private extension DownloadedGallery {
    func isReadableLocalAssetFile(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        let isRegularFile = values?.isRegularFile ?? true
        let fileSize = values?.fileSize ?? 0
        return isRegularFile && fileSize > 0
    }
}

enum ReadingContentSource: Equatable {
    case remote
    case local(DownloadedGallery, DownloadManifest)
}

struct DownloadVersionMetadata: Equatable, Codable, Sendable {
    let gid: String
    let token: String
    let currentGID: String?
    let currentKey: String?
    let parentGID: String?
    let parentKey: String?
    let firstGID: String?
    let firstKey: String?

    var versionIdentifier: String? {
        DownloadSignatureBuilder.chainVersionIdentifier(
            gid: resolvedCurrentGID,
            token: resolvedCurrentKey
        )
    }

    private var resolvedCurrentGID: String {
        currentGID?.notEmpty == true ? currentGID.forceUnwrapped : gid
    }

    private var resolvedCurrentKey: String {
        currentKey?.notEmpty == true ? currentKey.forceUnwrapped : token
    }
}

enum DownloadSignatureBuilder {
    enum SignatureKind: Equatable {
        case chain(gid: String, token: String)
        case hash(String)
    }

    enum Comparison: Equatable {
        case same
        case different
        case incomparable
    }

    static func make(
        gallery: Gallery,
        detail: GalleryDetail,
        host _: GalleryHost,
        previewURLs: [Int: URL],
        versionMetadata: DownloadVersionMetadata? = nil
    ) -> String {
        if let versionIdentifier = versionMetadata?.versionIdentifier {
            return versionIdentifier
        }

        let previewHash = SHA256.hash(
            data: previewURLs
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\(normalizedPreviewSignatureValue(url: $0.value))" }
                .joined(separator: "|")
                .data(using: .utf8) ?? Data()
        )

        let payload = [
            gallery.gid,
            gallery.token,
            gallery.title,
            detail.jpnTitle ?? "",
            String(detail.pageCount),
            normalizedCoverSignatureValue(url: detail.coverURL ?? gallery.coverURL),
            detail.formattedDateString,
            previewHash.compactMap { String(format: "%02x", $0) }.joined()
        ]
        .joined(separator: "::")

        let digest = SHA256.hash(
            data: payload.data(using: String.Encoding.utf8) ?? Data()
        )
        let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "hash:\(hash)"
    }

    static func chainVersionIdentifier(gid: String, token: String) -> String? {
        guard gid.notEmpty, token.notEmpty else { return nil }
        return "chain:\(gid):\(token)"
    }

    static func parse(_ value: String?) -> SignatureKind? {
        guard let value, value.notEmpty else { return nil }

        if value.hasPrefix("chain:") {
            let components = value.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard components.count == 3,
                  !components[1].isEmpty,
                  !components[2].isEmpty
            else {
                return nil
            }
            return .chain(gid: String(components[1]), token: String(components[2]))
        }

        if value.hasPrefix("hash:") {
            let hash = String(value.dropFirst("hash:".count))
            guard hash.notEmpty else { return nil }
            return .hash(hash)
        }

        return nil
    }

    static func compare(
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        gid: String,
        token: String
    ) -> Comparison {
        guard let storedSignature = parse(remoteVersionSignature),
              let latestSignature = parse(latestRemoteVersionSignature)
        else {
            return .incomparable
        }

        switch (storedSignature, latestSignature) {
        case let (.chain(storedGID, storedToken), .chain(latestGID, latestToken)):
            return storedGID == latestGID && storedToken == latestToken ? .same : .different

        case let (.hash(storedHash), .hash(latestHash)):
            return storedHash == latestHash ? .same : .different

        case (.hash, .chain):
            return latestRemoteVersionSignature == chainVersionIdentifier(gid: gid, token: token)
                ? .same
                : .incomparable

        case (.chain, .hash):
            return .incomparable
        }
    }

    static func canonicalizeStoredSignatureIfSafe(
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        gid: String,
        token: String
    ) -> String? {
        guard case .hash = parse(remoteVersionSignature),
              case .chain = parse(latestRemoteVersionSignature),
              latestRemoteVersionSignature == chainVersionIdentifier(gid: gid, token: token)
        else {
            return nil
        }
        return latestRemoteVersionSignature
    }

    static func hasUpdateComparison(
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        gid: String,
        token: String
    ) -> Comparison {
        compare(
            remoteVersionSignature: remoteVersionSignature,
            latestRemoteVersionSignature: latestRemoteVersionSignature,
            gid: gid,
            token: token
        )
    }

    private static func normalizedPreviewSignatureValue(url: URL) -> String {
        let lastPathComponent = url.lastPathComponent
        guard lastPathComponent.notEmpty else {
            return normalizedCoverSignatureValue(url: url)
        }
        return lastPathComponent
    }

    private static func normalizedCoverSignatureValue(url: URL?) -> String {
        guard let url else { return "" }
        let stablePathComponents = url.pathComponents
            .filter { $0 != "/" && $0.notEmpty }
        return stablePathComponents.joined(separator: "/")
    }
}
