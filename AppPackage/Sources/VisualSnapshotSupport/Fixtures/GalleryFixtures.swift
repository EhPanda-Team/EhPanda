import Foundation

/// Synthetic words for the 19-07 scenarios: a comment draft, the posting filter's term, and what the Report form is
/// filled with. Every string is invented for the public baselines (D-06); none is a real comment, member or address.
public enum GalleryFixtures {
    /// A new comment as typed into Post Comment.
    public static let commentDraft = "A visual fixture comment, written for the public sample."

    /// A comment that trips the posting filter, and the one term the scenario's filter list holds. The term is an
    /// invented neutral word, so the warning is shown without the bundled list's words.
    public static let filteredTerm = "visualfilterword"
    public static let filteredDraft = "A visual fixture comment with visualfilterword in it."

    /// The member ID of the comment author the blocked-row scenarios block (the first synthetic member).
    public static let blockedMemberID = "900001"
    public static let blockedMemberName = "Visual Member 1"

    /// The Report form as a user fills it: an email on a reserved example domain and a line of details.
    public static let reportEmail = "visual.fixture@example.com"
    public static let reportDetails = "Visual fixture details for the public sample."
}

/// One synthetic H@H archive: its size and its price in GP, as the site lists them.
public struct ArchiveFixture: Sendable {
    public let fileSize: String
    public let price: String
}

/// One synthetic torrent of the gallery.
public struct TorrentFixture: Sendable {
    public let fileName: String
    public let fileSize: String
    public let seeds: Int
    public let peers: Int
    public let downloads: Int
}

extension GalleryFixtures {
    /// The tag a Detail Search runs, written as the gallery page writes a tag search.
    public static let detailSearchKeyword = "other:\"visual fixture$\""

    /// The archives, one per resolution from 780x up to the original; the original is not offered.
    public static let archives = [
        ArchiveFixture(fileSize: "12.4 MiB", price: "180"),
        ArchiveFixture(fileSize: "18.6 MiB", price: "260"),
        ArchiveFixture(fileSize: "26.2 MiB", price: "380"),
        ArchiveFixture(fileSize: "34.8 MiB", price: "520"),
        ArchiveFixture(fileSize: "51.0 MiB", price: "Free"),
        ArchiveFixture(fileSize: "N/A", price: "N/A")
    ]

    /// The balances shown under the archives: enough for every archive, and less than any archive's price.
    public static let funds = (galleryPoints: "24680", credits: "135790")
    public static let lowFunds = (galleryPoints: "120", credits: "90")

    public static let torrents = [
        TorrentFixture(fileName: "Visual Fixture Gallery [1280x].zip", fileSize: "26.2 MiB", seeds: 12, peers: 3,
                       downloads: 140),
        TorrentFixture(fileName: "Visual Fixture Gallery [2400x].zip", fileSize: "51.0 MiB", seeds: 4, peers: 1,
                       downloads: 36)
    ]
    public static let torrentUploader = "Visual Uploader"

    /// The Tag Detail sheet of one invented tag: its description, three images and one link.
    public static let tagTitle = "visual fixture"
    public static let tagDescription = """
        An invented tag for the public visual samples. It names no real work, person or group, and its images are \
        the synthetic artwork.
        """
    public static let tagImageCount = 3

    /// What the New Dawn greeting reports as gained.
    public static let greeting = (exp: 30, credits: 1250, galleryPoints: 4200, hath: 2)

    /// The page whose Live Text the reader shows, and the line on it: the page's marker, where the synthetic
    /// artwork draws it, in the page's unit coordinates. Recorded once for the samples, never recognized live.
    public static let liveTextPage = 1
    public static let liveTextBounds = (minX: 0.14, minY: 0.48, maxX: 0.66, maxY: 0.66)

    /// The slider's value while the reader drags it.
    public static let scrubPage = 5
}
