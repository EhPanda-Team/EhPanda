import AppTools
import CoreGraphics
import Foundation

// Runtime-derived defaults that depend on app utilities, such as the active gallery host.
// They live in the utilities layer so AppModels.Defaults stays free of that dependency.
extension Defaults {
    public struct FrameSize {
        public static let cardCellHeight: CGFloat = Defaults.ImageSize.headerH + 20 * 2
    }
}

extension Defaults.URL {
    public static func api(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("api.php")
    }

    public static func myTags(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("mytags")
    }

    public static func uConfig(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("uconfig.php")
    }

    public static func galleryPopups(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("gallerypopups.php")
    }

    public static func galleryTorrents(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("gallerytorrents.php")
    }

    public static func popular(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("popular")
    }

    public static func watched(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("watched")
    }

    public static func favorites(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("favorites.php")
    }

    public static func toplist(host: GalleryHost) -> Foundation.URL {
        host.url.appendingPathComponent("toplist.php")
    }
}
