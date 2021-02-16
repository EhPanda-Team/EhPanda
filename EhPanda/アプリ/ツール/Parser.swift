//
//  Parser.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import SwiftUI
import Kingfisher

class Parser {
    // MARK: リスト
    func parseListItems(_ doc: HTMLDocument) -> (PageNumber, [Manga]) {
        var mangaItems = [Manga]()
        
        for link in doc.xpath("//tr") {
            
            let uploader = link.at_xpath("//td [@class='gl4c glhide']")?.at_xpath("//a")?.text
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                  let gl3cNode = link.at_xpath("//td [@class='gl3c glname']"),
                  let title = link.at_xpath("//div [@class='glink']")?.text,
                  let rating = parseRatingString(gl2cNode.at_xpath("//div [@class='ir']")?.toHTML)
                    ?? parseRatingString(gl2cNode.at_xpath("//div [@class='ir irr']")?.toHTML)
                    ?? parseRatingString(gl2cNode.at_xpath("//div [@class='ir irg']")?.toHTML)
                    ?? parseRatingString(gl2cNode.at_xpath("//div [@class='ir irb']")?.toHTML),
                  let category = link.at_xpath("//td [@class='gl1c glcat'] //div")?.text,
                  var publishedTime = gl2cNode.at_xpath("//div [@onclick]")?.text,
                  let coverURL = try? parseCoverURL(gl2cNode.at_xpath("//div [@class='glthumb']")?.at_css("img")),
                  let detailURL = link.at_xpath("//td [@class='gl3c glname'] //a")?["href"]
            else { continue }
            
            if !publishedTime.contains(":") {
                guard let content = gl2cNode.text,
                      let range = content.range(of: "pages")
                else { continue }
                
                let fixedTime = String(content.suffix(from: range.upperBound))
                publishedTime = fixedTime
            }
            
            var tags = [String]()
            var language: Language?
            for tagLink in gl3cNode.xpath("//div [@class='gt']") {
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
            
            guard let url = URL(string: detailURL),
                  !url.pathComponents[2].isEmpty,
                  !url.pathComponents[3].isEmpty
            else { continue }
            
            guard let enumCategory = Category(rawValue: category)
            else { continue }
            
            mangaItems.append(
                Manga(
                    id: url.pathComponents[2],
                    token: url.pathComponents[3],
                    title: title,
                    rating: rating,
                    tags: tags,
                    category: enumCategory,
                    language: language,
                    uploader: uploader,
                    publishedTime: publishedTime,
                    coverURL: coverURL,
                    detailURL: detailURL
                )
            )
        }
        
        return (parsePageNum(doc), mangaItems)
    }
    
    // MARK: 詳細情報
    func parseMangaDetail(_ doc: HTMLDocument) throws -> (MangaDetail, APIKey, HTMLDocument) {
        var mangaDetail: MangaDetail?
        var imageURLs = [MangaPreview]()
        
        for link in doc.xpath("//div [@class='gm']") {
            
            guard let enTitle = link.at_xpath("//h1 [@id='gn']")?.text,
                  let gd3Node = link.at_xpath("//div [@id='gd3']"),
                  let gddNode = gd3Node.at_xpath("//div [@id='gdd']"),
                  let gdrNode = gd3Node.at_xpath("//div [@id='gdr']"),
                  let gdfNode = gd3Node.at_xpath("//div [@id='gdf']"),
                  let gdtNode = doc.at_xpath("//div [@id='gdt']"),
                  let gd4Node = link.at_xpath("//div [@id='gd4']"),
                  let gd5Node = link.at_xpath("//div [@id='gd5']"),
                  let rawCoverURL = link.at_xpath("//div [@id='gd1']")?.innerHTML,
                  let coverRangeA = rawCoverURL.range(of: "url("),
                  let coverRangeB = rawCoverURL.range(of: ")"),
                  let tmpCategory = gd3Node.at_xpath("//div [@id='gdc']")?.text,
                  let category = Category(rawValue: tmpCategory),
                  let uploader = gd3Node.at_xpath("//div [@id='gdn']")?.text,
                  let tmpRating = gdrNode.at_xpath("//td [@id='rating_label']")?.text?
                    .replacingOccurrences(of: "Average: ", with: "")
                    .replacingOccurrences(of: "Not Yet Rated", with: "0"),
                  let ratingCount = gdrNode.at_xpath("//span [@id='rating_count']")?.text
            else { throw AppError.parseFailed }
            
            let coverURL = String(
                rawCoverURL
                    .suffix(from: coverRangeA.upperBound)
                    .prefix(upTo: coverRangeB.lowerBound)
            )
            
            var tmpPublishedTime: String?
            var tmpLanguage: String?
            var tmpLikeCount: String?
            var tmpPageCount: String?
            var tmpSizeCount: String?
            var tmpSizeType: String?
            for gddLink in gddNode.xpath("//tr") {
                guard let gdt1 = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                      let gdt2 = gddLink.at_xpath("//td [@class='gdt2']")?.text
                else { continue }
                
                if gdt1.contains("Posted") {
                    tmpPublishedTime = gdt2
                }
                if gdt1.contains("Language") {
                    tmpLanguage = gdt2
                        .replacingOccurrences(of: "  TR", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                if gdt1.contains("File Size") {
                    if gdt2.contains("KB") { tmpSizeType = "KB" }
                    if gdt2.contains("MB") { tmpSizeType = "MB" }
                    if gdt2.contains("GB") { tmpSizeType = "GB" }
                    tmpSizeCount = gdt2
                        .replacingOccurrences(of: " KB", with: "")
                        .replacingOccurrences(of: " MB", with: "")
                        .replacingOccurrences(of: " GB", with: "")
                }
                if gdt1.contains("Length") {
                    tmpPageCount = gdt2.replacingOccurrences(of: " pages", with: "")
                }
                if gdt1.contains("Favorited") {
                    tmpLikeCount = gdt2
                        .replacingOccurrences(of: " times", with: "")
                        .replacingOccurrences(of: "Never", with: "0")
                        .replacingOccurrences(of: "Once", with: "0")
                }
            }
            
            var detailTags = [MangaTag]()
            for gd4Link in gd4Node.xpath("//tr") {
                guard let rawCategory = gd4Link
                        .at_xpath("//td [@class='tc']")?
                        .text?.replacingOccurrences(of: ":", with: ""),
                      let category = TagCategory(rawValue: rawCategory)
                else { continue }
                
                var content = [String]()
                for aLink in gd4Link.xpath("//a") {
                    guard let aText = aLink.text
                    else { continue }
                    
                    var fixedText: String?
                    if let range = aText.range(of: "|") {
                        fixedText = String(aText.prefix(upTo: range.lowerBound))
                    }
                    content.append(fixedText ?? aText)
                }
                
                detailTags.append(MangaTag(category: category, content: content))
            }
            
            var archiveURL: String?
            for g2gspLink in gd5Node.xpath("//p [@class='g2 gsp']") {
                archiveURL = try? parseArchiveURL(g2gspLink)
                if archiveURL != nil { break }
            }
            
            var tmpTorrentCount: Int?
            for g2Link in gd5Node.xpath("//p [@class='g2']") {
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
                    archiveURL = try? parseArchiveURL(g2Link)
                }
            }
            
            for gdtLink in gdtNode.xpath("//img") {
                if imageURLs.count >= 10 { break }
                guard let imageURL = gdtLink["src"] else { continue }
                imageURLs.append(MangaPreview(url: imageURL))
            }
            imageURLs = imageURLs.filter { !$0.url.contains("blank.gif") }
            
            guard let publishedTime = tmpPublishedTime,
                  let likeCount = tmpLikeCount,
                  let pageCount = tmpPageCount,
                  let sizeCount = tmpSizeCount,
                  let sizeType = tmpSizeType,
                  let tmpLanguage2 = tmpLanguage,
                  let language = Language(rawValue: tmpLanguage2),
                  let rating = Float(tmpRating),
                  let torrentCount = tmpTorrentCount
            else { throw AppError.parseFailed }
            
            let isFavored = gdfNode.at_xpath("//a [@id='favoritelink']")?.text?
                .contains("Add to Favorites") == false
            let userRating = parseRatingString(
                gdrNode.at_xpath("//div [@class='ir irr']")?.toHTML
                ?? gdrNode.at_xpath("//div [@class='ir irg']")?.toHTML
                ?? gdrNode.at_xpath("//div [@class='ir irb']")?.toHTML
            )
            var jpnTitle = link.at_xpath("//h1 [@id='gj']")?.text
            if jpnTitle?.isEmpty != false {
                jpnTitle = nil
            }
            mangaDetail = MangaDetail(
                isFavored: isFavored,
                archiveURL: archiveURL,
                alterImages: [],
                torrents: [],
                comments: parseComments(doc),
                previews: imageURLs,
                title: enTitle,
                jpnTitle: jpnTitle,
                rating: rating,
                userRating: userRating,
                ratingCount: ratingCount,
                detailTags: detailTags,
                category: category,
                language: language,
                uploader: uploader,
                publishedTime: publishedTime,
                coverURL: coverURL,
                likeCount: likeCount,
                pageCount: pageCount,
                sizeCount: sizeCount,
                sizeType: sizeType,
                torrentCount: torrentCount
            )
            break
        }
        
        var apikey: APIKey?
        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let script = link.text,
                  script.contains("apikey"),
                  let rangeA = script.range(of: ";\nvar apikey = \""),
                  let rangeB = script.range(of: "\";\nvar average_rating")
            else { continue }
            
            let key = String(
                script.suffix(from: rangeA.upperBound).prefix(upTo: rangeB.lowerBound)
            )
            apikey = key
        }
        
        if let detail = mangaDetail,
           let key = apikey
        {
            return (detail, key, doc)
        } else {
            throw AppError.parseFailed
        }
    }
    
    // MARK: コメント
    func parseComments(_ doc: HTMLDocument) -> [MangaComment] {
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
                
                let author = String(c3Node.suffix(from: rangeB.upperBound))
                let commentTime = String(
                    c3Node.suffix(from: rangeA.upperBound).prefix(upTo: rangeB.lowerBound)
                )
                
                var votedUp = false
                var votedDown = false
                var votable = false
                var editable = false
                if let c4Link = c1Link.at_xpath("//div [@class='c4 nosel']") {
                    for aLink in c4Link.xpath("//a") {
                        guard let a_id = aLink["id"],
                              let a_style = aLink["style"]
                        else {
                            if let a_onclick = aLink["onclick"],
                               a_onclick.contains("edit_comment") {
                                editable = true
                            }
                            continue
                        }
                        
                        if a_id.contains("vote_up") {
                            votable = true
                        }
                        if a_id.contains("vote_up") && a_style.contains("blue") {
                            votedUp = true
                        }
                        if a_id.contains("vote_down") && a_style.contains("blue") {
                            votedDown = true
                        }
                    }
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMMM yyyy, HH:mm"
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
                        contents: parseCommentContent(c6Node),
                        commentID: commentID,
                        commentDate: commentDate
                    )
                )
            }
        }
        return comments
    }
    
    // MARK: コンテント
    func parseImagePreContents(_ doc: HTMLDocument, pageIndex: Int) -> [(Int, URL)] {
        var imageDetailURLs = [(Int, URL)]()
        
        let className = exx ? "gdtl" : "gdtm"
        guard let gdtNode = doc.at_xpath("//div [@id='gdt']") else { return [] }
        
        for (i, link) in gdtNode.xpath("//div [@class='\(className)']").enumerated() {
            
            guard let imageDetailStr = link.at_xpath("//a")?["href"],
                  let imageDetailURL = URL(string: imageDetailStr)
            else { continue }
            
            imageDetailURLs.append((i + pageIndex * 20, imageDetailURL))
        }
        
        return imageDetailURLs
    }
    
    func parseMangaContent(doc: HTMLDocument, tag: Int) -> MangaContent? {
        guard let i3Node = doc.at_xpath("//div [@id='i3']"),
              let imageURL = i3Node.at_css("img")?["src"]
        else { return nil }
        
        return MangaContent(tag: tag, url: imageURL)
    }
    
    // MARK: ユーザー
    func parseUserInfo(doc: HTMLDocument) -> User? {
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
        
        return User(displayName: displayName, avatarURL: avatarURL)
    }
    
    // MARK: アーカイブ
    func parseMangaArchive(doc: HTMLDocument) throws -> (MangaArchive, CurrentGP?, CurrentCredits?) {
        var hathArchives = [MangaArchive.HathArchive]()
        
        guard let tableNode = doc.at_xpath("//table") else { throw AppError.parseFailed }
        for tdLink in tableNode.xpath("//td") {
            var tmpResolution: ArchiveRes?
            var tmpFileSize: String?
            var tmpGPPrice: String?
            
            for pLink in tdLink.xpath("//p") {
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
        
        let funds = parseCurrentFunds(doc)
        return (MangaArchive(hathArchives: hathArchives), funds?.0, funds?.1)
    }
    
    // MARK: トレント
    func parseMangaTorrents(doc: HTMLDocument) -> [MangaTorrent] {
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
                    postedTime: postedTime,
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
    // MARK: カバー
    func parseCoverURL(_ node: XMLElement?) throws -> String {
        guard let node = node
        else { throw AppError.parseFailed }
        
        var coverURL = node["data-src"]
        if coverURL == nil { coverURL = node["src"] }
        
        guard let url = coverURL
        else { throw AppError.parseFailed }
        
        return url
    }
    
    // MARK: 評価
    func parseRatingString(_ ratingString: String?) -> Float? {
        guard let ratingString = ratingString else { return nil }
        
        var tmpRating: Float?
        if ratingString.contains("0px") { tmpRating = 5.0 }
        if ratingString.contains("-16px") { tmpRating = 4.0 }
        if ratingString.contains("-32px") { tmpRating = 3.0 }
        if ratingString.contains("-48px") { tmpRating = 2.0 }
        if ratingString.contains("-64px") { tmpRating = 1.0 }
        if ratingString.contains("-80px") { tmpRating = 0.0 }
        
        guard var rating = tmpRating else { return nil }
        if ratingString.contains("-21px") { rating -= 0.5 }
        return rating
    }
    
    // MARK: ページナンバー
    func parsePageNum(_ doc: HTMLDocument) -> PageNumber {
        var current = 0
        var maximum = 0
        
        guard let link = doc.at_xpath("//table [@class='ptt']") else { return PageNumber() }
        if let currentStr = link.at_xpath("//td [@class='ptds']")?.text {
            if let range = currentStr.range(of: "-") {
                current = (Int(String(currentStr.suffix(from: range.upperBound))) ?? 1) - 1
            } else {
                current = (Int(currentStr) ?? 1) - 1
            }
        }
        for ptbLink in link.xpath("//a") {
            if let num = Int(ptbLink.text ?? "") {
                maximum = num
            }
        }
        return PageNumber(current: current, maximum: maximum)
    }
    
    // MARK: 代替プレビュー
    func parseAlterImagesURL(_ doc: HTMLDocument) throws -> String {
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
    
    func parseAlterImages(id: String, _ data: Data) -> (Identity, [MangaAlterData]) {
        guard let image = UIImage(data: data) else { return (id, []) }
        
        var alterImages = [MangaAlterData]()
        let originW = image.size.width
        let originH = image.size.height

        for i in 0..<20 {
            let size = CGSize(width: originW / 20, height: originH)
            let anchor = CGPoint(x: originW / 20 * CGFloat(i), y: 0)
            
            if let croppedImg = image.kf.crop(to: size, anchorOn: anchor).pngData() {
                alterImages.append(MangaAlterData(data: croppedImg))
            }
        }
        
        return (id, alterImages)
    }
    
    // MARK: 残高
    func parseCurrentFunds(_ doc: HTMLDocument) -> (String, String)? {
        var currentGP: String?
        var currentCredits: String?
        
        for pLink in doc.xpath("//p") {
            if let pText = pLink.text,
               let rangeA = pText.range(of: "GP"),
               let rangeB = pText.range(of: "[?]"),
               let rangeC = pText.range(of: "Credits")
            {
                currentGP = String(
                    pText
                        .prefix(upTo: rangeA.lowerBound)
                )
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: "")
                
                currentCredits = String(
                    pText
                        .suffix(from: rangeB.upperBound)
                        .prefix(upTo: rangeC.lowerBound)
                )
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: "")
            }
        }
        
        if let gp = currentGP,
           let credits = currentCredits
        {
            return (gp, credits)
        } else {
            return nil
        }
    }
    
    // MARK: ダウンロードコマンドの返事
    func parseDownloadCommandResponse(_ doc: HTMLDocument) throws -> Resp {
        guard let dbNode = doc.at_xpath("//div [@id='db']")
        else { throw AppError.parseFailed }
        
        var response = [String]()
        for pLink in dbNode.xpath("//p") {
            if let pText = pLink.text {
                response.append(pText)
            }
        }
        
        if !response.isEmpty {
            return response.joined(separator: " ")
        } else {
            throw AppError.parseFailed
        }
    }
    
    // MARK: アーカイブリンク
    func parseArchiveURL(_ element: XMLElement) throws -> String {
        var archiveURL: String?
        if let aLink = element.at_xpath("//a"),
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
    
    // MARK: コメント内容
    func parseCommentContent(_ element: XMLElement) -> [CommentContent] {
        var contents = [CommentContent]()
        
        guard var rawContent = element.innerHTML?
                .replacingOccurrences(of: "<br>", with: "\n")
                .replacingOccurrences(of: "</span>", with: "")
                .replacingOccurrences(
                    of: "<div.*?>.*?</div>",
                    with: "",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: "<span.*?>",
                    with: "",
                    options: .regularExpression
                )
        else { return [] }
        
        while (element.xpath("//a").count
                + element.xpath("//img").count) > 0
        {
            var tmpLink: XMLElement?
            
            let links = [
                element.at_xpath("//a"),
                element.at_xpath("//img")
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
                  let html = link.toHTML,
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
            element.removeChild(link)
            
            if (element.xpath("//a").count
                    + element.xpath("//img").count) <= 0
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
