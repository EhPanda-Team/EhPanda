//
//  RequestManager.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import Kanna
import SwiftUI

class RequestManager {
    static let shared = RequestManager()
    
    func requestPopularItems() -> [Manga] {
        setIgnoreOffensiveInfo()
        
        guard let popularURL = URL(string: Defaults.URL.host + ("/popular")),
              let popularItems = parseHTML_Popular(popularURL) else {
            ePrint("HTML解析できませんでした")
            return []
        }
        return popularItems
    }
    
    func requestDetailItem(url: String) -> MangaDetail? {
        guard let detailURL = URL(string: url),
              let detailItem = parseHTML_Detail(detailURL) else {
            ePrint("HTML解析できませんでした")
            return nil
        }
        return detailItem
    }
    
    func requestPreviewItems(url: String) -> [MangaContent] {
        guard let detailURL = URL(string: url),
              let previewItems = parseHTML_PreviewImages(detailURL) else {
            ePrint("HTML解析できませんでした")
            return []
        }
        return previewItems
    }
    
    func requestContentItems(url: String, pageIndex: Int) -> [MangaContent] {
        guard let contentItems = parseHTML_ContentImages(url, pageIndex: pageIndex) else {
            ePrint("HTML解析できませんでした")
            return []
        }
        return contentItems
    }
    
    // MARK: 人気
    func parseHTML_Popular(_ url: URL) -> [Manga]? {
        var mangaItems = [Manga]()
        
        var document: HTMLDocument?
        do {
            document = try Kanna.HTML(url: url, encoding: .utf8)
        } catch {
            ePrint(error)
        }
        
        guard let doc = document else { return nil }
        for link in doc.xpath("//tr") {
            
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                  let title = link.at_xpath("//div [@class='glink']")?.text,
                  let rating = parseRatingString(gl2cNode.at_xpath("//div [@class='ir']")?.toHTML),
                  let category = link.at_xpath("//td [@class='gl1c glcat'] //div")?.text,
                  let uploader = link.at_xpath("//td [@class='gl4c glhide']")?.at_xpath("//a")?.text,
                  let publishedTime = gl2cNode.at_xpath("//div [@onclick]")?.text,
                  let coverURL = parseCoverURL(gl2cNode.at_xpath("//div [@class='glthumb']")?.at_css("img")),
                  let detailURL = link.at_xpath("//td [@class='gl3c glname'] //a")?["href"]
            else { continue }
            
            guard let enumCategory = Category(rawValue: category) else { continue }
            mangaItems.append(Manga(title: title,
                                    rating: rating,
                                    category: enumCategory,
                                    uploader: uploader,
                                    publishedTime: publishedTime,
                                    coverURL: coverURL,
                                    detailURL: detailURL))
        }
        
        if mangaItems.count < 50 {
            ePrint("⚠️パース結果数値が閾値より小さい")
        }
        
        return mangaItems
    }
    
    // MARK: 詳細情報
    func parseHTML_Detail(_ url: URL) -> MangaDetail? {
        var mangaDetail: MangaDetail?
        
        var document: HTMLDocument?
        do {
            document = try Kanna.HTML(url: url, encoding: .utf8)
        } catch {
            ePrint(error)
        }
        
        guard let doc = document else { return nil }
        for link in doc.xpath("//div [@class='gm']") {
            
            guard let jpnTitle = link.at_xpath("//h1 [@id='gj']")?.text,
                  let gddNode = link.at_xpath("//div [@id='gdd']"),
                  let gdrNode = link.at_xpath("//div [@id='gdr']"),
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
            
            guard let likeCount = tmpLikeCount,
                  let pageCount = tmpPageCount,
                  let sizeCount = tmpSizeCount,
                  let sizeType = tmpSizeType,
                  let tmpLanguage2 = tmpLanguage,
                  let language = Language(rawValue: tmpLanguage2)
            else { return nil }
            
            mangaDetail = MangaDetail(jpnTitle: jpnTitle,
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
    
    // MARK: プレビュー
    func parseHTML_PreviewImages(_ url: URL) -> [MangaContent]? {
        var mangaItems = [MangaContent]()
        var imageDetailURLs = [MangaURL]()
        
        var document: HTMLDocument?
        do {
            document = try Kanna.HTML(url: url, encoding: .utf8)
        } catch {
            ePrint(error)
        }
        
        guard let doc = document,
              let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { return nil }
        
        for (i, link) in gdtNode.xpath("//div [@class='gdtm']").enumerated() {
            if imageDetailURLs.count >= 10 { break }
            guard let imageDetailStr = link.at_xpath("//a")?["href"],
                  let imageDetailURL = URL(string: imageDetailStr)
            else { continue }
            
            imageDetailURLs.append(MangaURL(tag: i, url: imageDetailURL))
        }
        
        let urlsStartTime = CACurrentMediaTime()
        let queue = OperationQueue()
        for (index, mangaURL) in imageDetailURLs.enumerated() {
            queue.addOperation {
                var document: HTMLDocument?
                do {
                    document = try Kanna.HTML(url: mangaURL.url, encoding: .utf8)
                } catch {
                    ePrint(error)
                }
                
                guard let doc = document,
                      let i3Node = doc.at_xpath("//div [@id='i3']"),
                      let imageURL = i3Node.at_css("img")?["src"]
                else { return }
                
                mangaItems.append(MangaContent(tag: index, url: imageURL))
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        ePrint("プレビュー読み込み完了! (\(CACurrentMediaTime() - urlsStartTime)秒)")
        mangaItems.sort { (a, b) -> Bool in
            a.tag < b.tag
        }
        
        return mangaItems
    }
    
    // MARK: コンテント
    func parseHTML_ContentImages(_ url: String, pageIndex: Int) -> [MangaContent]? {
//        ePrint("\(pageIndex)")
        var mangaItems = [MangaContent]()
        var imageDetailURLs = [MangaURL]()
        
        let ehPageCount = Int(floor(Double(pageIndex)/4))
        guard let url = URL(string: url.appending("?p=\(ehPageCount)")) else { return nil }
            
        var document: HTMLDocument?
        do {
            document = try Kanna.HTML(url: url, encoding: .utf8)
        } catch {
            ePrint(error)
        }
        
        guard let doc = document,
              let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { return nil }
        
        var skipCount = 0
        for (i, link) in gdtNode.xpath("//div [@class='gdtm']").enumerated() {
            
            skipCount += 1
//            ePrint("!skip! skipCount: \(skipCount)  skipAmount: \((pageIndex % 4) * 10)")
            if imageDetailURLs.count >= 10 || skipCount <= (pageIndex % 4) * 10 { continue }
//            ePrint("!passed! skipCount: \(skipCount)  skipAmount: \((pageIndex % 4) * 10)")
            
            guard let imageDetailStr = link.at_xpath("//a")?["href"],
                  let imageDetailURL = URL(string: imageDetailStr)
            else { continue }
            
            imageDetailURLs.append(MangaURL(tag: pageIndex * 10 + i, url: imageDetailURL))
        }
        
        let urlsStartTime = CACurrentMediaTime()
        let queue = OperationQueue()
        for (index, mangaURL) in imageDetailURLs.enumerated() {
            queue.addOperation {
                var document: HTMLDocument?
                do {
                    document = try Kanna.HTML(url: mangaURL.url, encoding: .utf8)
                } catch {
                    ePrint(error)
                }
                
                guard let doc = document,
                      let i3Node = doc.at_xpath("//div [@id='i3']"),
                      let imageURL = i3Node.at_css("img")?["src"]
                else { return }
                
                mangaItems.append(MangaContent(tag: pageIndex * 10 + index, url: imageURL))
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        ePrint("コンテント読み込み完了! (\(CACurrentMediaTime() - urlsStartTime)秒)")
        mangaItems.sort { (a, b) -> Bool in
            a.tag < b.tag
        }
        
        return mangaItems
    }
}

// MARK: サブメソッド
extension RequestManager {
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
    
    func setIgnoreOffensiveInfo() {
        guard let url = URL(string: "https://e-hentai.org/") else { return }
        if isCookieSet(name: "nw", url: url) { return }
        setCookie(url: url, key: "nw", value: "1")
    }
    
    func setCookie(url: URL, key: String, value: String) {
        let cookieStr = key + "=" + value + ";Secure"
        let cookieHeaderField = ["Set-Cookie": cookieStr]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: cookieHeaderField, for: url)

        HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: url)
    }
    
    func isCookieSet(name: String, url: URL) -> Bool {
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                if (cookie.name == name) {
                    return true
                }
            }
        }

        return false
    }
}
