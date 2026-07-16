import Foundation
import Testing
@testable import AppModels

struct ErrorContextSanitizerTests {
    @Test(arguments: [
        GalleryRouteFixture(
            url: "https://e-hentai.org/g/123/secret-token?next=private",
            expectedGalleryID: "123",
            secret: "secret-token"
        ),
        GalleryRouteFixture(
            url: "https://exhentai.org/s/secret-key/456-7?next=private",
            expectedGalleryID: "456",
            secret: "secret-key"
        )
    ])
    private func galleryFailureRetainsOnlySafeRouteContext(fixture: GalleryRouteFixture) throws {
        let url = try #require(URL(string: fixture.url))
        let context = Context.galleryFailure(
            url: url,
            action: "Fetch gallery",
            reason: "The request failed."
        )
        let values = context.values.map(\.displayValue)

        #expect(context[.action]?.displayValue == "Fetch gallery")
        #expect(context[.reason]?.displayValue == "The request failed.")
        #expect(context[.gid]?.displayValue == fixture.expectedGalleryID)
        #expect(context.keys == [.action, .reason, .gid])
        #expect(values.contains(where: { $0.contains(fixture.secret) }) == false)
        #expect(values.contains(where: { $0.contains(url.path) }) == false)
        #expect(values.contains(where: { $0.contains("e-hentai.org") }) == false)
        #expect(values.contains(where: { $0.contains("exhentai.org") }) == false)
        #expect(values.contains(where: { $0.contains("next=private") }) == false)
    }

    @Test(arguments: [
        "https://e-hentai.org/g/not-a-number/secret-token",
        "https://exhentai.org/s/secret-key/not-a-number-7",
        "https://e-hentai.org/unsupported/123/secret-token"
    ])
    func malformedRoutesOmitGalleryIdentifier(urlString: String) throws {
        let url = try #require(URL(string: urlString))
        let context = Context.galleryFailure(
            url: url,
            action: "Fetch gallery",
            reason: "The request failed."
        )

        #expect(context.keys == [.action, .reason])
        #expect(context[.gid] == nil)
        #expect(context.values.contains(where: { $0.displayValue.contains("not-a-number") }) == false)
        #expect(context.values.contains(where: { $0.displayValue.contains("secret") }) == false)
    }
}

private struct GalleryRouteFixture: CustomTestStringConvertible, Sendable {
    let url: String
    let expectedGalleryID: String
    let secret: String

    var testDescription: String { url }
}
