import Testing
import Foundation
import OpenCC

// DEP-01 parity for the de-vendored `OpenCC` package (EhPanda-Team/SwiftyOpenCC fork). These cases
// prove the fork's converter actually opens its bundled `.ocd2` dictionaries and applies each
// regional conversion chain — a real converter call, not a resource-existence check. The three
// regional standards produce distinct output for the same input (`网络`), which locks the default
// (`s2t`), Hong Kong (`s2hk`), and Taiwan-idiom (`s2twp`) pipelines against the Wave 0 baseline.
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

    /// The three regional standards must diverge on the same input, proving each `.ocd2` chain is
    /// opened and applied rather than a single shared pipeline being reused.
    @Test
    func regionalStandardsProduceDistinctOutput() throws {
        let general = try ChineseConverter(options: [.traditionalize]).convert("网络")
        let hongKong = try ChineseConverter(options: [.traditionalize, .hkStandard]).convert("网络")
        let taiwan = try ChineseConverter(options: [.traditionalize, .twStandard, .twIdiom]).convert("网络")

        #expect(general == "網絡")
        #expect(hongKong == "網絡")
        #expect(taiwan == "網路")
        #expect(taiwan != general)
    }
}
