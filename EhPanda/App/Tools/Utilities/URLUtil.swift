//
//  URLUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import Foundation

struct URLUtil {
    // Fetch
    static func searchList(keyword: String, filter: Filter) -> URL {
        Defaults.URL.host.appending(queryItems: [.fSearch: keyword]).applyingFilter(filter)
    }

    static func moreSearchList(keyword: String, filter: Filter, lastID: String) -> URL {
        Defaults.URL.host.appending(queryItems: [.fSearch: keyword, .next: lastID]).applyingFilter(filter)
    }

    static func frontpageList(filter: Filter) -> URL {
        Defaults.URL.host.applyingFilter(filter)
    }

    static func moreFrontpageList(filter: Filter, lastID: String) -> URL {
        Defaults.URL.host.appending(queryItems: [.next: lastID]).applyingFilter(filter)
    }

    static func popularList(filter: Filter) -> URL {
        Defaults.URL.popular.applyingFilter(filter)
    }

    static func watchedList(filter: Filter, keyword: String = "") -> URL {
        var url = Defaults.URL.watched
        if !keyword.isEmpty {
            url.append(queryItems: [.fSearch: keyword])
        }
        return url.applyingFilter(filter)
    }

    static func moreWatchedList(filter: Filter, lastID: String, keyword: String = "") -> URL {
        var url = Defaults.URL.watched.appending(queryItems: [.next: lastID])
        if !keyword.isEmpty {
            url.append(queryItems: [.fSearch: keyword])
        }
        return url.applyingFilter(filter)
    }

    static func favoritesList(
        favIndex: Int,
        keyword: String = "",
        sortOrder: FavoritesSortOrder? = nil
    ) -> URL {
        var url = Defaults.URL.favorites
        if favIndex != -1 {
            url.append(queryItems: [.favcat: String(favIndex)])
        } else {
            url.append(queryItems: [.favcat: .all])
        }
        if !keyword.isEmpty {
            url.append(queryItems: [.fSearch: keyword])
            url.append(queryItems: [.sn: .filterOn, .st: .filterOn, .sf: .filterOn])
        }
        if let sortOrder = sortOrder {
            url.append(queryItems: [
                .inlineSet: sortOrder == .favoritedTime
                ? .sortOrderByFavoritedTime : .sortOrderByUpdateTime
            ])
        }
        return url
    }

    static func moreFavoritesList(
        favIndex: Int,
        lastID: String,
        lastTimestamp: String,
        keyword: String = ""
    ) -> URL {
        var url = Defaults.URL.favorites.appending(queryItems: [.next: [lastID, lastTimestamp].joined(separator: "-")])
        if favIndex != -1 {
            url.append(queryItems: [.favcat: String(favIndex)])
        } else {
            url.append(queryItems: [.favcat: .all])
        }
        if !keyword.isEmpty {
            url.append(queryItems: [.fSearch: keyword])
            url.append(queryItems: [.sn: .filterOn, .st: .filterOn, .sf: .filterOn])
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

    static func galleryDetail(url: URL) -> URL {
        url.appending(queryItems: [.showComments: .one])
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
    static func detailPage(url: URL, pageNum: Int) -> URL {
        url.appending(queryItems: [.letterP: String(pageNum)])
    }

    static func normalPreviewURL(plainURL: URL, width: String, height: String, offset: String) -> URL {
        plainURL.appending(queryItems: [.ehpandaWidth: width, .ehpandaHeight: height, .ehpandaOffset: offset])
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
        var queryItems1 = [Defaults.URL.Component.Key: String]()
        var queryItems2 = [Defaults.URL.Component.Key: Defaults.URL.Component.Value]()

        var categoryValue = 0
        categoryValue += filter.doujinshi ? Category.doujinshi.filterValue : 0
        categoryValue += filter.manga ? Category.manga.filterValue : 0
        categoryValue += filter.artistCG ? Category.artistCG.filterValue : 0
        categoryValue += filter.gameCG ? Category.gameCG.filterValue : 0
        categoryValue += filter.western ? Category.western.filterValue : 0
        categoryValue += filter.nonH ? Category.nonH.filterValue : 0
        categoryValue += filter.imageSet ? Category.imageSet.filterValue : 0
        categoryValue += filter.cosplay ? Category.cosplay.filterValue : 0
        categoryValue += filter.asianPorn ? Category.asianPorn.filterValue : 0
        categoryValue += filter.misc ? Category.misc.filterValue : 0

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
