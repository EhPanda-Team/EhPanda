//
//  Parser.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import SwiftUI
import Kingfisher

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

                let fixedTime = String(content.suffix(from: range.upperBound))
                text = fixedTime
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
                    tags.append(tagText)
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
                    rating: rating,
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
        func parseCoverURL(node: XMLElement?) throws -> String {
            guard let coverHTML = node?.at_xpath("//div [@id='gd1']")?.innerHTML,
            let rangeA = coverHTML.range(of: "url("),
            let rangeB = coverHTML.range(of: ")")
            else { throw AppError.parseFailed }

            return String(
                coverHTML
                    .suffix(from: rangeA.upperBound)
                    .prefix(upTo: rangeB.lowerBound)
            )
        }

        func parseRating(node: XMLElement?) throws -> Float {
            guard let ratingString = node?
              .at_xpath("//td [@id='rating_label']")?.text?
              .replacingOccurrences(of: "Average: ", with: "")
              .replacingOccurrences(of: "Not Yet Rated", with: "0"),
                  let rating = Float(ratingString)
            else { throw AppError.parseFailed }

            return rating
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
                        fixedText = String(aText.prefix(upTo: range.lowerBound))
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
                    tmpTorrentCount = Int(
                        String(
                            aText
                                .suffix(from: rangeA.upperBound)
                                .prefix(upTo: rangeB.lowerBound)
                        )
                    )
                }
                if archiveURL == nil {
                    archiveURL = try? parseArchiveURL(node: g2Link)
                }
            }

            guard let torrentCount = tmpTorrentCount
            else { throw AppError.parseFailed }

            return (archiveURL, torrentCount)
        }

        func parsePreviews(node: XMLElement?) throws -> [MangaPreview] {
            guard let object = node?.xpath("//img")
            else { throw AppError.parseFailed }

            var previews = [MangaPreview]()
            for link in object {
                if previews.count >= 10 { break }
                guard let url = link["src"] else { continue }

                previews.append(MangaPreview(url: url))
            }

            return previews.filter { !$0.url.contains("blank.gif") }
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
            guard let gdtNode = doc.at_xpath("//div [@id='gdt']"),
                  let gd3Node = link.at_xpath("//div [@id='gd3']"),
                  let gd4Node = link.at_xpath("//div [@id='gd4']"),
                  let gd5Node = link.at_xpath("//div [@id='gd5']"),
                  let gddNode = gd3Node.at_xpath("//div [@id='gdd']"),
                  let gdrNode = gd3Node.at_xpath("//div [@id='gdr']"),
                  let gdfNode = gd3Node.at_xpath("//div [@id='gdf']"),
                  let rating = try? parseRating(node: gdrNode),
                  let coverURL = try? parseCoverURL(node: link),
                  let tags = try? parseTags(node: gd4Node),
                  let previews = try? parsePreviews(node: gdtNode),
                  let arcAndTor = try? parseArcAndTor(node: gd5Node),
                  let infoPanel = try? parseInfoPanel(node: gddNode),
                  let language = Language(rawValue: infoPanel[1]),
                  let engTitle = link.at_xpath("//h1 [@id='gn']")?.text,
                  let uploader = gd3Node.at_xpath("//div [@id='gdn']")?.text,
                  let ratingCount = gdrNode.at_xpath("//span [@id='rating_count']")?.text,
                  let category = Category(rawValue: gd3Node.at_xpath("//div [@id='gdc']")?.text ?? ""),
                  let publishedDate = try? parseDate(time: infoPanel[0], format: Defaults.DateFormat.publish)
            else { throw AppError.parseFailed }

            let isFavored = gdfNode
                .at_xpath("//a [@id='favoritelink']")?
                .text?.contains("Add to Favorites") == false
            let gjText = link.at_xpath("//h1 [@id='gj']")?.text
            let jpnTitle = gjText?.isEmpty != false ? nil : gjText

            tmpMangaDetail = MangaDetail(
                isFavored: isFavored,
                archiveURL: arcAndTor.0,
                alterImagesURL: try? parseAlterImagesURL(doc: doc),
                alterImages: [],
                gid: gid,
                title: engTitle,
                jpnTitle: jpnTitle,
                rating: rating,
                ratingCount: ratingCount,
                category: category,
                language: language,
                uploader: uploader,
                publishedDate: publishedDate,
                coverURL: coverURL,
                likeCount: infoPanel[5],
                pageCount: infoPanel[4],
                sizeCount: infoPanel[2],
                sizeType: infoPanel[3],
                torrentCount: arcAndTor.1
            )
            tmpMangaState = MangaState(
                gid: gid, tags: tags,
                previews: previews,
                comments: parseComments(doc: doc)
            )
            break
        }

        guard let mangaDetail = tmpMangaDetail,
              let mangaState = tmpMangaState
        else { throw AppError.parseFailed }

        return (mangaDetail, mangaState)
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
                let author = String(
                    c3Node.suffix(from: rangeB.upperBound)
                )
                let commentTime = String(
                    c3Node
                        .suffix(from: rangeA.upperBound)
                        .prefix(upTo: rangeB.lowerBound)
                )

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
    static func parseImagePreContents(doc: HTMLDocument, previewMode: String, pageCount: Int) throws -> [(Int, URL)] {
        copyHTMLIfNeeded(html: doc.toHTML)
        var imageDetailURLs = [(Int, URL)]()

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { throw AppError.parseFailed }

        for (index, element) in gdtNode.xpath("//div [@class='\(previewMode)']").enumerated() {
            guard let imageDetailStr = element.at_xpath("//a")?["href"],
                  let imageDetailURL = URL(string: imageDetailStr)
            else { continue }

            imageDetailURLs.append((index + pageCount, imageDetailURL))
        }

        return imageDetailURLs
    }

    static func parseMangaContent(doc: HTMLDocument, tag: Int) throws -> MangaContent {
        copyHTMLIfNeeded(html: doc.toHTML)
        guard let i3Node = doc.at_xpath("//div [@id='i3']"),
              let imageURL = i3Node.at_css("img")?["src"]
        else { throw AppError.parseFailed }

        return MangaContent(tag: tag, url: imageURL)
    }

    static func parsePreviewMode(doc: HTMLDocument) throws -> String {
        guard let gdoNode = doc.at_xpath("//div [@id='gdo']"),
              let gdo4Node = gdoNode.at_xpath("//div [@id='gdo4']")
        else { return "gdtm" }

        for link in gdo4Node.xpath("//div") {
            if link.text == "Large",
               ["tha nosel", "ths nosel"]
                .contains(link["class"])
            {
                return "gdtl"
            }
        }
        return "gdtm"
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
        copyHTMLIfNeeded(html: doc.toHTML)

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
            var tmpMagnet: String?

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
                        let hash = String(
                            aURL.lastPathComponent.prefix(
                                upTo: range.lowerBound
                            )
                        )
                        tmpMagnet = Defaults.URL.magnet(hash: hash)
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
                  let magnet = tmpMagnet
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
                    magnet: magnet
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
                let removeText = String(text.prefix(upTo: range.upperBound))

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

    // MARK: APIKey
    static func parseAPIKey(doc: HTMLDocument) throws -> APIKey {
        var tmpKey: APIKey?

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let script = link.text, script.contains("apikey"),
                  let rangeA = script.range(of: ";\nvar apikey = \""),
                  let rangeB = script.range(of: "\";\nvar average_rating")
            else { continue }

            tmpKey = String(
                script
                    .suffix(from: rangeA.upperBound)
                    .prefix(upTo: rangeB.lowerBound)
            )
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
    static func parseRating(node: XMLElement?) throws -> Float {
        var tmpRatingString: String?
        ["ir", "ir irr", "ir irg", "ir irb"].forEach { string in
            if tmpRatingString != nil { return }
            let xpath = "//div [@class='" + string + "']"
            tmpRatingString = node?.at_xpath(xpath)?.toHTML
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
        return rating
    }

    // MARK: Page Number
    static func parsePageNum(doc: HTMLDocument) -> PageNumber {
        var current = 0
        var maximum = 0

        guard let link = doc.at_xpath("//table [@class='ptt']"),
              let currentStr = link.at_xpath("//td [@class='ptds']")?.text
        else { return PageNumber() }

        if let range = currentStr.range(of: "-") {
            current = (Int(String(currentStr.suffix(from: range.upperBound))) ?? 1) - 1
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

    // MARK: AltPreview
    static func parseAlterImagesURL(doc: HTMLDocument) throws -> String {
        var alterURL: String?
        for link in doc.xpath("//div [@class='gdtm']") {
            guard let style = link.at_xpath("//div")?["style"],
                  let rangeA = style.range(of: "https://"),
                  let rangeB = style.range(of: ".jpg")
            else { continue }

            alterURL = String(
                style.suffix(from: rangeA.lowerBound)
                    .prefix(upTo: rangeB.upperBound)
            )
            break
        }

        guard let url = alterURL
        else { throw AppError.parseFailed }

        return url
    }

    static func parseAlterImages(data: Data) -> [MangaAlterData] {
        guard let image = UIImage(data: data) else { return [] }

        var alterImages = [MangaAlterData]()
        let originW = image.size.width
        let originH = image.size.height
        let count = Int(originW / 100)

        for index in 0..<count {
            let rect = CGRect(
                x: originW / Double(count) * Double(index),
                y: 0.0, width: 100.0, height: originH
            )

            if let imgData = image.cropping(to: rect)?.pngData() {
                alterImages.append(MangaAlterData(data: imgData))
            }
        }

        return alterImages
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
                tmpGP = String(
                    text
                        .prefix(upTo: rangeA.lowerBound)
                )
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: "")

                tmpCredits = String(
                    text
                        .suffix(from: rangeB.upperBound)
                        .prefix(upTo: rangeC.lowerBound)
                )
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
            let resp = String(
                respString
                    .suffix(from: rangeA.upperBound)
                    .prefix(upTo: rangeB.lowerBound)
            )
            .capitalizingFirstLetter()
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if ArchiveRes(rawValue: resp) != nil {
                let clientName = String(
                    respString
                        .suffix(from: rangeC.upperBound)
                        .prefix(upTo: rangeD.lowerBound)
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

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
            archiveURL = String(
                onClick
                    .suffix(from: rangeA.upperBound)
                    .prefix(upTo: rangeB.lowerBound)
            )
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
            favoriteNames[-1] = "all_appendedByDev"
            return favoriteNames
        } else {
            throw AppError.parseFailed
        }
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

            let text = String(
                rawContent.prefix(
                    upTo: range.lowerBound
                )
            )
            if !text
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
            {
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
}
