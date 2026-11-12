import Foundation
public import Kanna

public protocol TestHelper {}

extension TestHelper {
    public func htmlDocument(filename: HTMLFilename) throws -> any HTMLDocument {
        try Kanna.HTML(url: htmlURL(filename: filename), encoding: .utf8)
    }

    /// The fixture's source text, for a test that varies one detail of a page.
    public func htmlString(filename: HTMLFilename) throws -> String {
        try String(contentsOf: htmlURL(filename: filename), encoding: .utf8)
    }

    private func htmlURL(filename: HTMLFilename) throws -> URL {
        guard let url = Bundle.module
                .url(forResource: filename.rawValue, withExtension: "html")
        else {
            throw TestError.htmlDocumentNotFound(filename)
        }
        return url
    }
}
