//
//  Manga.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI

// MARK: 構造体
struct Manga: Identifiable, Encodable, Decodable {
    var detail: MangaDetail?
    var contents: [MangaContent]?
    
    let id: String
    let token: String
    
    let title: String
    let rating: Float
    let category: Category
    let uploader: String?
    let publishedTime: String
    let coverURL: String
    let detailURL: String
}

struct MangaDetail: Encodable, Decodable {
    let previews: [MangaPreview]
    let jpnTitle: String
    let language: Language
    let likeCount: String
    let pageCount: String
    let sizeCount: String
    let sizeType: String
    let ratingCount: String
}

struct MangaPreview: Identifiable, Encodable, Decodable {
    var id = UUID()
    
    let url: String
}

struct MangaContent: Identifiable, Encodable, Decodable {
    var id = UUID()
    
    let tag: Int
    let url: String
}

struct MangaURL {
    let tag: Int
    let url: URL
}

// MARK: 列挙型
enum Category: String, Encodable, Decodable {
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

enum Language: String, Encodable, Decodable {
    case Other = "N/A"
    
    case Afrikaans = "Afrikaans"; case Albanian = "Albanian"; case Arabic = "Arabic"
    
    case Bengali = "Bengali"; case Bosnian = "Bosnian"; case Bulgarian = "Bulgarian"; case Burmese = "Burmese"
    
    case Catalan = "Catalan"; case Cebuano = "Cebuano"; case Chinese = "Chinese"; case Croatian = "Croatian"; case Czech = "Czech"
    
    case Danish = "Danish"; case Dutch = "Dutch"
    
    case English = "English"; case Esperanto = "Esperanto"; case Estonian = "Estonian"
    
    case Finnish = "Finnish"; case French = "French"
    
    case Georgian = "Georgian"; case German = "German"; case Greek = "Greek"
    
    case Hebrew = "Hebrew"; case Hindi = "Hindi"; case Hmong = "Hmong"; case Hungarian = "Hungarian"
    
    case Indonesian = "Indonesian"; case Italian = "Italian"
    
    case Japanese = "Japanese"
    
    case Kazakh = "Kazakh"; case Khmer = "Khmer"; case Korean = "Korean"; case Kurdish = "Kurdish"
    
    case Lao = "Lao"; case Latin = "Latin"
    
    case Mongolian = "Mongolian"
    
    case Ndebele = "Ndebele"; case Nepali = "Nepali"; case Norwegian = "Norwegian"
    
    case Oromo = "Oromo"
    
    case Pashto = "Pashto"; case Persian = "Persian"; case Polish = "Polish"; case Portuguese = "Portuguese"; case Punjabi = "Punjabi"
    
    case Romanian = "Romanian"; case Russian = "Russian"
    
    case Sango = "Sango"; case Serbian = "Serbian"; case Shona = "Shona"; case Slovak = "Slovak"; case Slovenian = "Slovenian"; case Somali = "Somali"; case Spanish = "Spanish"; case Swahili = "Swahili"; case Swedish = "Swedish"
    
    case Tagalog = "Tagalog"; case Thai = "Thai"; case Tigrinya = "Tigrinya"; case Turkish = "Turkish"
    
    case Ukrainian = "Ukrainian"; case Urdu = "Urdu"
    
    case Vietnamese = "Vietnamese"
    
    case Zulu = "Zulu"
}

// MARK: 計算型プロパティ
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

extension MangaDetail {
    var languageAbbr: String {
        switch language {
        case .Other: return "N/A"
        
        case .Afrikaans: return "AF"; case .Albanian: return "SQ"; case .Arabic: return "AR"
            
        case .Bengali: return "BN"; case .Bosnian: return "BS"; case .Bulgarian: return "BG"; case .Burmese: return "MY"
            
        case .Catalan: return "CA"; case .Cebuano: return "CEB"; case .Chinese: return "ZH"; case .Croatian: return "HR"; case .Czech: return "CS"
            
        case .Danish: return "DA"; case .Dutch: return "NL"
            
        case .English: return "EN"; case .Esperanto: return "EO"; case .Estonian: return "ET"
            
        case .Finnish: return "FI"; case .French: return "FR"
            
        case .Georgian: return "KA"; case .German: return "DE"; case .Greek: return "EL"
            
        case .Hebrew: return "HE"; case .Hindi: return "HI"; case .Hmong: return "HMN"; case .Hungarian: return "HU"
            
        case .Indonesian: return "ID"; case .Italian: return "IT"
            
        case .Japanese: return "JA"
            
        case .Kazakh: return "KK"; case .Khmer: return "KM"; case .Korean: return "KO"; case .Kurdish: return "KU"
            
        case .Lao: return "LO"; case .Latin: return "LA"
            
        case .Mongolian: return "MN"
            
        case .Ndebele: return "ND"; case .Nepali: return "NE"; case .Norwegian: return "NO"
            
        case .Oromo: return "OM"
            
        case .Pashto: return "PS"; case .Persian: return "FA"; case .Polish: return "PL"; case .Portuguese: return "PT"; case .Punjabi: return "PA"
            
        case .Romanian: return "RO"; case .Russian: return "RU"
            
        case .Sango: return "SG"; case .Serbian: return "SR"; case .Shona: return "SN"; case .Slovak: return "SK"; case .Slovenian: return "SL"; case .Somali: return "SO"; case .Spanish: return "ES"; case .Swahili: return "SW"; case .Swedish: return "SV"
            
        case .Tagalog: return "TL"; case .Thai: return "TH"; case .Tigrinya: return "TI"; case .Turkish: return "TR"
            
        case .Ukrainian: return "UK"; case .Urdu: return "UR"
            
        case .Vietnamese: return "VI"
            
        case .Zulu: return "ZU"
        }
    }
    
    var translatedLanguage: String {
        switch language {
        case .Other: return "その他"
            
        case .Afrikaans: return "アフリカーンス語"; case .Albanian: return "アルバニア語"; case .Arabic: return "アラビア語"
            
        case .Bengali: return "ベンガル語"; case .Bosnian: return "ボスニア語"; case .Bulgarian: return "ブルガリア語"; case .Burmese: return "ビルマ語"
            
        case .Catalan: return "カタルーニャ語"; case .Cebuano: return "セブアノ語"; case .Chinese: return "中国語"; case .Croatian: return "クロアチア語"; case .Czech: return "チェコ語"
            
        case .Danish: return "デンマーク語"; case .Dutch: return "オランダ語"
            
        case .English: return "英語"; case .Esperanto: return "国際語"; case .Estonian: return "エストニア語"
            
        case .Finnish: return "フィンランド語"; case .French: return "フランス語"
            
        case .Georgian: return "グルジア語"; case .German: return "ドイツ語"; case .Greek: return "ギリシア語"
            
        case .Hebrew: return "ヘブライ語"; case .Hindi: return "ヒンディー語"; case .Hmong: return "ミャオ語"; case .Hungarian: return "ハンガリー語"
            
        case .Indonesian: return "インドネシア語"; case .Italian: return "イタリア語"
            
        case .Japanese: return "日本語"
            
        case .Kazakh: return "カザフ語"; case .Khmer: return "クメール語"; case .Korean: return "韓国語"; case .Kurdish: return "クルド語"
            
        case .Lao: return "ラーオ語"; case .Latin: return "ラテン語"
            
        case .Mongolian: return "モンゴル語"
            
        case .Ndebele: return "ンデベレ"; case .Nepali: return "ネパール語"; case .Norwegian: return "ノルウェー語"
            
        case .Oromo: return "オロモ語"
            
        case .Pashto: return "パシュトー語"; case .Persian: return "ペルシア語"; case .Polish: return "ポーランド語"; case .Portuguese: return "ポルトガル語"; case .Punjabi: return "パンジャーブ語"
            
        case .Romanian: return "ルーマニア語"; case .Russian: return "ロシア語"
            
        case .Sango: return "サンゴ語"; case .Serbian: return "セルビア語"; case .Shona: return "ショナ語"; case .Slovak: return "スロバキア語"; case .Slovenian: return "スロベニア語"; case .Somali: return "ソマリ語"; case .Spanish: return "スペイン語"; case .Swahili: return "スワヒリ語"; case .Swedish: return "スウェーデン語"
            
        case .Tagalog: return "タガログ語"; case .Thai: return "タイ語"; case .Tigrinya: return "ティグリニャ語"; case .Turkish: return "トルコ語"
            
        case .Ukrainian: return "ウクライナ語"; case .Urdu: return "ウルドゥー語"
            
        case .Vietnamese: return "ベトナム語"
            
        case .Zulu: return "ズールー語"
        }
    }
}
