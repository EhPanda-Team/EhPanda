//
//  Manga.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import Foundation
import SwiftUI

struct Manga: Identifiable {
    let id = UUID()
    
    let title: String
    let rating: Float
    
    let category: Category
    let uploader: String
    let publishedTime: String
    
    let coverURL: String
    let detailURL: String
}

enum Category: String {
    case Doujinshi = "Doujinshi"
    case Manga = "Manga"
    case Artist_CG = "Artist CG"
    case Game_CG = "Game CG"
    case Western = "Western"
    case Non_H = "Non-H"
    case Image_Set = "Image Set"
    case Cosplay = "Cosplay"
    case Asian_Porn = "Asian Porn"
    case Misc = "Misc"
}

// 計算型プロパティ
extension Manga {
    var filledCount: Int { Int(rating) }
    var halfFilledCount: Int { Int(rating - 0.5) == filledCount ? 1 : 0 }
    var notFilledCount: Int { 5 - filledCount - halfFilledCount }
    
    var color: UIColor {
        switch category {
        case .Doujinshi:
            return .systemRed
        case .Manga:
            return .systemOrange
        case .Artist_CG:
            return .systemYellow
        case .Game_CG:
            return .systemGreen
        case .Western:
            return .green
        case .Non_H:
            return .systemBlue
        case .Image_Set:
            return .systemIndigo
        case .Cosplay:
            return .systemPurple
        case .Asian_Porn:
            return .purple
        case .Misc:
            return .systemPink
        }
    }
    
    var translatedCategory: String {
        switch category {
        case .Doujinshi:
            return "同人誌"
        case .Manga:
            return "漫画"
        case .Artist_CG:
            return "イラスト"
        case .Game_CG:
            return "ゲームCG"
        case .Western:
            return "西洋"
        case .Non_H:
            return "健全"
        case .Image_Set:
            return "画像集"
        case .Cosplay:
            return "コスプレ"
        case .Asian_Porn:
            return "アジア"
        case .Misc:
            return "その他"
        }
    }
}
