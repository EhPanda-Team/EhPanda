@testable import DetailFeature
import Foundation
import Testing

struct SiteFileSizeTests {
    struct Case: Sendable {
        let text: String
        let locale: String
        let formatted: String
    }

    @Test(arguments: [
        Case(text: "26.2 MiB", locale: "de_DE", formatted: "26,2 MiB"),
        Case(text: "26.2 MiB", locale: "en_US", formatted: "26.2 MiB"),
        Case(text: "26.2 MiB", locale: "ja_JP", formatted: "26.2 MiB"),
        Case(text: "512 KiB", locale: "de_DE", formatted: "512 KiB"),
        Case(text: "512 KiB", locale: "en_US", formatted: "512 KiB"),
        Case(text: "1.5 GiB", locale: "de_DE", formatted: "1,5 GiB"),
        Case(text: "1.5 GiB", locale: "ja_JP", formatted: "1.5 GiB"),
        Case(text: "1024.25 MiB", locale: "en_US", formatted: "1024.25 MiB")
    ])
    func aSiteSizeIsInTheReadersNumberFormat(_ size: Case) throws {
        let parsed = try #require(SiteFileSize(siteText: size.text))
        #expect(parsed.formatted(locale: Locale(identifier: size.locale)) == size.formatted)
    }

    @Test(arguments: ["N/A", "312 MB", "", "26,2 MiB", "26.2MiB", " 26.2 MiB", "26.2 MiB ", "1.2.3 MiB", "٢٦.٢ MiB"])
    func textThatIsNotASiteSizeIsNotParsed(_ text: String) {
        #expect(SiteFileSize(siteText: text) == nil)
    }

    @Test
    func theSpokenUnitIsTheCatalogsWordForTheCount() throws {
        let size = try #require(SiteFileSize(siteText: "26.2 MiB"))
        #expect(size.spokenUnit() == String(localized: .accessibilitySizeMebibyte(quantity: 26.2)))
    }

    @Test
    func aUnitTheCatalogDoesNotKnowHasNoSpokenUnit() {
        #expect(SiteFileSize(count: 26.2, unit: "MB").spokenUnit() == nil)
    }
}
