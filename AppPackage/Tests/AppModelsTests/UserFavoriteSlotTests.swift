import AppModels
import Testing

/// A gallery page names its favorites slot, never numbers it; the slot is recovered from the name.
struct UserFavoriteSlotTests {
    @Test
    func aDefaultNameIsItsOwnSlot() {
        let user = User()
        #expect(user.favoriteSlot(named: "Favorites 0") == 0)
        #expect(user.favoriteSlot(named: "Favorites 9") == 9)
    }

    @Test
    func aRenamedSlotIsFoundThroughTheUsersFolderNames() {
        let user = User(favoriteCategories: [0: "Favorites 0", 3: "Read later", 5: "Favorites 5"])
        #expect(user.favoriteSlot(named: "Read later") == 3)
    }

    @Test
    func theUsersOwnNamesWinOverTheDefaultPattern() {
        // Slot 7 was renamed to the default name of slot 2: the name belongs to the folder that carries it.
        let user = User(favoriteCategories: [7: "Favorites 2"])
        #expect(user.favoriteSlot(named: "Favorites 2") == 7)
    }

    @Test(arguments: ["", "Read later", "Favorites 10", "Favorites -1", "Favorites"])
    func anUnknownNameHasNoSlot(_ name: String) {
        #expect(User().favoriteSlot(named: name) == nil)
    }
}
