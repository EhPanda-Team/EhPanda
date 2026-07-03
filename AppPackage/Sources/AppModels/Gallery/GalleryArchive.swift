import Foundation
import Resources

public struct GalleryArchive: Codable, Equatable, Sendable {
    public init(
        hathArchives: [HathArchive]
    ) {
        self.hathArchives = hathArchives
    }
    public struct HathArchive: Codable, Identifiable, Equatable, Sendable {
        public var id: String { resolution.rawValue }

        public let resolution: ArchiveResolution
        public let fileSize: String
        private let gpPrice: String

        public init(resolution: ArchiveResolution, fileSize: String, gpPrice: String) {
            self.resolution = resolution
            self.fileSize = fileSize
            self.gpPrice = gpPrice
        }

        public var isValid: Bool {
            fileSize != "N/A" && gpPrice != "N/A"
        }
        public var price: String {
            switch gpPrice {
            case "Free":
                return L10n.Localizable.HathArchive.free
            default:
                return gpPrice
            }
        }
    }

    public let hathArchives: [HathArchive]
}

public enum ArchiveResolution: String, Codable, CaseIterable, Equatable, Sendable {
    case x780 = "780x"
    case x980 = "980x"
    case x1280 = "1280x"
    case x1600 = "1600x"
    case x2400 = "2400x"
    case original = "Original"
}

extension ArchiveResolution {
    public var value: String {
        switch self {
        case .x780, .x980, .x1280, .x1600, .x2400:
            return rawValue
        case .original:
            return L10n.Localizable.ArchiveResolution.original
        }
    }
    public var parameter: String {
        switch self {
        case .original:
            return "org"
        default:
            return .init(rawValue.dropLast())
        }
    }
}
