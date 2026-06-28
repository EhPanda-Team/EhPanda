import AppModels
import Foundation
import OpenCC

extension Dictionary where Value == TagTranslation {
    public var chtConverted: Self {
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
        var dictionary = self
        dictionary.forEach { (key, value) in
            dictionary[key] = TagTranslation(
                namespace: value.namespace, key: value.key,
                value: customConversion(text: converter.convert(value.value)),
                description: value.description, linksString: value.linksString
            )
        }
        return dictionary
    }
}
