//
//  Manga.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI

// MARK: Structs
public struct Manga: Identifiable, Codable, Equatable {
    public static func == (lhs: Manga, rhs: Manga) -> Bool {
        lhs.id == rhs.id
    }
    static let empty = Manga(
        id: "", token: "", title: "", rating: 0,
        tags: [], category: .Non_H, uploader: nil,
        publishedTime: "", coverURL: "", detailURL: ""
    )
    
    var detail: MangaDetail?
    var contents: [MangaContent]?
    
    public let id: String
    let token: String
    
    var title: String
    var rating: Float
    var tags: [String]
    let category: Category
    var language: Language?
    let uploader: String?
    let publishedTime: String
    let coverURL: String
    let detailURL: String
    var lastOpenTime: Date?
}

struct MangaDetail: Codable {
    var readingProgress: Int?
    var currentPageNum = 0
    var pageNumMaximum = 1
    
    var isFavored: Bool
    var archiveURL: String?
    var archive: MangaArchive?
    var alterImages: [MangaAlterData]
    var torrents: [MangaTorrent]
    var comments: [MangaComment]
    let previews: [MangaPreview]
    
    var title: String
    var jpnTitle: String?
    var rating: Float
    var userRating: Float?
    var ratingCount: String
    var detailTags: [MangaTag]
    let category: Category
    let language: Language
    let uploader: String
    let publishedTime: String
    let coverURL: String
    var likeCount: String
    var pageCount: String
    var sizeCount: String
    var sizeType: String
    var torrentCount: Int
}

struct MangaArchive: Codable {
    struct HathArchive: Codable, Identifiable {
        var id = UUID()
        
        let resolution: ArchiveRes
        let fileSize: String
        let gpPrice: String
    }
    
    let hathArchives: [HathArchive]
}

struct MangaTag: Codable, Identifiable {
    var id = UUID()
    
    let category: TagCategory
    let content: [String]
}

struct MangaComment: Identifiable, Codable {
    var id = UUID()
    
    var votedUp: Bool
    var votedDown: Bool
    let votable: Bool
    let editable: Bool
    
    let score: String?
    let author: String
    let contents: [CommentContent]
    let commentID: String
    let commentDate: Date
}

struct CommentContent: Identifiable, Codable {
    var id = UUID()
    
    let type: CommentContentType
    var text: String?
    var link: String?
    var imgURL: String?
    
    var secondLink: String?
    var secondImgURL: String?
}

struct MangaPreview: Identifiable, Codable {
    var id = UUID()
    
    let url: String
}

struct MangaAlterData: Identifiable, Codable {
    var id = UUID()
    
    let data: Data
}

struct MangaContent: Identifiable, Codable, Equatable {
    static func == (lhs: MangaContent, rhs: MangaContent) -> Bool {
        lhs.tag == rhs.tag
    }
    var id: Int { tag }
    
    let tag: Int
    let url: String
}

struct MangaTorrent: Identifiable, Codable {
    var id = UUID()
    
    let postedTime: String
    let fileSize: String
    let seedCount: Int
    let peerCount: Int
    let downloadCount: Int
    let uploader: String
    let fileName: String
    let magnet: String
}

// MARK: Computed Properties
extension Manga {
    var filledCount: Int { Int(rating) }
    var halfFilledCount: Int { Int(rating - 0.5) == filledCount ? 1 : 0 }
    var notFilledCount: Int { 5 - filledCount - halfFilledCount }
    
    var color: Color {
        category.color
    }
    var publishedDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: publishedTime) ?? Date()
    }
}

extension MangaDetail {
    var languageAbbr: String {
        language.languageAbbr
    }
}

extension MangaComment {
    var commentTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        return formatter.string(from: commentDate)
    }
}

extension Category {
    var color: Color {
        Color(galleryType.rawValue + "/" + rawValue)
    }
    var value: Int {
        switch self {
        case .Doujinshi:
            return 2
        case .Manga:
            return 4
        case .Artist_CG:
            return 8
        case .Game_CG:
            return 16
        case .Western:
            return 512
        case .Non_H:
            return 256
        case .Image_Set:
            return 32
        case .Cosplay:
            return 64
        case .Asian_Porn:
            return 128
        case .Misc:
            return 1
        }
    }
}

extension Language {
    var languageAbbr: String {
        switch self {
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
}

// MARK: Enums
enum Category: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    
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

enum TagCategory: String, Codable {
    case reclass = "Reclass"
    case language = "Language"
    case parody = "Parody"
    case character = "Character"
    case group = "Group"
    case artist = "Artist"
    case male = "Male"
    case female = "Female"
    case misc = "Misc"
}

enum ArchiveRes: String, Codable, CaseIterable {
    case x780 = "780x"
    case x980 = "980x"
    case x1280 = "1280x"
    case x1600 = "1600x"
    case x2400 = "2400x"
    case original = "Original"
}

extension ArchiveRes {
    var param: String {
        switch self {
        case .original:
            return "org"
        default:
            return rawValue
        }
    }
}

enum CommentContentType: Int, Codable {
    case singleImg
    case doubleImg
    case linkedImg
    case doubleLinkedImg
    
    case plainText
    case linkedText
    
    case singleLink
}

enum Language: String, Codable {
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
