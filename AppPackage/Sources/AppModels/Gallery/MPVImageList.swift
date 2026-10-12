/// A gallery's multi-page viewer image list: the key the viewer is addressed by and, by 1-based page number, each
/// page's image key and the size of its original file.
public struct MPVImageList: Equatable, Sendable {
    public let key: String
    public let imageKeys: [Int: String]
    /// The size of each page's original file, which the page's thumbnail URL names, for the pages whose thumbnail names
    /// one. The page shows that file, or a copy resampled from it.
    public let originalSizes: [Int: PagePixelSize]

    public init(key: String, imageKeys: [Int: String], originalSizes: [Int: PagePixelSize]) {
        self.key = key
        self.imageKeys = imageKeys
        self.originalSizes = originalSizes
    }
}
