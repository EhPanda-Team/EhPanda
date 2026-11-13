import AppTools
import SwiftUI
import Testing

struct FavoriteColorTests {
    @Test
    func thereIsOneColourPerFavoritesSlot() {
        #expect(Defaults.FavoriteColor.colors.count == 10)
        #expect(Set(Defaults.FavoriteColor.colors).count == 10)
    }

    @Test(arguments: 0...9)
    func everySlotHasItsColour(_ index: Int) {
        #expect(Defaults.FavoriteColor.color(at: index) == Defaults.FavoriteColor.colors[index])
    }

    // Regression: #462 indexed `colors[index]` unchecked, so a slot the app did not know (the site
    // numbering is 0...9 today, but a parsed value is only as good as the page) trapped in a list cell.
    @Test(arguments: [nil, -1, 10, 11, Int.max, Int.min] as [Int?])
    func anIndexOutsideTheSlotsHasNoColourInsteadOfTrapping(_ index: Int?) {
        #expect(Defaults.FavoriteColor.color(at: index) == nil)
    }
}
