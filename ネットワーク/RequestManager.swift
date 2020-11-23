//
//  RequestManager.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import Alamofire
import Kanna

class RequestManager {
    static let shared = RequestManager()
    let popularThreshold = 50
    
    func getPopularManga() -> [Manga]? {
        guard let popularURL = URL(string: Defaults.URL.host + ("/popular")) else {
            ePrint("StringからURLへ解析できませんでした")
            return nil
        }
        guard let mangaItems = parseHTML(popularURL, popularThreshold) else {
            ePrint("HTML解析できませんでした")
            return nil
        }
        return mangaItems
    }
    
    func parseHTML(_ url: URL, _ threshold: Int? = nil) -> [Manga]? {
        var mangaItems = [Manga]()
        
        var document: HTMLDocument?
        do {
            document = try Kanna.HTML(url: url, encoding: .utf8)
        } catch {
            ePrint(error)
        }
        
        guard let doc = document else { return nil }
        for link in doc.xpath("//tr") {
            
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']") else { continue }
            guard let title = link.at_xpath("//div [@class='glink']")?.text else { continue }
            guard let rating = parseRatingString(gl2cNode.at_xpath("//div [@class='ir']")?.toHTML) else { continue }
            guard let category = link.at_xpath("//td [@class='gl1c glcat'] //div")?.text else { continue }
            guard let uploader = link.at_xpath("//td [@class='gl4c glhide']")?.at_xpath("//a")?.text else { continue }
            guard let publishedTime = gl2cNode.at_xpath("//div [@onclick]")?.text else { continue }
            guard let coverURL = parseCoverURL(gl2cNode.at_xpath("//div [@class='glthumb']")?.at_css("img")) else { continue }
            guard let detailURL = link.at_xpath("//td [@class='gl3c glname'] //a")?["href"] else { continue }
            
            mangaItems.append(Manga(title: title, rating: rating, category: category, uploader: uploader, publishedTime: publishedTime, coverURL: coverURL, detailURL: detailURL))
        }
        
        if let threshold = threshold {
            if mangaItems.count < threshold {
                ePrint("⚠️パース結果数値が閾値より小さい")
            }
        }
        
        return mangaItems
    }
    
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
