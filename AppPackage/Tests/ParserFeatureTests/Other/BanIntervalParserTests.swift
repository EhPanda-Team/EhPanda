@testable import AppFeature
import Kanna
import ParserFeature
import Testing
import TestingSupport

struct BanIntervalParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .ipBanned)
        let banInterval = Parser.parseBanInterval(doc: document)
        #expect(banInterval == .minutes(minutes: 59, seconds: 48))
    }
}
