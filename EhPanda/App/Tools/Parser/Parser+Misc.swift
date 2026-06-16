import Kanna
import Foundation

extension Parser {
    static func parseSkipServerIdentifier(doc: HTMLDocument) throws -> String {
        guard let text = doc.at_xpath("//div [@id='i6']")?.at_xpath("//a [@id='loadfail']")?["onclick"],
              let rangeA = text.range(of: "nl('"), let rangeB = text.range(of: "')")
        else { throw AppError.parseFailed }
        return .init(text[rangeA.upperBound..<rangeB.lowerBound])
    }

    static func parseAPIKey(doc: HTMLDocument) throws -> String {
        var tmpKey: String?

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let script = link.text, script.contains("apikey"),
                  let rangeA = script.range(of: ";\nvar apikey = \""),
                  let rangeB = script.range(of: "\";\nvar average_rating")
            else { continue }

            tmpKey = String(script[rangeA.upperBound..<rangeB.lowerBound])
        }

        guard let apikey = tmpKey
        else { throw AppError.parseFailed }

        return apikey
    }

    static func parsePageNum(doc: HTMLDocument) -> PageNumber {
        var current = 0
        var maximum = 0

        guard let link = doc.at_xpath("//table [@class='ptt']"),
              let currentStr = link.at_xpath("//td [@class='ptds']")?.text
        else {
            if let link = doc.at_xpath("//div [@class='searchnav']") {
                var timestamp: String?
                var isEnabled = false

                for aLink in link.xpath("//a") where aLink.text?.contains("Next") == true {
                    timestamp = aLink["href"]
                        .map(URLComponents.init)??
                        .queryItems?
                        .first(where: { $0.name == "next" })?
                        .value?
                        .split(separator: "-")
                        .last
                        .map(String.init)

                    isEnabled = true
                    break
                }

                return PageNumber(
                    lastItemTimestamp: timestamp,
                    isNextButtonEnabled: isEnabled,
                    jumpNavigation: parsePageJumpNavigation(doc: doc)
                )
            } else {
                return PageNumber(
                    isNextButtonEnabled: false,
                    jumpNavigation: parsePageJumpNavigation(doc: doc)
                )
            }
        }

        if let range = currentStr.range(of: "-") {
            current = (Int(currentStr[range.upperBound...]) ?? 1) - 1
        } else {
            current = (Int(currentStr) ?? 1) - 1
        }
        for aLink in link.xpath("//a") {
            if let num = Int(aLink.text ?? "") {
                maximum = num - 1
            }
        }
        return PageNumber(current: current, maximum: maximum)
    }
}
