import Kanna
import Foundation

extension Parser {
    static func parseUserInfo(doc: HTMLDocument) throws -> User {
        var displayName: String?
        var avatarURL: URL?

        for ipbLink in doc.xpath("//table [@class='ipbtable']") {
            guard let profileName = ipbLink.at_xpath("//div [@id='profilename']")?.text
            else { continue }

            displayName = profileName

            for imgLink in ipbLink.xpath("//img") {
                guard let imgURLString = imgLink["src"],
                      imgURLString.contains("forums.e-hentai.org/uploads"),
                      let imgURL = URL(string: imgURLString)
                else { continue }

                avatarURL = imgURL
            }
        }
        if displayName != nil {
            return User(displayName: displayName, avatarURL: avatarURL)
        } else {
            throw AppError.parseFailed
        }
    }

    static func parseCurrentFunds(doc: HTMLDocument) throws -> (String, String) {
        var tmpGP: String?
        var tmpCredits: String?

        for element in doc.xpath("//p") {
            if let text = element.text,
               let rangeA = text.range(of: "GP"),
               let rangeB = text.range(of: "[?]"),
               let rangeC = text.range(of: "Credits") {
                tmpGP = String(text[..<rangeA.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: "")
                tmpCredits = String(text[rangeB.upperBound..<rangeC.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: "")
            }
        }

        guard let galleryPoints = tmpGP, let credits = tmpCredits
        else { throw AppError.parseFailed }

        return (galleryPoints, credits)
    }
}
