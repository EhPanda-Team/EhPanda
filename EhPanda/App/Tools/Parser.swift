//
//  Parser.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import UIKit
import Foundation

struct Parser {
    // MARK: List
    static func parseListItems(doc: HTMLDocument) -> [Manga] {
        func parseCoverURL(node: XMLElement?) throws -> String {
            guard let node = node?.at_xpath("//div [@class='glthumb']")?.at_css("img")
            else { throw AppError.parseFailed }

            var coverURL = node["data-src"]
            if coverURL == nil { coverURL = node["src"] }

            guard let url = coverURL
            else { throw AppError.parseFailed }

            return url
        }

        func parsePublishedTime(node: XMLElement?) throws -> String {
            guard var text = node?.at_xpath("//div [@onclick]")?.text
            else { throw AppError.parseFailed }

            if !text.contains(":") {
                guard let content = node?.text,
                      let range = content.range(of: "pages")
                else { throw AppError.parseFailed }

                text = String(content[range.upperBound...])
            }

            return text
        }

        func parseTagsAndLang(node: XMLElement?) throws -> ([String], Language?) {
            guard let object = node?.xpath("//div [@class='gt']")
            else { throw AppError.parseFailed }

            var tags = [String]()
            var language: Language?
            for tagLink in object {
                if tagLink["title"]?.contains("language") == true {
                    if let langText = tagLink.text?.capitalizingFirstLetter(),
                       let lang = Language(rawValue: langText)
                    {
                        language = lang
                    }
                }
                if let tagText = tagLink.text {
                    if let style = tagLink["style"],
                       let rangeA = style.range(of: "background:radial-gradient(#"),
                       let rangeB = style.range(of: ",#")
                    {
                        let hex = style[rangeA.upperBound..<rangeB.lowerBound]
                        let wrappedHex = Defaults.ParsingMark.hexStart
                            + hex + Defaults.ParsingMark.hexEnd
                        tags.append(tagText + wrappedHex)
                    } else {
                        tags.append(tagText)
                    }
                }
            }
            return (tags, language)
        }

        var mangaItems = [Manga]()
        for link in doc.xpath("//tr") {
            let uploader = link.at_xpath("//td [@class='gl4c glhide']")?.at_xpath("//a")?.text
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                  let gl3cNode = link.at_xpath("//td [@class='gl3c glname']"),
                  let rating = try? parseRating(node: gl2cNode),
                  let coverURL = try? parseCoverURL(node: gl2cNode),
                  let tagsAndLang = try? parseTagsAndLang(node: gl3cNode),
                  let publishedTime = try? parsePublishedTime(node: gl2cNode),
                  let title = link.at_xpath("//div [@class='glink']")?.text,
                  let detailURL = link.at_xpath("//td [@class='gl3c glname'] //a")?["href"],
                  let publishedDate = try? parseDate(time: publishedTime, format: Defaults.DateFormat.publish),
                  let category = Category(rawValue: link.at_xpath("//td [@class='gl1c glcat'] //div")?.text ?? ""),
                  let url = URL(string: detailURL), url.pathComponents.count >= 4
            else { continue }

            mangaItems.append(
                Manga(
                    gid: url.pathComponents[2],
                    token: url.pathComponents[3],
                    title: title,
                    rating: rating.0,
                    tags: tagsAndLang.0,
                    category: category,
                    language: tagsAndLang.1,
                    uploader: uploader,
                    publishedDate: publishedDate,
                    coverURL: coverURL,
                    detailURL: detailURL
                )
            )
        }

        return mangaItems
    }

    // MARK: Detail
    static func parseMangaDetail(doc: HTMLDocument, gid: String) throws -> (MangaDetail, MangaState) {
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

        func parseCoverURL(node: XMLElement?) throws -> String {
            guard let coverHTML = node?.at_xpath("//div [@id='gd1']")?.innerHTML,
            let rangeA = coverHTML.range(of: "url("),
            let rangeB = coverHTML.range(of: ")")
            else { throw AppError.parseFailed }

            return String(coverHTML[rangeA.upperBound..<rangeB.lowerBound])
        }

        func parseTags(node: XMLElement?) throws -> [MangaTag] {
            guard let object = node?.xpath("//tr")
            else { throw AppError.parseFailed }

            var tags = [MangaTag]()
            for link in object {
                guard let categoryString = link
                        .at_xpath("//td [@class='tc']")?
                        .text?.replacingOccurrences(of: ":", with: ""),
                      let category = TagCategory(
                        rawValue: categoryString.capitalizingFirstLetter()
                      )
                else { continue }

                var content = [String]()
                for aLink in link.xpath("//a") {
                    guard let aText = aLink.text
                    else { continue }

                    var fixedText: String?
                    if let range = aText.range(of: "|") {
                        fixedText = String(aText[..<range.lowerBound])
                    }
                    content.append(fixedText ?? aText)
                }

                tags.append(MangaTag(category: category, content: content))
            }

            return tags
        }

        func parseArcAndTor(node: XMLElement?) throws -> (String?, Int) {
            guard let node = node else { throw AppError.parseFailed }

            var archiveURL: String?
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
                count: 6
            )
            for gddLink in object {
                guard let gdt1Text = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                      let gdt2Text = gddLink.at_xpath("//td [@class='gdt2']")?.text
                else { continue }

                if gdt1Text.contains("Posted") {
                    infoPanel[0] = gdt2Text
                }
                if gdt1Text.contains("Language") {
                    infoPanel[1] = gdt2Text
                        .replacingOccurrences(of: "  TR", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                if gdt1Text.contains("File Size") {
                    infoPanel[2] = gdt2Text
                        .replacingOccurrences(of: " KB", with: "")
                        .replacingOccurrences(of: " MB", with: "")
                        .replacingOccurrences(of: " GB", with: "")

                    if gdt2Text.contains("KB") { infoPanel[3] = "KB" }
                    if gdt2Text.contains("MB") { infoPanel[3] = "MB" }
                    if gdt2Text.contains("GB") { infoPanel[3] = "GB" }
                }
                if gdt1Text.contains("Length") {
                    infoPanel[4] = gdt2Text.replacingOccurrences(of: " pages", with: "")
                }
                if gdt1Text.contains("Favorited") {
                    infoPanel[5] = gdt2Text
                        .replacingOccurrences(of: " times", with: "")
                        .replacingOccurrences(of: "Never", with: "0")
                        .replacingOccurrences(of: "Once", with: "1")
                }
            }

            guard infoPanel.filter({ !$0.isEmpty }).count == 6
            else { throw AppError.parseFailed }

            return infoPanel
        }

        var tmpMangaDetail: MangaDetail?
        var tmpMangaState: MangaState?
        for link in doc.xpath("//div [@class='gm']") {
            guard let gd3Node = link.at_xpath("//div [@id='gd3']"),
                  let gd4Node = link.at_xpath("//div [@id='gd4']"),
                  let gd5Node = link.at_xpath("//div [@id='gd5']"),
                  let gddNode = gd3Node.at_xpath("//div [@id='gdd']"),
                  let gdrNode = gd3Node.at_xpath("//div [@id='gdr']"),
                  let gdfNode = gd3Node.at_xpath("//div [@id='gdf']"),
                  let coverURL = try? parseCoverURL(node: link),
                  let tags = try? parseTags(node: gd4Node),
                  let previews = try? parsePreviews(doc: doc),
                  let arcAndTor = try? parseArcAndTor(node: gd5Node),
                  let infoPanel = try? parseInfoPanel(node: gddNode),
                  let sizeCount = Float(infoPanel[2]),
                  let pageCount = Int(infoPanel[4]),
                  let likeCount = Int(infoPanel[5]),
                  let language = Language(rawValue: infoPanel[1]),
                  let engTitle = link.at_xpath("//h1 [@id='gn']")?.text,
                  let uploader = gd3Node.at_xpath("//div [@id='gdn']")?.at_xpath("//a")?.text,
                  let (imgRating, textRating, containsUserRating) = try? parseRating(node: gdrNode),
                  let ratingCount = Int(gdrNode.at_xpath("//span [@id='rating_count']")?.text ?? ""),
                  let category = Category(rawValue: gd3Node.at_xpath("//div [@id='gdc']")?.text ?? ""),
                  let publishedDate = try? parseDate(time: infoPanel[0], format: Defaults.DateFormat.publish)
            else { throw AppError.parseFailed }

            let isFavored = gdfNode
                .at_xpath("//a [@id='favoritelink']")?
                .text?.contains("Add to Favorites") == false
            let gjText = link.at_xpath("//h1 [@id='gj']")?.text
            let jpnTitle = gjText?.isEmpty != false ? nil : gjText

            tmpMangaDetail = MangaDetail(
                gid: gid,
                title: engTitle,
                jpnTitle: jpnTitle,
                isFavored: isFavored,
                rating: containsUserRating ?
                    textRating ?? 0.0 : imgRating,
                userRating: containsUserRating
                    ? imgRating : 0.0,
                ratingCount: ratingCount,
                category: category,
                language: language,
                uploader: uploader,
                publishedDate: publishedDate,
                coverURL: coverURL,
                archiveURL: arcAndTor.0,
                likeCount: likeCount,
                pageCount: pageCount,
                sizeCount: sizeCount,
                sizeType: infoPanel[3],
                torrentCount: arcAndTor.1
            )
            tmpMangaState = MangaState(
                gid: gid, tags: tags,
                previews: previews,
                previewConfig: try? parsePreviewConfig(doc: doc),
                comments: parseComments(doc: doc)
            )
            break
        }

        guard let mangaDetail = tmpMangaDetail,
              let mangaState = tmpMangaState
        else { throw AppError.parseFailed }

        return (mangaDetail, mangaState)
    }

    // MARK: Preview
    static func parsePreviews(doc: HTMLDocument) throws -> [Int: String] {
        func parseNormalPreviews(node: XMLElement) -> [Int: String] {
            var previews = [Int: String]()

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
                let plainURL = linkStyle[rangeD.upperBound..<rangeE.lowerBound]
                let offset = remainingText[rangeE.upperBound..<rangeF.lowerBound]

                previews[index] = Defaults.URL.normalPreview(
                    plainURL: plainURL, width: width,
                    height: height, offset: offset
                )
            }

            return previews
        }
        func parseLargePreviews(node: XMLElement) -> [Int: String] {
            var previews = [Int: String]()

            for link in node.xpath("//img") {
                guard let index = Int(link["alt"] ?? ""),
                      let url = link["src"], !url.contains("blank.gif")
                else { continue }

                previews[index] = url
            }

            return previews
        }

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']"),
              let previewMode = try? parsePreviewMode(doc: doc)
        else { throw AppError.parseFailed }

        return previewMode == "gdtl"
            ? parseLargePreviews(node: gdtNode)
            : parseNormalPreviews(node: gdtNode)
    }

    // MARK: Comment
    static func parseComments(doc: HTMLDocument) -> [MangaComment] {
        var comments = [MangaComment]()
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
                    MangaComment(
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

    // MARK: Content
    static func parseMangaPreContents(doc: HTMLDocument) throws -> [(Int, URL)] {
        var imageDetailURLs = [(Int, URL)]()

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']"),
              let previewMode = try? parsePreviewMode(doc: doc)
        else { throw AppError.parseFailed }

        for link in gdtNode.xpath("//div [@class='\(previewMode)']") {
            guard let aLink = link.at_xpath("//a"),
                  let imageDetailString = aLink["href"],
                  let imageDetailURL = URL(string: imageDetailString),
                    let index = Int(aLink.at_xpath("//img")?["alt"] ?? "")
            else { continue }

            imageDetailURLs.append((index, imageDetailURL))
        }

        return imageDetailURLs
    }

    static func parseMangaContent(doc: HTMLDocument, index: Int) throws -> (Int, String) {
        if let (mpvKey, imgKeys) = try? parseMPVKeys(doc: doc) {
            throw AppError.mpvActivated(mpvKey: mpvKey, imgKeys: imgKeys)
        }
        guard let i3Node = doc.at_xpath("//div [@id='i3']"),
              let imageURL = i3Node.at_css("img")?["src"]
        else { throw AppError.parseFailed }

        return (index, imageURL)
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
        var avatarURL: String?

        for ipbLink in doc.xpath("//table [@class='ipbtable']") {
            guard let profileName = ipbLink.at_xpath("//div [@id='profilename']")?.text
            else { continue }

            displayName = profileName

            for imgLink in ipbLink.xpath("//img") {
                guard let imgURL = imgLink["src"],
                      imgURL.contains("forums.e-hentai.org/uploads")
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
    static func parseMangaArchive(doc: HTMLDocument) throws -> MangaArchive {
        guard let node = doc.at_xpath("//table")
        else { throw AppError.parseFailed }

        var hathArchives = [MangaArchive.HathArchive]()
        for link in node.xpath("//td") {
            var tmpResolution: ArchiveRes?
            var tmpFileSize: String?
            var tmpGPPrice: String?

            for pLink in link.xpath("//p") {
                if let pText = pLink.text {
                    if let res = ArchiveRes(rawValue: pText) {
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
                MangaArchive.HathArchive(
                    resolution: resolution,
                    fileSize: fileSize,
                    gpPrice: gpPrice
                )
            )
        }

        return MangaArchive(hathArchives: hathArchives)
    }

    // MARK: Torrent
    static func parseMangaTorrents(doc: HTMLDocument) -> [MangaTorrent] {
        var torrents = [MangaTorrent]()

        for link in doc.xpath("//form") {
            var tmpPostedTime: String?
            var tmpFileSize: String?
            var tmpSeedCount: Int?
            var tmpPeerCount: Int?
            var tmpDownloadCount: Int?
            var tmpUploader: String?
            var tmpFileName: String?
            var tmpHash: String?
            var tmpTorrentURL: String?

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
                        tmpTorrentURL = aHref
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
                MangaTorrent(
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
            Int(
                int
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: " ", with: "")
            )
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

    // MARK: EhProfile
    static func parseEhProfile(doc: HTMLDocument) throws -> EhProfile {
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

        var tmpForm: XMLElement?
        for link in doc.xpath("//form [@method='post']")
            where link["id"] == nil {
            tmpForm = link
        }
        guard let form = tmpForm else { throw AppError.parseFailed }

        // swiftlint:disable line_length
        var tmpCapableLoadThroughHathSetting: EhProfileLoadThroughHathSetting?; var tmpCapableImageResolution: EhProfileImageResolution?; var tmpCapableSearchResultCount: EhProfileSearchResultCount?; var tmpCapableThumbnailConfigSize: EhProfileThumbnailSize?; var tmpCapableThumbnailConfigRows: EhProfileThumbnailRows?; var tmpLoadThroughHathSetting: EhProfileLoadThroughHathSetting?; var tmpImageResolution: EhProfileImageResolution?; var tmpImageSizeWidth: Float?; var tmpImageSizeHeight: Float?; var tmpGalleryName: EhProfileGalleryName?; var tmpArchiverBehavior: EhProfileArchiverBehavior?; var tmpDisplayMode: EhProfileDisplayMode?; var tmpDoujinshiDisabled: Bool?; var tmpMangaDisabled: Bool?; var tmpArtistCGDisabled: Bool?; var tmpGameCGDisabled: Bool?; var tmpWesternDisabled: Bool?; var tmpNonHDisabled: Bool?; var tmpImageSetDisabled: Bool?; var tmpCosplayDisabled: Bool?; var tmpAsianPornDisabled: Bool?; var tmpMiscDisabled: Bool?; var tmpFavoriteName0: String?; var tmpFavoriteName1: String?; var tmpFavoriteName2: String?; var tmpFavoriteName3: String?; var tmpFavoriteName4: String?; var tmpFavoriteName5: String?; var tmpFavoriteName6: String?; var tmpFavoriteName7: String?; var tmpFavoriteName8: String?; var tmpFavoriteName9: String?; var tmpFavoritesSortOrder: EhProfileFavoritesSortOrder?; var tmpRatingsColor: String?; var tmpReclassExcluded: Bool?; var tmpLanguageExcluded: Bool?; var tmpParodyExcluded: Bool?; var tmpCharacterExcluded: Bool?; var tmpGroupExcluded: Bool?; var tmpArtistExcluded: Bool?; var tmpMaleExcluded: Bool?; var tmpFemaleExcluded: Bool?; var tmpTagFilteringThreshold: Float?; var tmpTagWatchingThreshold: Float?; var tmpExcludedUploaders: String?; var tmpSearchResultCount: EhProfileSearchResultCount?; var tmpThumbnailLoadTiming: EhProfileThumbnailLoadTiming?; var tmpThumbnailConfigSize: EhProfileThumbnailSize?; var tmpThumbnailConfigRows: EhProfileThumbnailRows?; var tmpThumbnailScaleFactor: Float?; var tmpViewportVirtualWidth: Float?; var tmpCommentsSortOrder: EhProfileCommentsSortOrder?; var tmpCommentVotesShowTiming: EhProfileCommentVotesShowTiming?; var tmpTagsSortOrder: EhProfileTagsSortOrder?; var tmpGalleryShowPageNumbers: Bool?; var tmpHathLocalNetworkHost: String?; var tmpUseOriginalImages: Bool?; var tmpUseMultiplePageViewer: Bool?; var tmpMultiplePageViewerStyle: EhProfileMultiplePageViewerStyle?; var tmpMultiplePageViewerShowThumbnailPane: Bool?
        // swiftlint:enable line_length

        for optouter in form.xpath("//div [@class='optouter']") {
            if optouter.at_xpath("//input [@name='uh']") != nil {
                tmpLoadThroughHathSetting = parseEnum(node: optouter, name: "uh")
                tmpCapableLoadThroughHathSetting = parseCapability(node: optouter, name: "uh")
            }
            if optouter.at_xpath("//input [@name='xr']") != nil {
                tmpImageResolution = parseEnum(node: optouter, name: "xr")
                tmpCapableImageResolution = parseCapability(node: optouter, name: "xr")
            }
            if optouter.at_xpath("//input [@name='rx']") != nil {
                tmpImageSizeWidth = Float(parseString(node: optouter, name: "rx") ?? "0")
                if tmpImageSizeWidth == nil { tmpImageSizeWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='ry']") != nil {
                tmpImageSizeHeight = Float(parseString(node: optouter, name: "ry") ?? "0")
                if tmpImageSizeHeight == nil { tmpImageSizeHeight = 0 }
            }
            if optouter.at_xpath("//input [@name='tl']") != nil {
                tmpGalleryName = parseEnum(node: optouter, name: "tl")
            }
            if optouter.at_xpath("//input [@name='ar']") != nil {
                tmpArchiverBehavior = parseEnum(node: optouter, name: "ar")
            }
            if optouter.at_xpath("//input [@name='dm']") != nil {
                tmpDisplayMode = parseEnum(node: optouter, name: "dm")
            }
            if optouter.at_xpath("//div [@id='catsel']") != nil {
                tmpDoujinshiDisabled = parseBool(node: optouter, name: "ct_doujinshi")
                tmpMangaDisabled = parseBool(node: optouter, name: "ct_manga")
                tmpArtistCGDisabled = parseBool(node: optouter, name: "ct_artistcg")
                tmpGameCGDisabled = parseBool(node: optouter, name: "ct_gamecg")
                tmpWesternDisabled = parseBool(node: optouter, name: "ct_western")
                tmpNonHDisabled = parseBool(node: optouter, name: "ct_non-h")
                tmpImageSetDisabled = parseBool(node: optouter, name: "ct_imageset")
                tmpCosplayDisabled = parseBool(node: optouter, name: "ct_cosplay")
                tmpAsianPornDisabled = parseBool(node: optouter, name: "ct_asianporn")
                tmpMiscDisabled = parseBool(node: optouter, name: "ct_misc")
            }
            if optouter.at_xpath("//div [@id='favsel']") != nil {
                tmpFavoriteName0 = parseString(node: optouter, name: "favorite_0")
                tmpFavoriteName1 = parseString(node: optouter, name: "favorite_1")
                tmpFavoriteName2 = parseString(node: optouter, name: "favorite_2")
                tmpFavoriteName3 = parseString(node: optouter, name: "favorite_3")
                tmpFavoriteName4 = parseString(node: optouter, name: "favorite_4")
                tmpFavoriteName5 = parseString(node: optouter, name: "favorite_5")
                tmpFavoriteName6 = parseString(node: optouter, name: "favorite_6")
                tmpFavoriteName7 = parseString(node: optouter, name: "favorite_7")
                tmpFavoriteName8 = parseString(node: optouter, name: "favorite_8")
                tmpFavoriteName9 = parseString(node: optouter, name: "favorite_9")
            }
            if optouter.at_xpath("//input [@name='fs']") != nil {
                tmpFavoritesSortOrder = parseEnum(node: optouter, name: "fs")
            }
            if optouter.at_xpath("//input [@name='ru']") != nil {
                tmpRatingsColor = parseString(node: optouter, name: "ru") ?? ""
            }
            if optouter.at_xpath("//div [@id='nssel']") != nil {
                tmpReclassExcluded = parseCheckBoxBool(node: optouter, name: "xn_1")
                tmpLanguageExcluded = parseCheckBoxBool(node: optouter, name: "xn_2")
                tmpParodyExcluded = parseCheckBoxBool(node: optouter, name: "xn_3")
                tmpCharacterExcluded = parseCheckBoxBool(node: optouter, name: "xn_4")
                tmpGroupExcluded = parseCheckBoxBool(node: optouter, name: "xn_5")
                tmpArtistExcluded = parseCheckBoxBool(node: optouter, name: "xn_6")
                tmpMaleExcluded = parseCheckBoxBool(node: optouter, name: "xn_7")
                tmpFemaleExcluded = parseCheckBoxBool(node: optouter, name: "xn_8")
            }
            if optouter.at_xpath("//input [@name='ft']") != nil {
                tmpTagFilteringThreshold = Float(parseString(node: optouter, name: "ft") ?? "0")
                if tmpTagFilteringThreshold == nil { tmpTagFilteringThreshold = 0 }
            }
            if optouter.at_xpath("//input [@name='wt']") != nil {
                tmpTagWatchingThreshold = Float(parseString(node: optouter, name: "wt") ?? "0")
                if tmpTagWatchingThreshold == nil { tmpTagWatchingThreshold = 0 }
            }
            if optouter.at_xpath("//textarea [@name='xu']") != nil {
                tmpExcludedUploaders = parseTextEditorString(node: optouter, name: "xu") ?? ""
            }
            if optouter.at_xpath("//input [@name='rc']") != nil {
                tmpSearchResultCount = parseEnum(node: optouter, name: "rc")
                tmpCapableSearchResultCount = parseCapability(node: optouter, name: "rc")
            }
            if optouter.at_xpath("//input [@name='lt']") != nil {
                tmpThumbnailLoadTiming = parseEnum(node: optouter, name: "lt")
            }
            if optouter.at_xpath("//input [@name='ts']") != nil {
                tmpThumbnailConfigSize = parseEnum(node: optouter, name: "ts")
                tmpCapableThumbnailConfigSize = parseCapability(node: optouter, name: "ts")
            }
            if optouter.at_xpath("//input [@name='tr']") != nil {
                tmpThumbnailConfigRows = parseEnum(node: optouter, name: "tr")
                tmpCapableThumbnailConfigRows = parseCapability(node: optouter, name: "tr")
            }
            if optouter.at_xpath("//input [@name='tp']") != nil {
                tmpThumbnailScaleFactor = Float(parseString(node: optouter, name: "tp") ?? "100")
                if tmpThumbnailScaleFactor == nil { tmpThumbnailScaleFactor = 100 }
            }
            if optouter.at_xpath("//input [@name='vp']") != nil {
                tmpViewportVirtualWidth = Float(parseString(node: optouter, name: "vp") ?? "0")
                if tmpViewportVirtualWidth == nil { tmpViewportVirtualWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='cs']") != nil {
                tmpCommentsSortOrder = parseEnum(node: optouter, name: "cs")
            }
            if optouter.at_xpath("//input [@name='sc']") != nil {
                tmpCommentVotesShowTiming = parseEnum(node: optouter, name: "sc")
            }
            if optouter.at_xpath("//input [@name='tb']") != nil {
                tmpTagsSortOrder = parseEnum(node: optouter, name: "tb")
            }
            if optouter.at_xpath("//input [@name='pn']") != nil {
                tmpGalleryShowPageNumbers = parseInt(node: optouter, name: "pn") == 1
            }
            if optouter.at_xpath("//input [@name='hh']") != nil {
                tmpHathLocalNetworkHost = parseString(node: optouter, name: "hh")
            }
            if optouter.at_xpath("//input [@name='oi']") != nil {
                tmpUseOriginalImages = parseInt(node: optouter, name: "oi") == 1
            }
            if optouter.at_xpath("//input [@name='qb']") != nil {
                tmpUseMultiplePageViewer = parseInt(node: optouter, name: "qb") == 1
            }
            if optouter.at_xpath("//input [@name='ms']") != nil {
                tmpMultiplePageViewerStyle = parseEnum(node: optouter, name: "ms")
            }
            if optouter.at_xpath("//input [@name='mt']") != nil {
                tmpMultiplePageViewerShowThumbnailPane = parseInt(node: optouter, name: "mt") == 0
            }
        }

        // swiftlint:disable line_length
        guard let capableLoadThroughHathSetting = tmpCapableLoadThroughHathSetting, let capableImageResolution = tmpCapableImageResolution, let capableSearchResultCount = tmpCapableSearchResultCount, let capableThumbnailConfigSize = tmpCapableThumbnailConfigSize, let capableThumbnailConfigRows = tmpCapableThumbnailConfigRows, let loadThroughHathSetting = tmpLoadThroughHathSetting, let imageResolution = tmpImageResolution, let imageSizeWidth = tmpImageSizeWidth, let imageSizeHeight = tmpImageSizeHeight, let galleryName = tmpGalleryName, let archiverBehavior = tmpArchiverBehavior, let displayMode = tmpDisplayMode, let doujinshiDisabled = tmpDoujinshiDisabled, let mangaDisabled = tmpMangaDisabled, let artistCGDisabled = tmpArtistCGDisabled, let gameCGDisabled = tmpGameCGDisabled, let westernDisabled = tmpWesternDisabled, let nonHDisabled = tmpNonHDisabled, let imageSetDisabled = tmpImageSetDisabled, let cosplayDisabled = tmpCosplayDisabled, let asianPornDisabled = tmpAsianPornDisabled, let miscDisabled = tmpMiscDisabled, let favoriteName0 = tmpFavoriteName0, let favoriteName1 = tmpFavoriteName1, let favoriteName2 = tmpFavoriteName2, let favoriteName3 = tmpFavoriteName3, let favoriteName4 = tmpFavoriteName4, let favoriteName5 = tmpFavoriteName5, let favoriteName6 = tmpFavoriteName6, let favoriteName7 = tmpFavoriteName7, let favoriteName8 = tmpFavoriteName8, let favoriteName9 = tmpFavoriteName9, let favoritesSortOrder = tmpFavoritesSortOrder, let ratingsColor = tmpRatingsColor, let reclassExcluded = tmpReclassExcluded, let languageExcluded = tmpLanguageExcluded, let parodyExcluded = tmpParodyExcluded, let characterExcluded = tmpCharacterExcluded, let groupExcluded = tmpGroupExcluded, let artistExcluded = tmpArtistExcluded, let maleExcluded = tmpMaleExcluded, let femaleExcluded = tmpFemaleExcluded, let tagFilteringThreshold = tmpTagFilteringThreshold, let tagWatchingThreshold = tmpTagWatchingThreshold, let excludedUploaders = tmpExcludedUploaders, let searchResultCount = tmpSearchResultCount, let thumbnailLoadTiming = tmpThumbnailLoadTiming, let thumbnailConfigSize = tmpThumbnailConfigSize, let thumbnailConfigRows = tmpThumbnailConfigRows, let thumbnailScaleFactor = tmpThumbnailScaleFactor, let viewportVirtualWidth = tmpViewportVirtualWidth, let commentsSortOrder = tmpCommentsSortOrder, let commentVotesShowTiming = tmpCommentVotesShowTiming, let tagsSortOrder = tmpTagsSortOrder, let galleryShowPageNumbers = tmpGalleryShowPageNumbers, let hathLocalNetworkHost = tmpHathLocalNetworkHost
        else { throw AppError.parseFailed }

        return EhProfile(capableLoadThroughHathSetting: capableLoadThroughHathSetting, capableImageResolution: capableImageResolution, capableSearchResultCount: capableSearchResultCount, capableThumbnailConfigSize: capableThumbnailConfigSize, capableThumbnailConfigRows: capableThumbnailConfigRows, loadThroughHathSetting: loadThroughHathSetting, imageResolution: imageResolution, imageSizeWidth: imageSizeWidth, imageSizeHeight: imageSizeHeight, galleryName: galleryName, archiverBehavior: archiverBehavior, displayMode: displayMode, doujinshiDisabled: doujinshiDisabled, mangaDisabled: mangaDisabled, artistCGDisabled: artistCGDisabled, gameCGDisabled: gameCGDisabled, westernDisabled: westernDisabled, nonHDisabled: nonHDisabled, imageSetDisabled: imageSetDisabled, cosplayDisabled: cosplayDisabled, asianPornDisabled: asianPornDisabled, miscDisabled: miscDisabled, favoriteName0: favoriteName0, favoriteName1: favoriteName1, favoriteName2: favoriteName2, favoriteName3: favoriteName3, favoriteName4: favoriteName4, favoriteName5: favoriteName5, favoriteName6: favoriteName6, favoriteName7: favoriteName7, favoriteName8: favoriteName8, favoriteName9: favoriteName9, favoritesSortOrder: favoritesSortOrder, ratingsColor: ratingsColor, reclassExcluded: reclassExcluded, languageExcluded: languageExcluded, parodyExcluded: parodyExcluded, characterExcluded: characterExcluded, groupExcluded: groupExcluded, artistExcluded: artistExcluded, maleExcluded: maleExcluded, femaleExcluded: femaleExcluded, tagFilteringThreshold: tagFilteringThreshold, tagWatchingThreshold: tagWatchingThreshold, excludedUploaders: excludedUploaders, searchResultCount: searchResultCount, thumbnailLoadTiming: thumbnailLoadTiming, thumbnailConfigSize: thumbnailConfigSize, thumbnailConfigRows: thumbnailConfigRows, thumbnailScaleFactor: thumbnailScaleFactor, viewportVirtualWidth: viewportVirtualWidth, commentsSortOrder: commentsSortOrder, commentVotesShowTiming: commentVotesShowTiming, tagsSortOrder: tagsSortOrder, galleryShowPageNumbers: galleryShowPageNumbers, hathLocalNetworkHost: hathLocalNetworkHost, useOriginalImages: tmpUseOriginalImages, useMultiplePageViewer: tmpUseMultiplePageViewer, multiplePageViewerStyle: tmpMultiplePageViewerStyle, multiplePageViewerShowThumbnailPane: tmpMultiplePageViewerShowThumbnailPane
        )
        // swiftlint:enable line_length
    }

    // MARK: APIKey
    static func parseAPIKey(doc: HTMLDocument) throws -> APIKey {
        var tmpKey: APIKey?

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

    // MARK: Page Number
    static func parsePageNum(doc: HTMLDocument) -> PageNumber {
        var current = 0
        var maximum = 0

        guard let link = doc.at_xpath("//table [@class='ptt']"),
              let currentStr = link.at_xpath("//td [@class='ptds']")?.text
        else { return PageNumber() }

        if let range = currentStr.range(of: "-") {
            current = (Int(currentStr[range.upperBound...]) ?? 1) - 1
        } else {
            current = (Int(currentStr) ?? 1) - 1
        }
        for aLink in link.xpath("//a") {
            if let num = Int(aLink.text ?? "") {
                maximum = num
            }
        }
        return PageNumber(current: current, maximum: maximum)
    }

    // MARK: Balance
    static func parseCurrentFunds(doc: HTMLDocument) throws -> (String, String)? {
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

        if let rangeA =
            respString.range(of: "A ") ?? respString.range(of: "An "),
           let rangeB = respString.range(of: "resolution"),
           let rangeC = respString.range(of: "client"),
           let rangeD = respString.range(of: "Downloads")
        {
            let resp = String(respString[rangeA.upperBound..<rangeB.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalizingFirstLetter()

            if ArchiveRes(rawValue: resp) != nil {
                let clientName = String(respString[rangeC.upperBound..<rangeD.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                respString = resp.localized() + " -> " + clientName
            }
        }

        return respString
    }

    // MARK: ArchiveURL
    static func parseArchiveURL(node: XMLElement) throws -> String {
        var archiveURL: String?
        if let aLink = node.at_xpath("//a"),
           aLink.text?.contains("Archive Download") == true,
           let onClick = aLink["onclick"],
           let rangeA = onClick.range(of: "popUp('"),
           let rangeB = onClick.range(of: "',")
        {
            archiveURL = String(onClick[rangeA.upperBound..<rangeB.lowerBound])
        }

        if let url = archiveURL {
            return url
        } else {
            throw AppError.parseFailed
        }
    }

    // MARK: FavoriteNames
    static func parseFavoriteNames(doc: HTMLDocument) throws -> [Int: String] {
        var favoriteNames = [Int: String]()

        for link in doc.xpath("//div [@id='favsel']") {
            for inputLink in link.xpath("//input") {
                guard let name = inputLink["name"],
                      let value = inputLink["value"],
                      let type = FavoritesType(rawValue: name)
                else { continue }

                favoriteNames[type.index] = value
            }
        }

        if !favoriteNames.isEmpty {
            return favoriteNames
        } else {
            throw AppError.parseFailed
        }
    }

    // MARK: Profile
    static func parseProfileIndex(doc: HTMLDocument) throws -> (Int?, Bool) {
        var profileNotFound = true
        var profileValue: Int?

        let selector = doc.at_xpath(
            "//select [@name='profile_set']"
        )
        let options = selector?.xpath("//option")

        guard let options = options,
                options.count >= 1
        else { throw AppError.parseFailed }

        for link in options where link.text == "EhPanda" {
            profileNotFound = false
            profileValue = Int(link["value"] ?? "")
        }

        return (profileValue, profileNotFound)
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

            if let href = link["href"] {
                if let imgSrc = link.at_xpath("//img")?["src"] {
                    if let content = contents.last,
                       content.type == .linkedImg
                    {
                        contents = contents.dropLast()
                        contents.append(
                            CommentContent(
                                type: .doubleLinkedImg,
                                link: content.link,
                                imgURL: content.imgURL,
                                secondLink: href,
                                secondImgURL: imgSrc
                            )
                        )
                    } else {
                        contents.append(
                            CommentContent(
                                type: .linkedImg,
                                link: href,
                                imgURL: imgSrc
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
                                link: href
                            )
                        )
                    }
                } else {
                    contents.append(
                        CommentContent(
                            type: .singleLink,
                            link: href
                        )
                    )
                }
            } else if let src = link["src"] {
                if let content = contents.last,
                   content.type == .singleImg
                {
                    contents = contents.dropLast()
                    contents.append(
                        CommentContent(
                            type: .doubleImg,
                            imgURL: content.imgURL,
                            secondImgURL: src
                        )
                    )
                } else {
                    contents.append(
                        CommentContent(
                            type: .singleImg,
                            imgURL: src
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
    static func parsePreviewConfigs(string: String) -> (String, CGSize, CGFloat)? {
        guard let rangeA = string.range(of: Defaults.PreviewIdentifier.width),
              let rangeB = string.range(of: Defaults.PreviewIdentifier.height),
              let rangeC = string.range(of: Defaults.PreviewIdentifier.offset)
        else { return nil }

        let plainURL = String(string[..<rangeA.lowerBound])
        guard let width = Int(string[rangeA.upperBound..<rangeB.lowerBound]),
              let height = Int(string[rangeB.upperBound..<rangeC.lowerBound]),
              let offset = Int(string[rangeC.upperBound...])
        else { return nil }

        let size = CGSize(width: width, height: height)
        return (plainURL, size, CGFloat(offset))
    }

    // MARK: parseWrappedHex
    static func parseWrappedHex(string: String) -> (String, String?) {
        let hexStart = Defaults.ParsingMark.hexStart
        let hexEnd = Defaults.ParsingMark.hexEnd
        guard let rangeA = string.range(of: hexStart),
              let rangeB = string.range(of: hexEnd)
        else { return (string, nil) }

        let wrappedHex = String(string[rangeA.upperBound..<rangeB.lowerBound])
        let rippedText = string.replacingOccurrences(of: hexStart + wrappedHex + hexEnd, with: "")

        return (rippedText, wrappedHex)
    }
}
