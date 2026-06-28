import Foundation
import AppModels

public struct URLUtil {
    // Fetch
    public static func searchList(keyword: String, filter: Filter) -> URL {
        Defaults.URL.host.appending(queryItems: [.fSearch: keyword]).applyingFilter(filter)
    }

    public static func moreSearchList(keyword: String, filter: Filter, lastID: String) -> URL {
        Defaults.URL.host.appending(queryItems: [.fSearch: keyword, .next: lastID]).applyingFilter(filter)
    }

    public static func frontpageList(filter: Filter) -> URL {
        Defaults.URL.host.applyingFilter(filter)
    }

    public static func moreFrontpageList(filter: Filter, lastID: String) -> URL {
        Defaults.URL.host.appending(queryItems: [.next: lastID]).applyingFilter(filter)
    }

    public static func popularList(filter: Filter) -> URL {
        Defaults.URL.popular.applyingFilter(filter)
    }

    public static func watchedList(filter: Filter, keyword: String = "") -> URL {
        var url = Defaults.URL.watched
        if !keyword.isEmpty {
            url.append(queryItems: [.fSearch: keyword])
        }
        return url.applyingFilter(filter)
    }

    public static func moreWatchedList(filter: Filter, lastID: String, keyword: String = "") -> URL {
        var url = Defaults.URL.watched.appending(queryItems: [.next: lastID])
        if !keyword.isEmpty {
            url.append(queryItems: [.fSearch: keyword])
        }
        return url.applyingFilter(filter)
    }

    public static func favoritesList(
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

    public static func moreFavoritesList(
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

    public static func toplistsList(catIndex: Int, pageNum: Int? = nil) -> URL {
        var url = Defaults.URL.toplist.appending(queryItems: [.topcat: String(catIndex)])
        if let pageNum = pageNum {
            url.append(queryItems: [.letterP: String(pageNum)])
        }
        return url
    }

    public static func moreToplistsList(catIndex: Int, pageNum: Int) -> URL {
        Defaults.URL.toplist.appending(queryItems: [.topcat: String(catIndex), .letterP: String(pageNum)])
    }

    public static func galleryDetail(url: URL) -> URL {
        url.appending(queryItems: [.showComments: .one])
    }

    public static func galleryTorrents(gid: String, token: String) -> URL {
        Defaults.URL.galleryTorrents.appending(queryItems: [.gid: gid, .token: token])
    }

    // Account Associated Operations
    public static func addFavorite(gid: String, token: String) -> URL {
        Defaults.URL.galleryPopups
            .appending(queryItems: [.gid: gid, .token: token])
            .appending(queryItems: [.act: .addFavAct])
    }

    public static func userInfo(uid: String) -> URL {
        Defaults.URL.forum.appending(queryItems: [.showUser: uid])
    }

    // Misc
    public static func detailPage(url: URL, pageNum: Int) -> URL {
        url.appending(queryItems: [.letterP: String(pageNum)])
    }

    public static func combinedPreviewURL(plainURL: URL, width: String, height: String, offset: String) -> URL {
        plainURL
            .appending(queryItems: [.ehpandaWidth: width])
            .appending(queryItems: [.ehpandaHeight: height])
            .appending(queryItems: [.ehpandaOffset: offset])
    }

    // GitHub
    public static func githubAPI(repoName: String) -> URL {
        Defaults.URL.githubAPI.appendingPathComponent("\(repoName)/releases/latest")
    }

    public static func githubDownload(repoName: String, fileName: String) -> URL {
        Defaults.URL.github.appendingPathComponent("\(repoName)/releases/latest/download/\(fileName)")
    }
}

// MARK: Combining (Filter)
private extension URL {
    func applyingFilter(_ filter: Filter) -> URL {
        var queryItems1 = [Defaults.URL.Component.Key: String]()
        var queryItems2 = [Defaults.URL.Component.Key: Defaults.URL.Component.Value]()

        applyingCategoryFilter(filter, queryItems1: &queryItems1)

        if !filter.advanced { return appending(queryItems: queryItems1).appending(queryItems: queryItems2) }
        queryItems2[.advSearch] = .one

        applyingBasicAdvancedFilter(filter, queryItems2: &queryItems2)
        applyingMinRatingFilter(filter, queryItems1: &queryItems1, queryItems2: &queryItems2)
        applyingPageRangeFilter(filter, queryItems1: &queryItems1, queryItems2: &queryItems2)
        applyingDisableFilter(filter, queryItems2: &queryItems2)

        return appending(queryItems: queryItems1).appending(queryItems: queryItems2)
    }

    func applyingCategoryFilter(
        _ filter: Filter,
        queryItems1: inout [Defaults.URL.Component.Key: String]
    ) {
        var categoryValue = 0
        categoryValue += filter.doujinshi ? AppModels.Category.doujinshi.filterValue : 0
        categoryValue += filter.manga ? AppModels.Category.manga.filterValue : 0
        categoryValue += filter.artistCG ? AppModels.Category.artistCG.filterValue : 0
        categoryValue += filter.gameCG ? AppModels.Category.gameCG.filterValue : 0
        categoryValue += filter.western ? AppModels.Category.western.filterValue : 0
        categoryValue += filter.nonH ? AppModels.Category.nonH.filterValue : 0
        categoryValue += filter.imageSet ? AppModels.Category.imageSet.filterValue : 0
        categoryValue += filter.cosplay ? AppModels.Category.cosplay.filterValue : 0
        categoryValue += filter.asianPorn ? AppModels.Category.asianPorn.filterValue : 0
        categoryValue += filter.misc ? AppModels.Category.misc.filterValue : 0
        if ![0, 1023].contains(categoryValue) {
            queryItems1[.fCats] = String(categoryValue)
        }
    }

    func applyingBasicAdvancedFilter(
        _ filter: Filter,
        queryItems2: inout [Defaults.URL.Component.Key: Defaults.URL.Component.Value]
    ) {
        if filter.galleryName { queryItems2[.fSname] = .filterOn }
        if filter.galleryTags { queryItems2[.fStags] = .filterOn }
        if filter.galleryDesc { queryItems2[.fSdesc] = .filterOn }
        if filter.torrentFilenames { queryItems2[.fStorr] = .filterOn }
        if filter.onlyWithTorrents { queryItems2[.fSto] = .filterOn }
        if filter.lowPowerTags { queryItems2[.fSdt1] = .filterOn }
        if filter.downvotedTags { queryItems2[.fSdt2] = .filterOn }
        if filter.expungedGalleries { queryItems2[.fSh] = .filterOn }
    }

    func applyingMinRatingFilter(
        _ filter: Filter,
        queryItems1: inout [Defaults.URL.Component.Key: String],
        queryItems2: inout [Defaults.URL.Component.Key: Defaults.URL.Component.Value]
    ) {
        if filter.minRatingActivated, [2, 3, 4, 5].contains(filter.minRating) {
            queryItems2[.fSr] = .filterOn
            queryItems1[.fSrdd] = String(filter.minRating)
        }
    }

    func applyingPageRangeFilter(
        _ filter: Filter,
        queryItems1: inout [Defaults.URL.Component.Key: String],
        queryItems2: inout [Defaults.URL.Component.Key: Defaults.URL.Component.Value]
    ) {
        guard filter.pageRangeActivated else { return }
        queryItems2[.fSp] = .filterOn
        let minPages = Int(filter.pageLowerBound)
        let maxPages = Int(filter.pageUpperBound)
        if let minPages, let maxPages {
            guard minPages > 0, maxPages > 0, minPages <= maxPages else { return }
            queryItems1[.fSpf] = String(minPages)
            queryItems1[.fSpt] = String(maxPages)
        } else if let minPages, minPages > 0 {
            queryItems1[.fSpf] = String(minPages)
        } else if let maxPages, maxPages > 0 {
            queryItems1[.fSpt] = String(maxPages)
        }
    }

    func applyingDisableFilter(
        _ filter: Filter,
        queryItems2: inout [Defaults.URL.Component.Key: Defaults.URL.Component.Value]
    ) {
        if filter.disableLanguage { queryItems2[.fSfl] = .filterOn }
        if filter.disableUploader { queryItems2[.fSfu] = .filterOn }
        if filter.disableTags { queryItems2[.fSft] = .filterOn }
    }
}
