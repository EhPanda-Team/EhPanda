import SwiftUI

/// Uses the available app viewport, so a windowed tablet can adopt the compact gallery rules.
public struct GalleryViewport {
    public let size: CGSize
    public let isRegularWidth: Bool

    public init(size: CGSize, isRegularWidth: Bool) {
        self.size = size
        self.isRegularWidth = isRegularWidth
    }

    public var isLarge: Bool {
        isRegularWidth && size.width >= 744 && size.height >= 600
    }

    public var isLandscape: Bool { size.width > size.height }

    public var maximumSlideshowHeight: CGFloat {
        let fraction: CGFloat = isLarge
            ? (isLandscape ? 0.4 : 0.5)
            : (isLandscape ? 0.8 : 0.7)
        return size.height * fraction
    }

    public var minimumThumbnailColumns: Int {
        isLarge && isLandscape ? 3 : 2
    }
}
