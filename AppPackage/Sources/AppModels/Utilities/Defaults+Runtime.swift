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
    public static var host: Foundation.URL { AppUtil.galleryHost == .exhentai ? exhentai : ehentai }
    public static var api: Foundation.URL { host.appendingPathComponent("api.php") }
    public static var myTags: Foundation.URL { host.appendingPathComponent("mytags") }
    public static var uConfig: Foundation.URL { host.appendingPathComponent("uconfig.php") }
    public static var galleryPopups: Foundation.URL { host.appendingPathComponent("gallerypopups.php") }
    public static var galleryTorrents: Foundation.URL { host.appendingPathComponent("gallerytorrents.php") }
    public static var popular: Foundation.URL { host.appendingPathComponent("popular") }
    public static var watched: Foundation.URL { host.appendingPathComponent("watched") }
    public static var favorites: Foundation.URL { host.appendingPathComponent("favorites.php") }
}
