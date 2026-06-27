import AppModels
import CoreGraphics
import Foundation

// Runtime-derived defaults that depend on app utilities (device metrics, the active gallery host).
// They live in the app layer so AppModels.Defaults stays free of those dependencies.
extension Defaults {
    @MainActor
    struct FrameSize {
        static var archiveGridWidth: CGFloat {
            DeviceUtil.isPadWidth ? 175 : DeviceUtil.isSEWidth ? 125 : 150
        }
        static var cardCellWidth: CGFloat { DeviceUtil.windowW * 0.8 }
        static let cardCellHeight: CGFloat = Defaults.ImageSize.headerH + 20 * 2
        static var cardCellSize: CGSize {
            .init(width: cardCellWidth, height: cardCellHeight)
        }
        static var rankingCellWidth: CGFloat {
            (DeviceUtil.isPadWidth ? 0.4 : 0.7) * DeviceUtil.windowW
        }
        static var alertWidthFactor: Double {
            DeviceUtil.isPadWidth ? 0.5 : 1.0
        }
    }
}

extension Defaults.ImageSize {
    @MainActor static var previewMinW: CGFloat { DeviceUtil.isPadWidth ? 180 : 100 }
    @MainActor static var previewMaxW: CGFloat { DeviceUtil.isPadWidth ? 220 : 120 }
    @MainActor static var previewAvgW: CGFloat { (previewMinW + previewMaxW) / 2 }
}

extension Defaults.URL {
    static var host: Foundation.URL { AppUtil.galleryHost == .exhentai ? exhentai : ehentai }
    static var api: Foundation.URL { host.appendingPathComponent("api.php") }
    static var myTags: Foundation.URL { host.appendingPathComponent("mytags") }
    static var uConfig: Foundation.URL { host.appendingPathComponent("uconfig.php") }
    static var galleryPopups: Foundation.URL { host.appendingPathComponent("gallerypopups.php") }
    static var galleryTorrents: Foundation.URL { host.appendingPathComponent("gallerytorrents.php") }
    static var popular: Foundation.URL { host.appendingPathComponent("popular") }
    static var watched: Foundation.URL { host.appendingPathComponent("watched") }
    static var favorites: Foundation.URL { host.appendingPathComponent("favorites.php") }
}
