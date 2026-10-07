@testable import AppFeature
import CustomDump
import Foundation
import ParserFeature
import Testing
import TestingSupport

// A capture loads one fixture version and verifies it completely before any scene reads it.
// Every fixture here is built inline in a fresh temporary directory; no real gallery content is
// involved. The aggregate digests are pinned to values computed by the fixture tools themselves
// (Scripts/visual), so the app and the tools cannot drift apart unnoticed.
struct CaptureFixtureTests {
    @Test
    func aggregateDigestsMatchTheFixtureTools() throws {
        let publicAssets = [
            PublicCaptureManifest.Asset(
                path: "assets/home/0.png",
                mime: "image/png",
                bytes: 3,
                sha256: "8f8cbb7dcf46e0bc7d53265749a6c17d116093a6ba95e442764060c76fd4a86c"
            ),
            PublicCaptureManifest.Asset(
                path: "metadata/home.json",
                mime: "application/json",
                bytes: 2,
                sha256: "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
            )
        ]
        let marketingAssets = [
            MarketingCaptureManifest.Asset(
                kind: .cover,
                gid: "1",
                index: nil,
                url: "https://ehgt.org/w/00/000/1-a.webp",
                path: "assets/1/cover.webp",
                mime: "image/webp",
                bytes: 4,
                sha256: "a57bb082e728a0cdce930ecfcccf4510a3a247be5f322b09b3a971a3f5ed34f8"
            ),
            MarketingCaptureManifest.Asset(
                kind: .detail,
                gid: "1",
                index: nil,
                url: "https://e-hentai.org/g/1/0123456789/?hc=1",
                path: "responses/1/detail.html",
                mime: "text/html",
                bytes: 4,
                sha256: "e5e239560bc125a20ff2ac1fea50915bc198dd4f5b5256ec447a8a71e00132b3"
            ),
            MarketingCaptureManifest.Asset(
                kind: .page,
                gid: "1",
                index: 3,
                url: "https://abc.hath.network/h/x",
                path: "assets/1/pages/3.webp",
                mime: "image/webp",
                bytes: 4,
                sha256: "3660315a9af3df255d8f19ab077e4797822b41488a0e2a04bc6af71213c23274"
            )
        ]

        expectNoDifference(
            try CaptureFixture.aggregateDigest(of: publicAssets),
            "64eec8d999fb1fbedb13ca8cc3427c4b7a884b4fb0ae12a25c6ef9991f9de65f"
        )
        let selectionSHA256 = String(repeating: "ab", count: 32)
        expectNoDifference(
            try CaptureFixture.aggregateDigest(of: marketingAssets, selectionSHA256: selectionSHA256),
            "a4a7f95256f59ae46eb1a996e7b901ef9104e185b5b415616717e72f3b911beb"
        )
    }

    @Test
    func marketingFixtureLoadsEveryVerifiedFile() throws {
        let fixture = try MarketingFixtureBuilder.standard()
        let directory = try fixture.write()

        let loaded = try CaptureFixture.load(directory: directory, purpose: .marketingReal)

        guard case .marketingReal(let manifest, let selection) = loaded.manifest else {
            Issue.record("Expected a marketing manifest")
            return
        }
        expectNoDifference(manifest.fixtureVersion, try fixture.fixtureVersion())
        expectNoDifference(selection.selectionID, "test-selection")
        expectNoDifference(
            Set(loaded.files.keys),
            Set(fixture.files.map(\.path)).union([CaptureFixture.manifestPath, CaptureFixture.selectionPath])
        )
        for file in fixture.files {
            expectNoDifference(loaded.files[file.path], file.data)
        }
    }

    @Test
    func publicFixtureLoadsWithoutSelectionFields() throws {
        let directory = try PublicFixtureBuilder().write()

        let loaded = try CaptureFixture.load(directory: directory, purpose: .regressionPublic)

        guard case .regressionPublic(let manifest) = loaded.manifest else {
            Issue.record("Expected a public manifest")
            return
        }
        expectNoDifference(manifest.fixtureIDs, ["home-finite"])
        expectNoDifference(manifest.fixtureVersion, "test-public-v1")
    }

    @Test
    func aFixtureOfThePurposeNotConfiguredIsRejected() throws {
        let publicDirectory = try PublicFixtureBuilder().write()
        let marketingDirectory = try MarketingFixtureBuilder.standard().write()
        var relabeled = try MarketingFixtureBuilder.standard()
        relabeled.editManifest = { $0["purpose"] = "regressionPublic" }
        let relabeledDirectory = try relabeled.write()

        #expect(throws: CaptureFailure.purposeMismatch(configured: .marketingReal)) {
            try CaptureFixture.load(directory: publicDirectory, purpose: .marketingReal)
        }
        #expect(throws: CaptureFailure.purposeMismatch(configured: .regressionPublic)) {
            try CaptureFixture.load(directory: marketingDirectory, purpose: .regressionPublic)
        }
        #expect(throws: CaptureFailure.purposeMismatch(configured: .marketingReal)) {
            try CaptureFixture.load(directory: relabeledDirectory, purpose: .marketingReal)
        }
    }

    @Test(arguments: Tampering.all)
    func aTamperedMarketingFixtureIsRejected(_ tampering: Tampering) throws {
        var fixture = try MarketingFixtureBuilder.standard()
        tampering.editBuilder(&fixture)
        let directory = try fixture.write()
        try tampering.editDirectory(directory)

        let error = #expect(throws: CaptureFailure.self) {
            try CaptureFixture.load(directory: directory, purpose: .marketingReal)
        }
        let failure = try #require(error)
        #expect(tampering.accepts(failure), "\(tampering.name) failed with \(failure)")
    }

    @Test
    func aTamperedPublicFixtureIsRejected() throws {
        var fixture = PublicFixtureBuilder()
        fixture.editManifest = { $0["aggregateDigest"] = String(repeating: "0", count: 64) }
        let wrongDigest = try fixture.write()
        let changedFile = try PublicFixtureBuilder().write()
        try Data("PNG".utf8).write(to: changedFile.appending(path: "assets/home/0.png"))

        #expect(throws: CaptureFailure.identityMismatch) {
            try CaptureFixture.load(directory: wrongDigest, purpose: .regressionPublic)
        }
        #expect(throws: CaptureFailure.checksumMismatch("assets/home/0.png")) {
            try CaptureFixture.load(directory: changedFile, purpose: .regressionPublic)
        }
    }

    @Test
    func aFixtureDirectoryReachedThroughALinkIsRejected() throws {
        let directory = try MarketingFixtureBuilder.standard().write()
        let link = directory.deletingLastPathComponent().appending(path: "linked-fixture")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        // Spelled as a launch spells it, with the trailing slash that makes path lookups follow a link.
        let launchSpelling = URL(filePath: link.path(percentEncoded: false), directoryHint: .isDirectory)

        #expect(throws: CaptureFailure.symbolicLink(".")) {
            try CaptureFixture.load(directory: launchSpelling, purpose: .marketingReal)
        }
    }
}

// MARK: Tampering
struct Tampering: Sendable, CustomTestStringConvertible {
    let name: String
    var editBuilder: @Sendable (inout MarketingFixtureBuilder) -> Void = { _ in }
    var editDirectory: @Sendable (URL) throws -> Void = { _ in }
    let accepts: @Sendable (CaptureFailure) -> Bool

    var testDescription: String { name }

    static let coverPath = "assets/101/cover.webp"

    static let all: [Self] = [
        Self(
            name: "changed bytes",
            editDirectory: { try Data("COVER".utf8).write(to: $0.appending(path: coverPath)) },
            accepts: { $0 == .checksumMismatch(coverPath) }
        ),
        Self(
            name: "appended byte",
            editDirectory: { try Data("cover!".utf8).write(to: $0.appending(path: coverPath)) },
            accepts: { $0 == .sizeMismatch(coverPath) }
        ),
        Self(
            name: "missing file",
            editDirectory: { try FileManager.default.removeItem(at: $0.appending(path: coverPath)) },
            accepts: { $0 == .missingFile(coverPath) }
        ),
        Self(
            name: "unlisted file",
            editDirectory: { try Data().write(to: $0.appending(path: "extra.txt")) },
            accepts: { $0 == .unexpectedFile("extra.txt") }
        ),
        Self(
            name: "linked file",
            editDirectory: { directory in
                let outside = directory.deletingLastPathComponent().appending(path: "outside.webp")
                try Data("cover".utf8).write(to: outside)
                try FileManager.default.removeItem(at: directory.appending(path: coverPath))
                try FileManager.default.createSymbolicLink(
                    at: directory.appending(path: coverPath),
                    withDestinationURL: outside
                )
            },
            accepts: { $0 == .symbolicLink(coverPath) }
        ),
        Self(
            name: "escaping path",
            editBuilder: { $0.editAsset = { asset in asset["path"] = "../escape.webp" } },
            accepts: { $0 == .unsafePath("../escape.webp") }
        ),
        Self(
            name: "absolute path",
            editBuilder: { $0.editAsset = { asset in asset["path"] = "/tmp/escape.webp" } },
            accepts: { $0 == .unsafePath("/tmp/escape.webp") }
        ),
        Self(
            name: "unknown manifest key",
            editBuilder: { $0.editManifest = { $0["extra"] = 1 } },
            accepts: { $0 == .malformedManifest(#"unknown keys ["extra"], missing keys []"#) }
        ),
        Self(
            name: "missing manifest key",
            editBuilder: { $0.editManifest = { $0["acquiredAt"] = nil } },
            accepts: { $0 == .malformedManifest(#"unknown keys [], missing keys ["acquiredAt"]"#) }
        ),
        Self(
            name: "unknown asset key",
            editBuilder: { $0.editAsset = { asset in asset["extra"] = 1 } },
            accepts: isMalformedManifest
        ),
        Self(
            name: "boolean schema version",
            editBuilder: { $0.editManifest = { $0["schemaVersion"] = true } },
            accepts: isMalformedManifest
        ),
        Self(
            name: "newer schema version",
            editBuilder: { $0.editManifest = { $0["schemaVersion"] = 2 } },
            accepts: isMalformedManifest
        ),
        Self(
            name: "unsupported media type",
            editBuilder: { $0.editAsset = { asset in asset["mime"] = "image/bmp" } },
            accepts: { $0 == .malformedManifest("unsupported media type for \(coverPath)") }
        ),
        Self(
            name: "page media type on an image",
            editBuilder: { $0.editAsset = { asset in asset["mime"] = "text/html" } },
            accepts: { $0 == .malformedManifest("unsupported media type for \(coverPath)") }
        ),
        Self(
            name: "repeated replay URL",
            editBuilder: { builder in
                let detailURL = builder.files.first(where: { $0.kind == .detail })?.url ?? ""
                builder.editAsset = { asset in asset["url"] = detailURL }
            },
            accepts: { $0 == .malformedManifest("two assets answer one replay URL") }
        ),
        Self(
            name: "assets out of path order",
            editBuilder: { $0.reversesAssets = true },
            accepts: { $0 == .malformedManifest("assets are not listed in path order") }
        ),
        Self(
            name: "changed selection",
            editDirectory: { directory in
                let url = directory.appending(path: CaptureFixture.selectionPath)
                try (Data(contentsOf: url) + Data(" ".utf8)).write(to: url)
            },
            accepts: { $0 == .selectionMismatch }
        ),
        Self(
            name: "selection identity differs from the manifest",
            editBuilder: { $0.manifestSelectionID = "another-selection" },
            accepts: { $0 == .selectionMismatch }
        ),
        Self(
            name: "wrong aggregate digest",
            editBuilder: { $0.editManifest = { $0["aggregateDigest"] = String(repeating: "0", count: 64) } },
            accepts: { $0 == .identityMismatch }
        ),
        Self(
            name: "wrong fixture version",
            editBuilder: { $0.editManifest = { $0["fixtureVersion"] = "marketing-0000000000000000" } },
            accepts: { $0 == .identityMismatch }
        )
    ]

    private static let isMalformedManifest: @Sendable (CaptureFailure) -> Bool = { failure in
        guard case .malformedManifest = failure else {
            return false
        }
        return true
    }
}

// MARK: Builders
/// One fixture file: its manifest entry fields and its bytes.
struct FixtureFile: Sendable {
    let kind: MarketingCaptureManifest.Kind
    let gid: String
    let index: Int?
    let url: String
    let path: String
    let mime: String
    let data: Data
}

/// Writes a marketing fixture version (17-03 schema) into a fresh temporary directory, with
/// optional edits applied after the identity is computed, as tampering would.
struct MarketingFixtureBuilder: Sendable {
    static let token = "0123456789"
    static let heroGIDs = ["101", "102", "103"]
    static let frontpageGIDs = ["104"]
    /// One gallery per Toplists period, in `yesterday`, `pastMonth`, `pastYear`, `allTime` order.
    static let toplistsGIDs = ["105", "106", "107", "108"]
    static var allGIDs: [String] { heroGIDs + frontpageGIDs + toplistsGIDs }

    var files: [FixtureFile]
    var selectedIndex = 1
    var toplistsPeriods = ["yesterday", "pastMonth", "pastYear", "allTime"]
    var manifestSelectionID = "test-selection"
    var reversesAssets = false
    /// Edits the first cover's manifest entry.
    var editAsset: @Sendable (inout [String: Any]) -> Void = { _ in }
    var editManifest: @Sendable (inout [String: Any]) -> Void = { _ in }

    /// Every selected gallery's detail page, using the parser tests' saved page, and one cover at
    /// `coverURL`, which the saved page names unless a test says otherwise.
    static func standard(coverURL: String? = nil) throws -> Self {
        let page = try savedDetailPage()
        var files = allGIDs.map { gid in
            FixtureFile(
                kind: .detail,
                gid: gid,
                index: nil,
                url: "https://e-hentai.org/g/\(gid)/\(token)/?hc=1",
                path: "responses/\(gid)/detail.html",
                mime: "text/html",
                data: page.data
            )
        }
        files.append(
            FixtureFile(
                kind: .cover,
                gid: "101",
                index: nil,
                url: coverURL ?? page.coverURL,
                path: Tampering.coverPath,
                mime: "image/webp",
                data: Data("cover".utf8)
            )
        )
        return Self(files: files)
    }

    func selectionData() throws -> Data {
        let toplists = Dictionary(uniqueKeysWithValues: zip(toplistsPeriods, Self.toplistsGIDs.map({ [$0] })))
        let selection: [String: Any] = [
            "schemaVersion": 1,
            "selectionID": "test-selection",
            "selectionStatus": "provisional",
            "selectionAuthority": "agent-delegated",
            "galleries": Self.allGIDs.map({ gid in
                ["url": "https://e-hentai.org/g/\(gid)/\(Self.token)/", "set": "nonexplicit"]
            }),
            "scenes": [
                "nonexplicit": [
                    "home": [
                        "hero": ["galleries": Self.heroGIDs, "selectedIndex": selectedIndex],
                        "frontpage": Self.frontpageGIDs,
                        "toplists": toplists
                    ],
                    "flow": ["gallery": "101", "readerPage": 1, "liveTextPage": 1, "pages": [1]],
                    "downloads": [[String: Any]]()
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: selection, options: [.prettyPrinted, .sortedKeys])
    }

    func fixtureVersion() throws -> String {
        "marketing-\(try aggregateDigest().prefix(16))"
    }

    /// Writes the fixture and returns its directory.
    func write() throws -> URL {
        let directory = try makeTemporaryDirectory()
        let selection = try selectionData()
        let aggregate = try aggregateDigest()
        let sortedFiles = files.sorted(by: { $0.path < $1.path })
        var entries = sortedFiles.map { file -> [String: Any] in
            [
                "kind": file.kind.rawValue,
                "gid": file.gid,
                "index": file.index.map({ $0 as Any }) ?? NSNull(),
                "url": file.url,
                "path": file.path,
                "mime": file.mime,
                "bytes": file.data.count,
                "sha256": CaptureFixture.sha256(file.data),
                "retrievedAt": "2026-10-07T00:00:00+00:00"
            ]
        }
        if let coverIndex = sortedFiles.firstIndex(where: { $0.kind == .cover }) {
            editAsset(&entries[coverIndex])
        }
        var manifest: [String: Any] = [
            "schemaVersion": 1,
            "purpose": "marketingReal",
            "fixtureVersion": "marketing-\(aggregate.prefix(16))",
            "aggregateDigest": aggregate,
            "selectionID": manifestSelectionID,
            "selectionStatus": "provisional",
            "selectionAuthority": "agent-delegated",
            "selectionSHA256": CaptureFixture.sha256(selection),
            "generatorSources": ["Scripts/visual/fixtures.py": String(repeating: "0", count: 64)],
            "acquiredAt": "2026-10-07T00:00:00+00:00",
            "assets": reversesAssets ? entries.reversed() : entries
        ]
        editManifest(&manifest)
        for file in files {
            try writeFile(file.data, to: directory.appending(path: file.path))
        }
        try selection.write(to: directory.appending(path: CaptureFixture.selectionPath))
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: CaptureFixture.manifestPath))
        return directory
    }

    private func aggregateDigest() throws -> String {
        let assets = files.sorted(by: { $0.path < $1.path }).map { file in
            MarketingCaptureManifest.Asset(
                kind: file.kind,
                gid: file.gid,
                index: file.index,
                url: file.url,
                path: file.path,
                mime: file.mime,
                bytes: file.data.count,
                sha256: CaptureFixture.sha256(file.data)
            )
        }
        let selectionSHA256 = CaptureFixture.sha256(try selectionData())
        return try CaptureFixture.aggregateDigest(of: assets, selectionSHA256: selectionSHA256)
    }

    /// The parser tests' saved detail page and the cover URL the app's parser reads from it.
    private static func savedDetailPage() throws -> (data: Data, coverURL: String) {
        let filename = HTMLFilename.galleryDetail
        let url = try #require(TestFixtures.url(forResource: filename.rawValue, withExtension: "html"))
        let parsed = try Parser.parseGalleryDetail(doc: SavedPages().htmlDocument(filename: filename), gid: "101")
        let coverURL = try #require(parsed.detail.coverURL)
        return (try Data(contentsOf: url), coverURL.absoluteString)
    }
}

private struct SavedPages: TestHelper {}

/// Writes a public regression fixture version (17-01 schema) into a fresh temporary directory.
struct PublicFixtureBuilder: Sendable {
    var editManifest: @Sendable (inout [String: Any]) -> Void = { _ in }

    let files = [
        (path: "assets/home/0.png", mime: "image/png", data: Data("png".utf8)),
        (path: "metadata/home.json", mime: "application/json", data: Data("{}".utf8))
    ]

    func write() throws -> URL {
        let directory = try makeTemporaryDirectory()
        let assets = files.map({ file in
            PublicCaptureManifest.Asset(
                path: file.path,
                mime: file.mime,
                bytes: file.data.count,
                sha256: CaptureFixture.sha256(file.data)
            )
        })
        var manifest: [String: Any] = [
            "schemaVersion": 1,
            "fixtureVersion": "test-public-v1",
            "aggregateDigest": try CaptureFixture.aggregateDigest(of: assets),
            "fixtureIDs": ["home-finite"],
            "generatorSources": ["AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift": "0"],
            "assets": assets.map({ ["path": $0.path, "mime": $0.mime, "bytes": $0.bytes, "sha256": $0.sha256] })
        ]
        editManifest(&manifest)
        for file in files {
            try writeFile(file.data, to: directory.appending(path: file.path))
        }
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: CaptureFixture.manifestPath))
        return directory
    }
}

/// A fresh directory under the test process's temporary directory, holding one fixture version.
func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "capture-fixture-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        .appending(path: "version", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func writeFile(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}
