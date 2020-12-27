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
    
    func requestContentItems(url: String, pageIndex: Int) -> [MangaContent] {
        guard let contentItems = parseHTML_ContentImages(url, pageIndex: pageIndex) else {
            ePrint("HTML解析できませんでした")
            return []
        }
        return contentItems
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
