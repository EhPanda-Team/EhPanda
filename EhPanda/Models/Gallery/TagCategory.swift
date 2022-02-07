//
//  TagCategory.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

enum TagCategory: String, Codable, CaseIterable {
    case reclass
    case language
    case parody
    case character
    case group
    case artist
    case male
    case female
    case mixed
    case cosplayer
    case other
    case temp
}

extension TagCategory {
    var value: String {
        switch self {
        case .reclass:
            return R.string.localizable.enumTagCategoryValueReclass()
        case .language:
            return R.string.localizable.enumTagCategoryValueLanguage()
        case .parody:
            return R.string.localizable.enumTagCategoryValueParody()
        case .character:
            return R.string.localizable.enumTagCategoryValueCharacter()
        case .group:
            return R.string.localizable.enumTagCategoryValueGroup()
        case .artist:
            return R.string.localizable.enumTagCategoryValueArtist()
        case .male:
            return R.string.localizable.enumTagCategoryValueMale()
        case .female:
            return R.string.localizable.enumTagCategoryValueFemale()
        case .mixed:
            return R.string.localizable.enumTagCategoryValueMixed()
        case .cosplayer:
            return R.string.localizable.enumTagCategoryValueCosplayer()
        case .other:
            return R.string.localizable.enumTagCategoryValueOther()
        case .temp:
            return R.string.localizable.enumTagCategoryValueTemp()
        }
    }
}
