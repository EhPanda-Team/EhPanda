//
//  Defaults.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import UIKit
import Foundation

struct Defaults {
    struct FrameSize {
        static var slideMenuWidth: CGFloat {
            if isPadWidth {
                return max((windowW ?? screenW) - 500, 300)
            } else {
                return max((windowW ?? screenW) - 90, 250)
            }
        }
    }
    struct ImageSize {
        static var rowScale: CGFloat = 8/11
        static var avatarScale: CGFloat = 1/1
        static var headerScale: CGFloat = 8/11
        static var previewScale: CGFloat = 32/45

        static var rowW: CGFloat = rowH * rowScale
        static var rowH: CGFloat = 110
        static var avatarW: CGFloat = 100
        static var avatarH: CGFloat = 100
        static var headerW: CGFloat = headerH * headerScale
        static var headerH: CGFloat = 150
        static var previewW: CGFloat = previewH * previewScale
        static var previewH: CGFloat = 200
    }
    struct Cookie {
        static var null = "null"
        static var expired = "expired"
        static var mystery = "mystery"

        static var igneous = "igneous"
        static var ipbMemberId = "ipb_member_id"
        static var ipbPassHash = "ipb_pass_hash"
    }
    struct Response {
        static var hathClientNotFound = "You must have a H@H client assigned to your account to use this feature."
        static var hathClientNotOnline = "Your H@H client appears to be offline. Turn it on, then try again."
        static var invalidResolution = "The requested gallery cannot be downloaded with the selected resolution."
    }
    struct URL {
        // Domains
        static var host: String {
            if isTokenMatched {
                return galleryType == .ehentai ? ehentai : exhentai
            } else {
                return durarara
            }
        }
        static let ehentai = "https://e-hentai.org/"
        static let exhentai = "https://exhentai.org/"
        static let forum = "https://forums.e-hentai.org/"
        static let login = merge([forum + index, loginAct])
        static let magnet = "magnet:?xt=urn:btih:"
        static let durarara = merge([ehentai, listCompact, nonh, fSearch + "parody:durarara$"])

        // Functional Pages
        static let tag = "tag/"
        static let popular = "popular"
        static let watched = "watched"
        static let mytags = "mytags"
        static let api = "api.php"
        static let index = "index.php"
        static let uconfig = "uconfig.php"
        static let favorites = "favorites.php"
        static let gallerypopups = "gallerypopups.php"
        static let gallerytorrents = "gallerytorrents.php"

        static let contentPage = "p="
        static let token = "t="
        static let gid = "gid="
        static let page = "page="
        static let from = "from="
        static let favcat = "favcat="
        static let showuser = "showuser="
        static let fSearch = "f_search="

        static let nonh = "f_cats=767"
        static let showComments = "hc=1"
        static let loginAct = "act=Login"
        static let addfavAct = "act=addfav"
        static let ignoreOffensive = "nw=always"
        static let listCompact = "inline_set=dm_l"
        static let detailLarge = "inline_set=ts_l"
        static let rowsLimit = "inline_set=tr_4"

        // Filter
        static let fCats = "f_cats="
        static let advSearch = "advsearch=1"
        static let fSnameOn = "f_sname=on"
        static let fStagsOn = "f_stags=on"
        static let fSdescOn = "f_sdesc=on"
        static let fStorrOn = "f_storr=on"
        static let fStoOn = "f_sto=on"
        static let fSdt1On = "f_sdt1=on"
        static let fSdt2On = "f_sdt2=on"
        static let fShOn = "f_sh=on"
        static let fSrOn = "f_sr=on"
        static let fSrdd = "f_srdd="
        static let fSpOn = "f_sp=on"
        static let fSpf = "f_spf="
        static let fSpt = "f_spt="
        static let fSflOn = "f_sfl=on"
        static let fSfuOn = "f_sfu=on"
        static let fSftOn = "f_sft=on"
    }
}

// MARK: Request
extension Defaults.URL {
    // Fetch
    static func searchList(keyword: String, filter: Filter) -> String {
        merge([
            host,
            listCompact,
            fSearch + keyword.URLString()
        ]
        + applyFilters(filter)
        )
    }
    static func moreSearchList(
        keyword: String,
        filter: Filter,
        pageNum: String,
        lastID: String
    ) -> String {
        merge(
            [
                host,
                listCompact,
                fSearch + keyword.URLString(),
                page + pageNum,
                from + lastID
            ]
            + applyFilters(filter)
        )
    }
    static func frontpageList() -> String {
        if isTokenMatched {
            return merge([host, listCompact])
        } else {
            return durarara
        }
    }
    static func moreFrontpageList(pageNum: String, lastID: String) -> String {
        merge([host, listCompact, page + pageNum, from + lastID])
    }
    static func popularList() -> String {
        if isTokenMatched {
            return merge([host + popular, listCompact])
        } else {
            return merge([ehentai, listCompact, nonh, fSearch + "parody:gintama$"])
        }
    }
    static func watchedList() -> String {
        merge([host + watched, listCompact])
    }
    static func moreWatchedList(pageNum: String, lastID: String) -> String {
        merge([host + watched, page + pageNum, from + lastID])
    }
    static func favoritesList(favIndex: Int) -> String {
        if favIndex == -1 {
            return merge([host + favorites, listCompact])
        } else {
            return merge([host + favorites, favcat + "\(favIndex)", listCompact])
        }
    }
    static func moreFavoritesList(favIndex: Int, pageNum: String, lastID: String) -> String {
        if favIndex == -1 {
            return merge([host + favorites, page + pageNum, from + lastID])
        } else {
            return merge([host + favorites, favcat + "\(favIndex)", page + pageNum, from + lastID])
        }
    }
    static func mangaDetail(url: String) -> String {
        merge([url, ignoreOffensive, showComments, detailLarge])
    }
    static func mangaTorrents(gid: String, token: String) -> String {
        merge([host + gallerytorrents, Defaults.URL.gid + gid, Defaults.URL.token + token])
    }
    static func associatedItemsRedir(keyword: AssociatedKeyword) -> String {
        if let title = keyword.title {
            return similarGallery(keyword: title)
        } else {
            return assciatedItems(keyword: (keyword.category ?? "", keyword.content ?? ""))
        }
    }
    static func assciatedItems(keyword: (String, String)) -> String {
        merge(keyword: keyword, pageNum: nil, lastID: nil)
    }
    static func similarGallery(keyword: String) -> String {
        merge([host, listCompact, fSearch + keyword.URLString()])
    }
    static func moreAssociatedItemsRedir(keyword: AssociatedKeyword, lastID: String, pageNum: String) -> String {
        if let title = keyword.title {
            return moreSimilarGallery(keyword: title, pageNum: pageNum, lastID: lastID)
        } else {
            return moreAssociatedItems(
                keyword: (keyword.category ?? "", keyword.content ?? ""),
                pageNum: pageNum, lastID: lastID
            )
        }
    }
    static func moreAssociatedItems(keyword: (String, String), pageNum: String, lastID: String) -> String {
        merge(keyword: keyword, pageNum: pageNum, lastID: lastID)
    }
    static func moreSimilarGallery(keyword: String, pageNum: String, lastID: String) -> String {
        merge([
                host,
                listCompact,
                fSearch + keyword.URLString(),
                page + pageNum,
                from + lastID
        ])
    }
    static func mangaContents(detailURL: String) -> String {
        merge([detailURL, detailLarge, rowsLimit])
    }

    // Account Associated Operations
    static func addFavorite(gid: String, token: String) -> String {
        merge([host + gallerypopups, Defaults.URL.gid + gid, Defaults.URL.token + token, addfavAct])
    }
    static func userID() -> String {
        forum + index
    }
    static func userInfo(uid: String) -> String {
        merge([forum + index, showuser + uid])
    }

    // Misc
    static func contentPage(url: String, pageNum: Int) -> String {
        merge([url, contentPage + "\(pageNum)"])
    }
    static func magnet(hash: String) -> String {
        magnet + hash
    }
    static func ehAPI() -> String {
        host + api
    }
    static func ehFavorites() -> String {
        host + favorites
    }
    static func ehConfig() -> String {
        host + uconfig
    }
    static func ehMyTags() -> String {
        host + mytags
    }
}

// MARK: Filter
private extension Defaults.URL {
    static func applyFilters(_ filter: Filter) -> [String] {
        var filters = [String]()

        var category = 0
        category += filter.doujinshi.isFiltered ? Category.doujinshi.value : 0
        category += filter.manga.isFiltered ? Category.manga.value : 0
        category += filter.artistCG.isFiltered ? Category.artistCG.value : 0
        category += filter.gameCG.isFiltered ? Category.gameCG.value : 0
        category += filter.western.isFiltered ? Category.western.value : 0
        category += filter.nonH.isFiltered ? Category.nonH.value : 0
        category += filter.imageSet.isFiltered ? Category.imageSet.value : 0
        category += filter.cosplay.isFiltered ? Category.cosplay.value : 0
        category += filter.asianPorn.isFiltered ? Category.asianPorn.value : 0
        category += filter.misc.isFiltered ? Category.misc.value : 0

        if ![0, 1023].contains(category) {
            filters.append(fCats + "\(category)")
        }

        if !filter.advanced { return filters }
        filters.append(advSearch)

        if filter.galleryName { filters.append(fSnameOn) }
        if filter.galleryTags { filters.append(fStagsOn) }
        if filter.galleryDesc { filters.append(fSdescOn) }
        if filter.torrentFilenames { filters.append(fStorrOn) }
        if filter.onlyWithTorrents { filters.append(fStoOn) }
        if filter.lowPowerTags { filters.append(fSdt1On) }
        if filter.downvotedTags { filters.append(fSdt2On) }
        if filter.expungedGalleries { filters.append(fShOn) }

        if filter.minRatingActivated,
           [2, 3, 4, 5].contains(filter.minRating)
        {
            filters.append(fSrOn)
            filters.append(fSrdd + "\(filter.minRating)")
        }

        if filter.pageRangeActivated,
           let minPages = Int(filter.pageLowerBound),
           let maxPages = Int(filter.pageUpperBound),
           minPages > 0 && maxPages > 0 && minPages <= maxPages
        {
            filters.append(fSpOn)
            filters.append(fSpf + "\(minPages)")
            filters.append(fSpt + "\(maxPages)")
        }

        if filter.disableLanguage { filters.append(fSflOn) }
        if filter.disableUploader { filters.append(fSfuOn) }
        if filter.disableTags { filters.append(fSftOn) }

        return filters
    }
}

// MARK: Tools
private extension Defaults.URL {
    static func merge(_ urls: [String]) -> String {
        let firstTwo = urls.prefix(2)
        let remainder = urls.suffix(from: 2)

        var joinedArray = [String]()
        joinedArray.append(firstTwo.joined(separator: "?"))

        if remainder.count > 0 {
            joinedArray.append(remainder.joined(separator: "&"))
        }

        if joinedArray.count > 1 {
            return joinedArray.joined(separator: "&")
        } else {
            return joinedArray.joined()
        }
    }
    static func merge(keyword: (String, String), pageNum: String?, lastID: String?) -> String {
        guard let pageNum = pageNum, let lastID = lastID else {
            return host + tag + "\(keyword.0):\(keyword.1.URLString())"
        }
        return merge([host + tag + "\(keyword.0):\(keyword.1.URLString())/\(pageNum)", from + lastID])
    }
}
