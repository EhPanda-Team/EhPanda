import Kanna
import AppModels

extension Parser {
    public static func parseFavoritesSortOrder(doc: HTMLDocument) -> FavoritesSortOrder? {
        guard let idoNode = doc.at_xpath("//div [@class='ido']") else { return nil }
        for link in idoNode.xpath("//div") where link.className == nil {
            guard let aText = link.at_xpath("//div")?.at_xpath("//a")?.text else { continue }
            if aText == "Use Posted" {
                return .favoritedTime
            } else if aText == "Use Favorited" {
                return .lastUpdateTime
            }
        }
        return nil
    }

    public static func parseFavoriteCategories(doc: HTMLDocument) throws -> [Int: String] {
        var favoriteCategories = [Int: String]()

        for link in doc.xpath("//div [@id='favsel']") {
            for inputLink in link.xpath("//input") {
                guard let name = inputLink["name"],
                      let value = inputLink["value"],
                      let type = FavoritesType(rawValue: name)
                else { continue }

                favoriteCategories[type.index] = value
            }
        }

        if !favoriteCategories.isEmpty {
            return favoriteCategories
        } else {
            throw AppError.parseFailed
        }
    }
}
