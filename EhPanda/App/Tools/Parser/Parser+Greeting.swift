import Kanna
import Foundation

extension Parser {
    // swiftlint:disable:next cyclomatic_complexity
    static func parseGreeting(doc: HTMLDocument) throws -> Greeting {
        guard let node = doc.at_xpath("//div [@id='eventpane']")
        else { throw AppError.parseFailed }

        var greeting = Greeting()
        for link in node.xpath("//p") {
            guard var text = link.text,
                  text.contains("You gain") == true
            else { continue }
            var gainedTypes = [String]()
            var gainedValues = [String]()
            for strongLink in link.xpath("//strong") {
                if let strongText = strongLink.text {
                    gainedValues.append(strongText)
                }
            }
            for value in gainedValues {
                guard let range = text.range(of: value) else { break }
                let removeText = String(text[..<range.upperBound])

                if value != gainedValues.first {
                    if let text = trim(string: removeText) {
                        gainedTypes.append(text)
                    }
                }

                text = text.replacingOccurrences(of: removeText, with: "")

                if value == gainedValues.last {
                    if let text = trim(string: text) {
                        gainedTypes.append(text)
                    }
                }
            }
            let gainedIntValues = gainedValues.compactMap { trim(int: $0) }
            guard gainedIntValues.count == gainedTypes.count
            else { throw AppError.parseFailed }

            for (index, type) in gainedTypes.enumerated() {
                let value = gainedIntValues[index]
                switch type {
                case "EXP": greeting.gainedEXP = value
                case "Credits": greeting.gainedCredits = value
                case "GP": greeting.gainedGP = value
                case "Hath": greeting.gainedHath = value
                default: break
                }
            }
            break
        }
        greeting.updateTime = Date()
        return greeting
    }
}

// MARK: Helpers
private extension Parser {
    static func trim(string: String) -> String? {
        if string.contains("EXP") {
            return "EXP"
        } else if string.contains("Credits") {
            return "Credits"
        } else if string.contains("GP") {
            return "GP"
        } else if string.contains("Hath") {
            return "Hath"
        } else {
            return nil
        }
    }

    static func trim(int: String) -> Int? {
        Int(int.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: ""))
    }
}
