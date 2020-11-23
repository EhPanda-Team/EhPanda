//
//  Manga.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI

struct Manga: Identifiable {
    var id: String {
        get { coverURL }
    }
    var translatedCategory: String {
        get {
            switch category {
            case "Doujinshi":
                return "同人誌"
            case "Manga":
                return "漫画"
            case "Artist CG":
                return "イラスト"
            case "Game CG":
                return "ゲームCG"
            case "Western":
                return "西洋"
            case "Non-H":
                return "健全"
            case "Image Set":
                return "画像集"
            case "Cosplay":
                return "コスプレ"
            case "Asian Porn":
                return "アジア"
            case "Misc":
                return "その他"
            default:
                return "未知"
            }
        }
    }
    var color: UIColor {
        get {
            switch category {
            case "Doujinshi":
                return .systemRed
            case "Manga":
                return .systemOrange
            case "Artist CG":
                return .systemYellow
            case "Game CG":
                return .systemGreen
            case "Western":
                return .green
            case "Non-H":
                return .systemBlue
            case "Image Set":
                return .systemIndigo
            case "Cosplay":
                return .systemPurple
            case "Asian Porn":
                return .purple
            case "Misc":
                return .systemPink
            default:
                return .gray
            }
        }
    }
    
    let title: String
    let rating: Float
    let category: String
    let uploader: String
    let publishedTime: String
    
    let coverURL: String
    let detailURL: String
}
