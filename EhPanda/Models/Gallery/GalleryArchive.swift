//
//  GalleryArchive.swift
//  EhPanda
//

import Foundation

struct GalleryArchive: Codable, Equatable {
    struct HathArchive: Codable, Identifiable, Equatable {
        var id: String { resolution.rawValue }

        let resolution: ArchiveResolution
        let fileSize: String
        private let gpPrice: String

        init(resolution: ArchiveResolution, fileSize: String, gpPrice: String) {
            self.resolution = resolution
            self.fileSize = fileSize
            self.gpPrice = gpPrice
        }

        var isValid: Bool {
            fileSize != "N/A" && gpPrice != "N/A"
        }
        var price: String {
            switch gpPrice {
            case "Free":
                return L10n.Localizable.Struct.HathArchive.Price.free
            default:
                return gpPrice
            }
        }
    }

    let hathArchives: [HathArchive]
}

enum ArchiveResolution: String, Codable, CaseIterable, Equatable {
    case x780 = "780x"
    case x980 = "980x"
    case x1280 = "1280x"
    case x1600 = "1600x"
    case x2400 = "2400x"
    case original = "Original"
}

extension ArchiveResolution {
    var value: String {
        switch self {
        case .x780, .x980, .x1280, .x1600, .x2400:
            return rawValue
        case .original:
            return L10n.Localizable.Enum.ArchiveResolution.Value.original
        }
    }
    var parameter: String {
        switch self {
        case .original:
            return "org"
        default:
            return .init(rawValue.dropLast())
        }
    }
}
