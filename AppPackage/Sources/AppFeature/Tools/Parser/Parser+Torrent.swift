import Kanna
import AppModels
import Foundation

extension Parser {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parseGalleryTorrents(doc: HTMLDocument) -> [GalleryTorrent] {
        var torrents = [GalleryTorrent]()

        for link in doc.xpath("//form") {
            var tmpPostedTime: String?
            var tmpFileSize: String?
            var tmpSeedCount: Int?
            var tmpPeerCount: Int?
            var tmpDownloadCount: Int?
            var tmpUploader: String?
            var tmpFileName: String?
            var tmpHash: String?
            var tmpTorrentURL: URL?

            for trLink in link.xpath("//tr") {
                for tdLink in trLink.xpath("//td") {
                    if let tdText = tdLink.text {
                        if tdText.contains("Posted: ") {
                            tmpPostedTime = tdText.replacingOccurrences(of: "Posted: ", with: "")
                        }
                        if tdText.contains("Size: ") {
                            tmpFileSize = tdText.replacingOccurrences(of: "Size: ", with: "")
                        }
                        if tdText.contains("Seeds: ") {
                            tmpSeedCount = Int(tdText.replacingOccurrences(of: "Seeds: ", with: ""))
                        }
                        if tdText.contains("Peers: ") {
                            tmpPeerCount = Int(tdText.replacingOccurrences(of: "Peers: ", with: ""))
                        }
                        if tdText.contains("Downloads: ") {
                            tmpDownloadCount = Int(tdText.replacingOccurrences(of: "Downloads: ", with: ""))
                        }
                        if tdText.contains("Uploader: ") {
                            tmpUploader = tdText.replacingOccurrences(of: "Uploader: ", with: "")
                        }
                    }
                    if let aLink = tdLink.at_xpath("//a"),
                       let aHref = aLink["href"],
                       let aText = aLink.text,
                       let aURL = URL(string: aHref),
                       let range = aURL.lastPathComponent.range(of: ".torrent") {
                        tmpHash = String(aURL.lastPathComponent[..<range.lowerBound])
                        tmpTorrentURL = aURL
                        tmpFileName = aText
                    }
                }
            }

            guard let postedTime = tmpPostedTime,
                  let postedDate = try? parseDate(
                    time: postedTime,
                    format: Defaults.DateFormat.torrent
                  ),
                  let fileSize = tmpFileSize,
                  let seedCount = tmpSeedCount,
                  let peerCount = tmpPeerCount,
                  let downloadCount = tmpDownloadCount,
                  let uploader = tmpUploader,
                  let fileName = tmpFileName,
                  let hash = tmpHash,
                  let torrentURL = tmpTorrentURL
            else { continue }

            torrents.append(
                GalleryTorrent(
                    postedDate: postedDate,
                    fileSize: fileSize,
                    seedCount: seedCount,
                    peerCount: peerCount,
                    downloadCount: downloadCount,
                    uploader: uploader,
                    fileName: fileName,
                    hash: hash,
                    torrentURL: torrentURL
                )
            )
        }

        return torrents
    }
}
