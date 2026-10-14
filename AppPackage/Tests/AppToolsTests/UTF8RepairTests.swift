import AppTools
import Foundation
import Testing

struct UTF8RepairTests {
    @Test(arguments: ["", "Gallery title", "中文・日本語・한글 🐼", "before\0after"])
    func preservesValidUTF8(_ text: String) {
        let data = Data(text.utf8)
        #expect(data.utf8InvalidCharactersRipped == data)
    }

    @Test
    func repairsMalformedBytesWithoutTruncatingTheResponse() {
        let data = Data([0x41, 0xFF, 0x00, 0x42, 0xE2, 0x82])
        #expect(data.utf8InvalidCharactersRipped == Data("A\u{FFFD}\0B\u{FFFD}".utf8))
    }
}
