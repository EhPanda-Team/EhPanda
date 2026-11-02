import AppModels
import AppTools
import Foundation
import Kanna

extension Parser {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parseComments(doc: any HTMLDocument) -> [GalleryComment] {
        var comments = [GalleryComment]()
        for link in doc.xpath("//div [@id='cdiv']") {
            for c1Link in link.xpath("//div [@class='c1']") {
                guard let c3Node = c1Link.at_xpath("//div [@class='c3']")?.text,
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
                let author = String(c3Node[rangeB.upperBound...])
                let commentTime = String(c3Node[rangeA.upperBound..<rangeB.lowerBound])

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
/// `<`, `>` and `&`, and no replacing can tell that markup from a `<strong>` the author typed.
private struct CommentContentBuilder {
    private var contents = [CommentContent]()
    private var pendingText = ""

    /// `node()` rather than `children`, which lists elements only and would lose the text.
    mutating func appendChildren(of parent: any XMLElement) {
        for child in parent.xpath("node()") {
            append(child)
        }
    }

    mutating func build() -> [CommentContent] {
        flushText()
        return contents
    }

    private mutating func append(_ node: any XMLElement) {
        switch node.tagName {
        case "text":
            pendingText += node.text ?? ""
        case "br":
            pendingText += "\n"
        case "a":
            appendLink(node)
        case "img":
            appendImage(node)
        case "div":
            // Not comment text: no saved comment has one, and the parser has always left them out.
            break
        default:
            // Inline formatting such as `strong`, `em` or `span`: its text belongs to the run.
            appendChildren(of: node)
        }
    }

    private mutating func appendLink(_ link: any XMLElement) {
        guard let href = link["href"], let url = URL(string: href) else {
            appendChildren(of: link)
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
        } else if let title = link.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if !title.isEmpty {
                contents.append(CommentContent(type: .linkedText, text: title, link: url))
            }
        } else {
            contents.append(CommentContent(type: .singleLink, link: url))
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
        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""
        if !text.isEmpty {
            contents.append(CommentContent(type: .plainText, text: text))
        }
    }
}
