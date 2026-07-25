@testable import AnalyticsClient
import AppModels
import Testing

// Every spelling is pinned case by case rather than derived from `allCases`. These raw values are
// dashboard column values: renaming a case silently renames the column and orphans every signal
// already recorded under the old name, so a rename has to break a test rather than pass one.

struct TabFixture: Sendable {
    let type: TabBarItemType
    let tab: AppTab
}

@Suite
struct AnalyticsVocabularyTests {
    @Test
    func homeSectionSpellsEveryCase() {
        #expect(HomeSection.allCases.count == 5)
        #expect(
            HomeSection.allCases.map(\.rawValue) == ["frontpage", "toplists", "popular", "watched", "history"]
        )
    }

    @Test
    func appTabSpellsEveryCase() {
        #expect(AppTab.allCases.count == 5)
        #expect(AppTab.allCases.map(\.rawValue) == ["home", "favorites", "search", "downloads", "setting"])
    }

    @Test
    func searchSurfaceSpellsEveryCase() {
        #expect(SearchSurface.allCases.count == 7)
        #expect(
            SearchSurface.allCases.map(\.rawValue) == [
                "search", "searchRoot", "frontpage", "popular", "watched", "favorites", "detailSearch"
            ]
        )
    }

    @Test
    func downloadOutcomeSpellsEveryCase() {
        // paused/resumed added by D-20, updated by D-21 — the phase's two approved widenings of
        // this vocabulary. This pin failing on their arrival was it working as intended.
        #expect(DownloadOutcome.allCases.count == 9)
        #expect(
            DownloadOutcome.allCases.map(\.rawValue) == [
                "started", "retried", "completed", "failed", "deleted", "moved",
                "paused", "resumed", "updated"
            ]
        )
    }

    @Test
    func loginFailureKindSpellsEveryCase() {
        #expect(LoginFailureKind.allCases.count == 5)
        #expect(
            LoginFailureKind.allCases.map(\.rawValue) == [
                "rejected", "captchaRequired", "cloudflareChallengeFailed", "networkingFailed", "other"
            ]
        )
    }

    @Test(arguments: [
        TabFixture(type: .home, tab: .home),
        TabFixture(type: .favorites, tab: .favorites),
        TabFixture(type: .search, tab: .search),
        TabFixture(type: .downloads, tab: .downloads),
        TabFixture(type: .setting, tab: .setting)
    ])
    func everyTabBarItemTypeMapsToItsTab(fixture: TabFixture) {
        #expect(AppTab(fixture.type) == fixture.tab)
    }

    // Distinctness is the property that matters beyond the table above: two tabs collapsing onto
    // one spelling would merge two screens' traffic into a single indistinguishable column.
    @Test
    func tabMappingIsInjectiveOverEveryTabBarItemType() {
        let mapped = TabBarItemType.allCases.map(AppTab.init)

        #expect(Set(mapped).count == TabBarItemType.allCases.count)
    }

    // `ReadingDirection` and `ListDisplayMode` are `Int`-raw domain enums. Transmitting their raw
    // values would put a column of bare integers on the dashboard, and inserting a case would
    // silently re-number every later one, changing the meaning of history already collected.
    @Test
    func readingDirectionSpellingsAreDistinctAndNonNumeric() {
        let names = ReadingDirection.allCases.map(\.analyticsName)

        #expect(names == ["vertical", "rightToLeft", "leftToRight"])
        #expect(Set(names).count == names.count)
        #expect(names.allSatisfy({ Int($0) == nil }))
    }

    @Test
    func listDisplayModeSpellingsAreDistinctAndNonNumeric() {
        let names = ListDisplayMode.allCases.map(\.analyticsName)

        #expect(names == ["detail", "thumbnail"])
        #expect(Set(names).count == names.count)
        #expect(names.allSatisfy({ Int($0) == nil }))
    }

    // D-15: the full eleven-case enum ships. D-07's parenthetical named nine, omitting `imageSet`
    // and `private`; the owner recorded that as incomplete recitation rather than narrowing.
    // Pinning the count here is what stops a later reader from re-narrowing on that list's word.
    @Test
    func categorySpellsAllElevenCases() {
        #expect(Category.allCases.count == 11)
        #expect(
            Category.allCases.map(\.analyticsName) == [
                "doujinshi", "manga", "artistCG", "gameCG", "western", "nonH",
                "imageSet", "cosplay", "asianPorn", "misc", "private"
            ]
        )
    }

    // Distinctness is asserted per enum, not across the whole vocabulary: two enums sharing a
    // spelling is correct and expected (`AppTab.search` and `SearchSurface.search` name the same
    // screen from two angles), while a duplicate *within* one enum would make its column
    // ambiguous at the point it is read, long after the signal that filled it was sent.
    @Test
    func everySpellingIsDistinctWithinItsOwnEnum() {
        #expect(Set(HomeSection.allCases.map(\.rawValue)).count == HomeSection.allCases.count)
        #expect(Set(AppTab.allCases.map(\.rawValue)).count == AppTab.allCases.count)
        #expect(Set(SearchSurface.allCases.map(\.rawValue)).count == SearchSurface.allCases.count)
        #expect(Set(DownloadOutcome.allCases.map(\.rawValue)).count == DownloadOutcome.allCases.count)
        #expect(Set(LoginFailureKind.allCases.map(\.rawValue)).count == LoginFailureKind.allCases.count)
    }
}
