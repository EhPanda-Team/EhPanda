import AppModels
import Foundation
import Kanna
import ParserFeature
import Testing
import TestingSupport

/// The Favorites page names its sort order only in the `inline_set=fs_` select's selected option
/// (`p` Published Time, `f` Favorited Time). The "Use Posted" / "Use Favorited" links the parser used to
/// look for are gone from the live pages, so it returned nil on every one of them.
struct FavoritesSortOrderParserTests: TestHelper {
    private static let fixtures: [HTMLFilename] = [
        .favoritesMinimalList, .favoritesMinimalPlusList, .favoritesCompactList,
        .favoritesExtendedList, .favoritesThumbnailList
    ]

    @Test(arguments: fixtures)
    func fixturesSortedByFavoritedTimeReadAsFavoritedTime(_ filename: HTMLFilename) throws {
        let document = try htmlDocument(filename: filename)
        #expect(Parser.parseFavoritesSortOrder(doc: document) == .favoritedTime, "\(filename)")
    }

    @Test(arguments: fixtures)
    func fixturesSortedByPublishedTimeReadAsLastUpdateTime(_ filename: HTMLFilename) throws {
        let html = try htmlString(filename: filename)
        let unselectedPublished = #"<option value="p">Published Time</option>"#
        let selectedPublished = #"<option value="p" selected="selected">Published Time</option>"#
        let selectedFavorited = #"<option value="f" selected="selected">Favorited Time</option>"#
        let unselectedFavorited = #"<option value="f">Favorited Time</option>"#
        #expect(html.contains(unselectedPublished) && html.contains(selectedFavorited),
                "\(filename) no longer carries the select this test rewrites")
        let published = html
            .replacing(unselectedPublished, with: selectedPublished)
            .replacing(selectedFavorited, with: unselectedFavorited)
        let document = try Kanna.HTML(html: published, encoding: .utf8)
        #expect(Parser.parseFavoritesSortOrder(doc: document) == .lastUpdateTime, "\(filename)")
    }

    @Test
    func pageWithoutTheSelectHasNoSortOrder() throws {
        let document = try Kanna.HTML(html: """
        <html><body><div class="searchnav">
          <select onchange="document.location='?inline_set=dm_c'">
            <option value="1" selected="selected">Compact</option>
          </select>
        </div></body></html>
        """, encoding: .utf8)
        #expect(Parser.parseFavoritesSortOrder(doc: document) == nil)
    }

    @Test
    func unknownSelectedValueHasNoSortOrder() throws {
        let document = try Kanna.HTML(html: """
        <html><body><div class="searchnav">
          <select onchange="document.location='?inline_set=fs_'+this.value+''">
            <option value="x" selected="selected">Something Else</option>
          </select>
        </div></body></html>
        """, encoding: .utf8)
        #expect(Parser.parseFavoritesSortOrder(doc: document) == nil)
    }
}
