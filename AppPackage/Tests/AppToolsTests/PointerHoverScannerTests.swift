import Foundation
import Testing

// MARK: - Fixture tests

/// Every rule the scanner has is guarded by a fixture that fails when the rule is removed, so a change to the
/// scanner cannot quietly widen what the audit lets through. Each fixture is its own test case.
@Suite
struct PointerHoverScannerTests {
    struct Fixture: Sendable, CustomTestStringConvertible {
        let name: String
        let source: String
        /// The site outcomes in order (`kind:pass` or `kind:fail`), or the markers that survive preprocessing.
        let expected: [String]

        var testDescription: String {
            name
        }

        init(_ name: String, _ source: String, _ expected: [String] = []) {
            self.name = name
            self.source = source
            self.expected = expected
        }
    }

    private static let markers = ["aMac", "bIOS", "cDebug", "dElse", "eOuter", "fInMac", "gInElse", "hOutElse"]

    private static func processed(_ source: String) -> String {
        PointerHoverScanner.preprocessed(source)
    }

    private static func outcomes(_ source: String) -> [String] {
        let sites = PointerHoverScanner.sites(in: processed(source))
        return sites.map({ "\($0.kind.rawValue):\($0.passes ? "pass" : "fail")" })
    }

    /// Each source hides `TapGesture` in something that must be blanked and keeps `keepMe` outside it.
    static let blanking = [
        Fixture("line comment", "// TapGesture\nkeepMe\n"),
        Fixture("block comment", "/* TapGesture\n */ keepMe\n"),
        Fixture("nested block comment", "/* a /* TapGesture */ TapGesture */ keepMe\n"),
        Fixture("doc comments", "/// TapGesture\n/** TapGesture */\nkeepMe\n"),
        Fixture("escaped quote", #"let a = "say \"TapGesture\" now" ; keepMe"#),
        Fixture("multiline string", "let a = \"\"\"\n  TapGesture \"q\"\n  \"\"\"\nkeepMe\n"),
        Fixture("raw string holding a quote",
                ###"let a = #"a " TapGesture"# ; let b = ##"x "# TapGesture"##"### + " ; keepMe"),
        Fixture("raw multiline string", "let a = #\"\"\"\n \"\" TapGesture \"\"\" TapGesture\n \"\"\"#\nkeepMe\n"),
        Fixture("interpolation holding a nested string", #"let a = "x \(foo("TapGesture)")) y TapGesture" ; keepMe"#),
        Fixture("raw interpolation", ##"let a = #"x \#(foo("TapGesture)")) \(TapGesture) "# ; keepMe"##)
    ]

    @Test(arguments: blanking)
    func commentsAndStringsAreBlanked(_ fixture: Fixture) {
        let result = Self.processed(fixture.source)

        #expect(result.contains("TapGesture") == false)
        #expect(result.contains("keepMe"))
        #expect(result.utf8.count == fixture.source.utf8.count)
    }

    @Test
    func nonASCIIBytesBecomeSpacesAndTheLayoutIsKept() {
        let source = "let a = \"日本語\" // é\nlet 名前 = keepMe\n"
        let result = Self.processed(source)

        #expect(result.utf8.count == source.utf8.count)
        #expect(result.utf8.allSatisfy({ $0 < 0x80 }))
        #expect(result.utf8.filter({ $0 == UInt8(ascii: "\n") }).count == 2)
        #expect(result.contains("keepMe"))
    }

    /// `keepMe` under `#if <name>` survives exactly when `expected` says `kept`.
    static let conditions = [
        Fixture("os(iOS)", "os(iOS)", ["kept"]),
        Fixture("os(macOS)", "os(macOS)"),
        Fixture("canImport(AppKit)", "canImport(AppKit)"),
        Fixture("canImport(UIKit)", "canImport(UIKit)", ["kept"]),
        Fixture("DEBUG", "DEBUG", ["kept"]),
        Fixture("!os(iOS)", "!os(iOS)"),
        Fixture("os(iOS) && DEBUG", "os(iOS) && DEBUG", ["kept"]),
        Fixture("os(macOS) || os(iOS)", "os(macOS) || os(iOS)", ["kept"]),
        Fixture("negated parentheses", "!(os(macOS) || canImport(AppKit))", ["kept"])
    ]

    @Test(arguments: conditions)
    func aConditionIsEvaluatedForIOS(_ fixture: Fixture) {
        let result = Self.processed("#if \(fixture.source)\nkeepMe\n#endif\n")

        #expect((result.contains("keepMe") ? ["kept"] : []) == fixture.expected)
    }

    static let branches = [
        Fixture("else branch", "#if os(macOS)\naMac\n#else\ndElse\n#endif\n", ["dElse"]),
        Fixture(
            "elseif picks the first true branch only",
            "#if os(macOS)\naMac\n#elseif os(iOS)\nbIOS\n#elseif DEBUG\ncDebug\n#else\ndElse\n#endif\n",
            ["bIOS"]
        ),
        Fixture(
            "nested conditionals",
            "#if os(iOS)\neOuter\n#if os(macOS)\nfInMac\n#else\ngInElse\n#endif\n#else\nhOutElse\n#endif\n",
            ["eOuter", "gInElse"]
        ),
        Fixture("conditionals inside an inactive branch",
                "#if os(macOS)\n#if os(iOS)\nbIOS\n#else\ndElse\n#endif\n#endif")
    ]

    @Test(arguments: branches)
    func branchesAreChosenLikeTheCompilerDoes(_ fixture: Fixture) {
        let result = Self.processed(fixture.source)

        #expect(Self.markers.filter({ result.contains($0) }) == fixture.expected)
    }

    @Test
    func aPreviewBlockIsBlanked() {
        let source = "#Preview(\"A\") {\n  x.buttonStyle(.plain)\n}\n#Preview {\n  x.onTapGesture {}\n}\nkeepMe"

        #expect(Self.outcomes(source).isEmpty)
        #expect(Self.processed(source).contains("keepMe"))
    }

    static let sites = [
        Fixture(
            "helper after the plain style",
            "x\n.buttonStyle(.plain)\n.interactiveHover(.highlight, in: .rect)\n.padding()",
            ["plainButtonStyle:pass"]
        ),
        Fixture(
            "helper after a padding that follows the style",
            "x\n.buttonStyle(.plain)\n.padding(8)\n.cellRowHover()",
            ["plainButtonStyle:pass"]
        ),
        Fixture(
            "helper inside the label, before the style",
            "x {\n  y.interactiveHover(.highlight, in: .rect)\n}\n.buttonStyle(.plain)",
            ["plainButtonStyle:fail"]
        ),
        Fixture(
            "helper named in a comment or a string",
            "x\n.buttonStyle(.plain)\n// .cellRowHover()\n.help(\"interactiveHover\")",
            ["plainButtonStyle:fail"]
        ),
        Fixture(
            "the next view's helper is not borrowed",
            "x\n.buttonStyle(.plain)\ny\n.buttonStyle(.row)\n.cellRowHover()",
            ["plainButtonStyle:fail"]
        ),
        Fixture(
            "plain initializer, helper after the style call",
            "x\n.buttonStyle(PlainButtonStyle())\n.cellRowHover()",
            ["plainButtonStyleInitializer:pass"]
        ),
        Fixture("plain initializer, no helper", "x\n.buttonStyle(PlainButtonStyle())\n.padding()",
                ["plainButtonStyleInitializer:fail"]),
        Fixture("onTapGesture with a trailing closure, then a helper", "x\n.onTapGesture {\n  go()\n}\n.cellRowHover()",
                ["onTapGesture:pass"]),
        Fixture(
            "onTapGesture with labelled closures, then a helper",
            "x\n.onTapGesture { go() } label: { name() }\n.cellRowHover()",
            ["onTapGesture:pass"]
        ),
        Fixture(
            "onTapGesture without a helper",
            "x\n.onTapGesture(count: 2) { go() }\n.padding()\ny\n.onTapGesture(perform: go)",
            ["onTapGesture:fail", "onTapGesture:fail"]
        ),
        Fixture(
            "tap gesture in a simultaneous gesture, helper after the call",
            "x\n.simultaneousGesture(\n  TapGesture().onEnded { _ in go() }\n)\n.cellRowHover()",
            ["tapGesture:pass"]
        ),
        Fixture(
            "tap gesture in a simultaneous gesture, no helper",
            "x\n.simultaneousGesture(\n  TapGesture().onEnded { _ in go() }\n)\n.padding()",
            ["tapGesture:fail"]
        ),
        Fixture(
            "tap gestures nested in exclusively read the outer call",
            "x\n.highPriorityGesture(\n  TapGesture(count: 2).exclusively(before: TapGesture())\n)\n.cellRowHover()",
            ["tapGesture:pass", "tapGesture:pass"]
        ),
        Fixture(
            "tap gestures nested in exclusively, no helper",
            "x\n.highPriorityGesture(\n  TapGesture(count: 2).exclusively(before: TapGesture())\n)\n.padding()",
            ["tapGesture:fail", "tapGesture:fail"]
        ),
        Fixture(
            "tap gesture value with no enclosing call",
            "let a = TapGesture().onEnded { go() }.cellRowHover()\nlet b = TapGesture()\nlet c = 1",
            ["tapGesture:pass", "tapGesture:fail"]
        ),
        Fixture(
            "spatial tap gesture is not a tap gesture",
            "let s = SpatialTapGesture(count: 1)\n  .onEnded { value in go(value) }",
            ["spatialTapGesture:fail"]
        ),
        Fixture(
            "helper after the unhighlighted style",
            "x\n.buttonStyle(.unhighlighted)\n.interactiveHover(.highlight, in: .rect)\n.padding()",
            ["unhighlightedButtonStyle:pass"]
        ),
        Fixture(
            "icon helper after the unhighlighted style",
            "x\n.buttonStyle(.unhighlighted)\n.interactiveIconHover()",
            ["unhighlightedButtonStyle:pass"]
        ),
        Fixture(
            "row helper after the unhighlighted style",
            "x\n.buttonStyle(.unhighlighted)\n.padding(8)\n.cellRowHover()",
            ["unhighlightedButtonStyle:pass"]
        ),
        Fixture(
            "unhighlighted style, no helper",
            "x\n.buttonStyle(.unhighlighted)\n.padding()\n.background(.red)",
            ["unhighlightedButtonStyle:fail"]
        ),
        Fixture(
            "unhighlighted style with spaces in the call",
            "x\n.buttonStyle( .unhighlighted )\n.cellRowHover()\ny\n.buttonStyle(  .unhighlighted\n)\n.padding()",
            ["unhighlightedButtonStyle:pass", "unhighlightedButtonStyle:fail"]
        ),
        Fixture(
            "helper inside the label, before the unhighlighted style",
            "x {\n  y.interactiveIconHover()\n}\n.buttonStyle(.unhighlighted)",
            ["unhighlightedButtonStyle:fail"]
        ),
        Fixture(
            "the next view's helper is not borrowed by an unhighlighted style",
            "x\n.buttonStyle(.unhighlighted)\ny\n.buttonStyle(.row)\n.cellRowHover()",
            ["unhighlightedButtonStyle:fail"]
        ),
        Fixture(
            "unhighlighted initializer, helper after the style call",
            "x\n.buttonStyle(UnhighlightedButtonStyle ())\n.cellRowHover()",
            ["unhighlightedButtonStyleInitializer:pass"]
        ),
        Fixture(
            "unhighlighted initializer, no helper",
            "x\n.buttonStyle(UnhighlightedButtonStyle())\n.padding()",
            ["unhighlightedButtonStyleInitializer:fail"]
        ),
        Fixture(
            "unhighlighted sites in a comment, a string or a preview",
            "// x.buttonStyle(.unhighlighted)\nlet a = \".buttonStyle(.unhighlighted) UnhighlightedButtonStyle()\"\n"
                + "#Preview {\n  x.buttonStyle(.unhighlighted)\n  y.buttonStyle(UnhighlightedButtonStyle())\n}\n"
        ),
        Fixture(
            "unhighlighted look-alikes and the style's own declaration",
            "x.buttonStyle(.unhighlightedRow)\nUnhighlightedButtonStyleHelper()\n"
                + "let a = UnhighlightedButtonStyle.self\n"
                + "extension ButtonStyle where Self == UnhighlightedButtonStyle {\n"
                + "  static var unhighlighted: UnhighlightedButtonStyle { .init() }\n}"
        ),
        Fixture("recognizers and handler names",
                "UITapGestureRecognizer(target: self)\nh.onSingleTapGestureEnded(x)\nTapGestureCount")
    ]

    @Test(arguments: sites)
    func sitesAreReadWithTheirChains(_ fixture: Fixture) {
        #expect(Self.outcomes(fixture.source) == fixture.expected)
    }

    static let styles = [
        Fixture(
            "button style with a helper in its body",
            "struct S: ButtonStyle {\n  var body: V { x.interactiveHover(.highlight, in: .rect) }\n}",
            ["buttonStyleConformance:pass"]
        ),
        Fixture("button style without a helper", "struct S: ButtonStyle {\n  var body: V { x }\n}",
                ["buttonStyleConformance:fail"]),
        Fixture(
            "primitive button style with a helper",
            "struct S: PrimitiveButtonStyle {\n  var body: V { x.cellRowHover() }\n}",
            ["buttonStyleConformance:pass"]
        ),
        Fixture("primitive button style without a helper", "struct S: PrimitiveButtonStyle {\n  var body: V { x }\n}",
                ["buttonStyleConformance:fail"]),
        Fixture(
            "button style listed after another protocol",
            "private struct S: Sendable, ButtonStyle {\n  var body: V { x }\n}",
            ["buttonStyleConformance:fail"]
        ),
        Fixture("other styles and look-alike names",
                "struct T: ToggleStyle {}\nextension ButtonStyle where Self == S {}\nstruct N: MyButtonStyleHelper {}")
    ]

    @Test(arguments: styles)
    func buttonStylesAreAuditedThroughTheirBodies(_ fixture: Fixture) {
        #expect(Self.outcomes(fixture.source) == fixture.expected)
    }

    @Test
    func aHandWrittenIconTapShapeIsDetected() {
        let written = [
            "x.contentShape(.interaction, HoverTargetCircle())",
            "x.contentShape(\n    .interaction,\n    HoverTargetCircle()\n)"
        ]
        let other = [
            "x.contentShape(.hoverEffect, HoverTargetCircle())",
            "x.contentShape(.interaction, .rect)",
            "// x.contentShape(.interaction, HoverTargetCircle())"
        ]

        #expect(written.allSatisfy({ PointerHoverScanner.setsIconTapShape(Self.processed($0)) }))
        #expect(other.contains(where: { PointerHoverScanner.setsIconTapShape(Self.processed($0)) }) == false)
    }

    @Test
    func aHoverHelperAfterDisabledOnItsChainIsDetected() {
        let late = [
            "x.disabled(a).interactiveHover(.highlight, in: .circle)",
            "x\n    .disabled(a)\n    .glassEffect(.regular, in: .circle)\n    .cellRowHover()",
            "x.disabled(\n    a\n).interactiveIconHover()"
        ]
        let other = [
            "x.interactiveHover(.highlight, in: .circle).disabled(a)",
            "x.disabled(a)\nButton(b) {}.cellRowHover()",
            "x.hoverEffectDisabled(a).interactiveIconHover()",
            "// x.disabled(a).cellRowHover()"
        ]

        for source in late {
            #expect(PointerHoverScanner.disabledBeforeHoverOffsets(in: Self.processed(source)).count == 1, "\(source)")
        }
        for source in other {
            #expect(PointerHoverScanner.disabledBeforeHoverOffsets(in: Self.processed(source)).isEmpty, "\(source)")
        }
    }

    private static let allowance = HoverAuditAllowance(file: "A.swift", kind: .tapGesture, count: 2, reason: "Why.")
    private static let unmet = [
        "A.swift": [
            PointerHoverScanner.Site(kind: .tapGesture, offset: 1, passes: false),
            PointerHoverScanner.Site(kind: .tapGesture, offset: 9, passes: false),
            PointerHoverScanner.Site(kind: .plainButtonStyle, offset: 20, passes: true)
        ]
    ]

    @Test
    func aStaleAllowanceCountIsReported() {
        let stale = HoverAuditAllowance(file: "A.swift", kind: .tapGesture, count: 3, reason: "Why.")
        let evaluation = PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [stale])

        #expect(evaluation.stale == ["A.swift|tapGesture": 2])
        #expect(evaluation.unlisted.isEmpty)
        #expect(PointerHoverScanner.evaluate(sitesByFile: [:], allowances: [Self.allowance]).stale.count == 1)
        #expect(PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [Self.allowance]).isClean)
    }

    @Test
    func aMissingAllowanceIsReported() {
        let evaluation = PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [])

        #expect(evaluation.unlisted == ["A.swift|tapGesture": 2])
        #expect(evaluation.stale.isEmpty)
    }

    @Test
    func anAllowanceWithoutAReasonIsReported() {
        let silent = HoverAuditAllowance(file: "A.swift", kind: .tapGesture, count: 2, reason: "  \n")
        let evaluation = PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [silent])

        #expect(evaluation.reasonless == ["A.swift|tapGesture"])
        #expect(evaluation.isClean == false)
    }
}
