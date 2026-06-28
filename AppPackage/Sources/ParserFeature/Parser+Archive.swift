import AppTools
import Kanna
import AppModels
import Foundation

extension Parser {
    public static func parseGalleryArchive(doc: HTMLDocument) throws -> GalleryArchive {
        guard let node = doc.at_xpath("//table")
        else { throw AppError.parseFailed }

        var hathArchives = [GalleryArchive.HathArchive]()
        for link in node.xpath("//td") {
            var tmpResolution: ArchiveResolution?
            var tmpFileSize: String?
            var tmpGPPrice: String?

            for pLink in link.xpath("//p") {
                if let pText = pLink.text {
                    if let res = ArchiveResolution(rawValue: pText) {
                        tmpResolution = res
                    }
                    if pText.contains("N/A") {
                        tmpFileSize = "N/A"
                        tmpGPPrice = "N/A"

                        if tmpResolution != nil {
                            break
                        }
                    } else {
                        if pText.contains("KiB")
                            || pText.contains("MiB")
                            || pText.contains("GiB") {
                            tmpFileSize = pText
                        } else {
                            tmpGPPrice = pText
                        }
                    }
                }
            }

            guard let resolution = tmpResolution,
                  let fileSize = tmpFileSize,
                  let gpPrice = tmpGPPrice
            else { continue }

            hathArchives.append(
                GalleryArchive.HathArchive(
                    resolution: resolution,
                    fileSize: fileSize,
                    gpPrice: gpPrice
                )
            )
        }

        return GalleryArchive(hathArchives: hathArchives)
    }

    public static func parseDownloadCommandResponse(doc: HTMLDocument) throws -> String {
        guard let dbNode = doc.at_xpath("//div [@id='db']")
        else { throw AppError.parseFailed }

        var response = [String]()
        for pLink in dbNode.xpath("//p") {
            if let pText = pLink.text {
                response.append(pText)
            }
        }

        var respString = response.joined(separator: " ")

        if let rangeA = respString.range(of: "A ") ?? respString.range(of: "An "),
           let rangeB = respString.range(of: "resolution"),
           let rangeC = respString.range(of: "client"),
           let rangeD = respString.range(of: "Downloads") {
            let resp = String(respString[rangeA.upperBound..<rangeB.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .firstLetterCapitalized

            if ArchiveResolution(rawValue: resp) != nil {
                let clientName = String(respString[rangeC.upperBound..<rangeD.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !clientName.isEmpty {
                    respString = resp + " -> " + clientName
                } else {
                    respString = resp
                }
            }
        }

        return respString
    }

    static func parseArchiveURL(node: XMLElement) throws -> URL {
        var archiveURL: URL?
        if let aLink = node.at_xpath("//a"),
            aLink.text?.contains("Archive Download") == true, let onClick = aLink["onclick"],
            let rangeA = onClick.range(of: "popUp('"), let rangeB = onClick.range(of: "',") {
            archiveURL = URL(string: .init(onClick[rangeA.upperBound..<rangeB.lowerBound]))
        }

        if let url = archiveURL {
            return url
        } else {
            throw AppError.parseFailed
        }
    }
}
