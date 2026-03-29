import Kanna
import Foundation

extension Parser {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parseComments(doc: HTMLDocument) -> [GalleryComment] {
        var comments = [GalleryComment]()
        for link in doc.xpath("//div [@id='cdiv']") {
            for c1Link in link.xpath("//div [@class='c1']") {
                guard let c3Node = c1Link.at_xpath("//div [@class='c3']")?.text,
                      let c6Node = c1Link.at_xpath("//div [@class='c6']"),
                      let commentID = c6Node["id"]?
                    .replacingOccurrences(of: "comment_", with: ""),
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
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func parseCommentContent(node: XMLElement) -> [CommentContent] {
        var contents = [CommentContent]()

        for div in node.xpath("//div") {
            node.removeChild(div)
        }
        for span in node.xpath("span") {
            node.removeChild(span)
        }

        guard var rawContent = node.innerHTML?
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "</span>", with: "")
        else { return [] }

        while (node.xpath("//a").count
               + node.xpath("//img").count) > 0 {
            var tmpLink: XMLElement?

            let links = [
                node.at_xpath("//a"),
                node.at_xpath("//img")
            ]
                .compactMap({ $0 })

            links.forEach { newLink in
                if tmpLink == nil {
                    tmpLink = newLink
                } else {
                    if let tmpHTML = tmpLink?.toHTML,
                       let newHTML = newLink.toHTML,
                       let tmpBound = rawContent.range(of: tmpHTML)?.lowerBound,
                       let newBound = rawContent.range(of: newHTML)?.lowerBound,
                       newBound < tmpBound {
                        tmpLink = newLink
                    }
                }
            }

            guard let link = tmpLink,
                  let html = link.toHTML?
                .replacingOccurrences(of: "<br>", with: "\n")
                .replacingOccurrences(of: "</span>", with: ""),
                  let range = rawContent.range(of: html)
            else { continue }

            let text = String(rawContent[..<range.lowerBound])
            if !text.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                contents.append(
                    CommentContent(
                        type: .plainText,
                        text: text
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                    )
                )
            }

            if let href = link["href"], let url = URL(string: href) {
                if let imgSrc = link.at_xpath("//img")?["src"],
                   let imgURL = URL(string: imgSrc) {
                    if let content = contents.last,
                       content.type == .linkedImg {
                        contents = contents.dropLast()
                        contents.append(
                            CommentContent(
                                type: .doubleLinkedImg,
                                link: content.link,
                                imgURL: content.imgURL,
                                secondLink: url,
                                secondImgURL: imgURL
                            )
                        )
                    } else {
                        contents.append(
                            CommentContent(
                                type: .linkedImg,
                                link: url,
                                imgURL: imgURL
                            )
                        )
                    }
                } else if let text = link.text {
                    if !text
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                            .isEmpty {
                        contents.append(
                            CommentContent(
                                type: .linkedText,
                                text: text
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ),
                                link: url
                            )
                        )
                    }
                } else {
                    contents.append(
                        CommentContent(
                            type: .singleLink,
                            link: url
                        )
                    )
                }
            } else if let src = link["src"], let url = URL(string: src) {
                if let content = contents.last,
                   content.type == .singleImg {
                    contents = contents.dropLast()
                    contents.append(
                        CommentContent(
                            type: .doubleImg,
                            imgURL: content.imgURL,
                            secondImgURL: url
                        )
                    )
                } else {
                    contents.append(
                        CommentContent(
                            type: .singleImg,
                            imgURL: url
                        )
                    )
                }

            }

            rawContent.removeSubrange(..<range.upperBound)
            node.removeChild(link)

            if (node.xpath("//a").count
                + node.xpath("//img").count) <= 0 {
                if !rawContent
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                    contents.append(
                        CommentContent(
                            type: .plainText,
                            text: rawContent
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                        )
                    )
                }
            }
        }

        if !rawContent.isEmpty && contents.isEmpty {
            if !rawContent
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {
                contents.append(
                    CommentContent(
                        type: .plainText,
                        text: rawContent
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                    )
                )
            }
        }

        return contents
    }
}
