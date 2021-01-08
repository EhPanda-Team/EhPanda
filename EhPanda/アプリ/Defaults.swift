//
//  Defaults.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

class Defaults {
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
        
        // 各機能ページ
        static let api = "api.php"
        static let index = "index.php"
        static let favorites = "favorites.php"
        static let gallerypopups = "gallerypopups.php"
        
        static let p = "p="
        static let t = "t="
        static let gid = "gid="
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
    static func search(keyword: String, filter: Filter) -> String {
        let params: [String]
            = [host, listCompact, f_search + keyword.URLString()]
            + applyFilters(filter)
        ePrint(merge(params))
        return merge(params)
    }
    static func popularList() -> String {
        merge([host, listCompact])
    }
    static func favoritesList() -> String {
        merge([host + favorites, listCompact])
    }
    
    static func mangaDetail(url: String) -> String {
        merge([url, ignoreOffensive, showComments, detailLarge])
    }
    static func contentPage(url: String, page: Int) -> String {
        merge([url, p + "\(page)"])
    }
    
    static func addFavorite(id: String, token: String) -> String {
        merge([host + gallerypopups, gid + id, t + token, addfav_act])
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
        joinedArray.append(remainder.joined(separator: "&"))
        return joinedArray.joined(separator: "&")
    }
}
