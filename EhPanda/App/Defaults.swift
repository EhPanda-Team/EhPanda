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
                return max(windowW - 500, 300)
            } else {
                return max(windowW - 90, 250)
            }
        }
    }
    struct ImageSize {
        static let rowScale: CGFloat = 8/11
        static let avatarScale: CGFloat = 1/1
        static let headerScale: CGFloat = 8/11
        static let previewScale: CGFloat = 8/11
        static let contentScale: CGFloat = 7/10

        static let rowW: CGFloat = rowH * rowScale
        static let rowH: CGFloat = 110
        static let avatarW: CGFloat = 100
        static let avatarH: CGFloat = 100
        static let headerW: CGFloat = headerH * headerScale
        static let headerH: CGFloat = isSEWidth ? 110 : 150
        static let previewMinW: CGFloat = isPadWidth ? 180 : 100
        static let previewMaxW: CGFloat = isPadWidth ? 220 : 120
        static let previewAvgW: CGFloat = (previewMinW + previewMaxW) / 2
    }
    struct Cookie {
        static let null = "null"
        static let expired = "expired"
        static let mystery = "mystery"
        static let selectedProfile = "sp"

        static let igneous = "igneous"
        static let ipbMemberId = "ipb_member_id"
        static let ipbPassHash = "ipb_pass_hash"
    }
    struct DateFormat {
        static let publish = "yyyy-MM-dd HH:mm"
        static let torrent = "yyyy-MM-dd HH:mm"
        static let comment = "dd MMMM yyyy, HH:mm"
        static let github = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    }
    struct FilePath {
        static let logs = "logs"
        static let ehpandaLog = "EhPanda.log"
    }
    struct PreviewIdentifier {
        static let width = "?ehpandaWidth="
        static let height = "&ehpandaHeight="
        static let offset = "&ehpandaOffset="
    }
    struct Response {
        static let hathClientNotFound = "You must have a H@H client assigned to your account to use this feature."
        static let hathClientNotOnline = "Your H@H client appears to be offline. Turn it on, then try again."
        static let invalidResolution = "The requested gallery cannot be downloaded with the selected resolution."
    }
    struct ParsingMark {
        static let hexStart = "hexStart<"
        static let hexEnd = ">hexEnd"
    }
    struct URL {
        // Domains
        static var host: String {
            galleryHost == .exhentai ? exhentai : ehentai
        }
        static let ehentai = "https://e-hentai.org/"
        static let exhentai = "https://exhentai.org/"
        static let forum = "https://forums.e-hentai.org/index.php"
        static let login = merge(urls: [forum, "act=Login", "CODE=01"])
        static let webLogin = merge(urls: [forum, "act=Login"])
        static let magnet = "magnet:?xt=urn:btih:"

        // Functional Pages
        static let tag = "tag/"
        static let popular = "popular"
        static let watched = "watched"
        static let mytags = "mytags"
        static let api = "api.php"
        static let news = "news.php"
        static let uconfig = "uconfig.php"
        static let favorites = "favorites.php"
        static let toplist = "toplist.php"
        static let gallerypopups = "gallerypopups.php"
        static let gallerytorrents = "gallerytorrents.php"

        static let token = "t="
        static let gid = "gid="
        static let page1 = "p="
        static let page2 = "page="
        static let from = "from="
        static let favcat = "favcat="
        static let topcat = "tl="
        static let showuser = "showuser="
        static let fSearch = "f_search="

        static let showComments = "hc=1"
        static let loginAct = "act=Login"
        static let addfavAct = "act=addfav"
        static let ignoreOffensive = "nw=always"
        static let listCompact = "inline_set=dm_l"
        static let previewNormal = "inline_set=ts_m"
        static let previewLarge = "inline_set=ts_l"
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

        // GitHub
        static let github = "https://github.com/"
        static let githubAPI = "https://api.github.com/repos/"
        static let pathToLatest = "/releases/latest"
        static let pathToDownload = pathToLatest + "/download/"
        static let ehTagTrasnlationRepo = "EhTagTranslation/Database"
        static let ehTagTranslationJpnRepo = "tatsuz0u/EhTagTranslation_Database_JPN"
    }
}

// MARK: Request
extension Defaults.URL {
    // Fetch
    static func searchList(keyword: String, filter: Filter) -> String {
        merge(urls: [
            host, fSearch
            + keyword.urlEncoded()
        ]
        + applyFilters(filter: filter)
        )
    }
    static func moreSearchList(
        keyword: String,
        filter: Filter,
        pageNum: String,
        lastID: String
    ) -> String {
        merge(
            urls: [
                host,
                fSearch + keyword.urlEncoded(),
                page2 + pageNum,
                from + lastID
            ]
            + applyFilters(filter: filter)
        )
    }
    static func frontpageList() -> String {
        host
    }
    static func moreFrontpageList(pageNum: String, lastID: String) -> String {
        merge(urls: [host, page2 + pageNum, from + lastID])
    }
    static func popularList() -> String {
        host + popular
    }
    static func watchedList() -> String {
        host + watched
    }
    static func moreWatchedList(pageNum: String, lastID: String) -> String {
        merge(urls: [host + watched, page2 + pageNum, from + lastID])
    }
    static func favoritesList(favIndex: Int) -> String {
        if favIndex == -1 {
            return host + favorites
        } else {
            return merge(urls: [host + favorites, favcat + "\(favIndex)"])
        }
    }
    static func moreFavoritesList(favIndex: Int, pageNum: String, lastID: String) -> String {
        if favIndex == -1 {
            return merge(urls: [host + favorites, page2 + pageNum, from + lastID])
        } else {
            return merge(urls: [host + favorites, favcat + "\(favIndex)", page2 + pageNum, from + lastID])
        }
    }
    static func toplistsList(catIndex: Int) -> String {
        merge(urls: [ehentai + toplist, topcat + "\(catIndex)"])
    }
    static func moreToplistsList(catIndex: Int, pageNum: String) -> String {
        merge(urls: [ehentai + toplist, topcat + "\(catIndex)", page1 + pageNum])
    }
    static func galleryDetail(url: String) -> String {
        merge(urls: [url, showComments])
    }
    static func galleryTorrents(gid: String, token: String) -> String {
        merge(urls: [host + gallerytorrents, Defaults.URL.gid + gid, Defaults.URL.token + token])
    }

    // Account Associated Operations
    static func addFavorite(gid: String, token: String) -> String {
        merge(urls: [host + gallerypopups, Defaults.URL.gid + gid, Defaults.URL.token + token, addfavAct])
    }
    static func userInfo(uid: String) -> String {
        merge(urls: [forum, showuser + uid])
    }
    static func greeting() -> String {
        ehentai + news
    }

    // Misc
    static func detailPage(url: String, pageNum: Int) -> String {
        merge(urls: [url, page1 + "\(pageNum)"])
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
    static func normalPreview(
        plainURL: Substring, width: Substring,
        height: Substring, offset: Substring
    ) -> String {
        plainURL
            + Defaults.PreviewIdentifier.width + width
            + Defaults.PreviewIdentifier.height + height
            + Defaults.PreviewIdentifier.offset + offset
    }
}

// MARK: Filter
private extension Defaults.URL {
    static func applyFilters(filter: Filter) -> [String] {
        var filters = [String]()

        var category = 0
        category += filter.doujinshi ? Category.doujinshi.value : 0
        category += filter.manga ? Category.manga.value : 0
        category += filter.artistCG ? Category.artistCG.value : 0
        category += filter.gameCG ? Category.gameCG.value : 0
        category += filter.western ? Category.western.value : 0
        category += filter.nonH ? Category.nonH.value : 0
        category += filter.imageSet ? Category.imageSet.value : 0
        category += filter.cosplay ? Category.cosplay.value : 0
        category += filter.asianPorn ? Category.asianPorn.value : 0
        category += filter.misc ? Category.misc.value : 0

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

// MARK: GitHub
extension Defaults.URL {
    static func githubAPI(repoName: String) -> String {
        githubAPI + repoName + pathToLatest
    }
    static func githubDownload(repoName: String, fileName: String) -> String {
        github + repoName + pathToDownload + fileName
    }
}

// MARK: Tools
private extension Defaults.URL {
    static func merge(urls: [String]) -> String {
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
}
