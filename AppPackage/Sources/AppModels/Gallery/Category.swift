import IssueReporting
import Resources
import SwiftUI

public enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    public var id: String { rawValue }

    public static let allFavoritesCases: [Self] = [.misc] + allCases.dropLast(2)
    public static let allFiltersCases: [Self] = allCases.dropLast()

    case doujinshi = "Doujinshi"
    case manga = "Manga"
    case artistCG = "Artist CG"
    case gameCG = "Game CG"
    case western = "Western"
    case nonH = "Non-H"
    case imageSet = "Image Set"
    case cosplay = "Cosplay"
    case asianPorn = "Asian Porn"
    case misc = "Misc"
    case `private` = "Private"
}

extension Category {
    public func color(host: GalleryHost) -> Color {
        .init(host.rawValue + "/" + rawValue)
    }
    /// The search-filter bit represented by this category.
    ///
    /// `.private` is a display-only private-gallery bucket, not a search-filter category, so it
    /// contributes no filter bit. Requesting its value reports a non-fatal development issue and returns zero.
    public var filterValue: Int {
        switch self {
        case .doujinshi: return 2
        case .manga: return 4
        case .artistCG: return 8
        case .gameCG: return 16
        case .western: return 512
        case .nonH: return 256
        case .imageSet: return 32
        case .cosplay: return 64
        case .asianPorn: return 128
        case .misc: return 1
        case .private:
            reportIssue(
                "`Category.private` has no `filterValue`, it is display-only and must be excluded from filter math."
            )
            return 0
        }
    }
    public var value: LocalizedStringResource {
        switch self {
        case .doujinshi: return .categoryDoujinshi
        case .manga: return .categoryManga
        case .artistCG: return .categoryArtistCg
        case .gameCG: return .categoryGameCg
        case .western: return .categoryWestern
        case .nonH: return .categoryNonH
        case .imageSet: return .categoryImageSet
        case .cosplay: return .categoryCosplay
        case .asianPorn: return .categoryAsianPorn
        case .misc: return .categoryMisc
        case .private: return .categoryPrivate
        }
    }
}
