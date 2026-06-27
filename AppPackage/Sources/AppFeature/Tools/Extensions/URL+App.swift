import Foundation
import AppModels
import Parser

extension URL {
    static let mock = Defaults.URL.ehentai

    func previewCacheCleanupURLs() -> [URL] {
        guard let info = Parser.parsePreviewConfigs(url: self),
              info.plainURL != self
        else {
            return [self]
        }

        return [self, info.plainURL]
    }
}
