public import Foundation

/// The raw result of a tag-translation download: the untouched DB JSON bytes plus the asset digest
/// resolved from the GitHub metadata. Decoding and caching happen downstream (see
/// `FileClient.cacheAndBuildRemoteTagTranslator`) so the request layer stays purely network.
public struct TagTranslatorPayload: Sendable, Equatable {
    public init(data: Data, digest: String) {
        self.data = data
        self.digest = digest
    }
    public let data: Data
    public let digest: String
}
