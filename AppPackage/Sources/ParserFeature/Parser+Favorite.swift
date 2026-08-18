import Kanna
import AppModels

extension Parser {
    public static func parseFavoritesSortOrder(doc: HTMLDocument) -> FavoritesSortOrder? {
        guard let select = doc.at_xpath("//div [@class='searchnav']//select[contains(@onchange, 'inline_set=fs_')]"),
              let selectedValue = select.at_xpath(".//option[@selected]")?["value"]
        else { return nil }

        switch selectedValue {
        case "p": return .lastUpdateTime
        case "f": return .favoritedTime
        default: return nil
        }
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
