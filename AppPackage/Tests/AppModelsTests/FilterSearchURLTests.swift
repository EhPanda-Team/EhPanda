import AppModels
import Foundation
import Testing

@Suite
struct FilterSearchURLTests {
    @Test(arguments: GalleryHost.allCases)
    func advancedFilterSendsOnlyTheSiteFormParameters(host: GalleryHost) throws {
        let filter = Filter(
            doujinshi: true,
            advanced: true,
            onlyWithTorrents: true,
            expungedGalleries: true,
            minRatingActivated: true,
            minRating: 4,
            pageRangeActivated: true,
            pageLowerBound: "10",
            pageUpperBound: "200",
            disableLanguage: true,
            disableUploader: true,
            disableTags: true
        )

        let url = URLUtil.searchList(host: host, keyword: "baseline", filter: filter)

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = try #require(components.queryItems)
        #expect(Set(queryItems.map(\.name)) == [
            "f_search", "f_cats", "advsearch", "f_sto", "f_sh", "f_srdd", "f_spf", "f_spt", "f_sfl", "f_sfu", "f_sft"
        ])
    }
}
