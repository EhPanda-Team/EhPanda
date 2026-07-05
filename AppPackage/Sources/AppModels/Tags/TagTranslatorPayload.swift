import Foundation

/// The raw result of a tag-translation download: the untouched DB JSON bytes plus the release date
/// resolved from the GitHub metadata. Decoding, OpenCC conversion, and caching happen downstream
/// (see `FileClient.cacheAndBuildRemoteTagTranslator`) so the request layer stays purely network.
public struct TagTranslatorPayload: Sendable, Equatable {
    public init(data: Data, updatedDate: Date) {
        self.data = data
        self.updatedDate = updatedDate
    }
    public let data: Data
    public let updatedDate: Date
}
