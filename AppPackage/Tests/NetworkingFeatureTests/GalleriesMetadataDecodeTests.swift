import Foundation
import Testing
import AppModels
@testable import NetworkingFeature

// REV-2: the `gdata` API returns bare `{ gid, error }` objects for expunged/removed gids (and can omit
// `token`). Decoding the whole `[GalleryMetadata]` array must tolerate those per-entry — one bad gid
// must never fail the batch and blank the entire History screen.
@Suite
struct GalleriesMetadataDecodeTests {
    @Test
    func mixedPayloadDropsErrorEntriesAndKeepsResolvableGalleries() throws {
        let json = """
        {
          "gmetadata": [
            {
              "gid": 100, "token": "aaa", "title": "First &amp; Title",
              "category": "Doujinshi", "thumb": "https://example.com/1.jpg",
              "uploader": "u1", "posted": "1600000000", "filecount": "20",
              "rating": "4.5", "tags": ["language:japanese", "artist:someone"]
            },
            { "gid": 999, "error": "Key missing, or incorrect key." },
            {
              "gid": 200, "token": "bbb", "title": "Second Title",
              "category": "Manga", "thumb": "https://example.com/2.jpg",
              "uploader": "u2", "posted": "1600000100", "filecount": "30",
              "rating": "3.0", "tags": ["language:english"]
            }
          ]
        }
        """

        let galleries = try GalleriesMetadataRequest.galleries(fromResponseData: Data(json.utf8))

        #expect(galleries.count == 2)
        #expect(galleries.map(\.id) == ["100", "200"])
        #expect(galleries.first?.token == "aaa")
        #expect(galleries.first?.title == "First & Title")
    }

    // A tokenless (but error-free) entry is unresolvable — its gallery URL can't be built — so it is
    // dropped rather than decoded with an empty token.
    @Test
    func tokenlessEntryIsDropped() throws {
        let json = """
        { "gmetadata": [ { "gid": 300, "title": "No Token", "posted": "1600000000" } ] }
        """
        let galleries = try GalleriesMetadataRequest.galleries(fromResponseData: Data(json.utf8))
        #expect(galleries.isEmpty)
    }
}
