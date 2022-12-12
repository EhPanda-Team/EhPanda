//
//  ListParserTestType.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
//

enum ListParserTestType: CaseIterable {
    // FrontPage
    case frontPageMinimalList
    case frontPageMinimalPlusList
    case frontPageCompactList
    case frontPageExtendedList
    case frontPageThumbnailList

    // Watched
    case watchedMinimalList
    case watchedMinimalPlusList
    case watchedCompactList
    case watchedExtendedList
    case watchedThumbnailList

    // Popular
    case popularMinimalList
    case popularMinimalPlusList
    case popularCompactList
    case popularExtendedList
    case popularThumbnailList

    // Favorites
    case favoritesMinimalList
    case favoritesMinimalPlusList
    case favoritesCompactList
    case favoritesExtendedList
    case favoritesThumbnailList

    // Toplists
    case toplistsCompactList
}

extension ListParserTestType {
    var filename: HTMLFilename {
        switch self {
        case .frontPageMinimalList: return .frontPageMinimalList
        case .frontPageMinimalPlusList: return .frontPageMinimalPlusList
        case .frontPageCompactList: return .frontPageCompactList
        case .frontPageExtendedList: return .frontPageExtendedList
        case .frontPageThumbnailList: return .frontPageThumbnailList
        case .watchedMinimalList: return .watchedMinimalList
        case .watchedMinimalPlusList: return .watchedMinimalPlusList
        case .watchedCompactList: return .watchedCompactList
        case .watchedExtendedList: return .watchedExtendedList
        case .watchedThumbnailList: return .watchedThumbnailList
        case .popularMinimalList: return .popularMinimalList
        case .popularMinimalPlusList: return .popularMinimalPlusList
        case .popularCompactList: return .popularCompactList
        case .popularExtendedList: return .popularExtendedList
        case .popularThumbnailList: return .popularThumbnailList
        case .favoritesMinimalList: return .favoritesMinimalList
        case .favoritesMinimalPlusList: return .favoritesMinimalPlusList
        case .favoritesCompactList: return .favoritesCompactList
        case .favoritesExtendedList: return .favoritesExtendedList
        case .favoritesThumbnailList: return .favoritesThumbnailList
        case .toplistsCompactList: return .toplistsCompactList
        }
    }
    var assertCount: Int {
        switch self {
        case .frontPageMinimalList, .frontPageMinimalPlusList, .frontPageCompactList, .frontPageExtendedList, .frontPageThumbnailList:
            return 200
        case .watchedMinimalList, .watchedMinimalPlusList, .watchedCompactList, .watchedExtendedList, .watchedThumbnailList:
            return 200
        case .popularMinimalList, .popularMinimalPlusList, .popularCompactList, .popularExtendedList, .popularThumbnailList:
            return 50
        case .favoritesMinimalList, .favoritesMinimalPlusList, .favoritesCompactList, .favoritesExtendedList, .favoritesThumbnailList:
            return 107
        case .toplistsCompactList:
            return 50
        }
    }
    var hasUploader: Bool {
        switch self {
        case .frontPageMinimalList, .frontPageMinimalPlusList, .frontPageCompactList, .frontPageExtendedList,
                .watchedMinimalList, .watchedMinimalPlusList, .watchedCompactList, .watchedExtendedList,
                .popularMinimalList, .popularMinimalPlusList, .popularCompactList, .popularExtendedList,
                .toplistsCompactList:
            return true
        case .frontPageThumbnailList, .watchedThumbnailList, .popularThumbnailList, .favoritesThumbnailList,
                .favoritesMinimalList, .favoritesMinimalPlusList, .favoritesCompactList, .favoritesExtendedList:
            return false
        }
    }
}
