import TestingSupport
import Kanna
import Testing
import ParserFeature
@testable import AppFeature

struct BanIntervalParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .ipBanned)
        let banInterval = Parser.parseBanInterval(doc: document)
        #expect(banInterval == .minutes(59, seconds: 48))
    }
}
