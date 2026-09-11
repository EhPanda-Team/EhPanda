import AppTools
import CryptoKit
import CustomDump
import Foundation
import SwiftUI
import Testing

/// Pins the 84 category background variants that Phase 16 D-26 froze.
///
/// D-26 makes the background the category's identity and derives the badge text colour from it, so the
/// backgrounds must never move by accident: the 44 standard (light / dark) variants are pinned by a
/// SHA-256 over a canonical serialization of their channels, and every one of the 84 is proven to pass
/// WCAG AA with the better of black or white text through the very helper the badge uses
/// (`Color.Resolved.relativeLuminance`, `Color.contrastingForeground(on:)`), so a regression in the
/// maths fails here against the audited table as well as in `ColorContrastTests`.
///
/// The 40 `contrast: high` variants carry a *separate* pin. D-27 left their re-authoring as a
/// should-fix for the owner; plan 16-15 did it under the `HC=A` decision, re-deriving the HC pin
/// deliberately while the standard pin stayed untouched — "more contrast" now means more, and the
/// guard on the standard backgrounds was never loosened to get there.
///
/// The walk reads the live `Contents.json` files from the repository, because the app resolves these
/// colours from the main bundle's catalog, which a package test cannot load by name. It refuses to
/// pass vacuously: the colorset count, the variant count and two named members are all equality-pinned.
@Suite
struct CategoryColorsetInvariantTests {
    private enum Appearance: String {
        case light
        case dark
        case lightHighContrast = "light+HC"
        case darkHighContrast = "dark+HC"

        var isHighContrast: Bool {
            self == .lightHighContrast || self == .darkHighContrast
        }
    }

    /// One `colors[]` entry of a colorset, with its channels normalised to 0…1 sRGB.
    private struct Variant {
        let host: String
        let category: String
        let appearance: Appearance
        let red: Double
        let green: Double
        let blue: Double

        var name: String { "\(host) / \(category) / \(appearance.rawValue)" }

        /// `<host>/<category>/<appearance>:<r>,<g>,<b>` with six-decimal channels — the hashed shape.
        var canonicalLine: String {
            let channels = [red, green, blue].map({ String(format: "%.6f", $0) }).joined(separator: ",")
            return "\(host)/\(category)/\(appearance.rawValue):\(channels)"
        }

        var resolved: Color.Resolved {
            Color.Resolved(colorSpace: .sRGB, red: Float(red), green: Float(green), blue: Float(blue), opacity: 1)
        }
    }

    private struct Scan {
        /// Paths relative to the `Colors` directory, sorted.
        let files: [String]
        let variants: [Variant]
    }

    private static let colorsDirectory = "App/Assets.xcassets/Category/Colors"
    private static let hosts = ["E-Hentai", "ExHentai"]
    /// The worst best-of variant's file and one file from the other host, so an enumerator that
    /// silently walked nothing cannot let a test pass vacuously — for either root.
    private static let knownMembers = [
        "ExHentai/Game CG.colorset/Contents.json",
        "E-Hentai/Manga.colorset/Contents.json"
    ]
    private static let repositoryRootMarkers = ["App", "AppPackage"]

    /// 11 categories × 2 hosts. `Private` ships only light and dark on both hosts, hence 84 variants
    /// rather than 88: 20 × 4 + 2 × 2.
    private static let expectedColorsetCount = 22
    private static let expectedVariantCount = 84
    private static let expectedStandardVariantCount = 44
    private static let expectedHighContrastVariantCount = 40

    /// Audited in `16-CONTRAST-AUDIT.md § Category variants`: the worst best-of is ExHentai / Game CG /
    /// light (white 4.55, black 4.62) and 47 of 84 variants choose black text.
    private static let expectedWorstBestOf = 4.62
    private static let expectedWorstVariantName = "ExHentai / Game CG / light"
    private static let expectedBlackTextCount = 47
    private static let minimumTextContrast = 4.5

    /// SHA-256 over the sorted canonical lines of the 44 standard variants. Changing any standard
    /// background byte fails this pin; that is the point (D-26).
    private static let standardPin = "f940492af7648bf41e12a5cca24532c8f7451d79875a75b3534a7b9c0f235363"
    /// SHA-256 over the sorted canonical lines of the 40 `contrast: high` variants. Re-derive only
    /// under a deliberate D-27 re-authoring; never touch the standard pin to do so.
    ///
    /// Re-pinned by plan 16-15 under the owner's `HC=A` decision (`16-CONTRAST-AUDIT.md § Decisions`):
    /// the 19 HC variants whose best-of contrast was below their standard sibling's were rewritten to
    /// the audit's proposed values, so no Increase Contrast badge now reads worse than its standard
    /// one (0 / 40 lower). The previous pin, over the as-shipped HC bytes, was
    /// `e81b0604c84754a0260818465051f11fae99fe756b934db2f16929ea83600937`.
    private static let highContrastPin = "84accf722ad6601f41e6cf8d069344f5c066f58df42bfdbf21b780dbcc539407"

    private static let linearBlack = Color.Resolved(colorSpace: .sRGBLinear, red: 0, green: 0, blue: 0)
    private static let linearWhite = Color.Resolved(colorSpace: .sRGBLinear, red: 1, green: 1, blue: 1)

    // MARK: - Walk

    @Test
    func walksEveryColorsetOfBothHosts() throws {
        let scan = try Self.scan()

        expectNoDifference(scan.files.count, Self.expectedColorsetCount)
        expectNoDifference(scan.variants.count, Self.expectedVariantCount)
        expectNoDifference(
            scan.variants.filter({ $0.appearance.isHighContrast == false }).count,
            Self.expectedStandardVariantCount
        )
        expectNoDifference(
            scan.variants.filter(\.appearance.isHighContrast).count,
            Self.expectedHighContrastVariantCount
        )
    }

    @Test(arguments: [
        ChannelFixture(component: "0xFF", expected: 1),
        ChannelFixture(component: "1.000", expected: 1),
        ChannelFixture(component: "255", expected: 1),
        ChannelFixture(component: "0x00", expected: 0),
        ChannelFixture(component: "0.000", expected: 0),
        ChannelFixture(component: "0", expected: 0)
    ])
    private func normalisesEveryComponentEncoding(fixture: ChannelFixture) throws {
        let channel = try Self.normalizedChannel(fixture.component)

        #expect(channel == fixture.expected)
    }

    /// ExHentai / Cosplay is the only colorset using decimal-byte components; a parser that misses that
    /// encoding reads `"163"` as 163.0 and reports a luminance in the tens of thousands.
    @Test
    func decimalEncodedCosplayVariantsHaveUnitIntervalLuminance() throws {
        let scan = try Self.scan()
        let cosplay = scan.variants.filter({ $0.host == "ExHentai" && $0.category == "Cosplay" })
        try #require(cosplay.isEmpty == false)

        for variant in cosplay {
            let luminance = variant.resolved.relativeLuminance
            #expect((0...1).contains(luminance), "\(variant.name) has luminance \(luminance)")
        }
    }

    // MARK: - Contrast

    @Test
    func everyVariantPassesWithBlackOrWhiteText() throws {
        let scan = try Self.scan()

        for variant in scan.variants {
            let bestOf = Self.bestOfContrast(variant)
            #expect(
                bestOf >= Self.minimumTextContrast,
                "\(variant.name) reaches only \(bestOf):1 with the better of black or white text"
            )
        }
    }

    @Test
    func worstBestOfIsExHentaiGameCGLight() throws {
        let scan = try Self.scan()

        let worst = try #require(
            scan.variants.min(by: { Self.bestOfContrast($0) < Self.bestOfContrast($1) })
        )

        expectNoDifference(worst.name, Self.expectedWorstVariantName)
        #expect(abs(Self.bestOfContrast(worst) - Self.expectedWorstBestOf) < 0.01)
    }

    @Test
    func fortySevenVariantsChooseBlackText() throws {
        let scan = try Self.scan()

        let blackTextCount = scan.variants
            .filter({ Color.contrastingForeground(on: $0.resolved) == .black })
            .count

        expectNoDifference(blackTextCount, Self.expectedBlackTextCount)
    }

    // MARK: - Pins

    @Test
    func standardVariantsArePinned() throws {
        let scan = try Self.scan()

        let digest = Self.digest(of: scan.variants.filter({ $0.appearance.isHighContrast == false }))

        #expect(
            digest == Self.standardPin,
            "A standard category background moved (D-26 froze them). Actual digest: \(digest)"
        )
    }

    @Test
    func highContrastVariantsArePinned() throws {
        let scan = try Self.scan()

        let digest = Self.digest(of: scan.variants.filter(\.appearance.isHighContrast))

        #expect(
            digest == Self.highContrastPin,
            "An Increase Contrast category background moved; re-pin only under D-27. Actual digest: \(digest)"
        )
    }
}

// MARK: - Contrast and hashing

private extension CategoryColorsetInvariantTests {
    private static func bestOfContrast(_ variant: Variant) -> Double {
        max(
            Color.contrastRatio(variant.resolved, linearWhite),
            Color.contrastRatio(variant.resolved, linearBlack)
        )
    }

    private static func digest(of variants: [Variant]) -> String {
        let serialization = variants.map(\.canonicalLine).sorted().joined(separator: "\n")
        return SHA256.hash(data: Data(serialization.utf8)).map({ String(format: "%02x", $0) }).joined()
    }
}

// MARK: - Parsing

private extension CategoryColorsetInvariantTests {
    /// Xcode writes a component as a hex byte (`"0x11"`), a 0…1 float (`"0.910"`) or a decimal byte
    /// (`"163"`); a bare integer is always a byte, never a unit float.
    static func normalizedChannel(_ component: String) throws -> Double {
        if component.hasPrefix("0x") {
            let byte = try #require(UInt8(component.dropFirst(2), radix: 16), "Bad hex component \(component)")
            return Double(byte) / 255
        }
        if component.contains(".") {
            return try #require(Double(component), "Bad float component \(component)")
        }
        let byte = try #require(UInt8(component), "Bad decimal component \(component)")
        return Double(byte) / 255
    }

    private static func appearance(of entries: [AppearanceEntry]) throws -> Appearance {
        var isDark = false
        var isHighContrast = false
        var unknown = [String]()

        for entry in entries {
            switch (entry.appearance, entry.value) {
            case ("luminosity", "dark"):
                isDark = true
            case ("contrast", "high"):
                isHighContrast = true
            default:
                unknown.append("\(entry.appearance)=\(entry.value)")
            }
        }
        try #require(unknown.isEmpty, "Unknown colorset appearance keys: \(unknown)")

        switch (isDark, isHighContrast) {
        case (false, false):
            return .light
        case (true, false):
            return .dark
        case (false, true):
            return .lightHighContrast
        case (true, true):
            return .darkHighContrast
        }
    }

    private static func variant(host: String, category: String, entry: Entry) throws -> Variant {
        try #require(
            entry.color.colorSpace == "srgb",
            "\(host) / \(category) declares colour space \(entry.color.colorSpace); the contrast maths assumes sRGB"
        )
        return Variant(
            host: host,
            category: category,
            appearance: try appearance(of: entry.appearances ?? []),
            red: try normalizedChannel(entry.color.components.red),
            green: try normalizedChannel(entry.color.components.green),
            blue: try normalizedChannel(entry.color.components.blue)
        )
    }
}

// MARK: - Scanning

private extension CategoryColorsetInvariantTests {
    private static func scan() throws -> Scan {
        let colorsDirectory = try repositoryRoot().appending(path: colorsDirectory)
        let decoder = JSONDecoder()
        var files = [String]()
        var variants = [Variant]()

        for host in hosts {
            let enumerator = try #require(
                FileManager.default.enumerator(
                    at: colorsDirectory.appending(path: host),
                    includingPropertiesForKeys: nil
                )
            )
            for case let url as URL in enumerator
            where url.lastPathComponent == "Contents.json"
                && url.deletingLastPathComponent().pathExtension == "colorset" {
                let category = url.deletingLastPathComponent().deletingPathExtension().lastPathComponent
                files.append(repositoryRelativePath(of: url, under: colorsDirectory))
                let contents = try decoder.decode(Contents.self, from: Data(contentsOf: url))
                for entry in contents.colors {
                    variants.append(try variant(host: host, category: category, entry: entry))
                }
            }
        }

        try #require(files.isEmpty == false)
        try requireKnownMembers(in: files)
        return Scan(files: files.sorted(), variants: variants)
    }

    /// Requires both hosts to have contributed their named colorset.
    static func requireKnownMembers(in files: [String]) throws {
        for knownMember in knownMembers {
            try #require(
                files.contains(knownMember),
                "The walk lost its known member \(knownMember); it refuses a vacuous pass."
            )
        }
    }

    static func repositoryRoot() throws -> URL {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()
        var located: URL?

        while located == nil, directory.path != "/" {
            if isRepositoryRoot(directory) {
                located = directory
            } else {
                directory = directory.deletingLastPathComponent()
            }
        }

        return try #require(
            located,
            "Could not locate the repository root; the colorset invariant refuses a vacuous walk."
        )
    }

    static func isRepositoryRoot(_ directory: URL) -> Bool {
        let fileManager = FileManager.default
        return repositoryRootMarkers.allSatisfy({ marker in
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: directory.appending(path: marker).path,
                isDirectory: &isDirectory
            )
            return exists && isDirectory.boolValue
        })
    }

    static func repositoryRelativePath(of url: URL, under root: URL) -> String {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path + "/"
        guard path.hasPrefix(rootPath) else { return path }
        return String(path.dropFirst(rootPath.count))
    }
}

// MARK: - Colorset JSON

private struct Contents: Decodable {
    let colors: [Entry]
}

private struct Entry: Decodable {
    let appearances: [AppearanceEntry]?
    let color: ColorEntry
}

private struct AppearanceEntry: Decodable {
    let appearance: String
    let value: String
}

private struct ColorEntry: Decodable {
    let colorSpace: String
    let components: Components

    private enum CodingKeys: String, CodingKey {
        case colorSpace = "color-space"
        case components
    }
}

private struct Components: Decodable {
    let red: String
    let green: String
    let blue: String
}

private struct ChannelFixture: CustomTestStringConvertible, Sendable {
    let component: String
    let expected: Double

    var testDescription: String { component }
}
