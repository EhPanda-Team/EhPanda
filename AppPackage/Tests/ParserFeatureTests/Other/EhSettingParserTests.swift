@testable import AppFeature
import AppModels
import Kanna
import ParserFeature
import Testing
import TestingSupport

struct EhSettingParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .ehSetting)
        let ehSetting = try Parser.parseEhSetting(doc: document)
        testEhProfiles(ehSetting.ehProfiles)
        testCapability(ehSetting: ehSetting)
        testRemainingStuff(ehSetting: ehSetting)
    }

    func testEhProfiles(_ profiles: [EhProfile]) {
        #expect(profiles.count == 4)

        let ehProfile1 = profiles[0]
        #expect(ehProfile1.value == 1)
        #expect(ehProfile1.name == "Default Profile")
        #expect(ehProfile1.isSelected == true)
        #expect(ehProfile1.isDefault == true)

        let ehProfile2 = profiles[1]
        #expect(ehProfile2.value == 2)
        #expect(ehProfile2.name == "EhPanda")
        #expect(ehProfile2.isSelected == false)
        #expect(ehProfile2.isDefault == false)
        #expect(EhSetting.verifyEhPandaProfileName(with: ehProfile2.name))

        let ehProfile3 = profiles[2]
        #expect(ehProfile3.value == 3)
        #expect(ehProfile3.name == "Mock Profile 3")
        #expect(ehProfile3.isSelected == false)
        #expect(ehProfile3.isDefault == false)

        let ehProfile4 = profiles[3]
        #expect(ehProfile4.value == 4)
        #expect(ehProfile4.name == "Mock Profile 4")
        #expect(ehProfile4.isSelected == false)
        #expect(ehProfile4.isDefault == false)
    }

    func testCapability(ehSetting: EhSetting) {
        #expect(ehSetting.capableLoadThroughHathSetting == .legacyNo)
        #expect(ehSetting.capableLoadThroughHathSettings == EhSetting.LoadThroughHathSetting.allCases)

        #expect(ehSetting.capableImageResolution == .x2560)
        #expect(ehSetting.capableImageResolutions == EhSetting.ImageResolution.allCases)

        #expect(ehSetting.capableSearchResultCount == .oneHundred)
        #expect(ehSetting.capableSearchResultCounts == [.twentyFive, .fifty, .oneHundred])

        #expect(ehSetting.capableThumbnailConfigSizes == [.auto, .small, .normal])

        #expect(ehSetting.capableThumbnailConfigRowCount == .forty)
        #expect(ehSetting.capableThumbnailConfigRowCounts == EhSetting.ThumbnailRowCount.allCases)
    }

    func testRemainingStuff(ehSetting: EhSetting) {
        #expect(ehSetting.loadThroughHathSetting == .anyClient)
        #expect(ehSetting.hahRegion == .autoDetect)
        #expect(ehSetting.literalDetectedCountry == "Japan")
        #expect(ehSetting.literalHahRegion == "Asia")
        #expect(ehSetting.imageResolution == .auto)
        #expect(ehSetting.imageSizeWidth == 0)
        #expect(ehSetting.imageSizeHeight == 0)
        #expect(ehSetting.galleryName == .japanese)
        #expect(ehSetting.archiverBehavior == .manualSelectManualStart)
        #expect(ehSetting.displayMode == .compact)
        #expect(ehSetting.showSearchRangeIndicator == true)
        #expect(ehSetting.disabledCategories == .init(repeating: false, count: 10))
        #expect(ehSetting.favoriteCategories == [
            "Favorites 0", "Favorites 1", "Favorites 2", "Favorites 3", "Favorites 4",
            "Favorites 5", "Favorites 6", "Favorites 7", "Favorites 8", "Favorites 9"
        ])
        #expect(ehSetting.favoritesSortOrder == .favoritedTime)
        #expect(ehSetting.ratingsColor == "")
        #expect(ehSetting.tagFilteringThreshold == 0)
        #expect(ehSetting.tagWatchingThreshold == 0)
        #expect(ehSetting.showFilteredRemovalCount == true)
        #expect(ehSetting.excludedLanguages == .init(repeating: false, count: 50))
        #expect(ehSetting.excludedUploaders == "")
        #expect(ehSetting.searchResultCount == .oneHundred)
        #expect(ehSetting.thumbnailLoadTiming == .onMouseOver)
        #expect(ehSetting.thumbnailConfigSize == .auto)
        #expect(ehSetting.thumbnailConfigRows == .four)
        #expect(ehSetting.coverScaleFactor == 100)
        #expect(ehSetting.viewportVirtualWidth == 0)
        #expect(ehSetting.commentsSortOrder == .oldest)
        #expect(ehSetting.commentVotesShowTiming == .onHoverOrClick)
        #expect(ehSetting.tagsSortOrder == .alphabetical)
        #expect(ehSetting.galleryPageNumbering == .none)
        #expect(ehSetting.useOriginalImages == false)
        #expect(ehSetting.useMultiplePageViewer == false)
        #expect(ehSetting.multiplePageViewerStyle == .alignCenterAlwaysScale)
        #expect(ehSetting.multiplePageViewerShowThumbnailPane == false)
    }
}
