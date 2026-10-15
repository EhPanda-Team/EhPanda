import AppModels
import Foundation
import Testing

@Suite
struct GalleryListPresentationTests {
    @Test
    func everyScopeHasAnIndependentCodableChoice() throws {
        var presentation = GalleryListPresentation()
        for (index, scope) in GalleryListScope.allCases.enumerated() {
            presentation[scope] = index.isMultiple(of: 2) ? .row : .grid
        }

        let decoded = try JSONDecoder().decode(
            GalleryListPresentation.self,
            from: JSONEncoder().encode(presentation)
        )

        for (index, scope) in GalleryListScope.allCases.enumerated() {
            #expect(decoded[scope] == (index.isMultiple(of: 2) ? .row : .grid))
        }
    }

    @Test
    func aFreshPresentationStartsEveryScopeInRowMode() {
        #expect(
            GalleryListScope.allCases.allSatisfy({ GalleryListPresentation()[$0] == .row })
        )
    }
}
