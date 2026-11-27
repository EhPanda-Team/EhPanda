public import AppModels
import Foundation
public import Kanna

extension Parser {
    /// Reads one tag set's page of the site's My Tags (`/mytags`, read live on both hosts on 2026-11-22).
    ///
    /// The page shows the set its picker has selected; the picker lists every set, each named with its tag count in
    /// parentheses, which is dropped. Each `div#usertag_<id>` after the add row (`usertag_0`) is one tag: its
    /// preview's `title` is the full `namespace:tag` (the preview's text may abbreviate the namespace); Watched and
    /// Hidden are set when their box carries the `checked` attribute (their `onchange` text contains
    /// `checked=false`, so a substring test would be wrong); its colour and weight are its inputs' values. A refused
    /// form post comes back as the same page with the reason in `#msg`. The inline script's `apiuid` and `apikey` are
    /// the edit API's credentials.
    /// A control in the tag set form whose `onclick` calls `do_tagset_delete` offers deleting the shown set (U-1 of
    /// quick 261126-udx), unless it is disabled (U-1a). Which sets the site offers it for is its own rule, unknown
    /// here, so only the page says it.
    ///
    /// A page without the credentials, the picker, its selected set or the tag list is not a My Tags page, and a row
    /// without its name or weight, or with a colour that is not `#RRGGBB`, fails the page rather than losing the row.
    public static func parseMyTags(doc: any HTMLDocument) throws(AppError) -> MyTagsPage {
        guard let apikey = parseScriptVariable(name: "apikey", doc: doc), !apikey.isEmpty,
              let apiuid = parseAPIUID(doc: doc),
              let picker = doc.at_xpath("//div[@id='tagset_outer']//select"),
              let selected = picker.at_xpath(".//option[@selected]"),
              let tagSetID = selected["value"].flatMap({ Int($0) }),
              let optionText = selected.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let usertags = doc.at_xpath("//div[@id='usertags_outer']")
        else { throw .parseFailed }

        var tags = [MyTag]()
        for row in usertags.xpath("./div[starts-with(@id, 'usertag_')]") {
            guard let tagID = row["id"].flatMap({ Int($0.dropFirst("usertag_".count)) })
            else { throw .parseFailed }
            guard tagID != 0 else { continue }
            guard let name = row.at_xpath(".//div[@id='tagpreview_\(tagID)']")?["title"], !name.isEmpty,
                  let weight = row.at_xpath(".//input[@id='tagweight_\(tagID)']")?["value"].flatMap({ Int($0) })
            else { throw .parseFailed }
            let color = try siteColor(row.at_xpath(".//input[@id='tagcolor_\(tagID)']")?["value"])
            tags.append(MyTag(
                id: tagID,
                name: name,
                isWatched: row.at_xpath(".//input[@id='tagwatch_\(tagID)']")?["checked"] != nil,
                isHidden: row.at_xpath(".//input[@id='taghide_\(tagID)']")?["checked"] != nil,
                color: color,
                weight: weight
            ))
        }

        let tagSetColor = try siteColor(doc.at_xpath("//input[@id='tagcolor']")?["value"])
        let message = doc.at_xpath("//div[@id='msg']")?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let deleteControl = "//div[@id='tagset_outer']//*[contains(@onclick, 'do_tagset_delete(')][not(@disabled)]"
        let offersDelete = doc.at_xpath(deleteControl) != nil
        return MyTagsPage(
            tagSet: MyTagSet(
                id: tagSetID,
                name: optionText.wholeMatch(of: /(.*) \(\d+\)/).map({ String($0.output.1) }) ?? optionText,
                isEnabled: doc.at_xpath("//input[@id='tagset_enable']")?["checked"] != nil,
                color: tagSetColor,
                tags: tags,
                isDeletable: offersDelete
            ),
            tagSetIDs: picker.xpath(".//option").compactMap({ option in option["value"].flatMap({ Int($0) }) }),
            apiuid: apiuid,
            apikey: apikey,
            message: message.isEmpty ? nil : String(message.prefix(200))
        )
    }

    /// The script's `var apiuid = <int>;`, which unlike the key the site writes unquoted.
    private static func parseAPIUID(doc: any HTMLDocument) -> Int? {
        for script in doc.xpath("//script") {
            if let text = script.text, let match = text.firstMatch(of: /var apiuid\s*=\s*(\d+)\s*;/) {
                return Int(match.output.1)
            }
        }
        return nil
    }

    /// An input's colour: nil when empty (the set's or the site's default applies), else `#RRGGBB`; anything else
    /// fails the page.
    private static func siteColor(_ value: String?) throws(AppError) -> SiteColor? {
        let text = value?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !text.isEmpty else { return nil }
        guard let color = SiteColor(hex: text) else { throw .parseFailed }
        return color
    }
}
