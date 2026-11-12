@testable import AppModels
import Testing

struct TranslatableLanguageTests {
    @Test(arguments: [
        ("en-US", TranslatableLanguage.english),
        ("ja-JP", .japanese),
        ("ko-KR", .korean),
        ("zh-Hans-CN", .simplifiedChinese),
        ("zh-Hant-TW", .traditionalChinese),
        ("zh-Hant-HK", .traditionalChinese),
        ("zh-Hant-MO", .traditionalChinese),
        ("zh-TW", .traditionalChinese),
        ("zh-HK", .traditionalChinese),
        ("zh-CN", .simplifiedChinese),
        ("zh", .simplifiedChinese)
    ])
    func preferredLanguageSelectsItsDataset(preferredLanguage: String, language: TranslatableLanguage) {
        #expect(TranslatableLanguage.matching(preferredLanguage: preferredLanguage) == language)
    }

    @Test(arguments: ["de-DE", "kok-IN", "de-DE-u-ca-japanese", "yue-Hant-HK"])
    func unsupportedLanguageHasNoDataset(preferredLanguage: String) {
        #expect(TranslatableLanguage.matching(preferredLanguage: preferredLanguage) == nil)
    }

    @Test
    func filenamesMatchThePublishedAssets() {
        #expect(TranslatableLanguage.allCases.map(\.remoteFilename) == [
            "en.json", "ja.json", "ko.json", "zh-Hans.json", "zh-Hant.json"
        ])
    }
}
