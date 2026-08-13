import Kanna
import SwiftUI
import AppModels
import Foundation

extension Parser {
    public static func parseMyTagsPage(doc: HTMLDocument) throws -> MyTagsResponse {
        let options = doc.xpath("//*[@id='tagset_outer']/div/select/option")
        let tagSets = options.compactMap { option -> (Int, String)? in
            guard let valueString = option["value"], let number = Int(valueString) else { return nil }
            let name = option.text ?? ""
            return (number, name)
        }

        let tagSetEnable = doc.at_xpath("//*[@id='tagset_enable']")?["checked"] != nil

        let tagSetBackgroundColor: Color? = {
            guard let input = doc.at_xpath("//*[@id='tagcolor']"),
                  let value = input["value"],
                  !value.isEmpty
            else {
                return nil
            }

            return Color(hex: value)
        }()

        let tagDivs = doc.xpath("//*[@id='usertags_outer']/div")
        let tags = tagDivs.compactMap { div -> WatchedTag? in
            guard let divId = div["id"], divId != "usertag_0" else { return nil }
            let tagId = divId.replacingOccurrences(of: "usertag_", with: "")

            guard let title = div.at_xpath(".//div[@id='tagpreview_\(tagId)']")?["title"] else { return nil }
            let pair = title
            let list = pair.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let namespace = list.count == 2 && !list[0].isEmpty ? list[0] : "temp"
            let key = list.count == 2 ? list[1] : list[0]

            let watched = div.at_xpath(".//input[@id='tagwatch_\(tagId)']")?["checked"] != nil
            let hidden = div.at_xpath(".//input[@id='taghide_\(tagId)']")?["checked"] != nil
            let backgroundColor: Color? = {
                guard let input = div.at_xpath(".//input[@id='tagcolor_\(tagId)']"),
                      let value = input["value"],
                      !value.isEmpty
                else {
                    return nil
                }

                return Color(hex: value)
            }()

            let weightString = div.at_xpath(".//input[@id='tagweight_\(tagId)']")?["value"] ?? "0"
            let weight = Int(weightString) ?? 0

            return WatchedTag(
                namespace: namespace,
                key: key,
                watched: watched,
                hidden: hidden,
                backgroundColor: backgroundColor,
                weight: weight
            )
        }

        let scriptText = doc.at_xpath("//*[@id='outer']/script[1]")?.text ?? ""
        let apikeyMatch = scriptText.range(of: #"apikey = "([^"]+)""#, options: .regularExpression)
        let apikey = apikeyMatch.flatMap { match in
            let start = match.upperBound
            let end = scriptText.index(start, offsetBy: 32, limitedBy: scriptText.endIndex) ?? scriptText.endIndex
            return String(scriptText[start..<end])
        } ?? ""

        return MyTagsResponse(
            tagSets: tagSets,
            tagSetEnable: tagSetEnable,
            tagSetBackgroundColor: tagSetBackgroundColor,
            tags: tags,
            apikey: apikey
        )
    }
}
