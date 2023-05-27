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
        static let archiveGridWidth: CGFloat =
        DeviceUtil.isPadWidth ? 175 : DeviceUtil.isSEWidth ? 125 : 150
        static var cardCellWidth: CGFloat { DeviceUtil.windowW * 0.8 }
        static let cardCellHeight: CGFloat = Defaults.ImageSize.headerH + 20 * 2
        static var cardCellSize: CGSize {
            .init(width: cardCellWidth, height: cardCellHeight)
        }
        static var rankingCellWidth: CGFloat {
            (DeviceUtil.isPadWidth ? 0.4 : 0.7) * DeviceUtil.windowW
        }
        static var alertWidthFactor: Double {
            DeviceUtil.isPadWidth ? 0.5 : 1.0
        }
    }
    struct ImageSize {
        static let rowAspect: CGFloat = 8/11
        static let headerAspect: CGFloat = 8/11
        static let previewAspect: CGFloat = 8/11
        static let contentAspect: CGFloat = 7/10
        static let webtoonMinAspect: CGFloat = 1/4
        static let webtoonIdealAspect: CGFloat = 2/3

        static let rowW: CGFloat = rowH * rowAspect
        static let rowH: CGFloat = 120
        static let headerW: CGFloat = headerH * headerAspect
        static let headerH: CGFloat = 150
        static let previewMinW: CGFloat = DeviceUtil.isPadWidth ? 180 : 100
        static let previewMaxW: CGFloat = DeviceUtil.isPadWidth ? 220 : 120
        static let previewAvgW: CGFloat = (previewMinW + previewMaxW) / 2
    }
    struct Cookie {
        static let yay = "yay"
        static let null = "null"
        static let expired = "expired"
        static let mystery = "mystery"
        static let ignoreOffensive = "nw"
        static let selectedProfile = "sp"
        static let skipServer = "skipserver"

        static let igneous = "igneous"
        static let ipbMemberId = "ipb_member_id"
        static let ipbPassHash = "ipb_pass_hash"
    }
    struct DateFormat {
        static let greeting = "dd MMMM yyyy"
        static let publish = "yyyy-MM-dd HH:mm"
        static let torrent = "yyyy-MM-dd HH:mm"
        static let comment = "dd MMMM yyyy, HH:mm"
        static let github = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    }
    struct FilePath {
        static let logs = "logs"
        static let ehpandaLog = "EhPanda.log"
    }
    struct Regex {
        static let tagSuggestion: NSRegularExpression? = try? .init(pattern: "(\\S+:\".+?\"|\".+?\"|\\S+:\\S+|\\S+)")
    }
    struct URL {
        static var host: Foundation.URL { AppUtil.galleryHost == .exhentai ? exhentai : ehentai }
        static let ehentai: Foundation.URL = .init(string: "https://e-hentai.org/").forceUnwrapped
        static let exhentai: Foundation.URL = .init(string: "https://exhentai.org/").forceUnwrapped
        static let sexhentai: Foundation.URL = .init(string: "https://s.exhentai.org/").forceUnwrapped

        static let torrentDownload: Foundation.URL = .init(string: "https://ehgt.org/g/t.png").forceUnwrapped
        static let torrentDownloadInvalid: Foundation.URL = .init(string: "https://ehgt.org/g/td.png").forceUnwrapped

        static let forum: Foundation.URL = .init(string: "https://forums.e-hentai.org/index.php").forceUnwrapped
        static let login = forum.appending(queryItems: [.act: .loginAct, .code: .zeroOne])
        static let webLogin = forum.appending(queryItems: [.act: .loginAct])

        static var api: Foundation.URL { host.appendingPathComponent("api.php") }
        static var myTags: Foundation.URL { host.appendingPathComponent("mytags") }
        static let news = ehentai.appendingPathComponent("news.php")
        static var uConfig: Foundation.URL { host.appendingPathComponent("uconfig.php") }
        static var galleryPopups: Foundation.URL { host.appendingPathComponent("gallerypopups.php") }
        static var galleryTorrents: Foundation.URL { host.appendingPathComponent("gallerytorrents.php") }

        static var popular: Foundation.URL { host.appendingPathComponent("popular") }
        static var watched: Foundation.URL { host.appendingPathComponent("watched") }
        static let toplist = ehentai.appendingPathComponent("toplist.php")
        static var favorites: Foundation.URL { host.appendingPathComponent("favorites.php") }

        // GitHub
        static let github: Foundation.URL = .init(string: "https://github.com/").forceUnwrapped
        static let githubAPI: Foundation.URL = .init(string: "https://api.github.com/repos/").forceUnwrapped

        // swiftlint:disable nesting identifier_name
        enum Component {
            enum Key: String {
                // Functional Pages
                case token = "t"
                case gid = "gid"
                case letterP = "p"
                case page = "page"
                case from = "from"
                case next = "next"
                case favcat = "favcat"
                case topcat = "tl"
                case showUser = "showuser"
                case fSearch = "f_search"

                case code = "CODE"
                case act = "act"
                case showComments = "hc"
                case inlineSet = "inline_set"
                case skipServerIdentifier = "nl"

                // Search favorites
                case sn = "sn"
                case st = "st"
                case sf = "sf"

                // Filter
                case fCats = "f_cats"
                case advSearch = "advsearch"
                case fSname = "f_sname"
                case fStags = "f_stags"
                case fSdesc = "f_sdesc"
                case fStorr = "f_storr"
                case fSto = "f_sto"
                case fSdt1 = "f_sdt1"
                case fSdt2 = "f_sdt2"
                case fSh = "f_sh"
                case fSr = "f_sr"
                case fSrdd = "f_srdd"
                case fSp = "f_sp"
                case fSpf = "f_spf"
                case fSpt = "f_spt"
                case fSfl = "f_sfl"
                case fSfu = "f_sfu"
                case fSft = "f_sft"

                // Custom
                case ehpandaWidth = "ehpandaWidth"
                case ehpandaHeight = "ehpandaHeight"
                case ehpandaOffset = "ehpandaOffset"
            }
            enum Value: String {
                case one = "1"
                case all = "all"
                case zeroOne = "01"
                case filterOn = "on"
                case loginAct = "Login"
                case addFavAct = "addfav"
                case sortOrderByUpdateTime = "fs_p"
                case sortOrderByFavoritedTime = "fs_f"
            }
        }
        // swiftlint:enable nesting identifier_name
    }
}
