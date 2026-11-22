import AppModels
import Foundation
import Testing

/// The favourite, rated and expunged marks a list row carries. Persisted `Gallery` JSON written before the
/// marks existed has no such keys and must keep decoding.
struct GalleryStatusFieldsTests {
    private func object(of gallery: Gallery) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(gallery)) as? [String: Any])
    }

    private func decode(_ object: [String: Any]) throws -> Gallery {
        try JSONDecoder().decode(Gallery.self, from: JSONSerialization.data(withJSONObject: object))
    }

    @Test
    func theMarksRoundTrip() throws {
        var gallery = Gallery.preview
        gallery.isExpunged = true
        gallery.hasRated = true
        gallery.favoriteTagIndex = 4
        gallery.favoriteTagName = "Read later"
        let restored = try JSONDecoder().decode(Gallery.self, from: JSONEncoder().encode(gallery))
        #expect(restored.isExpunged)
        #expect(restored.hasRated)
        #expect(restored.favoriteTagIndex == 4)
        #expect(restored.favoriteTagName == "Read later")
    }

    // Regression for the review's note on #462: new non-optional stored properties with defaults break
    // synthesized decoding of any persisted JSON that lacks the keys.
    @Test
    func jsonWrittenBeforeTheMarksExistedStillDecodes() throws {
        var old = try object(of: .preview)
        for key in ["isExpunged", "hasRated", "favoriteTagIndex", "favoriteTagName"] {
            old.removeValue(forKey: key)
        }
        let gallery = try decode(old)
        #expect(gallery.isExpunged == false)
        #expect(gallery.hasRated == false)
        #expect(gallery.favoriteTagIndex == nil)
        #expect(gallery.favoriteTagName == nil)
        #expect(gallery.isFavorite == false)
        #expect(gallery.title == Gallery.preview.title)
    }

    // Builds that kept the list's rating colour wrote it into the JSON. The model has no such key any more, so it is
    // ignored and the rest decodes (design decision, 2026-11-21).
    @Test
    func jsonThatStillCarriesTheListRatingColourDecodes() throws {
        var rated = Gallery.preview
        rated.hasRated = true
        var old = try object(of: rated)
        old["userRatingTint"] = "blue"
        let gallery = try decode(old)
        #expect(gallery.hasRated)
        #expect(gallery.title == Gallery.preview.title)
    }

    @Test
    func aMalformedMarkIsStillRejected() throws {
        // Absent keys default; a present key of the wrong type is a corrupt blob and fails the decode.
        var corrupt = try object(of: .preview)
        corrupt["hasRated"] = "yes"
        #expect(throws: (any Error).self) { try decode(corrupt) }
    }

    @Test
    func aGalleryIsAFavoriteByItsSlotOrByItsName() {
        var gallery = Gallery.preview
        #expect(gallery.isFavorite == false)
        gallery.favoriteTagName = "Favorites 3"
        #expect(gallery.isFavorite)
        gallery.favoriteTagName = nil
        gallery.favoriteTagIndex = 3
        #expect(gallery.isFavorite)
    }

    @Test
    func aDetailWrittenBeforeTheFavoriteSlotExistedStillDecodes() throws {
        var old = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(GalleryDetail.preview)) as? [String: Any]
        )
        old.removeValue(forKey: "favoriteTagIndex")
        old.removeValue(forKey: "favoriteTagName")
        let detail = try JSONDecoder().decode(GalleryDetail.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(detail.favoriteTagIndex == nil)
        #expect(detail.favoriteTagName == nil)
    }
}
