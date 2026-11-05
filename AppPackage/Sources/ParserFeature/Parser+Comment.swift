import AppModels
import AppTools
import Foundation
import Kanna
import SwiftUI

extension Parser {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parseComments(doc: any HTMLDocument) -> [GalleryComment] {
        var comments = [GalleryComment]()
        for link in doc.xpath("//div [@id='cdiv']") {
            for c1Link in link.xpath("//div [@class='c1']") {
                guard let c3Element = c1Link.at_xpath("//div [@class='c3']"),
                      let c3Node = c3Element.text,
                      let c6Node = c1Link.at_xpath("//div [@class='c6']"),
                      let commentID = c6Node["id"]?
                    .replacing("comment_", with: ""),
                      let rangeA = c3Node.range(of: "Posted on "),
                      let rangeB = c3Node.range(of: " by:   ")
                else { continue }

                var score: String?
                if let c5Node = c1Link.at_xpath("//div [@class='c5 nosel']") {
                    score = c5Node.at_xpath("//span")?.text
                }
                // The site follows the name with `&nbsp; &nbsp;` and a contact link, which are not part of it.
                let author = String(c3Node[rangeB.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let commentTime = String(c3Node[rangeA.upperBound..<rangeB.lowerBound])
                let authorMemberID = parseMemberID(c3Node: c3Element)

                var votedUp = false
                var votedDown = false
                var votable = false
                var editable = false
                if let c4Link = c1Link.at_xpath("//div [@class='c4 nosel']") {
                    for aLink in c4Link.xpath("//a") {
                        guard let aId = aLink["id"],
                              let aStyle = aLink["style"]
                        else {
                            if let aOnclick = aLink["onclick"],
                               aOnclick.contains("edit_comment") {
                                editable = true
                            }
                            continue
                        }

                        if aId.contains("vote_up") {
                            votable = true
                        }
                        if aId.contains("vote_up") && aStyle.contains("blue") {
                            votedUp = true
                        }
                        if aId.contains("vote_down") && aStyle.contains("blue") {
                            votedDown = true
                        }
                    }
                }

                let formatter = DateFormatter()
                formatter.dateFormat = Defaults.DateFormat.comment
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                guard let commentDate = formatter.date(from: commentTime) else { continue }

                comments.append(
                    GalleryComment(
                        votedUp: votedUp,
                        votedDown: votedDown,
                        votable: votable,
                        editable: editable,
                        score: score,
                        author: author,
                        authorMemberID: authorMemberID,
                        contents: parseCommentContent(node: c6Node),
                        commentID: commentID,
                        commentDate: commentDate
                    )
                )
            }
        }
        return comments
    }
}

// MARK: Helpers
private extension Parser {
    /// The poster's member ID: the digits of the forum contact link the site prints after the name,
    /// `https://forums.e-hentai.org/index.php?showuser=<digits>`. `nil` when the comment has no such link.
    static func parseMemberID(c3Node: any XMLElement) -> String? {
        for link in c3Node.xpath(".//a") {
            guard let href = link["href"], let components = URLComponents(string: href),
                  components.host?.hasSuffix("e-hentai.org") == true,
                  let value = components.queryItems?.first(where: { $0.name == "showuser" })?.value,
                  !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber })
            else { continue }
            return value
        }
        return nil
    }

    static func parseCommentContent(node: any XMLElement) -> [CommentContent] {
        var builder = CommentContentBuilder()
        builder.appendChildren(of: node)
        return builder.build()
    }
}

/// Turns a comment body into its runs by walking the DOM.
///
/// The text has to come from text nodes, which hold what the author wrote with the site's escaping
/// undone exactly once. Serialized HTML is the wrong source: it carries inline tags and re-escapes
/// `<`, `>` and `&`, and no replacing can tell that markup from a `<strong>` the author typed. The
/// elements around a text node become its attributes, so the styles survive as data the views render.
private struct CommentContentBuilder {
    private var contents = [CommentContent]()
    private var pendingText = AttributedString()

    /// `node()` rather than `children`, which lists elements only and would lose the text.
    mutating func appendChildren(of parent: any XMLElement, attributes: AttributeContainer = .init()) {
        for child in parent.xpath("node()") {
            append(child, attributes: attributes)
        }
    }

    mutating func build() -> [CommentContent] {
        flushText()
        return contents
    }

    private mutating func append(_ node: any XMLElement, attributes: AttributeContainer) {
        switch node.tagName {
        case "text":
            pendingText.append(AttributedString(node.text ?? "", attributes: attributes))
        case "br":
            pendingText.append(AttributedString("\n", attributes: attributes))
        case "a":
            appendLink(node, attributes: attributes)
        case "img":
            appendImage(node)
        case "div":
            // Not comment text: no saved comment has one, and the parser has always left them out.
            break
        default:
            appendChildren(of: node, attributes: Self.attributes(attributes, addingStyleOf: node))
        }
    }

    /// What an element adds to the text inside it. Saved and live pages write `[b]` as `strong`, `[i]`
    /// as `em`, `[s]` as `del` and `[u]` as a `span` with an inline `text-decoration`; the other tags
    /// are their HTML equivalents. Any other element adds nothing, and its text still reads.
    private static func attributes(
        _ attributes: AttributeContainer, addingStyleOf element: any XMLElement
    ) -> AttributeContainer {
        var attributes = attributes
        switch element.tagName {
        case "strong", "b":
            attributes.inlinePresentationIntent = (attributes.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
        case "em", "i":
            attributes.inlinePresentationIntent = (attributes.inlinePresentationIntent ?? []).union(.emphasized)
        case "del", "s", "strike":
            attributes.swiftUI.strikethroughStyle = .single
        case "u", "ins":
            attributes.swiftUI.underlineStyle = .single
        case "span":
            let style = element["style"] ?? ""
            if style.contains("underline") {
                attributes.swiftUI.underlineStyle = .single
            }
            if style.contains("line-through") {
                attributes.swiftUI.strikethroughStyle = .single
            }
        default:
            break
        }
        return attributes
    }

    private mutating func appendLink(_ link: any XMLElement, attributes: AttributeContainer) {
        guard let href = link["href"], let url = URL(string: href) else {
            appendChildren(of: link, attributes: attributes)
            return
        }
        flushText()

        if let imgSrc = link.at_xpath("//img")?["src"], let imgURL = URL(string: imgSrc) {
            if let last = contents.last, last.type == .linkedImg {
                contents.removeLast()
                contents.append(
                    CommentContent(
                        type: .doubleLinkedImg,
                        link: last.link,
                        imgURL: last.imgURL,
                        secondLink: url,
                        secondImgURL: imgURL
                    )
                )
            } else {
                contents.append(CommentContent(type: .linkedImg, link: url, imgURL: imgURL))
            }
        } else if link.text == nil {
            contents.append(CommentContent(type: .singleLink, link: url))
        } else {
            var title = CommentContentBuilder()
            title.appendChildren(of: link, attributes: attributes)
            if let text = Self.trimmed(title.pendingText) {
                contents.append(CommentContent(type: .linkedText, text: text, link: url))
            }
        }
    }

    private mutating func appendImage(_ image: any XMLElement) {
        guard let src = image["src"], let url = URL(string: src) else { return }
        flushText()

        if let last = contents.last, last.type == .singleImg {
            contents.removeLast()
            contents.append(CommentContent(type: .doubleImg, imgURL: last.imgURL, secondImgURL: url))
        } else {
            contents.append(CommentContent(type: .singleImg, imgURL: url))
        }
    }

    private mutating func flushText() {
        if let text = Self.trimmed(pendingText) {
            contents.append(CommentContent(type: .plainText, text: text))
        }
        pendingText = AttributedString()
    }

    /// `CharacterSet` rather than `Character.isWhitespace`, which keeps a zero-width space.
    private static func trimmed(_ text: AttributedString) -> AttributedString? {
        let isContent = { (character: Character) in
            !character.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) })
        }
        let characters = text.characters
        guard let first = characters.firstIndex(where: isContent),
              let last = characters.lastIndex(where: isContent)
        else { return nil }
        return AttributedString(text[first...last])
    }
}
