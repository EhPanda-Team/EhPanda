public import Foundation

/// The parts of a GitHub release that the tag database update check reads.
///
/// One release carries every language, so a language is current when its own asset's digest is unchanged.
/// Comparing the release date instead would download all languages whenever any one of them changed.
public struct TagDatabaseRelease: Decodable, Sendable {
    public let assets: [TagDatabaseAsset]

    public func asset(for language: TranslatableLanguage) -> TagDatabaseAsset? {
        assets.first(where: { $0.name == language.remoteFilename })
    }
}

public struct TagDatabaseAsset: Decodable, Sendable {
    public let name: String
    /// `sha256:<hex>`, assigned by GitHub. It can be absent while an asset is still processing.
    public let digest: String?
    public let downloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case digest
        case downloadURL = "browser_download_url"
    }
}
