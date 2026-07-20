import Kanna
import AppModels
import Foundation

extension Parser {
    // MARK: ImageURL
    public static func parseThumbnailURLs(doc: HTMLDocument) throws -> [Int: URL] {
        var thumbnailURLs = [Int: URL]()

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { throw AppError.parseFailed }

        for aLink in gdtNode.xpath("a") {
            guard let href = aLink["href"],
                  let thumbnailURL = URL(string: href),
                  let divNode = aLink.at_xpath(".//div[@title and @style]"),
                  let title = divNode["title"],
                  let page = parseGTX00IndexFromTitle(from: title)
            else { continue }

            thumbnailURLs[page] = thumbnailURL
        }

        return thumbnailURLs
    }

    public static func parseGalleryNormalImageURL(doc: HTMLDocument, index: Int) throws -> GalleryNormalImageInfo {
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

    public static func parseMPVKeys(doc: HTMLDocument) throws -> (String, [Int: String]) {
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
                .data(using: .utf8)
            else { throw AppError.parseFailed }

            let array: [[String: String]]
            do throws(AppError) {
                let jsonObject: Any
                do {
                    jsonObject = try JSONSerialization.jsonObject(with: data)
                } catch {
                    throw AppError.parseFailed
                }
                guard let parsedArray = jsonObject as? [[String: String]]
                else { throw AppError.parseFailed }
                array = parsedArray
            } catch {
                throw AppError.parseFailed
            }

            // The image list is ordered, and its keys are addressed by 1-based page number.
            for (page, dict) in zip(1..., array) {
                if let imgKey = dict["k"] {
                    imgKeys[page] = imgKey
                }
            }
        }

        guard let mpvKey = tmpMPVKey, !imgKeys.isEmpty
        else { throw AppError.parseFailed }

        return (mpvKey, imgKeys)
    }
}
