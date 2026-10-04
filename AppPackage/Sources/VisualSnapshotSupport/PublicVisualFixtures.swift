import CryptoKit
import Foundation
import UIKit

public struct PublicFixtureExport: Sendable {
    public let aggregateDigest: String
    public let manifestURL: URL
}

public struct PublicGalleryFixture: Codable, Sendable {
    public let gid: String
    public let token: String
    public let title: String
    public let pageCount: Int
    public let coverPath: String
    public let colorIndex: Int

}

public enum PublicVisualFixtures {
    public static let schemaVersion = 1
    public static let fixtureVersion = "phase17-finite-v2"
    public static let fixedDate = Date(timeIntervalSince1970: 1_735_689_600)
    public static let fixtureIDs = ["home-finite", "comments-finite", "downloads-finite", "reader-vertical-finite"]
    public static let homeGalleries: [PublicGalleryFixture] = (0..<6).map { index in
        PublicGalleryFixture(
            gid: "VH\(index + 1)", token: "visual-token-\(index)", title: "Visual Home Gallery \(index + 1)",
            pageCount: 24 + index, coverPath: "assets/home/\(index).png", colorIndex: index
        )
    }
    /// Distinct neighbors prevent the infinite carousel's native peeks from repeating a census item.
    /// Their device-dependent, intentionally partial visibility excludes them from the six-item census.
    /// Match VH1's title shape and page count so a neighbor cannot enlarge the carousel's shared row height.
    public static let homeCarouselNeighbors: [PublicGalleryFixture] = (1...2).map { number in
        PublicGalleryFixture(
            gid: "PEEK\(number)", token: "carousel-neighbor-token-\(number)",
            title: "Visual Home Gallery \(number + 6)", pageCount: 24,
            coverPath: "assets/home/carousel-neighbor-\(number).png", colorIndex: number
        )
    }
    public static let downloadGalleries: [PublicGalleryFixture] = (0..<16).map { index in
        PublicGalleryFixture(
            gid: "VD\(index + 1)", token: "download-token-\(index)", title: "Visual Download \(index + 1)",
            pageCount: 8, coverPath: "assets/downloads/\(index).png", colorIndex: index % 6
        )
    }
    public static let commentIDs = (1...12).map({ "VC\($0)" })
    public static let readerPageMarkers = (1...8).map({ "VRP\($0)" })

    @MainActor
    public static func artwork(marker: String, colorIndex: Int, size: CGSize = .init(width: 160, height: 220))
        -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let ratio = size.width / 160
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(hue: CGFloat(colorIndex) / 6, saturation: 0.5, brightness: 0.85, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.fill(CGRect(x: 24 * ratio, y: 32 * ratio, width: 112 * ratio, height: 16 * ratio))
            context.fill(CGRect(x: 24 * ratio, y: 72 * ratio, width: 72 * ratio, height: 8 * ratio))
            (marker as NSString).draw(
                in: CGRect(x: 24 * ratio, y: 105 * ratio, width: 112 * ratio, height: 48 * ratio),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 32 * ratio, weight: .bold),
                    .foregroundColor: UIColor.black
                ]
            )
        }
    }

    /// Exports the fixture set into an empty `directory`.
    ///
    /// - Parameter readerPagePixelWidth: The pixel width to render the 8:11 reader pages at, with the height
    ///   rounded to whole pixels; `nil` keeps the canonical 800 x 1100. The capture harness passes the width the
    ///   coordinate renders a page at (the vertical reader ignores safe areas, so the scene width) so the reader
    ///   never resamples a page. A resampled page straddling the viewport bottom does not render bit-reproducibly
    ///   between the clipped viewport and the unclipped tall window (measured 2026-10-04: +-1 flips on glyph
    ///   edges, 22 px on the 2x iPad at 800 -> 1668 px; 0 px at 1:1 on both devices and at 1.5x on the iPad).
    @MainActor
    public static func export(
        to directory: URL,
        scenarios: Data? = nil,
        readerPagePixelWidth: Int? = nil
    ) throws -> PublicFixtureExport {
        let readerPageSize = readerPagePixelWidth.map({
            CGSize(width: CGFloat($0), height: (Double($0) * 11 / 8).rounded())
        }) ?? CGSize(width: 800, height: 1100)
        var files: [FixtureFile] = []
        for gallery in homeGalleries + homeCarouselNeighbors + downloadGalleries {
            let image = artwork(marker: gallery.gid, colorIndex: gallery.colorIndex)
            guard let bytes = image.pngData() else { throw PublicFixtureError.imageEncodingFailed }
            files.append(FixtureFile(path: gallery.coverPath, mime: "image/png", bytes: bytes))
        }
        for (index, marker) in readerPageMarkers.enumerated() {
            let image = artwork(marker: marker, colorIndex: index % 6, size: readerPageSize)
            guard let bytes = image.pngData() else { throw PublicFixtureError.imageEncodingFailed }
            files.append(FixtureFile(path: "assets/reader/\(index + 1).png", mime: "image/png", bytes: bytes))
            let preview = artwork(marker: marker, colorIndex: index % 6)
            guard let previewBytes = preview.pngData() else { throw PublicFixtureError.imageEncodingFailed }
            files.append(FixtureFile(path: "assets/previews/\(index + 1).png", mime: "image/png", bytes: previewBytes))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        files.append(FixtureFile(
            path: "metadata/home.json", mime: "application/json",
            bytes: try encoder.encode(homeGalleries + homeCarouselNeighbors)
        ))
        files.append(FixtureFile(
            path: "metadata/downloads.json", mime: "application/json", bytes: try encoder.encode(downloadGalleries)
        ))
        let comments: [[String: Any]] = commentIDs.enumerated().map { index, identifier in
            [
                "commentID": identifier, "author": "Public Author", "timestamp": fixedDate.timeIntervalSince1970,
                "contentID": String(format: "00000000-0000-0000-0000-%012d", index + 1),
                "text": commentText(index: index)
            ]
        }
        files.append(FixtureFile(
            path: "metadata/comments.json", mime: "application/json", bytes: try jsonData(comments)
        ))
        let reader: [[String: Any]] = readerPageMarkers.enumerated().map { index, marker in
            ["page": index + 1, "marker": marker, "asset": "assets/reader/\(index + 1).png"]
        }
        files.append(FixtureFile(path: "metadata/reader.json", mime: "application/json", bytes: try jsonData(reader)))
        let groups: [[String: Any]] = readerPageMarkers.enumerated().map { index, marker in
            [
                "page": index + 1, "groups": [[
                    "id": "group-\(index + 1)",
                    "blocks": [["id": "block-\(index + 1)", "text": marker, "bounds": [0.15, 0.48, 0.7, 0.2]]]
                ]]
            ]
        }
        files.append(FixtureFile(path: "metadata/recognized-groups.json", mime: "application/json",
                                 bytes: try jsonData(groups)))
        let routes = [
            FixtureRoute(id: "home", method: "GET", path: "/home", response: "metadata/home.json"),
            FixtureRoute(id: "comments", method: "GET", path: "/comments", response: "metadata/comments.json"),
            FixtureRoute(id: "downloads", method: "GET", path: "/downloads", response: "metadata/downloads.json"),
            FixtureRoute(id: "reader", method: "GET", path: "/reader", response: "metadata/reader.json")
        ]
        files.append(FixtureFile(path: "routes.json", mime: "application/json", bytes: try encoder.encode(routes)))
        let inlineScenarios: [[String: Any]] = fixtureIDs.map { identifier in
            if identifier == "home-finite" {
                return [
                    "fixtureID": identifier,
                    "assets": (homeGalleries + homeCarouselNeighbors).map(\.coverPath)
                ]
            }
            return ["fixtureID": identifier]
        }
        let scenarioBytes = try scenarios ?? jsonData(inlineScenarios)
        try validateScenarios(scenarioBytes, assets: Set(files.map(\.path)), routes: Set(routes.map(\.id)))
        files.append(FixtureFile(path: "scenarios.json", mime: "application/json", bytes: scenarioBytes))
        let sourcePath = "AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift"
        let sourceBytes = try Data(contentsOf: URL(fileURLWithPath: #filePath))
        guard !sourceBytes.isEmpty else { throw PublicFixtureError.invalidSourceProvenance }
        let entries = files.sorted(by: { $0.path < $1.path }).map { file in
            FixtureEntry(path: file.path, mime: file.mime, bytes: file.bytes.count, sha256: digest(file.bytes))
        }
        let aggregateDigest = digest(try encoder.encode(entries))
        let manifest = FixtureManifest(
            schemaVersion: schemaVersion, fixtureVersion: fixtureVersion,
            generatorSources: [sourcePath: digest(sourceBytes)],
            fixtureIDs: fixtureIDs, assets: entries, aggregateDigest: aggregateDigest
        )
        if FileManager.default.fileExists(atPath: directory.path) {
            guard try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty else {
                throw PublicFixtureError.destinationNotEmpty
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in files {
            let destination = directory.appending(path: file.path)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                   withIntermediateDirectories: true)
            try file.bytes.write(to: destination, options: .atomic)
        }
        let manifestURL = directory.appending(path: "manifest.json")
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        return PublicFixtureExport(aggregateDigest: aggregateDigest, manifestURL: manifestURL)
    }

    public static func commentText(index: Int) -> String {
        let text = "Public fixture comment with enough text to exercise the actual multiline List row. "
            + "The finite sequence keeps a fixed author, date and order so every rendered row can be counted."
        return "VC\(index + 1)\n" + text + (index == commentIDs.count - 1 ? "\nVCEND" : "")
    }

    private static func validateScenarios(_ data: Data, assets: Set<String>, routes: Set<String>) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        let scenarios: [[String: Any]]
        if let rows = object as? [[String: Any]] {
            scenarios = rows
        } else if let catalog = object as? [String: Any], let rows = catalog["scenarios"] as? [[String: Any]] {
            scenarios = rows
        } else {
            throw PublicFixtureError.invalidScenarioCatalog
        }
        guard !scenarios.isEmpty else { throw PublicFixtureError.invalidScenarioCatalog }
        for scenario in scenarios {
            guard let identifier = scenario["fixtureID"] as? String else {
                throw PublicFixtureError.invalidScenarioCatalog
            }
            guard fixtureIDs.contains(identifier) else { throw PublicFixtureError.unknownFixture(identifier) }
            if scenario["assets"] != nil && !(scenario["assets"] is [String]) {
                throw PublicFixtureError.invalidScenarioCatalog
            }
            if scenario["routes"] != nil && !(scenario["routes"] is [String]) {
                throw PublicFixtureError.invalidScenarioCatalog
            }
            for asset in scenario["assets"] as? [String] ?? [] where !assets.contains(asset) {
                throw PublicFixtureError.missingAsset(asset)
            }
            for route in scenario["routes"] as? [String] ?? [] where !routes.contains(route) {
                throw PublicFixtureError.missingRoute(route)
            }
        }
    }

    private static func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined()
    }
}

public enum PublicFixtureError: Error, Equatable {
    case unknownFixture(String)
    case missingAsset(String)
    case missingRoute(String)
    case invalidScenarioCatalog
    case destinationNotEmpty
    case invalidSourceProvenance
    case imageEncodingFailed
}

private struct FixtureFile {
    let path: String
    let mime: String
    let bytes: Data
}

private struct FixtureEntry: Codable {
    let path: String
    let mime: String
    let bytes: Int
    let sha256: String
}

private struct FixtureRoute: Codable {
    let id: String
    let method: String
    let path: String
    let response: String
}

private struct FixtureManifest: Codable {
    let schemaVersion: Int
    let fixtureVersion: String
    let generatorSources: [String: String]
    let fixtureIDs: [String]
    let assets: [FixtureEntry]
    let aggregateDigest: String
}
