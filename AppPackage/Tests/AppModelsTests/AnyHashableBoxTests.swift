@testable import AppModels
import Testing

struct AnyHashableBoxTests {
    @Test
    func equalityHashingAndDisplayValueReflectTheUnderlyingValue() throws {
        #expect(AnyHashableBox("a") == AnyHashableBox("a"))
        #expect(AnyHashableBox(1) != AnyHashableBox(2))

        let values = [
            AnyHashableBox("a"): "string",
            AnyHashableBox(1): "integer"
        ]

        #expect(values[AnyHashableBox("a")] == "string")
        #expect(values[AnyHashableBox(1)] == "integer")
        #expect(AnyHashableBox(true).displayValue == "true")
    }

    @Test
    func contextSupportsLiteralValues() throws {
        let context: Context = [
            .action: "parseGalleryList",
            .statusCode: 200,
            .gid: 1
        ]
        let boolean: AnyHashableBox = true
        let float: AnyHashableBox = 1.5

        #expect(context[.action]?.displayValue == "parseGalleryList")
        #expect(context[.statusCode]?.displayValue == "200")
        #expect(context[.gid]?.displayValue == "1")
        #expect(boolean == AnyHashableBox(true))
        #expect(float == AnyHashableBox(1.5))
    }

    @Test
    func errorInfoExcludesIdentityFromEqualityAndHashing() throws {
        let context: Context = [.action: "parseGalleryList"]
        let lhs = ErrorInfo(error: .parseFailed, context: context)
        let rhs = ErrorInfo(error: .parseFailed, context: context)

        #expect(lhs.id != rhs.id)
        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }
}
