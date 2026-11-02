import AppModels
@testable import DetailFeature
import Foundation
import Testing

struct GalleryDetailFileSizeTests {
    struct Size: Sendable {
        let count: Float
        let locale: String
        let text: String
    }

    @Test(arguments: [
        Size(count: 314.3, locale: "en", text: "314.3"),
        Size(count: 97.56, locale: "en", text: "97.56"),
        Size(count: 1024, locale: "en", text: "1024"),
        Size(count: 314.3, locale: "de", text: "314,3")
    ])
    func testSizeKeepsItsDecimalsInTheReadersFormat(size: Size) {
        var detail = GalleryDetail.preview
        detail.sizeCount = size.count
        #expect(detail.formattedSizeCount(locale: Locale(identifier: size.locale)) == size.text)
    }
}
