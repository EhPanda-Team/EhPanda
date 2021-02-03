//
//  Defaults.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import UIKit
import Foundation

class Defaults {
    class FrameSize {
        static var slideMenuWidth: CGFloat {
            if isPad {
                return max(screenW - (isLandscape ? 800 : 500), 300) 
            } else {
                return screenW - 90
            }
            
        }
    }
    class ImageSize {
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
    class Cookie {
        static var null = "null"
        static var expired = "expired"
        static var mystery = "mystery"
        
        static var igneous = "igneous"
        static var ipb_member_id = "ipb_member_id"
        static var ipb_pass_hash = "ipb_pass_hash"
    }
    class URL {
        // いわゆるホストドメイン
        static var host: String {
            if exx {
                return galleryType == .eh ? ehentai : exhentai
            } else {
                return merge([ehentai, listCompact, nonh, f_search + "parody:durarara$"])
            }
        }
        static let ehentai = "https://e-hentai.org/"
        static let exhentai = "https://exhentai.org/"
        static let forum = "https://forums.e-hentai.org/"
        static let login = merge([forum + index, login_act])
        static let magnet = "magnet:?xt=urn:btih:"
        
        // 各機能ページ
        static let tag = "tag/"
        static let watched = "watched"
        static let uploads = "uploads/"
        static let api = "api.php"
        static let popular = "popular"
        static let index = "index.php"
        static let favorites = "favorites.php"
        static let gallerypopups = "gallerypopups.php"
        static let gallerytorrents = "gallerytorrents.php"
        
        static let p = "p="
        static let t = "t="
        static let gid = "gid="
        static let page = "page="
        static let from = "from="
        static let showuser = "showuser="
        static let f_search = "f_search="
        
        static let nonh = "f_cats=767"
        static let showComments = "hc=1"
        static let login_act = "act=Login"
        static let addfav_act = "act=addfav"
        static let ignoreOffensive = "nw=always"
        static let listCompact = "inline_set=dm_l"
        static let detailLarge = "inline_set=ts_l"
        
        // フィルター
        static let f_cats = "f_cats="
        static let advSearch = "advsearch=1"
        static let f_sname_on = "f_sname=on"
        static let f_stags_on = "f_stags=on"
        static let f_sdesc_on = "f_sdesc=on"
        static let f_storr_on = "f_storr=on"
        static let f_sto_on = "f_sto=on"
        static let f_sdt1_on = "f_sdt1=on"
        static let f_sdt2_on = "f_sdt2=on"
        static let f_sh_on = "f_sh=on"
        static let f_sr_on = "f_sr=on"
        static let f_srdd = "f_srdd="
        static let f_sp_on = "f_sp=on"
        static let f_spf = "f_spf="
        static let f_spt = "f_spt="
        static let f_sfl_on = "f_sfl=on"
        static let f_sfu_on = "f_sfu=on"
        static let f_sft_on = "f_sft=on"
    }
}

// MARK: リクエスト
extension Defaults.URL {
    static func searchList(keyword: String, filter: Filter) -> String {
        merge([
            host,
            listCompact,
            f_search + keyword.URLString()
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
        merge([
                host,
                listCompact,
                f_search + keyword.URLString(),
                page + pageNum,
                from + lastID
        ]
        + applyFilters(filter)
        )
    }
    static func frontpageList() -> String {
        if exx {
            return merge([host, listCompact])
        } else {
            return merge([ehentai, listCompact, nonh, f_search + "parody:durarara$"])
        }
    }
    static func moreFrontpageList(pageNum: String, lastID: String) -> String {
        merge([host, listCompact, page + pageNum, from + lastID])
    }
    static func popularList() -> String {
        if exx {
            return merge([host + popular, listCompact])
        } else {
            return merge([ehentai, listCompact, nonh, f_search + "parody:gintama$"])
        }
    }
    static func watchedList() -> String {
        merge([host + watched, listCompact])
    }
    static func moreWatchedList(pageNum: String, lastID: String) -> String {
        merge([host + watched, page + pageNum, from + lastID])
    }
    static func favoritesList() -> String {
        merge([host + favorites, listCompact])
    }
    static func moreFavoritesList(pageNum: String, lastID: String) -> String {
        merge([host + favorites, page + pageNum, from + lastID])
    }
    
    static func mangaDetail(url: String) -> String {
        merge([url, ignoreOffensive, showComments, detailLarge])
    }
    static func mangaTorrents(id: String, token: String) -> String {
        merge([host + gallerytorrents, gid + id, t + token])
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
        merge([host, listCompact, f_search + keyword.URLString()])
    }
    static func moreAssociatedItemsRedir(keyword: AssociatedKeyword, lastID: String, pageNum: String) -> String {
        if let title = keyword.title {
            return moreSimilarGallery(keyword: title, pageNum: pageNum, lastID: lastID)
        } else {
            return moreAssociatedItems(keyword: (keyword.category ?? "", keyword.content ?? ""), pageNum: pageNum, lastID: lastID)
        }
    }
    static func moreAssociatedItems(keyword: (String, String), pageNum: String, lastID: String) -> String {
        merge(keyword: keyword, pageNum: pageNum, lastID: lastID)
    }
    static func moreSimilarGallery(keyword: String, pageNum: String, lastID: String) -> String {
        merge([
                host,
                listCompact,
                f_search + keyword.URLString(),
                page + pageNum,
                from + lastID
        ])
    }
    
    static func contentPage(url: String, page: Int) -> String {
        merge([url, p + "\(page)"])
    }
    
    static func addFavorite(id: String, token: String) -> String {
        merge([host + gallerypopups, gid + id, t + token, addfav_act])
    }
    
    static func userID() -> String {
        forum + index
    }
    static func userInfo(uid: String) -> String {
        merge([forum + index, showuser + uid])
    }
    
    static func magnet(hash: String) -> String {
        magnet + hash
    }
}

// MARK: フィルター
extension Defaults.URL {
    static func applyFilters(_ filter: Filter) -> [String] {
        var filters = [String]()
        
        var category = 0
        category += filter.doujinshi.isFiltered ? Category.Doujinshi.value : 0
        category += filter.manga.isFiltered ? Category.Manga.value : 0
        category += filter.artist_CG.isFiltered ? Category.Artist_CG.value : 0
        category += filter.game_CG.isFiltered ? Category.Game_CG.value : 0
        category += filter.western.isFiltered ? Category.Western.value : 0
        category += filter.non_h.isFiltered ? Category.Non_H.value : 0
        category += filter.image_set.isFiltered ? Category.Image_Set.value : 0
        category += filter.cosplay.isFiltered ? Category.Cosplay.value : 0
        category += filter.asian_porn.isFiltered ? Category.Asian_Porn.value : 0
        category += filter.misc.isFiltered ? Category.Misc.value : 0
        
        if ![0, 1023].contains(category) {
            filters.append(f_cats + "\(category)")
        }
        
        if !filter.advanced { return filters }
        filters.append(advSearch)
        
        if filter.galleryName { filters.append(f_sname_on) }
        if filter.galleryTags { filters.append(f_stags_on) }
        if filter.galleryDesc { filters.append(f_sdesc_on) }
        if filter.torrentFilenames { filters.append(f_storr_on) }
        if filter.onlyWithTorrents { filters.append(f_sto_on) }
        if filter.lowPowerTags { filters.append(f_sdt1_on) }
        if filter.downvotedTags { filters.append(f_sdt2_on) }
        if filter.expungedGalleries { filters.append(f_sh_on) }
        
        if filter.minRatingActivated,
           [2, 3, 4, 5].contains(filter.minRating)
        {
            filters.append(f_sr_on)
            filters.append(f_srdd + "\(filter.minRating)")
        }
        
        if filter.pageRangeActivated,
           let minPages = Int(filter.pageLowerBound),
           let maxPages = Int(filter.pageUpperBound),
           minPages > 0 && maxPages > 0 && minPages <= maxPages
        {
            filters.append(f_sp_on)
            filters.append(f_spf + "\(minPages)")
            filters.append(f_spt + "\(maxPages)")
        }
        
        if filter.disableLanguage { filters.append(f_sfl_on) }
        if filter.disableUploader { filters.append(f_sfu_on) }
        if filter.disableTags { filters.append(f_sft_on) }
        
        return filters
    }
}

// MARK: ツール
extension Defaults.URL {
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
