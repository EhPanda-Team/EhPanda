import AppTools
import Kanna
import AppModels
import SwiftUI

extension Parser {
    public static func parseGalleries(doc: HTMLDocument) throws -> [Gallery] {
        let galleries: [Gallery]
        switch parseDisplayMode(doc: doc) {
        case "Minimal":
            galleries = try parseMinimalModeGalleries(doc: doc, parsesTags: false)
        case "Minimal+":
            galleries = try parseMinimalModeGalleries(doc: doc, parsesTags: true)
        case "Compact":
            galleries = try parseCompactModeGalleries(doc: doc)
        case "Extended":
            galleries = try parseExtendedModeGalleries(doc: doc)
        case "Thumbnail":
            galleries = try parseThumbnailModeGalleries(doc: doc)
        default:
            // Toplists doesn't have a display mode selector and it's compact mode
            galleries = try parseCompactModeGalleries(doc: doc)
        }

        // An explicit error banner names the real cause of a page that yielded nothing, so it is
        // reported in preference to a bare "no results" render.
        if galleries.isEmpty, let error = parseResponseError(doc: doc) {
            throw error
        }
        return galleries
    }
}

// MARK: DisplayMode
private extension Parser {
    /// Returns `nil` when the page carries no display-mode selector.
    ///
    /// Absence is a normal outcome rather than a parse failure: toplists legitimately ship without
    /// the selector and are laid out in compact mode, which the caller's `default` branch handles.
    static func parseDisplayMode(doc: HTMLDocument) -> String? {
        guard let containerNode = doc.at_xpath("//div [@id='dms']") ?? doc.at_xpath("//div [@class='searchnav']")
        else { return nil }

        var dmsNode: XMLElement?
        for select in containerNode.xpath("//select") where select["onchange"]?.contains("inline_set=dm_") == true {
            dmsNode = select
            break
        }
        guard let dmsNode else { return nil }

        for option in dmsNode.xpath("//option") where option["selected"] == "selected" {
            if let displayMode = option.text {
                return displayMode
            }
        }
        return nil
    }

    static func parseMinimalModeGalleries(doc: HTMLDocument, parsesTags: Bool) throws -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//tr") {
            let gltmNode = link.at_xpath("//div [@class='gltm']")
            // Missing tags intentionally degrade to an empty tag list.
            let tags = degrading("Gallery tags", { try parseGalleryTags(node: gltmNode) }) ?? []
            guard let gl2mNode = link.at_xpath("//td [@class='gl2m']"),
                  let gl3mNode = link.at_xpath("//td [@class='gl3m glname']"),
                  // A malformed panel intentionally drops only this gallery row.
                  let panelInfo = degrading("Thumbnail panel", { try parseThumbnailPanel(node: gl2mNode) }),
                  // A missing title intentionally drops only this gallery row.
                  let (galleryTitle, galleryURL) = degrading("Gallery title", {
                      try parseGalleryTitle(node: gl3mNode)
                  })
            else { continue }
            galleries.append(
                .init(
                    gid: galleryURL.pathComponents[2],
                    token: galleryURL.pathComponents[3],
                    title: galleryTitle,
                    rating: panelInfo.rating,
                    tags: parsesTags ? tags : [],
                    category: panelInfo.category,
                    // A missing uploader intentionally degrades to nil.
                    uploader: degrading("Uploader", { try parseUploader(node: link) }),
                    pageCount: panelInfo.pageCount,
                    postedDate: panelInfo.publishedDate,
                    coverURL: panelInfo.coverURL,
                    galleryURL: galleryURL
                )
            )
        }
        return galleries
    }

    static func parseCompactModeGalleries(doc: HTMLDocument) throws -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//tr") {
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                  let gl3cNode = link.at_xpath("//td [@class='gl3c glname']"),
                  // A malformed panel intentionally drops only this gallery row.
                  let panelInfo = degrading("Thumbnail panel", { try parseThumbnailPanel(node: gl2cNode) }),
                  // A missing title intentionally drops only this gallery row.
                  let (galleryTitle, galleryURL) = degrading("Gallery title", {
                      try parseGalleryTitle(node: gl3cNode)
                  })
            else { continue }
            galleries.append(
                .init(
                    gid: galleryURL.pathComponents[2],
                    token: galleryURL.pathComponents[3],
                    title: galleryTitle,
                    rating: panelInfo.rating,
                    // Missing tags intentionally degrade to an empty tag list.
                    tags: degrading("Gallery tags", { try parseGalleryTags(node: gl3cNode) }) ?? [],
                    category: panelInfo.category,
                    // A missing uploader intentionally degrades to nil.
                    uploader: degrading("Uploader", { try parseUploader(node: link) }),
                    pageCount: panelInfo.pageCount,
                    postedDate: panelInfo.publishedDate,
                    coverURL: panelInfo.coverURL,
                    galleryURL: galleryURL
                )
            )
        }

        return galleries
    }

    static func parseExtendedModeGalleries(doc: HTMLDocument) throws -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//tr") {
            guard let gl3eSiblingNode = link.at_xpath("//div [@class='gl3e']")?.nextSibling,
                  // A malformed panel intentionally drops only this gallery row.
                  let panelInfo = degrading("Thumbnail panel", { try parseThumbnailPanel(node: link) }),
                  // A missing title intentionally drops only this gallery row.
                  let (galleryTitle, galleryURL) = degrading("Gallery title", {
                      try parseGalleryTitle(node: gl3eSiblingNode)
                  })
            else { continue }
            galleries.append(
                .init(
                    gid: galleryURL.pathComponents[2],
                    token: galleryURL.pathComponents[3],
                    title: galleryTitle,
                    rating: panelInfo.rating,
                    // Missing tags intentionally degrade to an empty tag list.
                    tags: degrading("Gallery tags", { try parseGalleryTags(node: gl3eSiblingNode) }) ?? [],
                    category: panelInfo.category,
                    uploader: panelInfo.uploader,
                    pageCount: panelInfo.pageCount,
                    postedDate: panelInfo.publishedDate,
                    coverURL: panelInfo.coverURL,
                    galleryURL: galleryURL
                )
            )
        }
        return galleries
    }

    static func parseThumbnailModeGalleries(doc: HTMLDocument) throws -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//div [@class='gl1t']") {
            let gl6tNode = link.at_xpath("//div [@class='gl6t']")
            // A malformed panel intentionally drops only this gallery row.
            guard let panelInfo = degrading("Thumbnail panel", { try parseThumbnailPanel(node: link) }),
                  // A missing title intentionally drops only this gallery row.
                  let (galleryTitle, galleryURL) = degrading("Gallery title", {
                      try parseGalleryTitle(node: link)
                  })
            else { continue }
            galleries.append(
                .init(
                    gid: galleryURL.pathComponents[2],
                    token: galleryURL.pathComponents[3],
                    title: galleryTitle,
                    rating: panelInfo.rating,
                    // Missing tags intentionally degrade to an empty tag list.
                    tags: degrading("Gallery tags", { try parseGalleryTags(node: gl6tNode) }) ?? [],
                    category: panelInfo.category,
                    pageCount: panelInfo.pageCount,
                    postedDate: panelInfo.publishedDate,
                    coverURL: panelInfo.coverURL,
                    galleryURL: galleryURL
                )
            )
        }
        return galleries
    }
}

// MARK: Helpers
private extension Parser {
    static func parseThumbnailPanel(node: XMLElement) throws -> ThumbnailPanelInfo {
        var tmpCoverURL: URL?
        var tmpCategory: AppModels.Category?
        var tmpPublishedDate: Date?
        var tmpPageCount: Int?
        var uploader: String?

        for div in node.xpath("//div") {
            if let imgNode = div.at_css("img"),
               let urlString = imgNode["data-src"] ?? imgNode["src"], let url = URL(string: urlString),
               [Defaults.URL.torrentDownload, Defaults.URL.torrentDownloadInvalid].map(\.absoluteString)
                .contains(where: { $0 == urlString }) == false, imgNode["alt"] != "T" {
                tmpCoverURL = url
            }
            if let rawValue = div.text, let category = AppModels.Category(rawValue: rawValue) {
                tmpCategory = category
            }
            if let onClick = div["onclick"], !onClick.isEmpty, let dateString = div.text,
               // An invalid optional date intentionally leaves the published date unset.
               let date = degrading("Published date", {
                   try parseDate(time: dateString, format: Defaults.DateFormat.publish)
               }) {
                tmpPublishedDate = date
            }
            if let components = div.text?.split(separator: " "), components.count == 2,
               ["page", "pages"].contains(components[1]), let pageCount = Int(components[0]) {
                tmpPageCount = pageCount
            }
            // Extended display mode uses this
            if let aLink = div.at_xpath("//a"), aLink["href"]?.contains("uploader") == true {
                uploader = aLink.text
            } else if div.text == "(Disowned)" {
                uploader = div.text
            }
        }

        guard let coverURL = tmpCoverURL,
              let category = tmpCategory,
              // An invalid rating intentionally makes only this panel unavailable.
              let ratingResult = degrading("Panel rating", { try parseRating(node: node) }),
              let publishedDate = tmpPublishedDate,
              let pageCount = tmpPageCount
        else { throw AppError.parseFailed }
        return ThumbnailPanelInfo(
            coverURL: coverURL,
            category: category,
            rating: ratingResult.imgRating,
            publishedDate: publishedDate,
            pageCount: pageCount,
            uploader: uploader
        )
    }

    static func parseGalleryTitle(node: XMLElement) throws -> (String, URL) {
        func findTitle(glink: XMLElement) throws -> (String, URL) {
            guard let glinkParentNode = glink.parent,
                  let glinkGrandParentNode = glinkParentNode.parent,
                  let title = glink.text,
                  let urlString = glinkParentNode["href"] ?? glinkGrandParentNode["href"],
                  let url = URL(string: urlString),
                  url.pathComponents.count >= 4
            else { throw AppError.parseFailed }
            return (title, url)
        }

        for glink in node.xpath("//div") where glink.className?.contains("glink") == true {
            // A malformed div title candidate intentionally falls through to other candidates.
            if let result = degrading("Div title candidate", { try findTitle(glink: glink) }) {
                return result
            }
        }
        for glink in node.xpath("//span") where glink.className?.contains("glink") == true {
            // A malformed span title candidate intentionally falls through to parse failure.
            if let result = degrading("Span title candidate", { try findTitle(glink: glink) }) {
                return result
            }
        }
        throw AppError.parseFailed
    }

    static func parseGalleryTags(node: XMLElement?) throws -> [GalleryTag] {
        guard let node = node else { throw AppError.parseFailed }
        var tags = [GalleryTag]()
        for tagLink in node.xpath("//div")
        where ["gt", "gtl"].contains(tagLink.className) && tagLink["title"]?.isEmpty == false {
            guard let titleComponents = tagLink["title"]?.split(separator: ":"),
                  titleComponents.count == 2
            else { continue }
            var contentTextColor: Color?
            var contentBackgroundColor: Color?
            let namespace = String(titleComponents[0])
            let contentText = String(titleComponents[1])
            if let style = tagLink["style"], let rangeB = style.range(of: ",#"),
               let rangeA = style.range(of: "background:radial-gradient(#") {
                let hex = String(style[rangeA.upperBound..<rangeB.lowerBound])
                if hex.count == 6, let red = Int(hex.prefix(2), radix: 16),
                   let green = Int(hex.prefix(4).suffix(2), radix: 16),
                   let blue = Int(hex.suffix(2), radix: 16) {
                    contentBackgroundColor = .init(hex: .init(hex))
                    if (.init(red) * 0.299 + .init(green) * 0.587 + .init(blue) * 0.114) > 151 {
                        contentTextColor = .secondary
                    } else {
                        contentTextColor = .white
                    }
                }
            }
            if let index = tags.firstIndex(where: { $0.rawNamespace == namespace }) {
                let contents = tags[index].contents
                let galleryTagContent = GalleryTag.Content(
                    rawNamespace: namespace, text: contentText,
                    isVotedUp: false, isVotedDown: false,
                    textColor: contentTextColor,
                    backgroundColor: contentBackgroundColor
                )
                let newContents = contents + [galleryTagContent]
                tags[index] = .init(rawNamespace: namespace, contents: newContents)
            } else {
                let galleryTagContent = GalleryTag.Content(
                    rawNamespace: namespace, text: contentText,
                    isVotedUp: false, isVotedDown: false,
                    textColor: contentTextColor,
                    backgroundColor: contentBackgroundColor
                )
                tags.append(.init(rawNamespace: namespace, contents: [galleryTagContent]))
            }
        }
        return tags
    }

    static func parseUploader(node: XMLElement) throws -> String {
        var tmpUploader: String?
        for link in node.xpath("//td") where link.className?.contains("glhide") == true {
            for divLink in link.xpath("//div")
            where ["page", "pages"].contains(where: { divLink.text?.contains($0) != false }) == false {
                if let aLink = divLink.at_xpath("//a"),
                   aLink["href"]?.contains("uploader") == true,
                   let aText = aLink.text {
                    tmpUploader = aText
                } else if divLink.text == "(Disowned)" {
                    tmpUploader = divLink.text
                }
            }
        }
        guard let uploader = tmpUploader else { throw AppError.parseFailed }
        return uploader
    }
}
