import Foundation
import AppModels
import ParserFeature

extension URL {
    public func previewCacheCleanupURLs() -> [URL] {
        guard let info = Parser.parsePreviewConfigs(url: self),
              info.plainURL != self
        else {
            return [self]
        }

        return [self, info.plainURL]
    }
}
