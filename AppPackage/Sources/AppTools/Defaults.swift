import CoreGraphics
import Foundation

public struct Defaults: Sendable {
    public struct App: Sendable {
        public static let identifier = "app.ehpanda"
    }
    public struct ImageSize: Sendable {
        public static let rowAspect: CGFloat = 8/11
        public static let headerAspect: CGFloat = 8/11
        public static let previewAspect: CGFloat = 8/11
        public static let contentAspect: CGFloat = 7/10
        public static let webtoonMinAspect: CGFloat = 1/4
        public static let webtoonIdealAspect: CGFloat = 2/3

        public static let rowW: CGFloat = rowH * rowAspect
        public static let rowH: CGFloat = 120
        public static let headerW: CGFloat = headerH * headerAspect
        public static let headerH: CGFloat = 150
    }
    public struct Cookie: Sendable {
        public static let yay = "yay"
        public static let null = "null"
        public static let expired = "expired"
        public static let mystery = "mystery"
        public static let ignoreOffensive = "nw"
        public static let selectedProfile = "sp"
        public static let skipServer = "skipserver"

        public static let igneous = "igneous"
        public static let ipbMemberId = "ipb_member_id"
        public static let ipbPassHash = "ipb_pass_hash"
    }
    public struct DateFormat: Sendable {
        public static let greeting = "dd MMMM yyyy"
        public static let publish = "yyyy-MM-dd HH:mm"
        public static let torrent = "yyyy-MM-dd HH:mm"
        public static let comment = "dd MMMM yyyy, HH:mm"
        public static let github = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    }
    public struct FilePath: Sendable {
        public static let logs = "logs"
        public static let ehpandaLog = "EhPanda.log"
        public static let downloads = "Downloads"
        public static let downloadPages = "pages"
        public static let downloadManifest = "manifest.json"
        public static let automationDownloadFolder = "Automation"
        public static let defaultDownloadFolder = "Default"
    }
    public struct Regex: Sendable {
        public static let tagSuggestion: NSRegularExpression? = try? .init(
            pattern: "(\\S+:\".+?\"|\".+?\"|\\S+:\\S+|\\S+)"
        )
    }
    public struct URL: Sendable {
        public static let ehentai: Foundation.URL = .init(string: "https://e-hentai.org/").forceUnwrapped
        public static let exhentai: Foundation.URL = .init(string: "https://exhentai.org/").forceUnwrapped
        public static let sexhentai: Foundation.URL = .init(string: "https://s.exhentai.org/").forceUnwrapped

        public static let torrentDownload: Foundation.URL = .init(string: "https://ehgt.org/g/t.png").forceUnwrapped
        public static let torrentDownloadInvalid: Foundation.URL = .init(
            string: "https://ehgt.org/g/td.png"
        ).forceUnwrapped

        public static let forum: Foundation.URL = .init(string: "https://forums.e-hentai.org/index.php").forceUnwrapped
        public static let login = forum.appending(queryItems: [.act: .loginAct, .code: .zeroOne])
        public static let webLogin = forum.appending(queryItems: [.act: .loginAct])

        public static let news = ehentai.appendingPathComponent("news.php")

        public static let toplist = ehentai.appendingPathComponent("toplist.php")

        // GitHub
        public static let github: Foundation.URL = .init(string: "https://github.com/").forceUnwrapped
        public static let githubAPI: Foundation.URL = .init(string: "https://api.github.com/repos/").forceUnwrapped

        // swiftlint:disable nesting identifier_name
        public enum Component: Sendable {
            public enum Key: String, Sendable {
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
            public enum Value: String, Sendable {
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
