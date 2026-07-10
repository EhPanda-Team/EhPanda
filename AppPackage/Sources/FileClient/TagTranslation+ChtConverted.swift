import AppModels
import Foundation
import OpenCC

// The Traditional-Chinese conversion of a tag-translation table is an app-specific concern:
// it depends on the user's preferred regional language and on EhPanda's custom `full color`
// tag mapping. It therefore lives at the FileClient boundary rather than inside the
// general-purpose `OpenCC` converter package (which stays focused on string conversion).
extension Dictionary where Value == TagTranslation {
    var chtConverted: Self {
        func customConversion(text: String) -> String {
            switch text {
            case "full color":
                return "全彩"
            default:
                return text
            }
        }

        guard let preferredLanguage = Locale.preferredLanguages.first else { return self }

        var options: ChineseConverter.Options = [.traditionalize]
        if preferredLanguage.contains("HK") {
            options = [.traditionalize, .hkStandard]
        } else if preferredLanguage.contains("TW") {
            options = [.traditionalize, .twStandard, .twIdiom]
        }

        guard let converter = try? ChineseConverter(options: options) else { return self }
        return mapValues { value in
            TagTranslation(
                namespace: value.namespace, key: value.key,
                value: customConversion(text: converter.convert(value.value)),
                description: value.description, linksString: value.linksString
            )
        }
    }
}
