import Kanna

extension Parser {
    static func parseProfileIndex(doc: HTMLDocument) throws -> VerifyEhProfileResponse {
        var profileNotFound = true
        var profileValue: Int?

        let selector = doc.at_xpath("//select [@name='profile_set']")
        let options = selector?.xpath("//option")

        guard let options = options, options.count >= 1
        else { throw AppError.parseFailed }

        for link in options where EhSetting.verifyEhPandaProfileName(with: link.text) {
            profileNotFound = false
            profileValue = Int(link["value"] ?? "")
        }

        return .init(profileValue: profileValue, isProfileNotFound: profileNotFound)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parseEhSetting(doc: HTMLDocument) throws -> EhSetting {
        var tmpForm: XMLElement?
        for link in doc.xpath("//form [@method='post']")
        where link["id"] == nil {
            tmpForm = link
        }
        guard let profileOuter = doc.at_xpath("//div [@id='profile_outer']"),
              let form = tmpForm else { throw AppError.parseFailed }

        // swiftlint:disable line_length
        var ehProfiles = [EhProfile](); var isCapableOfCreatingNewProfile: Bool?; var capableLoadThroughHathSetting: EhSetting.LoadThroughHathSetting?; var capableImageResolution: EhSetting.ImageResolution?; var capableSearchResultCount: EhSetting.SearchResultCount?; var capableThumbnailConfigSizes = [EhSetting.ThumbnailSize](); var capableThumbnailConfigRowCount: EhSetting.ThumbnailRowCount?; var loadThroughHathSetting: EhSetting.LoadThroughHathSetting?; var browsingCountry: EhSetting.BrowsingCountry?; var imageResolution: EhSetting.ImageResolution?; var imageSizeWidth: Float?; var imageSizeHeight: Float?; var galleryName: EhSetting.GalleryName?; var literalBrowsingCountry: String?; var archiverBehavior: EhSetting.ArchiverBehavior?; var displayMode: EhSetting.DisplayMode?; var showSearchRangeIndicator: Bool?; var enableGalleryThumbnailSelector: Bool?; var disabledCategories = [Bool](); var favoriteCategories = [String](); var favoritesSortOrder: EhSetting.FavoritesSortOrder?; var ratingsColor: String?; var tagFilteringThreshold: Float?; var tagWatchingThreshold: Float?; var showFilteredRemovalCount: Bool?; var excludedLanguages = [Bool](); var excludedUploaders: String?; var searchResultCount: EhSetting.SearchResultCount?; var thumbnailLoadTiming: EhSetting.ThumbnailLoadTiming?; var thumbnailConfigSize: EhSetting.ThumbnailSize?; var thumbnailConfigRows: EhSetting.ThumbnailRowCount?; var coverScaleFactor: Float?; var viewportVirtualWidth: Float?; var commentsSortOrder: EhSetting.CommentsSortOrder?; var commentVotesShowTiming: EhSetting.CommentVotesShowTiming?; var tagsSortOrder: EhSetting.TagsSortOrder?; var galleryPageNumbers: EhSetting.GalleryPageNumbering?; var useOriginalImages: Bool?; var useMultiplePageViewer: Bool?; var multiplePageViewerStyle: EhSetting.MultiplePageViewerStyle?; var multiplePageViewerShowThumbnailPane: Bool?
        // swiftlint:enable line_length

        ehProfiles = parseSelections(node: profileOuter, name: "profile_set")
            .compactMap { option in
                guard let value = Int(option.value) else { return nil }
                return EhProfile(value: value, name: option.name, isSelected: option.isSelected)
            }

        for button in profileOuter.xpath("//input [@type='button']") {
            if button["value"] == "Create New" {
                isCapableOfCreatingNewProfile = true
                break
            } else {
                isCapableOfCreatingNewProfile = false
            }
        }

        for optouter in form.xpath("//div [@class='optouter']") {
            if optouter.at_xpath("//input [@name='uh']") != nil {
                loadThroughHathSetting = parseEnum(node: optouter, name: "uh")
                capableLoadThroughHathSetting = parseCapability(node: optouter, name: "uh")
            }
            if optouter.at_xpath("//select [@name='co']") != nil {
                var value = parseSelections(node: optouter, name: "co")
                    .filter(\.isSelected)
                    .first?
                    .value

                if value == "" { value = "-" }
                browsingCountry = EhSetting.BrowsingCountry(rawValue: value ?? "")

                if let pText = optouter.at_xpath("//p")?.text,
                   let rangeA = pText.range(of: "You appear to be browsing the site from "),
                   let rangeB = pText.range(of: " or use a VPN or proxy in this country") {
                    literalBrowsingCountry = String(pText[rangeA.upperBound..<rangeB.lowerBound])
                }
            }
            if optouter.at_xpath("//input [@name='xr']") != nil {
                imageResolution = parseEnum(node: optouter, name: "xr")
                capableImageResolution = parseCapability(node: optouter, name: "xr")
            }
            if optouter.at_xpath("//input [@name='rx']") != nil {
                imageSizeWidth = Float(parseString(node: optouter, name: "rx") ?? "0")
                if imageSizeWidth == nil { imageSizeWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='ry']") != nil {
                imageSizeHeight = Float(parseString(node: optouter, name: "ry") ?? "0")
                if imageSizeHeight == nil { imageSizeHeight = 0 }
            }
            if optouter.at_xpath("//input [@name='tl']") != nil {
                galleryName = parseEnum(node: optouter, name: "tl")
            }
            if optouter.at_xpath("//input [@name='ar']") != nil {
                archiverBehavior = parseEnum(node: optouter, name: "ar")
            }
            if optouter.at_xpath("//input [@name='dm']") != nil {
                displayMode = parseEnum(node: optouter, name: "dm")
            }
            if optouter.at_xpath("//input [@name='pp']") != nil {
                showSearchRangeIndicator = parseInt(node: optouter, name: "pp") == 0
            }
            if optouter.at_xpath("//input [@name='xn_0']") != nil {
                enableGalleryThumbnailSelector = parseCheckBoxBool(node: optouter, name: "xn_0")
            }
            if optouter.at_xpath("//div [@id='catsel']") != nil {
                disabledCategories = Array(0...9)
                    .map { "ct_\(EhSetting.categoryNames[$0])" }
                    .compactMap { parseBool(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//div [@id='favsel']") != nil {
                favoriteCategories = Array(0...9).map { "favorite_\($0)" }
                    .compactMap { parseString(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//input [@name='fs']") != nil {
                favoritesSortOrder = parseEnum(node: optouter, name: "fs")
            }
            if optouter.at_xpath("//input [@name='ru']") != nil {
                ratingsColor = parseString(node: optouter, name: "ru") ?? ""
            }
            if optouter.at_xpath("//input [@name='ft']") != nil {
                tagFilteringThreshold = Float(parseString(node: optouter, name: "ft") ?? "0")
                if tagFilteringThreshold == nil { tagFilteringThreshold = 0 }
            }
            if optouter.at_xpath("//input [@name='wt']") != nil {
                tagWatchingThreshold = Float(parseString(node: optouter, name: "wt") ?? "0")
                if tagWatchingThreshold == nil { tagWatchingThreshold = 0 }
            }
            if optouter.at_xpath("//input [@name='tf']") != nil {
                showFilteredRemovalCount = parseInt(node: optouter, name: "tf") == 0
            }
            if optouter.at_xpath("//div [@id='xlasel']") != nil {
                excludedLanguages = Array(0...49)
                    .map { "xl_\(EhSetting.languageValues[$0])" }
                    .compactMap { parseCheckBoxBool(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//textarea [@name='xu']") != nil {
                excludedUploaders = parseTextEditorString(node: optouter, name: "xu") ?? ""
            }
            if optouter.at_xpath("//input [@name='rc']") != nil {
                searchResultCount = parseEnum(node: optouter, name: "rc")
                capableSearchResultCount = parseCapability(node: optouter, name: "rc")
            }
            if optouter.at_xpath("//input [@name='lt']") != nil {
                thumbnailLoadTiming = parseEnum(node: optouter, name: "lt")
            }
            if optouter.at_xpath("//input [@name='ts']") != nil {
                var options = [ThumbnailSizeOption]()
                for link in optouter.xpath("//input [@name='ts']") {
                    if let valueString = link["value"], let value = Int(valueString) {
                        let isEnabled = link["disabled"] != "disabled"
                        let isSelected = link["checked"] == "checked"
                        options.append(
                            ThumbnailSizeOption(
                                value: value,
                                isEnabled: isEnabled,
                                isSelected: isSelected
                            )
                        )
                    }
                }
                let thumbnailSize: (Int) -> EhSetting.ThumbnailSize? = {
                    switch $0 {
                    case 0: .auto
                    case 1: .normal
                    case 2: .small
                    default: nil
                    }
                }
                for option in options where option.isEnabled {
                    if let size = thumbnailSize(option.value) {
                        capableThumbnailConfigSizes.append(size)
                    }
                }
                if let selectedSize = (options.first(where: \.isSelected)?.value).flatMap(thumbnailSize) {
                    thumbnailConfigSize = selectedSize
                }
            }
            if optouter.at_xpath("//input [@name='tr']") != nil {
                thumbnailConfigRows = parseEnum(node: optouter, name: "tr")
                capableThumbnailConfigRowCount = parseCapability(node: optouter, name: "tr")
            }
            if optouter.at_xpath("//input [@name='tp']") != nil {
                coverScaleFactor = Float(parseString(node: optouter, name: "tp") ?? "100")
                if coverScaleFactor == nil { coverScaleFactor = 100 }
            }
            if optouter.at_xpath("//input [@name='vp']") != nil {
                viewportVirtualWidth = Float(parseString(node: optouter, name: "vp") ?? "0")
                if viewportVirtualWidth == nil { viewportVirtualWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='cs']") != nil {
                commentsSortOrder = parseEnum(node: optouter, name: "cs")
            }
            if optouter.at_xpath("//input [@name='sc']") != nil {
                commentVotesShowTiming = parseEnum(node: optouter, name: "sc")
            }
            if optouter.at_xpath("//input [@name='tb']") != nil {
                tagsSortOrder = parseEnum(node: optouter, name: "tb")
            }
            if optouter.at_xpath("//input [@name='pn']") != nil {
                galleryPageNumbers = parseEnum(node: optouter, name: "pn")
            }
            if optouter.at_xpath("//input [@name='oi']") != nil {
                useOriginalImages = parseInt(node: optouter, name: "oi") == 1
            }
            if optouter.at_xpath("//input [@name='qb']") != nil {
                useMultiplePageViewer = parseInt(node: optouter, name: "qb") == 1
            }
            if optouter.at_xpath("//input [@name='ms']") != nil {
                multiplePageViewerStyle = parseEnum(node: optouter, name: "ms")
            }
            if optouter.at_xpath("//input [@name='mt']") != nil {
                multiplePageViewerShowThumbnailPane = parseInt(node: optouter, name: "mt") == 0
            }
        }

        // swiftlint:disable line_length
        guard !ehProfiles.filter(\.isSelected).isEmpty, let isCapableOfCreatingNewProfile, let capableLoadThroughHathSetting, let capableImageResolution, let capableSearchResultCount, !capableThumbnailConfigSizes.isEmpty, let capableThumbnailConfigRowCount, let loadThroughHathSetting, let browsingCountry, let literalBrowsingCountry, let imageResolution, let imageSizeWidth, let imageSizeHeight, let galleryName, let archiverBehavior, let displayMode, let showSearchRangeIndicator, let enableGalleryThumbnailSelector, disabledCategories.count == 10, favoriteCategories.count == 10, let favoritesSortOrder, let ratingsColor, let tagFilteringThreshold, let tagWatchingThreshold, let showFilteredRemovalCount, excludedLanguages.count == 50, let excludedUploaders, let searchResultCount, let thumbnailLoadTiming, let thumbnailConfigSize, let thumbnailConfigRows, let coverScaleFactor, let viewportVirtualWidth, let commentsSortOrder, let commentVotesShowTiming, let tagsSortOrder, let galleryPageNumbers
        else { throw AppError.parseFailed }

        return EhSetting(ehProfiles: ehProfiles.sorted(), isCapableOfCreatingNewProfile: isCapableOfCreatingNewProfile, capableLoadThroughHathSetting: capableLoadThroughHathSetting, capableImageResolution: capableImageResolution, capableSearchResultCount: capableSearchResultCount, capableThumbnailConfigRowCount: capableThumbnailConfigRowCount, capableThumbnailConfigSizes: capableThumbnailConfigSizes, loadThroughHathSetting: loadThroughHathSetting, browsingCountry: browsingCountry, literalBrowsingCountry: literalBrowsingCountry, imageResolution: imageResolution, imageSizeWidth: imageSizeWidth, imageSizeHeight: imageSizeHeight, galleryName: galleryName, archiverBehavior: archiverBehavior, displayMode: displayMode, showSearchRangeIndicator: showSearchRangeIndicator, enableGalleryThumbnailSelector: enableGalleryThumbnailSelector, disabledCategories: disabledCategories, favoriteCategories: favoriteCategories, favoritesSortOrder: favoritesSortOrder, ratingsColor: ratingsColor, tagFilteringThreshold: tagFilteringThreshold, tagWatchingThreshold: tagWatchingThreshold, showFilteredRemovalCount: showFilteredRemovalCount, excludedLanguages: excludedLanguages, excludedUploaders: excludedUploaders, searchResultCount: searchResultCount, thumbnailLoadTiming: thumbnailLoadTiming, thumbnailConfigSize: thumbnailConfigSize, thumbnailConfigRows: thumbnailConfigRows, coverScaleFactor: coverScaleFactor, viewportVirtualWidth: viewportVirtualWidth, commentsSortOrder: commentsSortOrder, commentVotesShowTiming: commentVotesShowTiming, tagsSortOrder: tagsSortOrder, galleryPageNumbering: galleryPageNumbers, useOriginalImages: useOriginalImages, useMultiplePageViewer: useMultiplePageViewer, multiplePageViewerStyle: multiplePageViewerStyle, multiplePageViewerShowThumbnailPane: multiplePageViewerShowThumbnailPane
        )
        // swiftlint:enable line_length
    }
}

// MARK: Helpers
private extension Parser {

    static func parseInt(node: XMLElement, name: String) -> Int? {
        var value: Int?
        for link in node.xpath("//input [@name='\(name)']")
        where link["checked"] == "checked" {
            value = Int(link["value"] ?? "")
        }
        return value
    }

    static func parseEnum<T: RawRepresentable>(node: XMLElement, name: String) -> T? where T.RawValue == Int {
        guard let rawValue = parseInt(
            node: node, name: name
        ) else { return nil }
        return T(rawValue: rawValue)
    }

    static func parseString(node: XMLElement, name: String) -> String? {
        node.at_xpath("//input [@name='\(name)']")?["value"]
    }

    static func parseTextEditorString(node: XMLElement, name: String) -> String? {
        node.at_xpath("//textarea [@name='\(name)']")?.text
    }

    static func parseBool(node: XMLElement, name: String) -> Bool? {
        switch parseString(node: node, name: name) {
        case "0": return false
        case "1": return true
        default: return nil
        }
    }

    static func parseCheckBoxBool(node: XMLElement, name: String) -> Bool? {
        node.at_xpath("//input [@name='\(name)']")?["checked"] == "checked"
    }

    static func parseCapability<T: RawRepresentable>(node: XMLElement, name: String) -> T? where T.RawValue == Int {
        var maxValue: Int?
        for link in node.xpath("//input [@name='\(name)']") where link["disabled"] != "disabled" {
            let value = Int(link["value"] ?? "") ?? 0
            if maxValue == nil {
                maxValue = value
            } else if maxValue ?? 0 < value {
                maxValue = value
            }
        }
        return T(rawValue: maxValue ?? 0)
    }

    static func parseSelections(node: XMLElement, name: String) -> [SelectionOption] {
        guard let select = node.at_xpath("//select [@name='\(name)']")
        else { return [] }

        var selections = [SelectionOption]()
        for link in select.xpath("//option") {
            guard let name = link.text,
                  let value = link["value"]
            else { continue }

            selections.append(
                SelectionOption(
                    name: name,
                    value: value,
                    isSelected: link["selected"] == "selected"
                )
            )
        }

        return selections
    }
}
