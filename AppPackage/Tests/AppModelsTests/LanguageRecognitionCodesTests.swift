import AppModels
import Foundation
import Testing
import Vision

// Live Text reads a page in its gallery's language. Vision's own recognition languages decide which
// gallery languages that can be, so the table names exactly those, each by one of Vision's codes; any
// other language is left for Vision to detect.
struct LanguageRecognitionCodesTests {
    private static let visionLanguages = RecognizeTextRequest().supportedRecognitionLanguages

    @Test(arguments: Language.allCases.filter({ $0.codes != nil }))
    func everyCodeIsOneOfVisionsLanguages(language: Language) throws {
        let codes = try #require(language.codes)
        let supported = Set(Self.visionLanguages.map(\.maximalIdentifier))

        for code in codes {
            #expect(supported.contains(Locale.Language(identifier: code).maximalIdentifier), "\(code)")
        }
    }

    @Test
    func everyGalleryLanguageVisionReadsHasItsCode() throws {
        let english = Locale(identifier: "en_US")
        var checked = [Language]()

        for visionLanguage in Self.visionLanguages {
            guard let code = visionLanguage.languageCode?.identifier,
                  let name = english.localizedString(forLanguageCode: code),
                  let language = Language(rawValue: name)
            else {
                continue
            }
            let mapped = (language.codes ?? []).map({ Locale.Language(identifier: $0).languageCode })
            #expect(mapped.contains(visionLanguage.languageCode), "\(name): \(visionLanguage.maximalIdentifier)")
            checked.append(language)
        }

        // Guards the lookup itself: the gallery languages Vision has read since iOS 16 must be found.
        #expect(Set(checked).isSuperset(of: [.english, .chinese, .japanese, .korean, .german]))
    }
}
