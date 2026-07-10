import Testing
import Foundation
import AppModels
import OpenCC
import OpenCCExt

// Wave 0 parity lock for DEP-01. These fixtures freeze the *current* SwiftyOpenCC behavior the app
// relies on — both the raw `ChineseConverter` option combinations and the `chtConverted` app seam —
// so the later local SwiftyOpenCC module (D-01..D-04) can be proven identical instead of trusted by
// inspection. The direct-converter cases pass explicit options, so they are deterministic regardless
// of the test machine's preferred language; the `chtConverted` cases use locale-invariant inputs
// (`简体` traditionalizes to `簡體` under s2t/s2hk/s2twp alike, and `full color` is a hard-coded custom
// mapping) so the app-seam assertions hold on any machine's locale.
@Suite
struct ChineseConverterParityTests {
    /// Default traditionalization (`s2t`): plain simplified → traditional characters.
    @Test
    func defaultTraditionalizeConvertsSimplifiedToTraditional() throws {
        let converter = try ChineseConverter(options: [.traditionalize])
        #expect(converter.convert("简体") == "簡體")
        #expect(converter.convert("网络") == "網絡")
    }

    /// Hong Kong standard (`s2hk`): keeps the general `網絡` form for "network".
    @Test
    func hongKongStandardKeepsGeneralForm() throws {
        let converter = try ChineseConverter(options: [.traditionalize, .hkStandard])
        #expect(converter.convert("网络") == "網絡")
    }

    /// Taiwan standard + idiom (`s2twp`): the "network" idiom becomes `網路`, distinct from HK/default.
    @Test
    func taiwanIdiomConvertsNetworkToTaiwanForm() throws {
        let converter = try ChineseConverter(options: [.traditionalize, .twStandard, .twIdiom])
        #expect(converter.convert("网络") == "網路")
    }

    /// The `chtConverted` app seam: default traditionalization plus the custom `full color` → `全彩`
    /// mapping. Both inputs are locale-invariant so this locks the seam on any machine.
    @Test
    func chtConvertedAppliesTraditionalizeAndCustomFullColor() throws {
        let response = EhTagTranslationDatabaseResponse(data: [
            .init(namespace: "female", data: [
                "simp": .init(name: "简体"),
                "fc": .init(name: "full color")
            ])
        ])

        let converted = response.tagTranslations.chtConverted

        let simplified = try #require(converted.values.first(where: { $0.key == "simp" }))
        let fullColor = try #require(converted.values.first(where: { $0.key == "fc" }))
        #expect(simplified.value == "簡體")
        #expect(fullColor.value == "全彩")
    }
}
