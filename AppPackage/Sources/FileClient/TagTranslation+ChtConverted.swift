import AppModels
import Foundation
import OpenCC

// The Traditional-Chinese conversion of a tag-translation table is an app-specific concern:
// it depends on the user's preferred regional language and on EhPanda's custom `full color`
// tag mapping. It therefore lives at the FileClient boundary rather than inside the
// general-purpose `OpenCC` converter package (which stays focused on string conversion).
extension Dictionary where Value == TagTranslation {
    var chtConverted: Self {
        guard let preferredLanguage = Locale.preferredLanguages.first else { return self }

        var options: ChineseConverter.Options = [.traditionalize]
        if preferredLanguage.contains("HK") {
            options = [.traditionalize, .hkStandard]
        } else if preferredLanguage.contains("TW") {
            options = [.traditionalize, .twStandard, .twIdiom]
        }

        let converter: ChineseConverter
        do {
            converter = try ChineseConverter(options: options)
        } catch {
            // Conversion is an optional enhancement; an unavailable converter keeps the source text.
            return self
        }
        return mapValues { value in
            let translatedValue = value.namespace == .other && value.key == "full color"
                ? "全彩" : converter.convert(value.value)
            return TagTranslation(
                namespace: value.namespace, key: value.key,
                value: translatedValue,
                description: value.description, linksString: value.linksString
            )
        }
    }
}
