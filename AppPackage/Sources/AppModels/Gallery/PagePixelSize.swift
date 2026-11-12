public import Foundation

/// The size in pixels of a gallery page's image.
public struct PagePixelSize: Hashable, Sendable {
    public let width: Int
    public let height: Int

    /// A size with two positive sides, or `nil`.
    public init?(width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
    }
}

extension PagePixelSize {
    /// The size the first file identifier among `url`'s path components names, or `nil` when no component is one or
    /// the size has an empty side.
    ///
    /// An image file's identifier is `<SHA-1>-<bytes>-<width>-<height>-<type>`, to which a thumbnail's URL adds a
    /// `_<size>` suffix and a file extension. A page's image URL names the file it serves
    /// (`/h/<identifier>/keystamp=…/<name>`), the resampled file when the page is resampled; a page's thumbnail names
    /// the original file.
    public init?(fileIdentifierIn url: URL) {
        let fileIdentifier = /[0-9a-f]{40}-[0-9]+-([0-9]+)-([0-9]+)-[0-9a-z]+(?:_[0-9a-z]+)?(?:\.[0-9a-z]+)?/
        for component in url.pathComponents {
            if let match = component.wholeMatch(of: fileIdentifier),
               let width = Int(match.1), let height = Int(match.2) {
                self.init(width: width, height: height)
                return
            }
        }
        return nil
    }
}
