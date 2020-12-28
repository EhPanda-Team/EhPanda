//
//  Parser.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import SwiftUI

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
    func parseMangaDetail(_ doc: HTMLDocument) -> MangaDetail? {
        var mangaDetail: MangaDetail?
        var imageURLs = [MangaPreview]()
        
        for link in doc.xpath("//div [@class='gm']") {
            
            guard let jpnTitle = link.at_xpath("//h1 [@id='gj']")?.text,
                  let gddNode = link.at_xpath("//div [@id='gdd']"),
                  let gdrNode = link.at_xpath("//div [@id='gdr']"),
                  let gdtNode = doc.at_xpath("//div [@id='gdt']"),
                  let ratingCount = gdrNode.at_xpath("//span [@id='rating_count']")?.text
            else { return nil }
            
            var tmpLanguage: String?
            var tmpLikeCount: String?
            var tmpPageCount: String?
            var tmpSizeCount: String?
            var tmpSizeType: String?
            for gddLink in gddNode.xpath("//tr") {
                guard let gdt1 = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                      let gdt2 = gddLink.at_xpath("//td [@class='gdt2']")?.text
                else { continue }
                
                if gdt1.contains("Language") { tmpLanguage = gdt2.replacingOccurrences(of: "  TR", with: "").trimmingCharacters(in: .whitespaces) }
                if gdt1.contains("File Size") {
                    if gdt2.contains("KB") { tmpSizeType = "KB" }
                    if gdt2.contains("MB") { tmpSizeType = "MB" }
                    if gdt2.contains("GB") { tmpSizeType = "GB" }
                    tmpSizeCount = gdt2.replacingOccurrences(of: " KB", with: "")
                                       .replacingOccurrences(of: " MB", with: "")
                                       .replacingOccurrences(of: " GB", with: "")
                }
                if gdt1.contains("Length") { tmpPageCount = gdt2.replacingOccurrences(of: " pages", with: "") }
                if gdt1.contains("Favorited") { tmpLikeCount = gdt2.replacingOccurrences(of: " times", with: "") }
            }
            
            for gdtLink in gdtNode.xpath("//img") {
                if imageURLs.count >= 10 { break }
                guard let imageURL = gdtLink["src"] else { continue }
                imageURLs.append(MangaPreview(url: imageURL))
            }
            
            guard let likeCount = tmpLikeCount,
                  let pageCount = tmpPageCount,
                  let sizeCount = tmpSizeCount,
                  let sizeType = tmpSizeType,
                  let tmpLanguage2 = tmpLanguage,
                  let language = Language(rawValue: tmpLanguage2)
            else { return nil }
            
            mangaDetail = MangaDetail(previews: imageURLs,
                                      jpnTitle: jpnTitle,
                                      language: language,
                                      likeCount: likeCount,
                                      pageCount: pageCount,
                                      sizeCount: sizeCount,
                                      sizeType: sizeType,
                                      ratingCount: ratingCount)
            break
        }
        
        return mangaDetail
    }
        
    // MARK: コンテント
    func parseImagePreContents(_ doc: HTMLDocument, pageStartIndex: Int) -> [(Int, URL)] {
        var imageDetailURLs = [(Int, URL)]()
        
        guard let gdtNode = doc.at_xpath("//div [@id='gdt']") else { return [] }
        
        var skipCount = 0
        for (i, link) in gdtNode.xpath("//div [@class='gdtm']").enumerated() {
            
            skipCount += 1
            if imageDetailURLs.count >= 10
                || skipCount <= (pageStartIndex % 4) * 10 { continue }
            
            guard let imageDetailStr = link.at_xpath("//a")?["href"],
                  let imageDetailURL = URL(string: imageDetailStr)
            else { continue }
            
            imageDetailURLs.append((pageStartIndex * 10 + i, url: imageDetailURL))
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
}
