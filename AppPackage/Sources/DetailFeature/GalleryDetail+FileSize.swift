import AppModels
import Foundation

extension GalleryDetail {
    /// The gallery's size as the site gives it, a count and a binary unit. Its views show it through ``SiteFileSize``,
    /// the type the sizes of its torrents and archives use too, so every size follows the reader's number format.
    var fileSize: SiteFileSize {
        SiteFileSize(count: sizeCount, unit: sizeType)
    }
}
