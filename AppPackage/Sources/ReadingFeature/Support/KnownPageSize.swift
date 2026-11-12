import AppModels

/// A page's pixel size as far as the reader knows it, and what told it. The sources are ordered by how close they are
/// to the image the page shows, and a size from a closer source replaces one from a farther source, never the reverse.
///
/// The vertical strip sizes a page from it before the page's image loads (`StripPageFrame`), so a page whose size is
/// known when the strip builds it takes the frame its image takes.
struct KnownPageSize: Equatable, Sendable {
    enum Source: Int, Comparable, Sendable {
        /// The file identifier in the page's thumbnail URL, which names the page's original file: the page's image is
        /// that file or a copy resampled from it.
        case originalFile
        /// The file identifier in the URL the page's image is served from.
        case servedURL
        /// The page's image, decoded.
        case decodedImage

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    let pixelSize: PagePixelSize
    let source: Source
}

extension ReadingReducer.State {
    /// Records `pixelSize` as `page`'s size unless a closer source gave it a size already.
    mutating func recordSize(_ pixelSize: PagePixelSize, ofPage page: Int, from source: KnownPageSize.Source) {
        if let known = pageSizes[page], known.source > source { return }
        pageSizes[page] = KnownPageSize(pixelSize: pixelSize, source: source)
    }
}
