@testable import AppModels
import Foundation
import Testing

struct UnsupportedDeepLinkErrorTests {
    @Test(arguments: [
        UnsupportedLinkFixture(
            url: "https://fixture-user:fixture-password@evil.com:8443/g/123/third-path-token"
                + "?credential=fixture-query-secret#fixture-fragment-secret",
            expectedRendering: "https://evil.com/g/…",
            forbiddenValues: [
                "fixture-user",
                "fixture-password",
                "8443",
                "123",
                "third-path-token",
                "fixture-query-secret",
                "fixture-fragment-secret"
            ]
        ),
        UnsupportedLinkFixture(
            url: "ehpanda://exhentai.org/s/private-key/987-4"
                + "?credential=second-query-secret#second-fragment-secret",
            expectedRendering: "ehpanda://exhentai.org/s/…",
            forbiddenValues: [
                "private-key",
                "987-4",
                "second-query-secret",
                "second-fragment-secret"
            ]
        )
    ])
    private func unsupportedLinkContextSanitizesAccessBearingComponents(
        fixture: UnsupportedLinkFixture
    ) throws {
        let url = try #require(URL(string: fixture.url))
        let context = Context.unsupportedLink(url: url)
        let values = context.values.map(\.displayValue)

        #expect(context[.action]?.displayValue == "Open link")
        #expect(context[.reason]?.displayValue == "The link is not a recognized gallery link.")
        #expect(context[.link]?.displayValue == fixture.expectedRendering)
        #expect(Set(context.keys) == [.action, .reason, .link])
        for forbiddenValue in fixture.forbiddenValues {
            #expect(values.contains(where: { $0.contains(forbiddenValue) }) == false)
        }
    }

    @Test
    func unsupportedDeepLinkIsNonRetryableAndFullyDescribed() throws {
        let error = AppError.unsupportedDeepLink
        let errorDescription = try #require(error.errorDescription)
        let recoverySuggestion = try #require(error.recoverySuggestion)

        #expect(error.isRetryable == false)
        #expect(errorDescription.isEmpty == false)
        #expect(recoverySuggestion.isEmpty == false)
    }
}

private struct UnsupportedLinkFixture: CustomTestStringConvertible, Sendable {
    let url: String
    let expectedRendering: String
    let forbiddenValues: [String]

    var testDescription: String { url }
}
