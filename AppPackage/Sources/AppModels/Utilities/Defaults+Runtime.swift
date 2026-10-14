public import AppTools
import CoreGraphics
public import Foundation

// Runtime-derived defaults that depend on app utilities, such as the active gallery host.
// They live in the utilities layer so AppModels.Defaults stays free of that dependency.
extension Defaults {
    public struct FrameSize {
        public static let cardCellHeight: CGFloat = Defaults.ImageSize.headerH + 20 * 2
    }
}

extension Defaults.URL {
    public static func api(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "api.php")
    }

    public static func myTags(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "mytags")
    }

    public static func uConfig(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "uconfig.php")
    }

    public static func galleryPopups(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "gallerypopups.php")
    }

    public static func galleryTorrents(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "gallerytorrents.php")
    }

    public static func popular(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "popular")
    }

    public static func watched(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "watched")
    }

    public static func favorites(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "favorites.php")
    }

    public static func toplist(host: GalleryHost) -> Foundation.URL {
        host.url.appending(path: "toplist.php")
    }
}
