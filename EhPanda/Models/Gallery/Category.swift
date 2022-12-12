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
            let message = "`Private` doesn't have a `filterValue`!"
            Logger.error(message)
            fatalError(message)
        }
    }
    var value: String {
        switch self {
        case .doujinshi: return L10n.Localizable.Enum.Category.Value.doujinshi
        case .manga: return L10n.Localizable.Enum.Category.Value.manga
        case .artistCG: return L10n.Localizable.Enum.Category.Value.artistCG
        case .gameCG: return L10n.Localizable.Enum.Category.Value.gameCG
        case .western: return L10n.Localizable.Enum.Category.Value.western
        case .nonH: return L10n.Localizable.Enum.Category.Value.nonH
        case .imageSet: return L10n.Localizable.Enum.Category.Value.imageSet
        case .cosplay: return L10n.Localizable.Enum.Category.Value.cosplay
        case .asianPorn: return L10n.Localizable.Enum.Category.Value.asianPorn
        case .misc: return L10n.Localizable.Enum.Category.Value.misc
        case .private: return L10n.Localizable.Enum.Category.Value.private
        }
    }
}
