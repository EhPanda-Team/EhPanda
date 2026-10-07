#if DEBUG
import CryptoKit
import Foundation

/// The two fixture schemas a capture launch accepts, decoded from a fixture version's
/// `manifest.json`.
///
/// The public regression export (17-01) carries no selection fields at all. The real marketing
/// manifest (17-03) names its `selection.json` by digest, so the validated pair travels together.
enum CaptureFixtureManifest: Equatable, Sendable {
    case regressionPublic(PublicCaptureManifest)
    case marketingReal(MarketingCaptureManifest, selection: CaptureSelection)
}

/// The public regression export's manifest (17-01).
struct PublicCaptureManifest: Equatable, Sendable {
    struct Asset: Equatable, Sendable {
        let path: String
        let mime: String
        let bytes: Int
        let sha256: String
    }

    let schemaVersion: Int
    let fixtureVersion: String
    let aggregateDigest: String
    let fixtureIDs: [String]
    let generatorSources: [String: String]
    let assets: [Asset]
}

/// The real marketing fixture's manifest (17-03). Its retrieval and acquisition times are
/// checked for presence and type but not kept: they are the only fields that differ between two
/// acquisitions of the same bytes, which share one fixture version, so no scene may depend on them.
struct MarketingCaptureManifest: Equatable, Sendable {
    struct Asset: Equatable, Sendable {
        let kind: Kind
        let gid: String
        let index: Int?
        /// The exact request URL this asset answers during replay.
        let url: String
        let path: String
        let mime: String
        let bytes: Int
        let sha256: String
    }

    enum Kind: String, Decodable, Sendable {
        case detail
        case thumbnails
        case imagePage
        case cover
        case preview
        case page

        var isPage: Bool {
            switch self {
            case .detail, .thumbnails, .imagePage:
                true
            case .cover, .preview, .page:
                false
            }
        }
    }

    let schemaVersion: Int
    let purpose: String
    let fixtureVersion: String
    let aggregateDigest: String
    let selectionID: String
    let selectionStatus: String
    let selectionAuthority: String
    let selectionSHA256: String
    let generatorSources: [String: String]
    let assets: [Asset]
}

/// The parts of a marketing `selection.json` that capture scenes read.
///
/// Decoding is deliberately partial: the manifest binds this file by SHA-256, and acquisition
/// validated its complete schema before publishing it, so a scene only needs typed access to
/// the sections it shows. Sections no scene reads yet, such as the reader flow, are not decoded.
struct CaptureSelection: Equatable, Sendable, Decodable {
    struct Gallery: Equatable, Sendable, Decodable {
        let url: URL
        let set: String
    }

    struct Scene: Equatable, Sendable, Decodable {
        let home: Home
    }

    struct Home: Equatable, Sendable, Decodable {
        let hero: Hero
        let frontpage: [String]
        /// Gallery IDs by Toplists period: `yesterday`, `pastMonth`, `pastYear` and `allTime`.
        let toplists: [String: [String]]
    }

    struct Hero: Equatable, Sendable, Decodable {
        let galleries: [String]
        let selectedIndex: Int
    }

    let schemaVersion: Int
    let selectionID: String
    let selectionStatus: String
    let selectionAuthority: String
    let galleries: [Gallery]
    /// Scenes by selection set, such as `nonexplicit`.
    let scenes: [String: Scene]
}

/// One validated fixture version: its manifest and the verified bytes of every file it lists.
///
/// Scenes read only these bytes, which are the ones loading checked, so a file replaced after
/// validation can never reach a scene.
struct CaptureFixture: Sendable {
    static let manifestPath = "manifest.json"
    static let selectionPath = "selection.json"

    let manifest: CaptureFixtureManifest
    /// Verified contents by fixture-relative path, including `selection.json` for marketing.
    let files: [String: Data]

    /// Loads and validates the fixture version at `directory` for `purpose`.
    ///
    /// Rejects the other purpose's schema, unknown or missing manifest keys, non-canonical or
    /// repeated paths, unsupported media types, symbolic links, unlisted or missing files, a length
    /// or SHA-256 mismatch, a selection that differs from the one named, and an aggregate digest
    /// or version that differs from the listed assets.
    static func load(
        directory: URL,
        purpose: CaptureSceneConfiguration.Purpose
    ) throws(CaptureFailure) -> Self {
        try requireRealDirectory(directory)
        let manifestData = try read(manifestPath, in: directory)
        switch purpose {
        case .regressionPublic:
            let manifest = try decode(PublicManifestPayload.self, from: manifestData, purpose: purpose).manifest
            let assets = manifest.assets.map({ ListedFile(path: $0.path, bytes: $0.bytes, sha256: $0.sha256) })
            for asset in manifest.assets where !publicMIMETypes.contains(asset.mime) {
                throw .malformedManifest("unsupported media type for \(asset.path)")
            }
            var files = try verifiedFiles(assets, controlPaths: [manifestPath], in: directory)
            guard manifest.aggregateDigest == (try aggregateDigest(of: manifest.assets)) else {
                throw .identityMismatch
            }
            files[manifestPath] = manifestData
            return Self(manifest: .regressionPublic(manifest), files: files)
        case .marketingReal:
            let manifest = try decode(MarketingManifestPayload.self, from: manifestData, purpose: purpose).manifest
            let assets = manifest.assets.map({ ListedFile(path: $0.path, bytes: $0.bytes, sha256: $0.sha256) })
            for asset in manifest.assets where !isSupportedMIMEType(of: asset) {
                throw .malformedManifest("unsupported media type for \(asset.path)")
            }
            guard Set(manifest.assets.map(\.url)).count == manifest.assets.count else {
                throw .malformedManifest("two assets answer one replay URL")
            }
            var files = try verifiedFiles(assets, controlPaths: [manifestPath, selectionPath], in: directory)
            let selectionData = try read(selectionPath, in: directory)
            let selection = try selection(selectionData, of: manifest)
            let aggregate = try aggregateDigest(of: manifest.assets, selectionSHA256: manifest.selectionSHA256)
            guard aggregate == manifest.aggregateDigest, manifest.fixtureVersion == "marketing-\(aggregate.prefix(16))"
            else {
                throw .identityMismatch
            }
            files[manifestPath] = manifestData
            files[selectionPath] = selectionData
            return Self(manifest: .marketingReal(manifest, selection: selection), files: files)
        }
    }
}

// MARK: Identity
extension CaptureFixture {
    /// The public exporter's aggregate digest: SHA-256 of its own pretty-printed encoding of the
    /// asset list.
    static func aggregateDigest(of assets: [PublicCaptureManifest.Asset]) throws(CaptureFailure) -> String {
        sha256(try encode(assets, formatting: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]))
    }

    /// The acquisition tool's aggregate digest: SHA-256 of its canonical JSON (sorted keys, no
    /// whitespace, unescaped slashes) of every asset entry except its retrieval time, beside the
    /// selection digest.
    static func aggregateDigest(
        of assets: [MarketingCaptureManifest.Asset],
        selectionSHA256: String
    ) throws(CaptureFailure) -> String {
        let identity = MarketingIdentity(assets: assets, selectionSHA256: selectionSHA256)
        return sha256(try encode(identity, formatting: [.sortedKeys, .withoutEscapingSlashes]))
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined()
    }

    private static func encode(
        _ value: some Encodable,
        formatting: JSONEncoder.OutputFormatting
    ) throws(CaptureFailure) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = formatting
        do {
            return try encoder.encode(value)
        } catch {
            throw .malformedManifest("assets cannot be re-encoded for their digest")
        }
    }
}

// MARK: Validation
private extension CaptureFixture {
    struct ListedFile {
        let path: String
        let bytes: Int
        let sha256: String
    }

    /// Media the public generator writes: rendered artwork and JSON metadata.
    static let publicMIMETypes: Set = ["application/json", "image/gif", "image/jpeg", "image/png", "image/webp"]
    /// Media an image request may answer with, matching the acquisition tool's set.
    static let mediaMIMETypes: Set = ["image/gif", "image/jpeg", "image/png", "image/webp"]

    /// Pages are saved HTML; every other kind is an image the acquisition tool accepted.
    static func isSupportedMIMEType(of asset: MarketingCaptureManifest.Asset) -> Bool {
        asset.kind.isPage ? asset.mime == "text/html" : mediaMIMETypes.contains(asset.mime)
    }

    static func decode<Payload: Decodable>(
        _: Payload.Type,
        from data: Data,
        purpose: CaptureSceneConfiguration.Purpose
    ) throws(CaptureFailure) -> Payload {
        // Only the marketing schema has a `purpose` key, so its presence alone tells the two apart.
        let hasPurpose: Bool
        do {
            hasPurpose = try JSONDecoder().decode(PurposeProbe.self, from: data).purpose != nil
        } catch {
            throw .malformedManifest(CaptureFailure.describe(error))
        }
        guard hasPurpose == (purpose == .marketingReal) else {
            throw .purposeMismatch(configured: purpose)
        }
        do {
            return try JSONDecoder().decode(Payload.self, from: data)
        } catch let failure as PurposeFailure {
            throw failure.failure
        } catch {
            throw .malformedManifest(CaptureFailure.describe(error))
        }
    }

    /// Reads every listed file after checking that the directory holds exactly the listed files
    /// and the control files, none of them reached through a symbolic link.
    static func verifiedFiles(
        _ listed: [ListedFile],
        controlPaths: Set<String>,
        in directory: URL
    ) throws(CaptureFailure) -> [String: Data] {
        let paths = listed.map(\.path)
        for path in paths where !isCanonicalRelativePath(path) || controlPaths.contains(path) {
            throw .unsafePath(path)
        }
        guard Set(paths).count == paths.count else {
            throw .malformedManifest("an asset path is listed twice")
        }
        guard paths == paths.sorted() else {
            throw .malformedManifest("assets are not listed in path order")
        }
        let present = try regularFiles(in: directory)
        let expected = Set(paths).union(controlPaths)
        if let unexpected = present.subtracting(expected).min() {
            throw .unexpectedFile(unexpected)
        }
        if let missing = expected.subtracting(present).min() {
            throw .missingFile(missing)
        }
        var files = [String: Data]()
        for file in listed {
            let data = try read(file.path, in: directory)
            guard data.count == file.bytes else { throw .sizeMismatch(file.path) }
            guard sha256(data) == file.sha256 else { throw .checksumMismatch(file.path) }
            files[file.path] = data
        }
        return files
    }

    /// Requires `directory` to be a directory itself rather than a link to one: the harness
    /// resolves a moving `current` link once and passes the version directory it found.
    static func requireRealDirectory(_ directory: URL) throws(CaptureFailure) {
        // Looked up without the trailing slash a directory URL carries, which would follow a link.
        var path = directory.standardizedFileURL.path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        let values: URLResourceValues
        do {
            values = try URL(filePath: path, directoryHint: .notDirectory)
                .resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        } catch {
            throw .missingFixtureDirectory
        }
        guard values.isSymbolicLink != true else { throw .symbolicLink(".") }
        guard values.isDirectory == true else { throw .missingFixtureDirectory }
    }

    /// Every regular file under `directory` by relative path; any symbolic link inside fails,
    /// because a link could redirect a listed path outside the fixture.
    static func regularFiles(in directory: URL) throws(CaptureFailure) -> Set<String> {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        let root = directory.standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys))
        else {
            throw .unreadableFile(".")
        }
        var files = Set<String>()
        for case let url as URL in enumerator {
            let path = url.standardizedFileURL.pathComponents
                .dropFirst(root.pathComponents.count)
                .joined(separator: "/")
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: keys)
            } catch {
                throw .unreadableFile(path)
            }
            if values.isSymbolicLink == true {
                throw .symbolicLink(path)
            }
            if values.isRegularFile == true {
                files.insert(path)
            } else if values.isDirectory != true {
                throw .unexpectedFile(path)
            }
        }
        return files
    }

    /// A relative path of non-empty components, none of them `.` or `..`, that names one file
    /// inside the fixture in exactly one spelling.
    static func isCanonicalRelativePath(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.isEmpty && components.allSatisfy({ component in
            !component.isEmpty && component != "." && component != ".."
                && !component.contains("\\") && component.unicodeScalars.allSatisfy({ $0.value >= 0x20 })
        })
    }

    static func read(_ path: String, in directory: URL) throws(CaptureFailure) -> Data {
        do {
            return try Data(contentsOf: directory.appending(path: path), options: .uncached)
        } catch {
            throw .unreadableFile(path)
        }
    }

    static func selection(
        _ data: Data,
        of manifest: MarketingCaptureManifest
    ) throws(CaptureFailure) -> CaptureSelection {
        guard sha256(data) == manifest.selectionSHA256 else { throw .selectionMismatch }
        let selection: CaptureSelection
        do {
            selection = try JSONDecoder().decode(CaptureSelection.self, from: data)
        } catch {
            throw .malformedScene("selection.json: \(CaptureFailure.describe(error))")
        }
        guard
            selection.schemaVersion == 1,
            selection.selectionID == manifest.selectionID,
            selection.selectionStatus == manifest.selectionStatus,
            selection.selectionAuthority == manifest.selectionAuthority
        else {
            throw .selectionMismatch
        }
        return selection
    }
}

// MARK: Decoding
private struct PurposeProbe: Decodable {
    let purpose: String?
}

/// Lets a payload decoder report a purpose mismatch, which is not a malformed manifest.
private struct PurposeFailure: Error {
    let failure: CaptureFailure
}

private struct PublicManifestPayload: Decodable {
    let manifest: PublicCaptureManifest

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case fixtureVersion
        case aggregateDigest
        case fixtureIDs
        case generatorSources
        case assets
    }

    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: container, debugDescription: "unsupported schema version"
            )
        }
        manifest = .init(
            schemaVersion: schemaVersion,
            fixtureVersion: try container.decode(String.self, forKey: .fixtureVersion),
            aggregateDigest: try container.decode(String.self, forKey: .aggregateDigest),
            fixtureIDs: try container.decode([String].self, forKey: .fixtureIDs),
            generatorSources: try container.decode([String: String].self, forKey: .generatorSources),
            assets: try container.decode([PublicCaptureManifest.Asset].self, forKey: .assets)
        )
    }
}

extension PublicCaptureManifest.Asset: Codable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case path
        case mime
        case bytes
        case sha256
    }

    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        mime = try container.decode(String.self, forKey: .mime)
        bytes = try container.decode(Int.self, forKey: .bytes)
        sha256 = try container.decode(String.self, forKey: .sha256)
    }
}

private struct MarketingManifestPayload: Decodable {
    let manifest: MarketingCaptureManifest

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case purpose
        case fixtureVersion
        case aggregateDigest
        case selectionID
        case selectionStatus
        case selectionAuthority
        case selectionSHA256
        case generatorSources
        case acquiredAt
        case assets
    }

    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: container, debugDescription: "unsupported schema version"
            )
        }
        let purpose = try container.decode(String.self, forKey: .purpose)
        guard purpose == CaptureSceneConfiguration.Purpose.marketingReal.rawValue else {
            throw PurposeFailure(failure: .purposeMismatch(configured: .marketingReal))
        }
        manifest = .init(
            schemaVersion: schemaVersion,
            purpose: purpose,
            fixtureVersion: try container.decode(String.self, forKey: .fixtureVersion),
            aggregateDigest: try container.decode(String.self, forKey: .aggregateDigest),
            selectionID: try container.decode(String.self, forKey: .selectionID),
            selectionStatus: try container.decode(String.self, forKey: .selectionStatus),
            selectionAuthority: try container.decode(String.self, forKey: .selectionAuthority),
            selectionSHA256: try container.decode(String.self, forKey: .selectionSHA256),
            generatorSources: try container.decode([String: String].self, forKey: .generatorSources),
            assets: try container.decode([MarketingCaptureManifest.Asset].self, forKey: .assets)
        )
        _ = try container.decode(String.self, forKey: .acquiredAt)
    }
}

extension MarketingCaptureManifest.Asset: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case gid
        case index
        case url
        case path
        case mime
        case bytes
        case sha256
        case retrievedAt
    }

    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(MarketingCaptureManifest.Kind.self, forKey: .kind)
        gid = try container.decode(String.self, forKey: .gid)
        index = try container.decode(Int?.self, forKey: .index)
        url = try container.decode(String.self, forKey: .url)
        path = try container.decode(String.self, forKey: .path)
        mime = try container.decode(String.self, forKey: .mime)
        bytes = try container.decode(Int.self, forKey: .bytes)
        sha256 = try container.decode(String.self, forKey: .sha256)
        _ = try container.decode(String.self, forKey: .retrievedAt)
    }
}

/// The acquisition tool's version identity: every asset entry except its retrieval time, beside
/// the selection digest. Its canonical encoding is what the aggregate digest hashes.
private struct MarketingIdentity: Encodable {
    struct Entry {
        let asset: MarketingCaptureManifest.Asset
    }

    let assets: [Entry]
    let selectionSHA256: String

    init(assets: [MarketingCaptureManifest.Asset], selectionSHA256: String) {
        self.assets = assets.map(Entry.init)
        self.selectionSHA256 = selectionSHA256
    }
}

extension MarketingIdentity.Entry: Encodable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case gid
        case index
        case url
        case path
        case mime
        case bytes
        case sha256
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(asset.kind.rawValue, forKey: .kind)
        try container.encode(asset.gid, forKey: .gid)
        // `encode`, not `encodeIfPresent`: the canonical form writes a missing index as null.
        try container.encode(asset.index, forKey: .index)
        try container.encode(asset.url, forKey: .url)
        try container.encode(asset.path, forKey: .path)
        try container.encode(asset.mime, forKey: .mime)
        try container.encode(asset.bytes, forKey: .bytes)
        try container.encode(asset.sha256, forKey: .sha256)
    }
}
#endif
