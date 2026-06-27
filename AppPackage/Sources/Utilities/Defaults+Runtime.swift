import AppModels
import CoreGraphics
import Foundation

// Runtime-derived defaults that depend on app utilities (device metrics, the active gallery host).
// They live in the utilities layer so AppModels.Defaults stays free of those dependencies.
extension Defaults {
    @MainActor
    public struct FrameSize {
        public static var archiveGridWidth: CGFloat {
            DeviceUtil.isPadWidth ? 175 : DeviceUtil.isSEWidth ? 125 : 150
        }
        public static var cardCellWidth: CGFloat { DeviceUtil.windowW * 0.8 }
        public static let cardCellHeight: CGFloat = Defaults.ImageSize.headerH + 20 * 2
        public static var cardCellSize: CGSize {
            .init(width: cardCellWidth, height: cardCellHeight)
        }
        public static var rankingCellWidth: CGFloat {
            (DeviceUtil.isPadWidth ? 0.4 : 0.7) * DeviceUtil.windowW
        }
        public static var alertWidthFactor: Double {
            DeviceUtil.isPadWidth ? 0.5 : 1.0
        }
    }
}

extension Defaults.ImageSize {
    @MainActor public static var previewMinW: CGFloat { DeviceUtil.isPadWidth ? 180 : 100 }
    @MainActor public static var previewMaxW: CGFloat { DeviceUtil.isPadWidth ? 220 : 120 }
    @MainActor public static var previewAvgW: CGFloat { (previewMinW + previewMaxW) / 2 }
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
