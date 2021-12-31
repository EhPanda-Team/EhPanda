//
//  URLUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import UIKit
import Foundation
import OrderedCollections

struct URLUtil {
    private static func checkIfHandleable(url: URL) -> Bool {
        (url.absoluteString.contains(Defaults.URL.ehentai.absoluteString)
         || url.absoluteString.contains(Defaults.URL.exhentai.absoluteString))
            && url.pathComponents.count >= 4 && ["g", "s"].contains(url.pathComponents[1])
            && !url.pathComponents[2].isEmpty && !url.pathComponents[3].isEmpty
    }

    static func parseGID(url: URL, isGalleryURL: Bool) -> String {
        var gid = url.pathComponents[2]
        let token = url.pathComponents[3]
        if let range = token.range(of: "-"), isGalleryURL {
            gid = String(token[..<range.lowerBound])
        }
        return gid
    }

    static func handleURL(
        _ url: URL, handlesOutgoingURL: Bool = false,
        completion: (Bool, URL?, Int?, String?) -> Void
    ) {
        guard checkIfHandleable(url: url) else {
            if handlesOutgoingURL {
                UIApplication.shared.open(url, options: [:])
            }
            completion(false, nil, nil, nil)
            return
        }

        let token = url.pathComponents[3]
        if let range = token.range(of: "-") {
            let pageIndex = Int(token[range.upperBound...])
            completion(true, url, pageIndex, nil)
            return
        }

        if let range = url.absoluteString.range(of: url.pathComponents[3] + "/") {
            let commentField = String(url.absoluteString[range.upperBound...])
            if let range = commentField.range(of: "#c") {
                let commentID = String(commentField[range.upperBound...])
                completion(false, url, nil, commentID)
                return
            }
        }

        completion(false, url, nil, nil)
    }
}

// MARK: Combining
extension URLUtil {
    // Fetch
    static func searchList(keyword: String, filter: Filter, pageNum: Int? = nil) -> URL {
        var queryItems: OrderedDictionary<Defaults.URL.Component.Key, String> = [.fSearch: keyword.urlEncoded()]
        if let pageNum = pageNum {
            queryItems[.page] = String(pageNum)
        }
        return Defaults.URL.host.appending(queryItems: queryItems)
    }
    static func moreSearchList(keyword: String, filter: Filter, pageNum: Int, lastID: String) -> URL {
        Defaults.URL.host.appending(queryItems: [
            .fSearch: keyword.urlEncoded(), .page: String(pageNum), .from: lastID
        ])
        .applyingFilter(filter)
    }
    static func frontpageList(filter: Filter, pageNum: Int? = nil) -> URL {
        var url = Defaults.URL.host
        if let pageNum = pageNum {
            url.append(queryItems: [.page: String(pageNum)])
        }
        return url.applyingFilter(filter)
    }
    static func moreFrontpageList(filter: Filter, pageNum: Int, lastID: String) -> URL {
        Defaults.URL.host.appending(queryItems: [.page: String(pageNum), .from: lastID]).applyingFilter(filter)
    }
    static func popularList(filter: Filter) -> URL {
        Defaults.URL.popular.applyingFilter(filter)
    }
    static func watchedList(filter: Filter, pageNum: Int? = nil) -> URL {
        var url = Defaults.URL.watched
        if let pageNum = pageNum {
            url.append(queryItems: [.page: String(pageNum)])
        }
        return url.applyingFilter(filter)
    }
    static func moreWatchedList(filter: Filter, pageNum: Int, lastID: String) -> URL {
        Defaults.URL.watched.appending(queryItems: [.page: String(pageNum), .from: lastID]).applyingFilter(filter)
    }
    static func favoritesList(favIndex: Int, pageNum: Int? = nil, sortOrder: FavoritesSortOrder? = nil) -> URL {
        var url = Defaults.URL.favorites
        if favIndex == -1 {
            if pageNum == nil {
                guard let sortOrder = sortOrder else { return url }
                return url.appending(queryItems: [
                    .inlineSet: sortOrder == .favoritedTime
                    ? .sortOrderByFavoritedTime : .sortOrderByUpdateTime
                ])
            }
        } else {
            url.append(queryItems: [.favcat: String(favIndex)])
        }
        if let pageNum = pageNum {
            url.append(queryItems: [.page: String(pageNum)])
        }
        if let sortOrder = sortOrder {
            url.append(queryItems: [
                .inlineSet: sortOrder == .favoritedTime
                ? .sortOrderByFavoritedTime : .sortOrderByUpdateTime
            ])
        }
        return url
    }
    static func moreFavoritesList(favIndex: Int, pageNum: Int, lastID: String) -> URL {
        var url = Defaults.URL.favorites.appending(queryItems: [.page: String(pageNum), .from: lastID])
        if favIndex != -1 {
            url.append(queryItems: [.favcat: String(favIndex)])
        }
        return url
    }
    static func toplistsList(catIndex: Int, pageNum: Int? = nil) -> URL {
        var url = Defaults.URL.toplist.appending(queryItems: [.topcat: String(catIndex)])
        if let pageNum = pageNum {
            url.append(queryItems: [.letterP: String(pageNum)])
        }
        return url
    }
    static func moreToplistsList(catIndex: Int, pageNum: Int) -> URL {
        Defaults.URL.toplist.appending(queryItems: [.topcat: String(catIndex), .letterP: String(pageNum)])
    }
    static func galleryDetail(url: String) -> URL {
        url.safeURL().appending(queryItems: [.showComments: .one])
    }
    static func galleryTorrents(gid: String, token: String) -> URL {
        Defaults.URL.galleryTorrents.appending(queryItems: [.gid: gid, .token: token])
    }

    // Account Associated Operations
    static func addFavorite(gid: String, token: String) -> URL {
        Defaults.URL.galleryPopups
            .appending(queryItems: [.gid: gid, .token: token])
            .appending(queryItems: [.act: .addFavAct])
    }
    static func userInfo(uid: String) -> URL {
        Defaults.URL.forum.appending(queryItems: [.showUser: uid])
    }

    // Misc
    static func detailPage(url: String, pageNum: Int) -> URL {
        url.safeURL().appending(queryItems: [.letterP: String(pageNum)])
    }
    static func normalPreview(plainURL: String, width: String, height: String, offset: String) -> URL {
        plainURL.safeURL().appending(queryItems: [.ehpandaWidth: width, .ehpandaHeight: height, .ehpandaOffset: offset])
    }

    // GitHub
    static func githubAPI(repoName: String) -> URL {
        Defaults.URL.githubAPI.appendingPathComponent("\(repoName)/releases/latest")
    }
    static func githubDownload(repoName: String, fileName: String) -> URL {
        Defaults.URL.github.appendingPathComponent("\(repoName)/releases/latest/download/\(fileName)")
    }
}

// MARK: Combining (Filter)
private extension URL {
    func applyingFilter(_ filter: Filter) -> URL {
        var queryItems1 = OrderedDictionary<Defaults.URL.Component.Key, String>()
        var queryItems2 = OrderedDictionary<Defaults.URL.Component.Key, Defaults.URL.Component.Value>()

        var categoryValue = 0
        categoryValue += filter.doujinshi ? Category.doujinshi.value : 0
        categoryValue += filter.manga ? Category.manga.value : 0
        categoryValue += filter.artistCG ? Category.artistCG.value : 0
        categoryValue += filter.gameCG ? Category.gameCG.value : 0
        categoryValue += filter.western ? Category.western.value : 0
        categoryValue += filter.nonH ? Category.nonH.value : 0
        categoryValue += filter.imageSet ? Category.imageSet.value : 0
        categoryValue += filter.cosplay ? Category.cosplay.value : 0
        categoryValue += filter.asianPorn ? Category.asianPorn.value : 0
        categoryValue += filter.misc ? Category.misc.value : 0

        if ![0, 1023].contains(categoryValue) {
            queryItems1[.fCats] = String(categoryValue)
        }

        if !filter.advanced { return appending(queryItems: queryItems1).appending(queryItems: queryItems2) }
        queryItems2[.advSearch] = .one

        if filter.galleryName { queryItems2[.fSname] = .filterOn }
        if filter.galleryTags { queryItems2[.fStags] = .filterOn }
        if filter.galleryDesc { queryItems2[.fSdesc] = .filterOn }
        if filter.torrentFilenames { queryItems2[.fStorr] = .filterOn }
        if filter.onlyWithTorrents { queryItems2[.fSto] = .filterOn }
        if filter.lowPowerTags { queryItems2[.fSdt1] = .filterOn }
        if filter.downvotedTags { queryItems2[.fSdt2] = .filterOn }
        if filter.expungedGalleries { queryItems2[.fSh] = .filterOn }

        if filter.minRatingActivated, [2, 3, 4, 5].contains(filter.minRating) {
            queryItems2[.fSr] = .filterOn
            queryItems1[.fSrdd] = String(filter.minRating)
        }

        if filter.pageRangeActivated, let minPages = Int(filter.pageLowerBound),
           let maxPages = Int(filter.pageUpperBound),
           minPages > 0 && maxPages > 0 && minPages <= maxPages
        {
            queryItems2[.fSp] = .filterOn
            queryItems1[.fSpf] = String(minPages)
            queryItems1[.fSpt] = String(maxPages)
        }

        if filter.disableLanguage { queryItems2[.fSfl] = .filterOn }
        if filter.disableUploader { queryItems2[.fSfu] = .filterOn }
        if filter.disableTags { queryItems2[.fSft] = .filterOn }

        return appending(queryItems: queryItems1).appending(queryItems: queryItems2)
    }
}
