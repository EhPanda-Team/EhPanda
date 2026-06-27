import Kanna
import Testing
import Foundation

protocol TestHelper {}

final class TestBundleLocator {}

extension TestHelper {
    func htmlDocument(filename: HTMLFilename) throws -> HTMLDocument {
        guard let url = Bundle(for: TestBundleLocator.self)
                .url(forResource: filename.rawValue, withExtension: "html")
        else {
            throw TestError.htmlDocumentNotFound(filename)
        }
        return try Kanna.HTML(url: url, encoding: .utf8)
    }
}
