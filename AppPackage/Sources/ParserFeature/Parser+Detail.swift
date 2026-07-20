import Kanna
import AppModels
import Foundation
import AppTools

extension Parser {
    public static func parseGalleryURL(doc: HTMLDocument) throws -> URL {
        guard let galleryURLString = doc.at_xpath("//div [@class='sb']")?.at_xpath("//a")?["href"],
              let galleryURL = URL(string: galleryURLString) else { throw AppError.parseFailed }
        return galleryURL
    }

    // swiftlint:disable:next function_body_length
    public static func parseGalleryDetail(
        doc: HTMLDocument, gid: String
    ) throws -> (detail: GalleryDetail, state: GalleryState) {
        var tmpGalleryDetail: GalleryDetail?
        var tmpGalleryState: GalleryState?
        for link in doc.xpath("//div [@class='gm']") {
            guard tmpGalleryDetail == nil, tmpGalleryState == nil,
                  let gd3Node = link.at_xpath("//div [@id='gd3']"),
                  let gd4Node = link.at_xpath("//div [@id='gd4']"),
                  let gd5Node = link.at_xpath("//div [@id='gd5']"),
                  let gddNode = gd3Node.at_xpath("//div [@id='gdd']"),
                  let gdrNode = gd3Node.at_xpath("//div [@id='gdr']"),
                  let gdfNode = gd3Node.at_xpath("//div [@id='gdf']"),
                  // A malformed cover intentionally rejects only this detail candidate.
                  let coverURL = degrading("Cover URL", { try parseCoverURL(node: link) }),
                  // Malformed tags intentionally reject only this detail candidate.
                  let tags = degrading("Detail tags", { try parseGalleryTags(node: gd4Node) }),
                  // Malformed previews intentionally reject only this detail candidate.
                  let previewURLs = degrading("Preview URLs", { try parsePreviewURLs(doc: doc) }),
                  // Malformed archive metadata intentionally rejects only this detail candidate.
                  let arcAndTor = degrading("Archive and torrent", { try parseArcAndTor(node: gd5Node) }),
                  // A malformed info panel intentionally rejects only this detail candidate.
                  let infoPanel = degrading("Info panel", { try parseInfoPanel(node: gddNode) }),
                  // Invalid visibility intentionally rejects only this detail candidate.
                  let visibility = degrading("Visibility", {
                      try parseVisibility(value: infoPanel.visibility)
                  }),
                  let sizeCount = Float(infoPanel.fileSize),
                  let pageCount = Int(infoPanel.pageCount),
                  let favoritedCount = Int(infoPanel.favoritedCount),
                  let language = Language(rawValue: infoPanel.language),
                  let engTitle = link.at_xpath("//h1 [@id='gn']")?.text,
                  // A missing uploader intentionally rejects only this detail candidate.
                  let uploader = degrading("Uploader", { try parseUploader(node: gd3Node) }),
                  // An invalid rating intentionally rejects only this detail candidate.
                  let ratingResult = degrading("Rating", { try parseRating(node: gdrNode) }),
                  let ratingCount = Int(gdrNode.at_xpath("//span [@id='rating_count']")?.text ?? ""),
                  let category = AppModels.Category(rawValue: gd3Node.at_xpath("//div [@id='gdc']")?.text ?? ""),
                  // An invalid posted date intentionally rejects only this detail candidate.
                  let postedDate = degrading("Posted date", {
                      try parseDate(time: infoPanel.postedDate, format: Defaults.DateFormat.publish)
                  })
            else { continue }

            let isFavorited = gdfNode
                .at_xpath("//a [@id='favoritelink']")?
                .text?.contains("Add to Favorites") == false
            let gjText = link.at_xpath("//h1 [@id='gj']")?.text
            let jpnTitle = gjText?.isEmpty != false ? nil : gjText
            let parentURLString = infoPanel.parentURL.isValidURL ? infoPanel.parentURL : ""

            tmpGalleryDetail = GalleryDetail(
                gid: gid,
                title: engTitle,
                jpnTitle: jpnTitle,
                isFavorited: isFavorited,
                visibility: visibility,
                rating: ratingResult.containsUserRating ? ratingResult.textRating ?? 0.0 : ratingResult.imgRating,
                userRating: ratingResult.containsUserRating ? ratingResult.imgRating : 0.0,
                ratingCount: ratingCount,
                category: category,
                language: language,
                uploader: uploader,
                postedDate: postedDate,
                coverURL: coverURL,
                archiveURL: arcAndTor.archiveURL,
                parentURL: URL(string: parentURLString),
                favoritedCount: favoritedCount,
                pageCount: pageCount,
                sizeCount: sizeCount,
                sizeType: infoPanel.sizeType,
                torrentCount: arcAndTor.torrentCount
            )
            tmpGalleryState = GalleryState(
                gid: gid,
                tags: tags,
                previewURLs: previewURLs,
                // Missing preview layout metadata intentionally degrades to nil.
                previewConfig: degrading("Preview config", { try parsePreviewConfig(doc: doc) }),
                comments: parseComments(doc: doc)
            )
            break
        }

        guard let galleryDetail = tmpGalleryDetail,
              let galleryState = tmpGalleryState
        else {
            if let reason = doc.at_xpath("//div [@class='d']")?.at_xpath("//p")?.text {
                if let rangeA = reason.range(of: "copyright claim by "),
                   let rangeB = reason.range(of: ".Sorry about that.") {
                    let owner = String(reason[rangeA.upperBound..<rangeB.lowerBound])
                    throw AppError.copyrightClaim(owner)
                } else {
                    throw AppError.expunged(reason)
                }
            } else if let error = parseResponseError(doc: doc) {
                throw error
            } else {
                throw AppError.parseFailed
            }
        }

        return (galleryDetail, galleryState)
    }
}

// MARK: Helpers
private extension Parser {
    static func parsePreviewMode(doc: HTMLDocument) throws -> String {
        if doc.at_xpath("//div [@class='gt100']") != nil {
            return "gt100"
        } else if doc.at_xpath("//div [@class='gt200']") != nil {
            return "gt200"
        } else {
            throw AppError.parseFailed
        }
    }

    static func parsePreviewConfig(doc: HTMLDocument) throws -> PreviewConfig {
        let previewMode = try parsePreviewMode(doc: doc)
        guard let gpcText = doc.at_xpath("//p [@class='gpc']")?.text,
              let rangeA = gpcText.range(of: "Showing 1 - "),
              let rangeB = gpcText.range(of: " of "),
              let singlePageCount = Int(gpcText[rangeA.upperBound..<rangeB.lowerBound])
        else { throw AppError.parseFailed }

        let isLargePreview = previewMode == "gt200"
        let factor = isLargePreview ? 1 : 2
        let rowsCount =
        switch singlePageCount {
        case _ where singlePageCount <= 20 * factor: 4
        case _ where singlePageCount <= 40 * factor: 8
        case _ where singlePageCount <= 100 * factor: 20
        case _ where singlePageCount <= 200 * factor: 40
        default: 4
        }
        return isLargePreview ? .large(rows: rowsCount) : .normal(rows: rowsCount)
    }

    static func parseCoverURL(node: XMLElement?) throws -> URL {
        guard let coverHTML = node?.at_xpath("//div [@id='gd1']")?.innerHTML,
              let rangeA = coverHTML.range(of: "url("), let rangeB = coverHTML.range(of: ")"),
              let url = URL(string: .init(coverHTML[rangeA.upperBound..<rangeB.lowerBound]))
        else { throw AppError.parseFailed }

        return url
    }

    static func parseGalleryTags(node: XMLElement) throws -> [GalleryTag] {
        var tags = [GalleryTag]()
        for link in node.xpath("//tr") {
            guard let tcText = link.at_xpath("//td [@class='tc']")?.text else { continue }
            let namespace = String(tcText.dropLast())
            var contents = [GalleryTag.Content]()
            for divLink in link.xpath("//div") {
                guard var text = divLink.text, let aClass = divLink.at_xpath("//a")?.className else { continue }
                if let range = text.range(of: " | ") {
                    text = .init(text[..<range.lowerBound])
                }
                contents.append(
                    .init(
                        rawNamespace: namespace, text: text,
                        isVotedUp: aClass == "tup",
                        isVotedDown: aClass == "tdn",
                        textColor: nil,
                        backgroundColor: nil
                    )
                )
            }

            tags.append(.init(rawNamespace: namespace, contents: contents))
        }

        return tags
    }

    static func parseArcAndTor(node: XMLElement?) throws -> (archiveURL: URL?, torrentCount: Int) {
        guard let node = node else { throw AppError.parseFailed }

        var archiveURL: URL?
        for g2gspLink in node.xpath("//p [@class='g2 gsp']") {
            if archiveURL == nil {
                // A malformed optional archive link intentionally degrades to nil.
                archiveURL = degrading("Archive URL", { try parseArchiveURL(node: g2gspLink) })
            } else {
                break
            }
        }

        var tmpTorrentCount: Int?
        for g2Link in node.xpath("//p [@class='g2']") {
            if let aText = g2Link.at_xpath("//a")?.text,
               let rangeA = aText.range(of: "Torrent Download ("),
               let rangeB = aText.range(of: ")") {
                tmpTorrentCount = Int(aText[rangeA.upperBound..<rangeB.lowerBound])
            }
            if archiveURL == nil {
                // A malformed fallback archive link intentionally degrades to nil.
                archiveURL = degrading("Fallback archive URL", { try parseArchiveURL(node: g2Link) })
            }
        }

        guard let torrentCount = tmpTorrentCount
        else { throw AppError.parseFailed }

        return (archiveURL, torrentCount)
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func parseInfoPanel(node: XMLElement?) throws -> InfoPanel {
        guard let object = node?.xpath("//tr")
        else { throw AppError.parseFailed }

        var postedDate = ""
        var parentURL = ""
        var visibility = ""
        var language = ""
        var fileSize = ""
        var sizeType = ""
        var pageCount = ""
        var favoritedCount = ""
        for gddLink in object {
            guard let gdt1Text = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                  let gdt2Text = gddLink.at_xpath("//td [@class='gdt2']")?.text
            else { continue }
            let aHref = gddLink.at_xpath("//td [@class='gdt2']")?.at_xpath("//a")?["href"]

            if gdt1Text.contains("Posted") {
                postedDate = gdt2Text
            }
            if gdt1Text.contains("Parent") {
                parentURL = aHref ?? "None"
            }
            if gdt1Text.contains("Visible") {
                visibility = gdt2Text
            }
            if gdt1Text.contains("Language"), let firstWord = gdt2Text.split(separator: " ").first {
                language = firstWord.trimmingCharacters(in: .whitespaces)
            }
            if gdt1Text.contains("File Size") {
                fileSize = gdt2Text
                    .replacingOccurrences(of: " KiB", with: "")
                    .replacingOccurrences(of: " MiB", with: "")
                    .replacingOccurrences(of: " GiB", with: "")

                if gdt2Text.contains("KiB") { sizeType = "KiB" }
                if gdt2Text.contains("MiB") { sizeType = "MiB" }
                if gdt2Text.contains("GiB") { sizeType = "GiB" }
            }
            if gdt1Text.contains("Length") {
                pageCount = gdt2Text.replacingOccurrences(of: " pages", with: "")
            }
            if gdt1Text.contains("Favorited") {
                favoritedCount = gdt2Text
                    .replacingOccurrences(of: " times", with: "")
                    .replacingOccurrences(of: "Never", with: "0")
                    .replacingOccurrences(of: "Once", with: "1")
            }
        }

        // Every field must have been filled — a partially scraped panel is a parse failure.
        guard ![postedDate, parentURL, visibility, language,
                fileSize, sizeType, pageCount, favoritedCount].contains(where: \.isEmpty)
        else { throw AppError.parseFailed }

        return InfoPanel(
            postedDate: postedDate,
            parentURL: parentURL,
            visibility: visibility,
            language: language,
            fileSize: fileSize,
            sizeType: sizeType,
            pageCount: pageCount,
            favoritedCount: favoritedCount
        )
    }

    static func parseVisibility(value: String) throws -> GalleryVisibility {
        guard value != "Yes" else { return .yes }
        guard let rangeA = value.range(of: "("),
              let rangeB = value.range(of: ")")
        else { throw AppError.parseFailed }

        let reason = String(value[rangeA.upperBound..<rangeB.lowerBound])
        return .no(reason: reason)
    }

    static func parseUploader(node: XMLElement?) throws -> String {
        guard let gdnNode = node?.at_xpath("//div [@id='gdn']") else {
            throw AppError.parseFailed
        }

        if let aText = gdnNode.at_xpath("//a")?.text {
            return aText
        } else if let gdnText = gdnNode.text {
            return gdnText
        } else {
            throw AppError.parseFailed
        }
    }
}
