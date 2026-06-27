import Kanna
import Testing
@testable import EhPanda

struct GreetingParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryDetailWithGreeting)
        let greeting = try Parser.parseGreeting(doc: document)
        #expect(greeting.gainedEXP == 30)
        #expect(greeting.gainedCredits == 329)
        #expect(greeting.gainedGP == nil)
        #expect(greeting.gainedHath == nil)
        #expect(greeting.updateTime != nil)
        #expect(greeting.gainedNothing == false)
        #expect(greeting.gainContent != nil)
    }
}
