@testable import DetailFeature
import Foundation
import Testing

struct LinkedTextTests {
    /// Detection runs on a `String` and links an `AttributedString`, so the range has to survive
    /// characters that take different lengths in UTF-16 and UTF-8.
    @Test(arguments: ["", "大小感人 ", "𝐒𝐮𝐩𝐩𝐨𝐫𝐭 ", "😀 ", "e\u{301} "])
    func linkCoversExactlyItsURL(prefix: String) throws {
        let url = "https://example.com/a"
        let result = LinkedText.detectingLinks(in: AttributedString("\(prefix)\(url) tail"))

        let linkRuns = result.runs.filter({ $0.link != nil })
        let link = try #require(linkRuns.first)
        #expect(linkRuns.count == 1)
        #expect(link.link == URL(string: url))
        #expect(String(result[link.range].characters) == url)
    }

    @Test
    func detectionKeepsTheStyleAroundAndUnderALink() throws {
        var bold = AttributeContainer()
        bold.inlinePresentationIntent = .stronglyEmphasized
        let text = AttributedString("see https://example.com/a now", attributes: bold)

        let result = LinkedText.detectingLinks(in: text)

        #expect(result.runs.allSatisfy({ $0.inlinePresentationIntent == .stronglyEmphasized }))
        #expect(result.runs.count == 3)
    }

    @Test
    func textWithoutALinkIsUnchanged() {
        let text = AttributedString("no links here")
        #expect(LinkedText.detectingLinks(in: text) == text)
    }
}
