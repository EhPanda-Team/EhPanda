import Kanna
import Foundation

extension Parser {
    // MARK: ImageURL
    static func parseThumbnailURLs(doc: HTMLDocument) throws -> [Int: URL] {
        var thumbnailURLs = [Int: URL]()

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { throw AppError.parseFailed }

        for aLink in gdtNode.xpath("a") {
            guard let href = aLink["href"],
                  let thumbnailURL = URL(string: href),
                  let divNode = aLink.at_xpath(".//div[@title and @style]"),
                  let title = divNode["title"],
                  let index = parseGTX00IndexFromTitle(from: title)
            else { continue }

            thumbnailURLs[index] = thumbnailURL
        }

        return thumbnailURLs
    }

    static func parseGalleryNormalImageURL(doc: HTMLDocument, index: Int) throws -> GalleryNormalImageInfo {
        guard let i3Node = doc.at_xpath("//div [@id='i3']"),
              let imageURLString = i3Node.at_css("img")?["src"],
              let imageURL = URL(string: imageURLString)
        else { throw AppError.parseFailed }

        guard let i7Node = doc.at_xpath("//div [@id='i7']"),
              let originalImageURLString = i7Node.at_xpath("//a")?["href"],
              let originalImageURL = URL(string: originalImageURLString)
        else {
            return GalleryNormalImageInfo(
                index: index,
                imageURL: imageURL,
                originalImageURL: nil
            )
        }

        return GalleryNormalImageInfo(
            index: index,
            imageURL: imageURL,
            originalImageURL: originalImageURL
        )
    }

    static func parseMPVKeys(doc: HTMLDocument) throws -> (String, [Int: String]) {
        var tmpMPVKey: String?
        var imgKeys = [Int: String]()

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let text = link.text,
                  let rangeA = text.range(of: "mpvkey = \""),
                  let rangeB = text.range(of: "\";\nvar imagelist = "),
                  let rangeC = text.range(of: "\"}]")
            else { continue }

            tmpMPVKey = String(text[rangeA.upperBound..<rangeB.lowerBound])

            guard let data = String(text[rangeB.upperBound..<rangeC.upperBound])
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "\"", with: "\"")
                .replacingOccurrences(of: "\n", with: "")
                .data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(
                    with: data) as? [[String: String]]
            else { throw AppError.parseFailed }

            array.enumerated().forEach { (index, dict) in
                if let imgKey = dict["k"] {
                    imgKeys[index + 1] = imgKey
                }
            }
        }

        guard let mpvKey = tmpMPVKey, !imgKeys.isEmpty
        else { throw AppError.parseFailed }

        return (mpvKey, imgKeys)
    }
}
