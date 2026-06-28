import Kanna
import Foundation

public protocol TestHelper {}

extension TestHelper {
    public func htmlDocument(filename: HTMLFilename) throws -> HTMLDocument {
        guard let url = Bundle.module
                .url(forResource: filename.rawValue, withExtension: "html")
        else {
            throw TestError.htmlDocumentNotFound(filename)
        }
        return try Kanna.HTML(url: url, encoding: .utf8)
    }
}
