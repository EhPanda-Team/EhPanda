//
//  Category.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import SwiftUI

enum Category: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    static let allFavoritesCases: [Self] = [.misc] + allCases.dropLast(2)
    static let allFiltersCases: [Self] = allCases.dropLast()

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
    var color: Color {
        .init(AppUtil.galleryHost.rawValue + "/" + rawValue)
    }
    var filterValue: Int {
        switch self {
        case .doujinshi:
            return 2
        case .manga:
            return 4
        case .artistCG:
            return 8
        case .gameCG:
            return 16
        case .western:
            return 512
        case .nonH:
            return 256
        case .imageSet:
            return 32
        case .cosplay:
            return 64
        case .asianPorn:
            return 128
        case .misc:
            return 1
        case .private:
            let message = "Category `Private` shouldn't be used in filters!"
            Logger.error(message)
            fatalError(message)
        }
    }
    var value: String {
        switch self {
        case .doujinshi:
            return R.string.localizable.enumCategoryValueDoujinshi()
        case .manga:
            return R.string.localizable.enumCategoryValueManga()
        case .artistCG:
            return R.string.localizable.enumCategoryValueArtistCG()
        case .gameCG:
            return R.string.localizable.enumCategoryValueGameCG()
        case .western:
            return R.string.localizable.enumCategoryValueWestern()
        case .nonH:
            return R.string.localizable.enumCategoryValueNonH()
        case .imageSet:
            return R.string.localizable.enumCategoryValueImageSet()
        case .cosplay:
            return R.string.localizable.enumCategoryValueCosplay()
        case .asianPorn:
            return R.string.localizable.enumCategoryValueAsianPorn()
        case .misc:
            return R.string.localizable.enumCategoryValueMisc()
        case .private:
            return R.string.localizable.enumCategoryValuePrivate()
        }
    }
}
