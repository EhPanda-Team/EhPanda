//
//  Parser.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import OpenCC
import SwiftUI

struct Parser {
    // MARK: List
    static func parseGalleries(doc: HTMLDocument) throws -> [Gallery] {
        func parseDisplayMode(doc: HTMLDocument) throws -> String {
            guard let containerNode = doc.at_xpath("//div [@id='dms']") ?? doc.at_xpath("//div [@class='searchnav']")
            else { throw AppError.parseFailed }

            var dmsNode: XMLElement?
            for select in containerNode.xpath("//select") where select["onchange"]?.contains("inline_set=dm_") == true {
                dmsNode = select
                break
            }
            guard let dmsNode else { throw AppError.parseFailed }

            for option in dmsNode.xpath("//option") where option["selected"] == "selected" {
                if let displayMode = option.text {
                    return displayMode
                }
            }
            throw AppError.parseFailed
        }
        func parseThumbnailPanel(node: XMLElement) throws -> (URL, Category, Float, Date, Int, String?) {
            var tmpCoverURL: URL?
            var tmpCategory: Category?
            var tmpPublishedDate: Date?
            var tmpPageCount: Int?
            var uploader: String?

            for div in node.xpath("//div") {
                if let imgNode = div.at_css("img"),
                   let urlString = imgNode["data-src"] ?? imgNode["src"], let url = URL(string: urlString),
                   [Defaults.URL.torrentDownload, Defaults.URL.torrentDownloadInvalid].map(\.absoluteString)
                    .contains(where: { $0 == urlString }) == false, imgNode["alt"] != "T"
                {
                    tmpCoverURL = url
                }
                if let rawValue = div.text, let category = Category(rawValue: rawValue) {
                    tmpCategory = category
                }
                if let onClick = div["onclick"], !onClick.isEmpty, let dateString = div.text,
                   let date = try? parseDate(time: dateString, format: Defaults.DateFormat.publish)
                {
                    tmpPublishedDate = date
                }
                if let components = div.text?.split(separator: " "), components.count == 2,
                   ["page", "pages"].contains(components[1]), let pageCount = Int(components[0])
                {
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
                  let (rating, _, _) = try? parseRating(node: node),
                  let publishedDate = tmpPublishedDate,
                  let pageCount = tmpPageCount
            else { throw AppError.parseFailed }
            return (coverURL, category, rating, publishedDate, pageCount, uploader)
        }
        func parseGalleryTitle(node: XMLElement) throws -> (String, URL) {
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
                if let result = try? findTitle(glink: glink) {
                    return result
                }
            }
            for glink in node.xpath("//span") where glink.className?.contains("glink") == true {
                if let result = try? findTitle(glink: glink) {
                    return result
                }
            }
            throw AppError.parseFailed
        }
        func parseGalleryTags(node: XMLElement?) throws -> [GalleryTag] {
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
                   let rangeA = style.range(of: "background:radial-gradient(#")
                {
                    let hex = String(style[rangeA.upperBound..<rangeB.lowerBound])
                    if hex.count == 6, let red = Int(hex.prefix(2), radix: 16),
                       let green = Int(hex.prefix(4).suffix(2), radix: 16),
                       let blue = Int(hex.suffix(2), radix: 16)
                    {
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
        func parseUploader(node: XMLElement) throws -> String {
            var tmpUploader: String?
            for link in node.xpath("//td") where link.className?.contains("glhide") == true {
                for divLink in link.xpath("//div")
                where ["page", "pages"].contains(where: { divLink.text?.contains($0) != false }) == false {
                    if let aLink = divLink.at_xpath("//a"),
                       aLink["href"]?.contains("uploader") == true,
                       let aText = aLink.text
                    {
                        tmpUploader = aText
                    } else if divLink.text == "(Disowned)" {
                        tmpUploader = divLink.text
                    }
                }
            }
            guard let uploader = tmpUploader else { throw AppError.parseFailed }
            return uploader
        }

        // MARK: Galleries (Minimal)
        func parseMinimalModeGalleries(doc: HTMLDocument, parsesTags: Bool) throws -> [Gallery] {
            var galleries = [Gallery]()
            for link in doc.xpath("//tr") {
                let gltmNode = link.at_xpath("//div [@class='gltm']")
                let tags = (try? parseGalleryTags(node: gltmNode)) ?? []
                guard let gl2mNode = link.at_xpath("//td [@class='gl2m']"),
                      let gl3mNode = link.at_xpath("//td [@class='gl3m glname']"),
                      let (coverURL, category, rating, publishedDate, pageCount, _) =
                        try? parseThumbnailPanel(node: gl2mNode),
                      let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: gl3mNode)
                else { continue }
                galleries.append(
                    .init(
                        gid: galleryURL.pathComponents[2],
                        token: galleryURL.pathComponents[3],
                        title: galleryTitle,
                        rating: rating,
                        tags: parsesTags ? tags : [],
                        category: category,
                        uploader: try? parseUploader(node: link),
                        pageCount: pageCount,
                        postedDate: publishedDate,
                        coverURL: coverURL,
                        galleryURL: galleryURL
                    )
                )
            }
            return galleries
        }
        // MARK: Galleries (Compact)
        func parseCompactModeGalleries(doc: HTMLDocument) throws -> [Gallery] {
            var galleries = [Gallery]()
            for link in doc.xpath("//tr") {
                guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                      let gl3cNode = link.at_xpath("//td [@class='gl3c glname']"),
                      let (coverURL, category, rating, publishedDate, pageCount, _) =
                        try? parseThumbnailPanel(node: gl2cNode),
                      let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: gl3cNode)
                else { continue }
                galleries.append(
                    .init(
                        gid: galleryURL.pathComponents[2],
                        token: galleryURL.pathComponents[3],
                        title: galleryTitle,
                        rating: rating,
                        tags: (try? parseGalleryTags(node: gl3cNode)) ?? [],
                        category: category,
                        uploader: try? parseUploader(node: link),
                        pageCount: pageCount,
                        postedDate: publishedDate,
                        coverURL: coverURL,
                        galleryURL: galleryURL
                    )
                )
            }

            return galleries
        }
        // MARK: Galleries (Extended)
        func parseExtendedModeGalleries(doc: HTMLDocument) throws -> [Gallery] {
            var galleries = [Gallery]()
            for link in doc.xpath("//tr") {
                guard let gl3eSiblingNode = link.at_xpath("//div [@class='gl3e']")?.nextSibling,
                      let (coverURL, category, rating, publishedDate, pageCount, uploader) =
                        try? parseThumbnailPanel(node: link),
                      let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: gl3eSiblingNode)
                else { continue }
                galleries.append(
                    .init(
                        gid: galleryURL.pathComponents[2],
                        token: galleryURL.pathComponents[3],
                        title: galleryTitle,
                        rating: rating,
                        tags: (try? parseGalleryTags(node: gl3eSiblingNode)) ?? [],
                        category: category,
                        uploader: uploader,
                        pageCount: pageCount,
                        postedDate: publishedDate,
                        coverURL: coverURL,
                        galleryURL: galleryURL
                    )
                )
            }
            return galleries
        }
        // MARK: Galleries (Thumbnail)
        func parseThumbnailModeGalleries(doc: HTMLDocument) throws -> [Gallery] {
            var galleries = [Gallery]()
            for link in doc.xpath("//div [@class='gl1t']") {
                let gl6tNode = link.at_xpath("//div [@class='gl6t']")
                guard let (coverURL, category, rating, publishedDate, pageCount, _) =
                        try? parseThumbnailPanel(node: link),
                      let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: link)
                else { continue }
                galleries.append(
                    .init(
                        gid: galleryURL.pathComponents[2],
                        token: galleryURL.pathComponents[3],
                        title: galleryTitle,
                        rating: rating,
                        tags: (try? parseGalleryTags(node: gl6tNode)) ?? [],
                        category: category,
                        pageCount: pageCount,
                        postedDate: publishedDate,
                        coverURL: coverURL,
                        galleryURL: galleryURL
                    )
                )
            }
            return galleries
        }

        let galleries: [Gallery]
        switch try? parseDisplayMode(doc: doc) {
        case "Minimal":
            galleries = (try? parseMinimalModeGalleries(doc: doc, parsesTags: false)) ?? []
        case "Minimal+":
            galleries = (try? parseMinimalModeGalleries(doc: doc, parsesTags: true)) ?? []
        case "Compact":
            galleries = (try? parseCompactModeGalleries(doc: doc)) ?? []
        case "Extended":
            galleries = (try? parseExtendedModeGalleries(doc: doc)) ?? []
        case "Thumbnail":
            galleries = (try? parseThumbnailModeGalleries(doc: doc)) ?? []
        default:
            // Toplists doesn't have a display mode selector and it's compact mode
            galleries = (try? parseCompactModeGalleries(doc: doc)) ?? []
        }

        if galleries.isEmpty, let banInterval = parseBanInterval(doc: doc) {
            throw AppError.ipBanned(banInterval)
        }
        return galleries
    }

    // MARK: Detail
    static func parseGalleryURL(doc: HTMLDocument) throws -> URL {
        guard let galleryURLString = doc.at_xpath("//div [@class='sb']")?.at_xpath("//a")?["href"],
              let galleryURL = URL(string: galleryURLString) else { throw AppError.parseFailed }
        return galleryURL
    }
    static func parseGalleryDetail(doc: HTMLDocument, gid: String) throws -> (GalleryDetail, GalleryState) {
        func parsePreviewConfig(doc: HTMLDocument) throws -> PreviewConfig {
            guard let previewMode = try? parsePreviewMode(doc: doc),
                  let gdoNode = doc.at_xpath("//div [@id='gdo']"),
                  let rows = gdoNode.at_xpath("//div [@id='gdo2']")?.xpath("//div")
            else { throw AppError.parseFailed }

            for rowLink in rows where rowLink.className == "ths nosel" {
                guard let rowsCount = Int(
                    rowLink.text?.replacingOccurrences(
                        of: " rows", with: "") ?? ""
                ) else { throw AppError.parseFailed }

                if previewMode == "gdtl" {
                    return .large(rows: rowsCount)
                } else {
                    return .normal(rows: rowsCount)
                }
            }
            throw AppError.parseFailed
        }

        func parseCoverURL(node: XMLElement?) throws -> URL {
            guard let coverHTML = node?.at_xpath("//div [@id='gd1']")?.innerHTML,
                  let rangeA = coverHTML.range(of: "url("), let rangeB = coverHTML.range(of: ")"),
                  let url = URL(string: .init(coverHTML[rangeA.upperBound..<rangeB.lowerBound]))
            else { throw AppError.parseFailed }

            return url
        }

        func parseGalleryTags(node: XMLElement) throws -> [GalleryTag] {
            var tags = [GalleryTag]()
            for link in node.xpath("//tr") {
                guard let tcText = link.at_xpath("//td [@class='tc']")?.text else { continue }
                let namespace = String(tcText.dropLast())
                var contents = [GalleryTag.Content]()
                for divLink in link.xpath("//div") {
                    guard var text = divLink.text, let aClass = divLink.at_xpath("//a")?.className else { continue }
                    if let range = text.range(of: " | ") {
                        text = .init(text[..<range.lowerBound])
                    }
                    contents.append(
                        .init(
                            rawNamespace: namespace, text: text,
                            isVotedUp: aClass == "tup",
                            isVotedDown: aClass == "tdn",
                            textColor: nil,
                            backgroundColor: nil
                        )
                    )
                }

                tags.append(.init(rawNamespace: namespace, contents: contents))
            }

            return tags
        }

        func parseArcAndTor(node: XMLElement?) throws -> (URL?, Int) {
            guard let node = node else { throw AppError.parseFailed }

            var archiveURL: URL?
            for g2gspLink in node.xpath("//p [@class='g2 gsp']") {
                if archiveURL == nil {
                    archiveURL = try? parseArchiveURL(node: g2gspLink)
                } else {
                    break
                }
            }

            var tmpTorrentCount: Int?
            for g2Link in node.xpath("//p [@class='g2']") {
                if let aText = g2Link.at_xpath("//a")?.text,
                   let rangeA = aText.range(of: "Torrent Download ("),
                   let rangeB = aText.range(of: ")")
                {
                    tmpTorrentCount = Int(aText[rangeA.upperBound..<rangeB.lowerBound])
                }
                if archiveURL == nil {
                    archiveURL = try? parseArchiveURL(node: g2Link)
                }
            }

            guard let torrentCount = tmpTorrentCount
            else { throw AppError.parseFailed }

            return (archiveURL, torrentCount)
        }

        func parseInfoPanel(node: XMLElement?) throws -> [String] {
            guard let object = node?.xpath("//tr")
            else { throw AppError.parseFailed }

            var infoPanel = Array(
                repeating: "",
                count: 8
            )
            for gddLink in object {
                guard let gdt1Text = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                      let gdt2Text = gddLink.at_xpath("//td [@class='gdt2']")?.text
                else { continue }
                let aHref = gddLink.at_xpath("//td [@class='gdt2']")?.at_xpath("//a")?["href"]

                if gdt1Text.contains("Posted") {
                    infoPanel[0] = gdt2Text
                }
                if gdt1Text.contains("Parent") {
                    infoPanel[1] = aHref ?? "None"
                }
                if gdt1Text.contains("Visible") {
                    infoPanel[2] = gdt2Text
                }
                if gdt1Text.contains("Language") {
                    let words = gdt2Text.split(separator: " ")
                    if !words.isEmpty {
                        infoPanel[3] = words[0]
                            .trimmingCharacters(in: .whitespaces)
                    }
                }
                if gdt1Text.contains("File Size") {
                    infoPanel[4] = gdt2Text
                        .replacingOccurrences(of: " KB", with: "")
                        .replacingOccurrences(of: " MB", with: "")
                        .replacingOccurrences(of: " GB", with: "")

                    if gdt2Text.contains("KB") { infoPanel[5] = "KB" }
                    if gdt2Text.contains("MB") { infoPanel[5] = "MB" }
                    if gdt2Text.contains("GB") { infoPanel[5] = "GB" }
                }
                if gdt1Text.contains("Length") {
                    infoPanel[6] = gdt2Text.replacingOccurrences(of: " pages", with: "")
                }
                if gdt1Text.contains("Favorited") {
                    infoPanel[7] = gdt2Text
                        .replacingOccurrences(of: " times", with: "")
                        .replacingOccurrences(of: "Never", with: "0")
                        .replacingOccurrences(of: "Once", with: "1")
                }
            }

            guard infoPanel.filter({ !$0.isEmpty }).count == 8
            else { throw AppError.parseFailed }

            return infoPanel
        }

        func parseVisibility(value: String) throws -> GalleryVisibility {
            guard value != "Yes" else { return .yes }
            guard let rangeA = value.range(of: "("),
                  let rangeB = value.range(of: ")")
            else { throw AppError.parseFailed }

            let reason = String(value[rangeA.upperBound..<rangeB.lowerBound])
            return .no(reason: reason)
        }

        func parseUploader(node: XMLElement?) throws -> String {
            guard let gdnNode = node?.at_xpath("//div [@id='gdn']") else {
                throw AppError.parseFailed
            }

            if let aText = gdnNode.at_xpath("//a")?.text {
                return aText
            } else if let gdnText = gdnNode.text {
                return gdnText
            } else {
                throw AppError.parseFailed
            }
        }

        var tmpGalleryDetail: GalleryDetail?
        var tmpGalleryState: GalleryState?
        for link in doc.xpath("//div [@class='gm']") {
            guard tmpGalleryDetail == nil, tmpGalleryState == nil,
                  let gd3Node = link.at_xpath("//div [@id='gd3']"),
                  let gd4Node = link.at_xpath("//div [@id='gd4']"),
                  let gd5Node = link.at_xpath("//div [@id='gd5']"),
                  let gddNode = gd3Node.at_xpath("//div [@id='gdd']"),
                  let gdrNode = gd3Node.at_xpath("//div [@id='gdr']"),
                  let gdfNode = gd3Node.at_xpath("//div [@id='gdf']"),
                  let coverURL = try? parseCoverURL(node: link),
                  let tags = try? parseGalleryTags(node: gd4Node),
                  let previewURLs = try? parsePreviewURLs(doc: doc),
                  let arcAndTor = try? parseArcAndTor(node: gd5Node),
                  let infoPanel = try? parseInfoPanel(node: gddNode),
                  let visibility = try? parseVisibility(value: infoPanel[2]),
                  let sizeCount = Float(infoPanel[4]),
                  let pageCount = Int(infoPanel[6]),
                  let favoritedCount = Int(infoPanel[7]),
                  let language = Language(rawValue: infoPanel[3]),
                  let engTitle = link.at_xpath("//h1 [@id='gn']")?.text,
                  let uploader = try? parseUploader(node: gd3Node),
                  let (imgRating, textRating, containsUserRating) = try? parseRating(node: gdrNode),
                  let ratingCount = Int(gdrNode.at_xpath("//span [@id='rating_count']")?.text ?? ""),
                  let category = Category(rawValue: gd3Node.at_xpath("//div [@id='gdc']")?.text ?? ""),
                  let postedDate = try? parseDate(time: infoPanel[0], format: Defaults.DateFormat.publish)
            else { continue }

            let isFavorited = gdfNode
                .at_xpath("//a [@id='favoritelink']")?
                .text?.contains("Add to Favorites") == false
            let gjText = link.at_xpath("//h1 [@id='gj']")?.text
            let jpnTitle = gjText?.isEmpty != false ? nil : gjText
            let parentURLString = infoPanel[1].isValidURL ? infoPanel[1] : ""

            tmpGalleryDetail = GalleryDetail(
                gid: gid,
                title: engTitle,
                jpnTitle: jpnTitle,
                isFavorited: isFavorited,
                visibility: visibility,
                rating: containsUserRating ? textRating ?? 0.0 : imgRating,
                userRating: containsUserRating ? imgRating : 0.0,
                ratingCount: ratingCount,
                category: category,
                language: language,
                uploader: uploader,
                postedDate: postedDate,
                coverURL: coverURL,
                archiveURL: arcAndTor.0,
                parentURL: URL(string: parentURLString),
                favoritedCount: favoritedCount,
                pageCount: pageCount,
                sizeCount: sizeCount,
                sizeType: infoPanel[5],
                torrentCount: arcAndTor.1
            )
            tmpGalleryState = GalleryState(
                gid: gid, tags: tags,
                previewURLs: previewURLs,
                previewConfig: try? parsePreviewConfig(doc: doc),
                comments: parseComments(doc: doc)
            )
            break
        }

        guard let galleryDetail = tmpGalleryDetail,
              let galleryState = tmpGalleryState
        else {
            if let reason = doc.at_xpath("//div [@class='d']")?.at_xpath("//p")?.text {
                if let rangeA = reason.range(of: "copyright claim by "),
                   let rangeB = reason.range(of: ".Sorry about that.")
                {
                    let owner = String(reason[rangeA.upperBound..<rangeB.lowerBound])
                    throw AppError.copyrightClaim(owner)
                } else {
                    throw AppError.expunged(reason)
                }
            } else if let banInterval = parseBanInterval(doc: doc) {
                throw AppError.ipBanned(banInterval)
            } else {
                throw AppError.parseFailed
            }
        }

        return (galleryDetail, galleryState)
    }

    // MARK: Preview
    static func parsePreviewURLs(doc: HTMLDocument) throws -> [Int: URL] {
        func parseNormalPreviewURLs(node: XMLElement) -> [Int: URL] {
            var previewURLs = [Int: URL]()

            for link in node.xpath("//div") where link.className == nil {
                guard let imgLink = link.at_xpath("//img"),
                      let index = Int(imgLink["alt"] ?? ""),
                      let linkStyle = link["style"],
                      let rangeA = linkStyle.range(of: "width:"),
                      let rangeB = linkStyle.range(of: "px; height:"),
                      let rangeC = linkStyle.range(of: "px; background"),
                      let rangeD = linkStyle.range(of: "url("),
                      let rangeE = linkStyle.range(of: ") -")
                else { continue }

                let remainingText = linkStyle[rangeE.upperBound...]
                guard let rangeF = remainingText.range(of: "px ")
                else { continue }

                let width = linkStyle[rangeA.upperBound..<rangeB.lowerBound]
                let height = linkStyle[rangeB.upperBound..<rangeC.lowerBound]
                let offset = remainingText[rangeE.upperBound..<rangeF.lowerBound]
                guard let plainURL = URL(string: .init(linkStyle[rangeD.upperBound..<rangeE.lowerBound]))
                else { continue }

                previewURLs[index] = URLUtil.normalPreviewURL(
                    plainURL: plainURL, width: String(width),
                    height: String(height), offset: String(offset)
                )
            }

            return previewURLs
        }
        func parseLargePreviewURLs(node: XMLElement) -> [Int: URL] {
            var previewURLs = [Int: URL]()

            for link in node.xpath("//img") {
                guard let index = Int(link["alt"] ?? ""),
                      let urlString = link["src"], !urlString.contains("blank.gif"),
                      let url = URL(string: urlString)
                else { continue }

                previewURLs[index] = url
            }

            return previewURLs
        }

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']"),
              let previewMode = try? parsePreviewMode(doc: doc)
        else { throw AppError.parseFailed }

        return previewMode == "gdtl"
            ? parseLargePreviewURLs(node: gdtNode)
            : parseNormalPreviewURLs(node: gdtNode)
    }

    // MARK: Comment
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

    // MARK: ImageURL
    static func parseThumbnailURLs(doc: HTMLDocument) throws -> [Int: URL] {
        var thumbnailURLs = [Int: URL]()

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']"),
              let previewMode = try? parsePreviewMode(doc: doc)
        else { throw AppError.parseFailed }

        for link in gdtNode.xpath("//div [@class='\(previewMode)']") {
            guard let aLink = link.at_xpath("//a"),
                  let thumbnailURLString = aLink["href"],
                  let thumbnailURL = URL(string: thumbnailURLString),
                  let index = Int(aLink.at_xpath("//img")?["alt"] ?? "")
            else { continue }

            thumbnailURLs[index] = thumbnailURL
        }

        return thumbnailURLs
    }

    static func parseSkipServerIdentifier(doc: HTMLDocument) throws -> String {
        guard let text = doc.at_xpath("//div [@id='i6']")?.at_xpath("//a [@id='loadfail']")?["onclick"],
              let rangeA = text.range(of: "nl('"), let rangeB = text.range(of: "')")
        else { throw AppError.parseFailed }
        return .init(text[rangeA.upperBound..<rangeB.lowerBound])
    }

    static func parseGalleryNormalImageURL(doc: HTMLDocument, index: Int) throws -> (Int, URL, URL?) {
        guard let i3Node = doc.at_xpath("//div [@id='i3']"),
              let imageURLString = i3Node.at_css("img")?["src"],
              let imageURL = URL(string: imageURLString)
        else { throw AppError.parseFailed }

        guard let i7Node = doc.at_xpath("//div [@id='i7']"),
              let originalImageURLString = i7Node.at_xpath("//a")?["href"],
              let originalImageURL = URL(string: originalImageURLString)
        else { return (index, imageURL, nil) }

        return (index, imageURL, originalImageURL)
    }

    static func parsePreviewMode(doc: HTMLDocument) throws -> String {
        guard let gdoNode = doc.at_xpath("//div [@id='gdo']"),
              let gdo4Node = gdoNode.at_xpath("//div [@id='gdo4']")
        else { return "gdtm" }

        for link in gdo4Node.xpath("//div") where link.text == "Large" {
            return link["class"] == "ths nosel" ? "gdtl" : "gdtm"
        }
        return "gdtm"
    }

    static func parseMPVKeys(doc: HTMLDocument) throws -> (String, [Int: String]) {
        var tmpMPVKey: String?
        var imgKeys = [Int: String]()

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let text = link.text,
                  let rangeA = text.range(of: "mpvkey = \""),
                  let rangeB = text.range(of: "\";\nvar imagelist = "),
                  let rangeC = text.range(of: "\"}]")
            else { continue }

            tmpMPVKey = String(text[rangeA.upperBound..<rangeB.lowerBound])

            guard let data = String(text[rangeB.upperBound..<rangeC.upperBound])
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "\"", with: "\"")
                .replacingOccurrences(of: "\n", with: "")
                .data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(
                    with: data) as? [[String: String]]
            else { throw AppError.parseFailed }

            array.enumerated().forEach { (index, dict) in
                if let imgKey = dict["k"] {
                    imgKeys[index + 1] = imgKey
                }
            }
        }

        guard let mpvKey = tmpMPVKey, !imgKeys.isEmpty
        else { throw AppError.parseFailed }

        return (mpvKey, imgKeys)
    }

    // MARK: User
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

    // MARK: Archive
    static func parseGalleryArchive(doc: HTMLDocument) throws -> GalleryArchive {
        guard let node = doc.at_xpath("//table")
        else { throw AppError.parseFailed }

        var hathArchives = [GalleryArchive.HathArchive]()
        for link in node.xpath("//td") {
            var tmpResolution: ArchiveResolution?
            var tmpFileSize: String?
            var tmpGPPrice: String?

            for pLink in link.xpath("//p") {
                if let pText = pLink.text {
                    if let res = ArchiveResolution(rawValue: pText) {
                        tmpResolution = res
                    }
                    if pText.contains("N/A") {
                        tmpFileSize = "N/A"
                        tmpGPPrice = "N/A"

                        if tmpResolution != nil {
                            break
                        }
                    } else {
                        if pText.contains("KB")
                            || pText.contains("MB")
                            || pText.contains("GB")
                        {
                            tmpFileSize = pText
                        } else {
                            tmpGPPrice = pText
                        }
                    }
                }
            }

            guard let resolution = tmpResolution,
                  let fileSize = tmpFileSize,
                  let gpPrice = tmpGPPrice
            else { continue }

            hathArchives.append(
                GalleryArchive.HathArchive(
                    resolution: resolution,
                    fileSize: fileSize,
                    gpPrice: gpPrice
                )
            )
        }

        return GalleryArchive(hathArchives: hathArchives)
    }

    // MARK: Torrent
    static func parseGalleryTorrents(doc: HTMLDocument) -> [GalleryTorrent] {
        var torrents = [GalleryTorrent]()

        for link in doc.xpath("//form") {
            var tmpPostedTime: String?
            var tmpFileSize: String?
            var tmpSeedCount: Int?
            var tmpPeerCount: Int?
            var tmpDownloadCount: Int?
            var tmpUploader: String?
            var tmpFileName: String?
            var tmpHash: String?
            var tmpTorrentURL: URL?

            for trLink in link.xpath("//tr") {
                for tdLink in trLink.xpath("//td") {
                    if let tdText = tdLink.text {
                        if tdText.contains("Posted: ") {
                            tmpPostedTime = tdText.replacingOccurrences(of: "Posted: ", with: "")
                        }
                        if tdText.contains("Size: ") {
                            tmpFileSize = tdText.replacingOccurrences(of: "Size: ", with: "")
                        }
                        if tdText.contains("Seeds: ") {
                            tmpSeedCount = Int(tdText.replacingOccurrences(of: "Seeds: ", with: ""))
                        }
                        if tdText.contains("Peers: ") {
                            tmpPeerCount = Int(tdText.replacingOccurrences(of: "Peers: ", with: ""))
                        }
                        if tdText.contains("Downloads: ") {
                            tmpDownloadCount = Int(tdText.replacingOccurrences(of: "Downloads: ", with: ""))
                        }
                        if tdText.contains("Uploader: ") {
                            tmpUploader = tdText.replacingOccurrences(of: "Uploader: ", with: "")
                        }
                    }
                    if let aLink = tdLink.at_xpath("//a"),
                       let aHref = aLink["href"],
                       let aText = aLink.text,
                       let aURL = URL(string: aHref),
                       let range = aURL.lastPathComponent.range(of: ".torrent")
                    {
                        tmpHash = String(aURL.lastPathComponent[..<range.lowerBound])
                        tmpTorrentURL = aURL
                        tmpFileName = aText
                    }
                }
            }

            guard let postedTime = tmpPostedTime,
                  let postedDate = try? parseDate(
                    time: postedTime,
                    format: Defaults.DateFormat.torrent
                  ),
                  let fileSize = tmpFileSize,
                  let seedCount = tmpSeedCount,
                  let peerCount = tmpPeerCount,
                  let downloadCount = tmpDownloadCount,
                  let uploader = tmpUploader,
                  let fileName = tmpFileName,
                  let hash = tmpHash,
                  let torrentURL = tmpTorrentURL
            else { continue }

            torrents.append(
                GalleryTorrent(
                    postedDate: postedDate,
                    fileSize: fileSize,
                    seedCount: seedCount,
                    peerCount: peerCount,
                    downloadCount: downloadCount,
                    uploader: uploader,
                    fileName: fileName,
                    hash: hash,
                    torrentURL: torrentURL
                )
            )
        }

        return torrents
    }
}

extension Parser {
    // MARK: Greeting
    static func parseGreeting(doc: HTMLDocument) throws -> Greeting {
        func trim(string: String) -> String? {
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

        func trim(int: String) -> Int? {
            Int(int.replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: " ", with: ""))
        }

        guard let node = doc.at_xpath("//div [@id='eventpane']")
        else { throw AppError.parseFailed }

        var greeting = Greeting()
        for link in node.xpath("//p") {
            guard var text = link.text,
                  text.contains("You gain") == true
            else { continue }

            var gainedValues = [String]()
            for strongLink in link.xpath("//strong") {
                if let strongText = strongLink.text {
                    gainedValues.append(strongText)
                }
            }

            var gainedTypes = [String]()
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
                case "EXP":
                    greeting.gainedEXP = value
                case "Credits":
                    greeting.gainedCredits = value
                case "GP":
                    greeting.gainedGP = value
                case "Hath":
                    greeting.gainedHath = value
                default:
                    break
                }
            }
            break
        }

        greeting.updateTime = Date()
        return greeting
    }

    // MARK: EhSetting
    static func parseEhSetting(doc: HTMLDocument) throws -> EhSetting {
        func parseInt(node: XMLElement, name: String) -> Int? {
            var value: Int?
            for link in node.xpath("//input [@name='\(name)']")
                where link["checked"] == "checked" {
                value = Int(link["value"] ?? "")
            }
            return value
        }
        func parseEnum<T: RawRepresentable>(node: XMLElement, name: String) -> T?
            where T.RawValue == Int
        {
            guard let rawValue = parseInt(
                node: node, name: name
            ) else { return nil }
            return T(rawValue: rawValue)
        }
        func parseString(node: XMLElement, name: String) -> String? {
            node.at_xpath("//input [@name='\(name)']")?["value"]
        }
        func parseTextEditorString(node: XMLElement, name: String) -> String? {
            node.at_xpath("//textarea [@name='\(name)']")?.text
        }
        func parseBool(node: XMLElement, name: String) -> Bool? {
            switch parseString(node: node, name: name) {
            case "0": return false
            case "1": return true
            default: return nil
            }
        }
        func parseCheckBoxBool(node: XMLElement, name: String) -> Bool? {
            node.at_xpath("//input [@name='\(name)']")?["checked"] == "checked"
        }
        func parseCapability<T: RawRepresentable>(node: XMLElement, name: String) -> T?
            where T.RawValue == Int
        {
            var maxValue: Int?
            for link in node.xpath("//input [@name='\(name)']")
                where link["disabled"] != "disabled"
            {
                let value = Int(link["value"] ?? "") ?? 0
                if maxValue == nil {
                    maxValue = value
                } else if maxValue ?? 0 < value {
                    maxValue = value
                }
            }
            return T(rawValue: maxValue ?? 0)
        }
        func parseSelections(node: XMLElement, name: String) -> [(String, String, Bool)] {
            guard let select = node.at_xpath("//select [@name='\(name)']")
            else { return [] }

            var selections = [(String, String, Bool)]()
            for link in select.xpath("//option") {
                guard let name = link.text,
                      let value = link["value"]
                else { continue }

                selections.append((name, value, link["selected"] == "selected"))
            }

            return selections
        }

        var tmpForm: XMLElement?
        for link in doc.xpath("//form [@method='post']")
            where link["id"] == nil {
            tmpForm = link
        }
        guard let profileOuter = doc.at_xpath("//div [@id='profile_outer']"),
              let form = tmpForm else { throw AppError.parseFailed }

        // swiftlint:disable line_length
        var ehProfiles = [EhProfile](); var isCapableOfCreatingNewProfile: Bool?; var capableLoadThroughHathSetting: EhSetting.LoadThroughHathSetting?; var capableImageResolution: EhSetting.ImageResolution?; var capableSearchResultCount: EhSetting.SearchResultCount?; var capableThumbnailConfigSize: EhSetting.ThumbnailSize?; var capableThumbnailConfigRowCount: EhSetting.ThumbnailRowCount?; var loadThroughHathSetting: EhSetting.LoadThroughHathSetting?; var browsingCountry: EhSetting.BrowsingCountry?; var imageResolution: EhSetting.ImageResolution?; var imageSizeWidth: Float?; var imageSizeHeight: Float?; var galleryName: EhSetting.GalleryName?; var literalBrowsingCountry: String?; var archiverBehavior: EhSetting.ArchiverBehavior?; var displayMode: EhSetting.DisplayMode?; var showSearchRangeIndicator: Bool?; var disabledCategories = [Bool](); var favoriteCategories = [String](); var favoritesSortOrder: EhSetting.FavoritesSortOrder?; var ratingsColor: String?; var tagFilteringThreshold: Float?; var tagWatchingThreshold: Float?; var showFilteredRemovalCount: Bool?; var excludedLanguages = [Bool](); var excludedUploaders: String?; var searchResultCount: EhSetting.SearchResultCount?; var thumbnailLoadTiming: EhSetting.ThumbnailLoadTiming?; var thumbnailConfigSize: EhSetting.ThumbnailSize?; var thumbnailConfigRows: EhSetting.ThumbnailRowCount?; var thumbnailScaleFactor: Float?; var viewportVirtualWidth: Float?; var commentsSortOrder: EhSetting.CommentsSortOrder?; var commentVotesShowTiming: EhSetting.CommentVotesShowTiming?; var tagsSortOrder: EhSetting.TagsSortOrder?; var galleryShowPageNumbers: Bool?; var useOriginalImages: Bool?; var useMultiplePageViewer: Bool?; var multiplePageViewerStyle: EhSetting.MultiplePageViewerStyle?; var multiplePageViewerShowThumbnailPane: Bool?
        // swiftlint:enable line_length

        ehProfiles = parseSelections(node: profileOuter, name: "profile_set")
            .compactMap { (name, value, isSelected) in
                guard let value = Int(value) else { return nil }
                return EhProfile(value: value, name: name, isSelected: isSelected)
            }

        for button in profileOuter.xpath("//input [@type='button']") {
            if button["value"] == "Create New" {
                isCapableOfCreatingNewProfile = true
                break
            } else {
                isCapableOfCreatingNewProfile = false
            }
        }

        for optouter in form.xpath("//div [@class='optouter']") {
            if optouter.at_xpath("//input [@name='uh']") != nil {
                loadThroughHathSetting = parseEnum(node: optouter, name: "uh")
                capableLoadThroughHathSetting = parseCapability(node: optouter, name: "uh")
            }
            if optouter.at_xpath("//select [@name='co']") != nil {
                var value = parseSelections(node: optouter, name: "co").filter(\.2).first?.1

                if value == "" { value = "-" }
                browsingCountry = EhSetting.BrowsingCountry(rawValue: value ?? "")

                if let pText = optouter.at_xpath("//p")?.text,
                   let rangeA = pText.range(of: "You appear to be browsing the site from "),
                   let rangeB = pText.range(of: " or use a VPN or proxy in this country")
                {
                    literalBrowsingCountry = String(pText[rangeA.upperBound..<rangeB.lowerBound])
                }
            }
            if optouter.at_xpath("//input [@name='xr']") != nil {
                imageResolution = parseEnum(node: optouter, name: "xr")
                capableImageResolution = parseCapability(node: optouter, name: "xr")
            }
            if optouter.at_xpath("//input [@name='rx']") != nil {
                imageSizeWidth = Float(parseString(node: optouter, name: "rx") ?? "0")
                if imageSizeWidth == nil { imageSizeWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='ry']") != nil {
                imageSizeHeight = Float(parseString(node: optouter, name: "ry") ?? "0")
                if imageSizeHeight == nil { imageSizeHeight = 0 }
            }
            if optouter.at_xpath("//input [@name='tl']") != nil {
                galleryName = parseEnum(node: optouter, name: "tl")
            }
            if optouter.at_xpath("//input [@name='ar']") != nil {
                archiverBehavior = parseEnum(node: optouter, name: "ar")
            }
            if optouter.at_xpath("//input [@name='dm']") != nil {
                displayMode = parseEnum(node: optouter, name: "dm")
            }
            if optouter.at_xpath("//input [@name='pp']") != nil {
                showSearchRangeIndicator = parseInt(node: optouter, name: "pp") == 0
            }
            if optouter.at_xpath("//div [@id='catsel']") != nil {
                disabledCategories = Array(0...9)
                    .map { "ct_\(EhSetting.categoryNames[$0])" }
                    .compactMap { parseBool(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//div [@id='favsel']") != nil {
                favoriteCategories = Array(0...9).map { "favorite_\($0)" }
                    .compactMap { parseString(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//input [@name='fs']") != nil {
                favoritesSortOrder = parseEnum(node: optouter, name: "fs")
            }
            if optouter.at_xpath("//input [@name='ru']") != nil {
                ratingsColor = parseString(node: optouter, name: "ru") ?? ""
            }
            if optouter.at_xpath("//input [@name='ft']") != nil {
                tagFilteringThreshold = Float(parseString(node: optouter, name: "ft") ?? "0")
                if tagFilteringThreshold == nil { tagFilteringThreshold = 0 }
            }
            if optouter.at_xpath("//input [@name='wt']") != nil {
                tagWatchingThreshold = Float(parseString(node: optouter, name: "wt") ?? "0")
                if tagWatchingThreshold == nil { tagWatchingThreshold = 0 }
            }
            if optouter.at_xpath("//input [@name='tf']") != nil {
                showFilteredRemovalCount = parseInt(node: optouter, name: "tf") == 0
            }
            if optouter.at_xpath("//div [@id='xlasel']") != nil {
                excludedLanguages = Array(0...49)
                    .map { "xl_\(EhSetting.languageValues[$0])" }
                    .compactMap { parseCheckBoxBool(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//textarea [@name='xu']") != nil {
                excludedUploaders = parseTextEditorString(node: optouter, name: "xu") ?? ""
            }
            if optouter.at_xpath("//input [@name='rc']") != nil {
                searchResultCount = parseEnum(node: optouter, name: "rc")
                capableSearchResultCount = parseCapability(node: optouter, name: "rc")
            }
            if optouter.at_xpath("//input [@name='lt']") != nil {
                thumbnailLoadTiming = parseEnum(node: optouter, name: "lt")
            }
            if optouter.at_xpath("//input [@name='ts']") != nil {
                thumbnailConfigSize = parseEnum(node: optouter, name: "ts")
                capableThumbnailConfigSize = parseCapability(node: optouter, name: "ts")
            }
            if optouter.at_xpath("//input [@name='tr']") != nil {
                thumbnailConfigRows = parseEnum(node: optouter, name: "tr")
                capableThumbnailConfigRowCount = parseCapability(node: optouter, name: "tr")
            }
            if optouter.at_xpath("//input [@name='tp']") != nil {
                thumbnailScaleFactor = Float(parseString(node: optouter, name: "tp") ?? "100")
                if thumbnailScaleFactor == nil { thumbnailScaleFactor = 100 }
            }
            if optouter.at_xpath("//input [@name='vp']") != nil {
                viewportVirtualWidth = Float(parseString(node: optouter, name: "vp") ?? "0")
                if viewportVirtualWidth == nil { viewportVirtualWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='cs']") != nil {
                commentsSortOrder = parseEnum(node: optouter, name: "cs")
            }
            if optouter.at_xpath("//input [@name='sc']") != nil {
                commentVotesShowTiming = parseEnum(node: optouter, name: "sc")
            }
            if optouter.at_xpath("//input [@name='tb']") != nil {
                tagsSortOrder = parseEnum(node: optouter, name: "tb")
            }
            if optouter.at_xpath("//input [@name='pn']") != nil {
                galleryShowPageNumbers = parseInt(node: optouter, name: "pn") == 1
            }
            if optouter.at_xpath("//input [@name='oi']") != nil {
                useOriginalImages = parseInt(node: optouter, name: "oi") == 1
            }
            if optouter.at_xpath("//input [@name='qb']") != nil {
                useMultiplePageViewer = parseInt(node: optouter, name: "qb") == 1
            }
            if optouter.at_xpath("//input [@name='ms']") != nil {
                multiplePageViewerStyle = parseEnum(node: optouter, name: "ms")
            }
            if optouter.at_xpath("//input [@name='mt']") != nil {
                multiplePageViewerShowThumbnailPane = parseInt(node: optouter, name: "mt") == 0
            }
        }

        // swiftlint:disable line_length
        guard !ehProfiles.filter(\.isSelected).isEmpty, let isCapableOfCreatingNewProfile, let capableLoadThroughHathSetting, let capableImageResolution, let capableSearchResultCount, let capableThumbnailConfigSize, let capableThumbnailConfigRowCount, let loadThroughHathSetting, let browsingCountry, let literalBrowsingCountry, let imageResolution, let imageSizeWidth, let imageSizeHeight, let galleryName, let archiverBehavior, let displayMode, let showSearchRangeIndicator, disabledCategories.count == 10, favoriteCategories.count == 10, let favoritesSortOrder, let ratingsColor, let tagFilteringThreshold, let tagWatchingThreshold, let showFilteredRemovalCount, excludedLanguages.count == 50, let excludedUploaders, let searchResultCount, let thumbnailLoadTiming, let thumbnailConfigSize, let thumbnailConfigRows, let thumbnailScaleFactor, let viewportVirtualWidth, let commentsSortOrder, let commentVotesShowTiming, let tagsSortOrder, let galleryShowPageNumbers
        else { throw AppError.parseFailed }

        return EhSetting(ehProfiles: ehProfiles.sorted(), isCapableOfCreatingNewProfile: isCapableOfCreatingNewProfile, capableLoadThroughHathSetting: capableLoadThroughHathSetting, capableImageResolution: capableImageResolution, capableSearchResultCount: capableSearchResultCount, capableThumbnailConfigSize: capableThumbnailConfigSize, capableThumbnailConfigRowCount: capableThumbnailConfigRowCount, loadThroughHathSetting: loadThroughHathSetting, browsingCountry: browsingCountry, literalBrowsingCountry: literalBrowsingCountry, imageResolution: imageResolution, imageSizeWidth: imageSizeWidth, imageSizeHeight: imageSizeHeight, galleryName: galleryName, archiverBehavior: archiverBehavior, displayMode: displayMode, showSearchRangeIndicator: showSearchRangeIndicator, disabledCategories: disabledCategories, favoriteCategories: favoriteCategories, favoritesSortOrder: favoritesSortOrder, ratingsColor: ratingsColor, tagFilteringThreshold: tagFilteringThreshold, tagWatchingThreshold: tagWatchingThreshold, showFilteredRemovalCount: showFilteredRemovalCount, excludedLanguages: excludedLanguages, excludedUploaders: excludedUploaders, searchResultCount: searchResultCount, thumbnailLoadTiming: thumbnailLoadTiming, thumbnailConfigSize: thumbnailConfigSize, thumbnailConfigRows: thumbnailConfigRows, thumbnailScaleFactor: thumbnailScaleFactor, viewportVirtualWidth: viewportVirtualWidth, commentsSortOrder: commentsSortOrder, commentVotesShowTiming: commentVotesShowTiming, tagsSortOrder: tagsSortOrder, galleryShowPageNumbers: galleryShowPageNumbers, useOriginalImages: useOriginalImages, useMultiplePageViewer: useMultiplePageViewer, multiplePageViewerStyle: multiplePageViewerStyle, multiplePageViewerShowThumbnailPane: multiplePageViewerShowThumbnailPane
        )
        // swiftlint:enable line_length
    }

    // MARK: APIKey
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
    // MARK: Date
    static func parseDate(time: String, format: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = formatter.date(from: time)
        else { throw AppError.parseFailed }

        return date
    }

    // MARK: Rating
    /// Returns ratings parsed from stars image / text and if the return contains a userRating .
    static func parseRating(node: XMLElement) throws -> (Float, Float?, Bool) {
        func parseTextRating(node: XMLElement) throws -> Float {
            guard let ratingString = node
              .at_xpath("//td [@id='rating_label']")?.text?
              .replacingOccurrences(of: "Average: ", with: "")
              .replacingOccurrences(of: "Not Yet Rated", with: "0"),
                  let rating = Float(ratingString)
            else { throw AppError.parseFailed }

            return rating
        }

        var tmpRatingString: String?
        var containsUserRating = false

        for link in node.xpath("//div") where
            link.className?.contains("ir") == true
            && link["style"]?.isEmpty == false
        {
            if tmpRatingString != nil { break }
            tmpRatingString = link["style"]
            containsUserRating = link.className != "ir"
        }

        guard let ratingString = tmpRatingString
        else { throw AppError.parseFailed }

        var tmpRating: Float?
        if ratingString.contains("0px") { tmpRating = 5.0 }
        if ratingString.contains("-16px") { tmpRating = 4.0 }
        if ratingString.contains("-32px") { tmpRating = 3.0 }
        if ratingString.contains("-48px") { tmpRating = 2.0 }
        if ratingString.contains("-64px") { tmpRating = 1.0 }
        if ratingString.contains("-80px") { tmpRating = 0.0 }

        guard var rating = tmpRating
        else { throw AppError.parseFailed }

        if ratingString.contains("-21px") { rating -= 0.5 }
        return (rating, try? parseTextRating(node: node), containsUserRating)
    }

    // MARK: PageNumber
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

                return PageNumber(lastItemTimestamp: timestamp, isNextButtonEnabled: isEnabled)
            } else {
                return PageNumber(isNextButtonEnabled: false)
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

    // MARK: SortOrder
    static func parseFavoritesSortOrder(doc: HTMLDocument) -> FavoritesSortOrder? {
        guard let idoNode = doc.at_xpath("//div [@class='ido']") else { return nil }
        for link in idoNode.xpath("//div") where link.className == nil {
            guard let aText = link.at_xpath("//div")?.at_xpath("//a")?.text else { continue }
            if aText == "Use Posted" {
                return .favoritedTime
            } else if aText == "Use Favorited" {
                return .lastUpdateTime
            }
        }
        return nil
    }

    // MARK: Balance
    static func parseCurrentFunds(doc: HTMLDocument) throws -> (String, String) {
        var tmpGP: String?
        var tmpCredits: String?

        for element in doc.xpath("//p") {
            if let text = element.text,
               let rangeA = text.range(of: "GP"),
               let rangeB = text.range(of: "[?]"),
               let rangeC = text.range(of: "Credits")
            {
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

    // MARK: DownloadCmdResp
    static func parseDownloadCommandResponse(doc: HTMLDocument) throws -> String {
        guard let dbNode = doc.at_xpath("//div [@id='db']")
        else { throw AppError.parseFailed }

        var response = [String]()
        for pLink in dbNode.xpath("//p") {
            if let pText = pLink.text {
                response.append(pText)
            }
        }

        var respString = response.joined(separator: " ")

        if let rangeA = respString.range(of: "A ") ?? respString.range(of: "An "),
           let rangeB = respString.range(of: "resolution"),
           let rangeC = respString.range(of: "client"),
           let rangeD = respString.range(of: "Downloads")
        {
            let resp = String(respString[rangeA.upperBound..<rangeB.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .firstLetterCapitalized

            if ArchiveResolution(rawValue: resp) != nil {
                let clientName = String(respString[rangeC.upperBound..<rangeD.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !clientName.isEmpty {
                    respString = resp + " -> " + clientName
                } else {
                    respString = resp
                }
            }
        }

        return respString
    }

    // MARK: ArchiveURL
    static func parseArchiveURL(node: XMLElement) throws -> URL {
        var archiveURL: URL?
        if let aLink = node.at_xpath("//a"),
            aLink.text?.contains("Archive Download") == true, let onClick = aLink["onclick"],
            let rangeA = onClick.range(of: "popUp('"), let rangeB = onClick.range(of: "',")
        {
            archiveURL = URL(string: .init(onClick[rangeA.upperBound..<rangeB.lowerBound]))
        }

        if let url = archiveURL {
            return url
        } else {
            throw AppError.parseFailed
        }
    }

    // MARK: FavoriteCategories
    static func parseFavoriteCategories(doc: HTMLDocument) throws -> [Int: String] {
        var favoriteCategories = [Int: String]()

        for link in doc.xpath("//div [@id='favsel']") {
            for inputLink in link.xpath("//input") {
                guard let name = inputLink["name"],
                      let value = inputLink["value"],
                      let type = FavoritesType(rawValue: name)
                else { continue }

                favoriteCategories[type.index] = value
            }
        }

        if !favoriteCategories.isEmpty {
            return favoriteCategories
        } else {
            throw AppError.parseFailed
        }
    }

    // MARK: Profile
    static func parseProfileIndex(doc: HTMLDocument) throws -> VerifyEhProfileResponse {
        var profileNotFound = true
        var profileValue: Int?

        let selector = doc.at_xpath("//select [@name='profile_set']")
        let options = selector?.xpath("//option")

        guard let options = options, options.count >= 1
        else { throw AppError.parseFailed }

        for link in options where EhSetting.verifyEhPandaProfileName(with: link.text) {
            profileNotFound = false
            profileValue = Int(link["value"] ?? "")
        }

        return .init(profileValue: profileValue, isProfileNotFound: profileNotFound)
    }

    // MARK: CommentContent
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
                + node.xpath("//img").count) > 0
        {
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
                       newBound < tmpBound
                    {
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
                   let imgURL = URL(string: imgSrc)
                {
                    if let content = contents.last,
                       content.type == .linkedImg
                    {
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
                        .isEmpty
                    {
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
                   content.type == .singleImg
                {
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
                    + node.xpath("//img").count) <= 0
            {
                if !rawContent
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
                {
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
                .isEmpty
            {
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

    // MARK: parsePreviewConfigs
    static func parsePreviewConfigs(url: URL) -> (URL, CGSize, CGSize)? {
        guard var components = URLComponents(
                url: url, resolvingAgainstBaseURL: false
              ),
              let queryItems = components.queryItems
        else { return nil }

        let keys = [
            Defaults.URL.Component.Key.ehpandaWidth,
            Defaults.URL.Component.Key.ehpandaHeight,
            Defaults.URL.Component.Key.ehpandaOffset
        ]
        let configs = keys.map(\.rawValue).compactMap { key in
            queryItems.filter({ $0.name == key }).first?.value
        }
        .compactMap(Int.init)

        components.queryItems = nil
        guard configs.count == keys.count,
              let plainURL = components.url
        else { return nil }

        let size = CGSize(width: configs[0], height: configs[1])
        return (plainURL, size, CGSize(width: configs[2], height: 0))
    }

    // MARK: parseBanInterval
    static func parseBanInterval(doc: HTMLDocument) -> BanInterval? {
        guard let text = doc.body?.text, let range = text.range(of: "The ban expires in ")
        else { return nil }

        let expireDescription = String(text[range.upperBound...])

        if let daysRange = expireDescription.range(of: "days"),
           let days = Int(expireDescription[..<daysRange.lowerBound]
                            .trimmingCharacters(in: .whitespaces))
        {
            if let andRange = expireDescription.range(of: "and"),
               let hoursRange = expireDescription.range(of: "hours"),
               let hours = Int(expireDescription[andRange.upperBound..<hoursRange.lowerBound]
                                 .trimmingCharacters(in: .whitespaces))
            {
                return .days(days, hours: hours)
            } else {
                return .days(days, hours: nil)
            }
        } else if let hoursRange = expireDescription.range(of: "hours"),
                  let hours = Int(expireDescription[..<hoursRange.lowerBound]
                                    .trimmingCharacters(in: .whitespaces))
        {
            if let andRange = expireDescription.range(of: "and"),
               let minutesRange = expireDescription.range(of: "minutes"),
               let minutes = Int(expireDescription[andRange.upperBound..<minutesRange.lowerBound]
                                      .trimmingCharacters(in: .whitespaces))
            {
                return .hours(hours, minutes: minutes)
            } else {
                return .hours(hours, minutes: nil)
            }
        } else if let minutesRange = expireDescription.range(of: "minutes"),
                  let minutes = Int(expireDescription[..<minutesRange.lowerBound]
                                        .trimmingCharacters(in: .whitespaces))
        {
            if let andRange = expireDescription.range(of: "and"),
               let secondsRange = expireDescription.range(of: "seconds"),
               let seconds = Int(expireDescription[andRange.upperBound..<secondsRange.lowerBound]
                                  .trimmingCharacters(in: .whitespaces))
            {
                return .minutes(minutes, seconds: seconds)
            } else {
                return .minutes(minutes, seconds: nil)
            }
        } else {
            Logger.error(
                "Unrecognized BanInterval format", context: [
                    "expireDescription": expireDescription
                ]
            )
            return .unrecognized(content: expireDescription)
        }
    }
}
