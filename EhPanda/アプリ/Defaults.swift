//
//  Defaults.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

class Defaults {
    class URL {
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
        
        
        static func search(keyword: String) -> String {
            merge([host, listCompact, f_search, keyword.URLString()])
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
        
        static func merge(_ urls: [String]) -> String {
            let firstTwo = urls.prefix(2)
            let remainder = urls.suffix(from: 2)
            
            var joinedArray = [String]()
            joinedArray.append(firstTwo.joined(separator: "?"))
            joinedArray.append(remainder.joined(separator: "&"))
            return joinedArray.joined(separator: "&")
        }
    }
}
