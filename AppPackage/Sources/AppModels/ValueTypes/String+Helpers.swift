import Foundation

extension String {
    public var nonEmpty: String? {
        isEmpty ? nil : self
    }
    public var linkStyled: String {
        "[\(self)](\(Defaults.URL.ehentai.absoluteString))"
    }
    public var firstLetterCapitalized: String {
        prefix(1).capitalized + dropFirst()
    }
    public var stringsBesideColon: (String?, String) {
        let strings = split(separator: ":").map(String.init)
        if strings.count == 2, !strings[0].isEmpty {
            return (strings[0], strings[1])
        }
        return (nil, self)
    }
    public var barcesAndSpacesRemoved: String {
        replacingOccurrences(from: "(", to: ")", with: "")
            .replacingOccurrences(from: "[", to: "]", with: "")
            .replacingOccurrences(from: "{", to: "}", with: "")
            .replacingOccurrences(from: "【", to: "】", with: "")
            .replacingOccurrences(from: "「", to: "」", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func replacingOccurrences(
        from subString1: String, to subString2: String, with replacement: String
    ) -> String {
        var result = self

        while let rangeA = result.range(of: subString1),
              let rangeB = result.range(of: subString2),
              rangeA.lowerBound < rangeB.upperBound {
            let unwanted = result[rangeA.lowerBound..<rangeB.upperBound]
            result = result.replacingOccurrences(of: unwanted, with: replacement)
        }

        return result
    }
}
