import Kanna
import Testing
@testable import AppFeature

struct BanIntervalParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .ipBanned)
        let banInterval = Parser.parseBanInterval(doc: document)
        #expect(banInterval == .minutes(59, seconds: 48))
    }
}
