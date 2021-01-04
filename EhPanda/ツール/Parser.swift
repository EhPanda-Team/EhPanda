//
//  Parser.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import SwiftUI
import SDWebImageSwiftUI

class Parser {
    // MARK: 人気
    func parsePopularListItems(_ doc: HTMLDocument) -> [Manga] {
        var mangaItems = [Manga]()
        
        for link in doc.xpath("//tr") {
            
            let uploader = link.at_xpath("//td [@class='gl4c glhide']")?.at_xpath("//a")?.text
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                  let title = link.at_xpath("//div [@class='glink']")?.text,
                  let rating = parseRatingString(gl2cNode.at_xpath("//div [@class='ir']")?.toHTML),
                  let category = link.at_xpath("//td [@class='gl1c glcat'] //div")?.text,
                  var publishedTime = gl2cNode.at_xpath("//div [@onclick]")?.text,
                  let coverURL = parseCoverURL(gl2cNode.at_xpath("//div [@class='glthumb']")?.at_css("img")),
                  let detailURL = link.at_xpath("//td [@class='gl3c glname'] //a")?["href"]
            else { continue }
            
            if !publishedTime.contains(":") {
                guard let content = gl2cNode.text,
                      let range = content.range(of: "pages")
                else { continue }
                
                let fixedTime = String(content.suffix(from: range.upperBound))
                publishedTime = fixedTime
            }
            
            guard let url = URL(string: detailURL),
                  !url.pathComponents[2].isEmpty,
                  !url.pathComponents[3].isEmpty
            else { continue }
            
            guard let enumCategory = Category(rawValue: category) else { continue }
            mangaItems.append(Manga(id: url.pathComponents[2],
                                    token: url.pathComponents[3],
                                    title: title,
                                    rating: rating,
                                    category: enumCategory,
                                    uploader: uploader,
                                    publishedTime: publishedTime,
                                    coverURL: coverURL,
                                    detailURL: detailURL))
        }
        
        return mangaItems
    }
    
    // MARK: 詳細情報
    func parseMangaDetail(_ doc: HTMLDocument) -> (MangaDetail?, User?, HTMLDocument?) {
        var mangaDetail: MangaDetail?
        var imageURLs = [MangaPreview]()
        
        for link in doc.xpath("//div [@class='gm']") {
            
            guard let jpnTitle = link.at_xpath("//h1 [@id='gj']")?.text,
                  let gddNode = link.at_xpath("//div [@id='gdd']"),
                  let gdrNode = link.at_xpath("//div [@id='gdr']"),
                  let gdtNode = doc.at_xpath("//div [@id='gdt']"),
                  let ratingCount = gdrNode.at_xpath("//span [@id='rating_count']")?.text
            else { return (nil, nil, nil) }
            
            var tmpLanguage: String?
            var tmpLikeCount: String?
            var tmpPageCount: String?
            var tmpSizeCount: String?
            var tmpSizeType: String?
            for gddLink in gddNode.xpath("//tr") {
                guard let gdt1 = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                      let gdt2 = gddLink.at_xpath("//td [@class='gdt2']")?.text
                else { continue }
                
                if gdt1.contains("Language") {
                    tmpLanguage = gdt2
                        .replacingOccurrences(of: "  TR", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                if gdt1.contains("File Size") {
                    if gdt2.contains("KB") { tmpSizeType = "KB" }
                    if gdt2.contains("MB") { tmpSizeType = "MB" }
                    if gdt2.contains("GB") { tmpSizeType = "GB" }
                    tmpSizeCount = gdt2.replacingOccurrences(of: " KB", with: "")
                        .replacingOccurrences(of: " MB", with: "")
                        .replacingOccurrences(of: " GB", with: "")
                }
                if gdt1.contains("Length") {
                    tmpPageCount = gdt2.replacingOccurrences(of: " pages", with: "")
                }
                if gdt1.contains("Favorited") {
                    tmpLikeCount = gdt2
                        .replacingOccurrences(of: " times", with: "")
                        .replacingOccurrences(of: "Once", with: "0")
                }
            }
            
            for gdtLink in gdtNode.xpath("//img") {
                if imageURLs.count >= 10 { break }
                guard let imageURL = gdtLink["src"] else { continue }
                imageURLs.append(MangaPreview(url: imageURL))
            }
            imageURLs = imageURLs.filter { !$0.url.contains("blank.gif") }
            
            guard let likeCount = tmpLikeCount,
                  let pageCount = tmpPageCount,
                  let sizeCount = tmpSizeCount,
                  let sizeType = tmpSizeType,
                  let tmpLanguage2 = tmpLanguage,
                  let language = Language(rawValue: tmpLanguage2)
            else { return (nil, nil, nil) }
            
            mangaDetail = MangaDetail(alterImages: [],
                                      comments: parseComments(doc),
                                      previews: imageURLs,
                                      jpnTitle: jpnTitle,
                                      language: language,
                                      likeCount: likeCount,
                                      pageCount: pageCount,
                                      sizeCount: sizeCount,
                                      sizeType: sizeType,
                                      ratingCount: ratingCount)
            break
        }
        
        var user: User?
        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let script = link.text,
                  script.contains("apikey"),
                  let rangeA = script.range(of: "apiuid = "),
                  let rangeB = script.range(of: ";\nvar apikey = \""),
                  let rangeC = script.range(of: "\";\nvar average_rating")
            else { continue }
            
            let apiuid = String(
                script.suffix(from: rangeA.upperBound).prefix(upTo: rangeB.lowerBound)
            )
            let apikey = String(
                script.suffix(from: rangeB.upperBound).prefix(upTo: rangeC.lowerBound)
            )
            user = User(apiuid: apiuid, apikey: apikey)
        }
        
        return (mangaDetail, user, doc)
    }
    
    // MARK: コメント
    func parseComments(_ doc: HTMLDocument) -> [MangaComment] {
        var comments = [MangaComment]()
        for link in doc.xpath("//div [@id='cdiv']") {
            for c1Link in link.xpath("//div [@class='c1']") {
                guard let c3Node = c1Link.at_xpath("//div [@class='c3']")?.text,
                      let c6Node = c1Link.at_xpath("//div [@class='c6']"),
                      let content = c6Node.innerHTML?
                        .replacingOccurrences(of: "\n", with: "")
                        .replacingOccurrences(of: "<br>", with: "\n"),
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
                
                comments.append(MangaComment(votedUp: votedUp,
                                             votedDown: votedDown,
                                             votable: votable,
                                             editable: editable,
                                             score: score,
                                             author: author,
                                             content: content,
                                             commentID: commentID,
                                             commentDate: commentDate))
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
}

// MARK: サブメソッド
extension Parser {
    func parseCoverURL(_ node: XMLElement?) -> String? {
        guard let node = node else { return nil }
        
        var coverURL = node["data-src"]
        if coverURL == nil { coverURL = node["src"] }
        return coverURL
    }
    
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
    
    func parseAlterImagesURL(_ doc: HTMLDocument) -> String {
        var alterURL = ""
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
        
        return alterURL
    }
    
    func parseAlterImages(_ data: Data, id: String) -> ([Data], String) {
        guard let image = UIImage(data: data) else { return ([], id) }
        
        var alterImages = [Data]()
        let originW = image.size.width
        let originH = image.size.height

        for i in 0..<20 {
            let rect = CGRect(
                x: originW / 20 * CGFloat(i),
                y: 0,
                width: originW / 20,
                height: originH
            )

            if let croppedImg = image.sd_croppedImage(with: rect)?.pngData() {
                alterImages.append(croppedImg)
            }
        }
        
        return (alterImages, id)
    }
}
