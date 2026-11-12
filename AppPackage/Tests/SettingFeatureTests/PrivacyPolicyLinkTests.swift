import Foundation
import Resources
import Testing

/// The privacy link (`contact.privacy_policy`, shown in Settings and on the first-launch analytics choice) must open
/// the website's page in the reader's language. The site has one page per language, `/<language>/privacy/`, with that
/// exact case and the trailing slash, and nothing at `/privacy` (owner msg 2818, addresses in website msg 2819).
/// A language the app is not translated into falls back to the English page.
struct PrivacyPolicyLinkTests {
    struct Link: Sendable, CustomTestStringConvertible {
        let locale: String
        let url: String

        var testDescription: String { "\(locale) → \(url)" }
    }

    private func privacyLink(locale: String) -> String {
        var resource = LocalizedStringResource.RConstant.contactPrivacyPolicy
        resource.locale = Locale(identifier: locale)
        return String(localized: resource)
    }

    @Test(arguments: [
        Link(locale: "en", url: "https://ehpanda.app/en/privacy/"),
        Link(locale: "de", url: "https://ehpanda.app/de/privacy/"),
        Link(locale: "ja", url: "https://ehpanda.app/ja/privacy/"),
        Link(locale: "ko", url: "https://ehpanda.app/ko/privacy/"),
        Link(locale: "zh-Hans", url: "https://ehpanda.app/zh-Hans/privacy/"),
        Link(locale: "zh-Hant", url: "https://ehpanda.app/zh-Hant/privacy/")
    ])
    func eachLanguageLinksItsOwnPage(_ link: Link) {
        #expect(privacyLink(locale: link.locale) == link.url)
    }

    @Test(arguments: [
        Link(locale: "en-GB", url: "https://ehpanda.app/en/privacy/"),
        Link(locale: "de-AT", url: "https://ehpanda.app/de/privacy/"),
        Link(locale: "ja-JP", url: "https://ehpanda.app/ja/privacy/"),
        Link(locale: "ko-KR", url: "https://ehpanda.app/ko/privacy/"),
        Link(locale: "zh-Hans-CN", url: "https://ehpanda.app/zh-Hans/privacy/"),
        Link(locale: "zh-Hant-TW", url: "https://ehpanda.app/zh-Hant/privacy/")
    ])
    func aRegionalVariantLinksItsLanguagesPage(_ link: Link) {
        #expect(privacyLink(locale: link.locale) == link.url)
    }

    @Test(arguments: ["fr", "pt-BR", "ar", "ru"])
    func anUntranslatedLanguageFallsBackToTheEnglishPage(_ locale: String) {
        #expect(privacyLink(locale: locale) == "https://ehpanda.app/en/privacy/")
    }

    @Test
    func noLanguageLinksTheBarePrivacyPath() {
        for locale in ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant", "fr"] {
            let link = privacyLink(locale: locale)
            #expect(URL(string: link) != nil)
            #expect(link.hasSuffix("/privacy/"))
            #expect(link != "https://ehpanda.app/privacy")
        }
    }
}
