# Phase 16: Accessibility (Dynamic Type + Assistive Technology) - Pattern Map

**Mapped:** 2026-08-23
**Files analyzed:** 14 agent-authored files/file groups (round-1 reflow edits are owner-implemented and deliberately NOT mapped — D-01)
**Analogs found:** 13 / 14 (the Nutrition Label doc has no repo analog; it follows the skill template)

Scope rule carried from CONTEXT.md: the owner finds and fixes Dynamic Type reflow by hand. Nothing below
assigns a reflow edit to a view file. The agent's round-1 carve-out is lint config; everything else is
round 2 (agent-implemented, owner-reviewed) plus planning artifacts.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.swiftlint.yml` (+5 `custom_rules`: 4 × D-16, 1 × D-30) | config (lint) | batch (build-time scan) | the 21 existing `custom_rules` in `.swiftlint.yml`, esp. `accessibility_text_argument` (49-56), `optional_try` (198-209), `system_name_image_parameter` (253-260) | exact |
| `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` | planning doc (verdict table) | batch (append rows per pass) | `.planning/phases/10-ui-polish/10-11-SUMMARY.md` B1–B10 table (105-112) | exact |
| `AppPackage/Sources/AppTools/Color+Contrast.swift` | utility (`Color` / `Color.Resolved` extension) | transform (pure math) | `AppPackage/Sources/AppTools/ColorCodable.swift` (Color extension, imports SwiftUI) + `AppTools/Extensions/URL+ImageCacheKey.swift` (public computed-property extension shape) | role-match |
| `AppPackage/Tests/AppToolsTests/ColorContrastTests.swift` | test (Swift Testing, parameterised) | transform | `AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift` | exact |
| `AppPackage/Tests/AppModelsTests/CategoryColorsetInvariantTests.swift` (target: `AppModelsTests`, see note) | test (repository walk + invariant) | file-I/O | `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift` (`repositoryRoot()` / `scannedFiles()` / `requireKnownMembers`) | exact (data-flow) |
| `EhPandaUITests/AccessibilityAuditUITests.swift` | test (XCUITest) | request-response (launch → navigate → audit) | `EhPandaUITests/DeepLinkSmokeUITests.swift` + `DeepLinkSchemeUITests.swift` + `Support/DeepLinkLauncher.swift` + `Support/UITestConstants.swift` | exact |
| Icon-only controls: `.accessibilityLabel` / `.accessibilityValue` sites (~14, per RESEARCH §Round-2 inventory) | component (SwiftUI view modifier edits) | request-response (static semantics) | `GalleryListComponents/DownloadBadgeLabel.swift:26-27,56-58`; `DetailFeature/DetailView+HeaderSection.swift:152,339-358`; `SettingFeature/AppearanceSetting/AppearanceSettingView.swift:39-44` | exact |
| Custom tappables → native semantics (10 `.onTapGesture` sites incl. `ExcludeToggle`, `CategoryCell`, `AppIconRow`) | component | event-driven | `DownloadsFeature/DownloadsView+Subviews.swift:391-413` `DownloadListRow`; `DetailView+HeaderSection.swift:162-190` `favoriteButton` (state via two `Label`s, not a label string) | role-match |
| Voice Control `.accessibilityInputLabels` additions | component | request-response | `DownloadBadgeLabel.swift:56-58` (`String(localized:)` from catalog keys — the only overload available) | role-match |
| Reduce Motion gating (~20 sites, RESEARCH §Reduce Motion "In scope") | component | event-driven (animation) | `SystemNotification/View+Toast.swift:34,97-105`; `DownloadsFeature/DownloadsView+Subviews.swift:129-131,152-158`; `AppComponents/ViewModifiers.swift:9-24` | exact |
| `AppPackage/Sources/AppComponents/CategoryView.swift` (`CategoryLabel` text colour + `CategoryCell` text colour & button semantics) | component | transform | itself (lines 28-37, 74-100) + the new `Color+Contrast.swift` helper | exact (in-place edit) |
| `<module>/Resources/Localizable.xcstrings` — new `accessibility.*` keys (six locales) | config (string catalog) | — | `DetailFeature/Resources/Localizable.xcstrings` keys `accessibility.download` (plain) and `accessibility.downloading` (named `%#@variable@` substitutions) | exact |
| (optional, D-30 fallback) Swift Testing source scan for Reduce Motion / hardcoded strings | test (repository walk) | file-I/O | `DownloadsFeatureTests/DownloadSourceInventoryTests.swift` | exact |
| `.planning/phases/16-dynamic-type-accessibility/16-NUTRITION-LABEL.md` | planning doc | — | none in repo — use `$HOME/.claude/skills/swift-accessibility-skill/SKILL.md` §4 template | no analog |

Target note for `CategoryColorsetInvariantTests`: RESEARCH leaves the test target open ("AppComponentsTests or
AppModelsTests"). There is **no** `AppComponentsTests` target today (`AppPackage/Tests/` listing), and
`AppModelsTests` already hosts `CategoryFilterValueTests.swift` for `Category`. Recommend `AppModelsTests` — the
colorset names are resolved by `Category.color(host:)` in `AppModels`, and the test reads JSON from disk, needing
no view import. Creating a new test target would need a `.swiftlint.yml` (`parent_config: ../../../.swiftlint.yml`)
per CLAUDE.md; putting it in an existing target avoids that.

## Pattern Assignments

### `.swiftlint.yml` — five custom rules (config, batch)

**Analog:** the existing `custom_rules` block, `.swiftlint.yml:40-277`. Every rule there uses `name`, `regex`,
`message`, `excluded_match_kinds`, `severity: error`. Keys are alphabetically ordered inside `custom_rules`
(`accessibility_empty_string` … `unchecked_subscript_index_access`); insert the new rules in alphabetical position,
not appended at the end.

**Rule shape pattern** (`.swiftlint.yml:253-260`, the closest "ban a token" rule):
```yaml
  system_name_image_parameter:
    name: "systemName / systemImage Parameter"
    regex: "\\b(?:systemName|systemImage)\\s*:"
    message: "`systemName` and `systemImage` parameters should be avoided. Prefer `systemSymbol`."
    excluded_match_kinds:
      - comment
      - string
    severity: error
```

**`doccomment` spelling trap, documented inline three times** (`.swiftlint.yml:198-209`) — copy the comment, not
just the kind, wherever `doccomment` is excluded:
```yaml
  optional_try:
    name: "try?"
    regex: "\\btry\\?\\s*"
    message: "try? should be avoided. Properly handle every errors."
    excluded_match_kinds:
      - comment
      # `doccomment`, NOT `doc_comment`. An unrecognised kind makes SwiftLint discard the WHOLE
      # rule config and fall back to defaults; a custom rule has no default, so it silently
      # vanishes behind one stderr warning and reports zero violations forever.
      - doccomment
      - string
    severity: error
```

**Accessibility-modifier regex family to extend** (`.swiftlint.yml:49-56`) — the D-30 guard
`accessibility_hardcoded_string` is a sibling of this rule and must use the same `\.accessibility(Label|Value|Hint|InputLabels)\s*\(` head. Note it must **not** exclude `string` (the violation *is* the literal):
```yaml
  accessibility_text_argument:
    name: "Accessibility Text Argument"
    regex: '\.accessibility(Label|Value|Hint|InputLabels)\s*\((?:[^()]|\([^()]*\))*?\bText\s*\('
    message: "Accessibility modifiers should not wrap their content in Text. Pass a LocalizedStringResource (or String) directly, e.g. .accessibilityLabel(.someKey)."
    excluded_match_kinds:
      - comment
      - string
    severity: error
```

**Exact YAML for the five rules:** RESEARCH.md §"SwiftLint rules" lines 810-863 (regexes verified 5/0/0/0/0 with the
0.65.0 artifact binary). Use single-quoted regex strings as the accessibility rules do (no double escaping).

**Verification pattern — negative-control probe** (`.planning/phases/11-infra-refactor-lint-capstone/11-EXCEPTIONS.md:64-82`):
write a throwaway Swift file containing each banned construct, lint against the **live** config with the
standalone binary, confirm each rule fires, delete the file. Record a table like:
```
| Rule | Probe construct | Fired |
|---|---|---|
| `no_minimum_scale_factor` | `.minimumScaleFactor(0.5)` | ✓ |
| `no_dynamic_type_size_modifier` | `.dynamicTypeSize(.large)` | ✓ (and silent on `@Environment(\.dynamicTypeSize)`) |
...
```
Standalone lint command shape (from 11-EXCEPTIONS §1.2 / RESEARCH §Validation): the swiftlint binary lives under
`$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/…/macos/swiftlint`;
run `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests`.

**Sequencing (Pitfall 4):** `no_minimum_scale_factor` fails every build until the owner's 5 removals land; commit it
with or after them. The other four land immediately at zero.

---

### `16-SWEEP.md` — round-1 verdict table (planning doc)

**Analog:** `.planning/phases/10-ui-polish/10-11-SUMMARY.md:105-112` (B1–B10 reflow verdict table).

**Table shape to copy** (lines 105-108):
```markdown
| # | Site | Reflow applied | Default (.large) parity |
|---|------|----------------|-------------------------|
| B1 | `SystemNotification/ToastMessageView.swift:67` | dropped `.lineLimit(1)` on the toast title+subtitle VStack; HUD grows to fit | single-line toast text unchanged at default |
| B2 | `SettingFeature/Components/LaboratorySettingView.swift:70,74` | dropped `.lineLimit(1)` and the now-inert `.minimumScaleFactor(0.75)`; title2 label wraps | short setting labels fit one line at default; shrink was never engaged at default |
```

**Adapt for this phase** (RESEARCH §Resumability): one row per (screen, device, orientation, size) from the 42-row
inventory, columns `# | Screen | Device | Orientation | Size | Status | Finding` with
`Status ∈ pending | pass | finding:#N | re-verify | accepted`; plus the 5 named D-13 rows kept as a separate
section. Findings carry a *written* description only (D-32) — never a screenshot filename. Paths are
repository-relative (CLAUDE.md no-absolute-home-path rule).

---

### `AppPackage/Sources/AppTools/Color+Contrast.swift` (utility, transform)

**Analog:** `AppPackage/Sources/AppTools/ColorCodable.swift` (a `Color` extension in `AppTools` importing
`SwiftUI`) for module placement and imports; `AppTools/Extensions/URL+ImageCacheKey.swift` for the
public-computed-property extension shape. Place the new file under `AppTools/Extensions/` to match
`URL+ImageCacheKey.swift` naming (`Type+Topic.swift`).

**Imports pattern** (`ColorCodable.swift:1`): `AppTools` already depends only on `composableArchitecture`
(`Package.swift:381-386`) and imports `SwiftUI` directly — no new dependency needed.
```swift
import SwiftUI
```

**Extension shape pattern** (`URL+ImageCacheKey.swift:3-11,27-39`): `public` computed properties on the extended
type with a `///` doc comment that states the why:
```swift
extension URL {
    /// The keys an image is cached under, primary first: the stable alias (when the
    /// path yields one) so differing query/host variants of the same page collide,
    /// then the absolute URL as an exact-match fallback. Writers store under the
    /// primary key; readers check them in order.
    public var imageCacheKeys: [String] {
```

**Core pattern** — RESEARCH §Pattern 5 (lines 534-566), reproduced here because it is the load-bearing math:
```swift
extension Color.Resolved {
    /// WCAG 2.x relative luminance. `Color.Resolved` already stores linearised sRGB channels.
    public var relativeLuminance: Double {
        0.2126 * Double(linearRed) + 0.7152 * Double(linearGreen) + 0.0722 * Double(linearBlue)
    }
}

extension Color {
    /// WCAG contrast ratio between two resolved colours, ≥ 1.
    public static func contrastRatio(_ a: Color.Resolved, _ b: Color.Resolved) -> Double { … }

    /// Black or white, whichever contrasts more with `self` in `environment`.
    /// The two ratios cross at L = √0.0525 − 0.05 ≈ 0.1791, where both equal ≈ 4.583:1 —
    /// so the chosen colour is never below 4.58:1 for any background.
    public func contrastingForeground(in environment: EnvironmentValues) -> Color {
        resolve(in: environment).relativeLuminance > 0.1791 ? .black : .white
    }
}
```
Use `linearRed/Green/Blue`, never `.red/.green/.blue` (Pitfall 8). Threshold on luminance 0.1791 (better-of), not
"white unless < 4.5" (Pitfall 9). Doc-comment the WHY (memory: "document deliberate designs").

**Lint constraints that apply:** `labeled_tuple_elements` (a `(hi, lo)` tuple destructure is fine; a tuple *return
type* must be labeled), `single_line_trailing_closure`, `line_length 120`.

---

### `AppPackage/Tests/AppToolsTests/ColorContrastTests.swift` (test, transform)

**Analog:** `AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift` (same target; `AppToolsTests` depends only
on `AppTools`, `Package.swift:889-895`; the target's `.swiftlint.yml` already exists).

**Imports pattern** (lines 1-4; `sorted_imports` is error-level — keep alphabetical):
```swift
import AppTools
import CustomDump
import Foundation
import Testing
```
Add `import SwiftUI` (for `Color.Resolved`) in sorted position.

**Parameterised fixture pattern** (lines 6-13, 65-79, 103-127):
```swift
struct GalleryURLParserTests {
    @Test(arguments: [
        GalleryRouteFixture(
            url: "https://e-hentai.org/g/3103480/0000000000/",
            expectedURL: "https://e-hentai.org/g/3103480/0000000000/",
            gid: "3103480"
        ),
        …
    ])
    private func parsesGalleryRoute(fixture: GalleryRouteFixture) throws {
        let url = try #require(URL(string: fixture.url))
        …
        expectNoDifference(route, GalleryURLParser.Route(…))
    }
}

private struct GalleryRouteFixture: CustomTestStringConvertible, Sendable {
    let url: String
    …
    var testDescription: String { url }
}
```
Cases to cover (RESEARCH §Where the rule lives): black, white, the crossover (L = 0.1791 → both ≈ 4.583),
the worst variant (ExHentai Game CG light: white 4.55, black 4.62 → black chosen). Build `Color.Resolved` values
directly via `Color.Resolved(colorSpace: .sRGBLinear, red:green:blue:)` or the sRGB init, as the fixture payload.
Note: `Color.resolve(in:)` needs an `EnvironmentValues`; unit tests can construct `EnvironmentValues()` directly.

---

### `AppPackage/Tests/AppModelsTests/CategoryColorsetInvariantTests.swift` (test, file-I/O repo walk)

**Analog:** `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift` — the house
repository-root walk with a known-member guard.

**Imports pattern** (lines 1-2):
```swift
import Foundation
import Testing
```

**Suite/guard skeleton** (lines 18-45, 120-124):
```swift
@Suite
struct DownloadLogPrivacyInvariantTests {
    private struct ScannedFile {
        let relativePath: String
        let contents: String
        …
    }

    private static let scannedDirectories = [clientModuleDirectory, sessionModuleDirectory]
    /// One file per scanned directory, so an enumerator that silently walked nothing cannot let a
    /// test pass vacuously — for either root.
    private static let knownMembers = [ … ]
    private static let repositoryRootMarkers = ["App", "AppPackage"]

    @Test
    func testNoDownloadLogPublishesGalleryIdentity() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)
        …
    }
}
```

**Repository walk helpers to copy** (lines 270-346) — copy `repositoryRoot()`, `isRepositoryRoot(_:)`,
`repositoryRelativePath(of:under:)` and the enumerator loop; the test cannot import the other test target's
private helpers:
```swift
    private static func scannedFiles() throws -> [ScannedFile] {
        let root = try repositoryRoot()
        let fileManager = FileManager.default
        …
        for scannedDirectory in scannedDirectories {
            let directory = root.appending(path: scannedDirectory)
            let enumerator = try #require(
                fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: nil
                )
            )
            for case let url as URL in enumerator
            where url.pathExtension == "swift"
                && url.standardizedFileURL.path != invariantFilePath {
                files.append(ScannedFile(
                    relativePath: repositoryRelativePath(of: url, under: root),
                    contents: try String(contentsOf: url, encoding: .utf8)
                ))
            }
        }
        return files
    }

    static func repositoryRoot() throws -> URL {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()
        var located: URL?
        while located == nil, directory.path != "/" {
            if isRepositoryRoot(directory) { located = directory }
            else { directory = directory.deletingLastPathComponent() }
        }
        return try #require(located, "Could not locate the repository root; … refuses a vacuous scan.")
    }
```
Adapt: walk `App/Assets.xcassets/Category/Colors/{E-Hentai,ExHentai}` for `Contents.json` (not `.swift`);
`knownMembers` = `ExHentai/Game CG.colorset/Contents.json` (the worst case) and one E-Hentai file; require exactly
84 variants. Parse components via `JSONSerialization`/`Codable`, normalising the **three** string encodings
(`"0.910"`, `"0x11"`, `"163"` — RESEARCH §Colorset facts). Pin byte-identity with SHA-256 over the 22 files in
sorted-path order (`import CryptoKit`). Equality-pinned tables, not lower bounds (lines 98-117 rationale).

**Lint constraint:** `unchecked_subscript_index_access` is excluded for `*Tests.swift`; `force_try`/`force_unwrapping`
are errors everywhere — use `try #require(...)` as the analog does.

---

### `EhPandaUITests/AccessibilityAuditUITests.swift` (test, XCUITest)

**Analog:** `EhPandaUITests/DeepLinkSmokeUITests.swift` (file shape) + `DeepLinkSchemeUITests.swift:90-110`
(assertion-helper shape) + `Support/DeepLinkLauncher.swift` + `Support/UITestConstants.swift`.

**File/class pattern** (`DeepLinkSmokeUITests.swift:1-15`):
```swift
import XCTest

@MainActor
final class DeepLinkSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testColdGalleryDeepLinkUsesHermeticFixture() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(
            UITestConstants.galleryURL(scheme: "ehpanda")
        )

        try app.openCold(url)
```
(`@MainActor` on the class; `setUpWithError` override is plain `override`, never `@MainActor override` — memory
"XCTest override isolation".)

**Launch/navigation helpers to reuse, not re-implement** (`Support/DeepLinkLauncher.swift:5-27,42-59`):
```swift
@MainActor
extension XCUIApplication {
    func launchStubbed(extraEnvironment: [String: String] = [:]) throws { … }   // hermetic stub network
    func openCold(_ url: URL) throws { terminate(); try configureStubbedLaunch(); open(url) }

    @discardableResult
    func requireElement(
        _ accessibilityIdentifier: String,
        matching elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement
}
```
`configureStubbedLaunch` forces `-AppleLanguages (en)` (matches D-30 English verification) and sets
`EHPANDA_UITEST_STUB_NETWORK=1` + fixture dir. Tab entry: pass `EHPANDA_AUTOMATION_TAB` via
`launchStubbed(extraEnvironment:)` (`AppLaunchAutomation.swift:50,110-118` accepts `home|favorites|search|downloads|setting`).
Never the `IPB_*`/`IGNEOUS` keys (D-09).

**Deep-link constants** (`Support/UITestConstants.swift:22-39`): `galleryURL(scheme:)`, `singlePageURL(scheme:)`,
`commentURL(scheme:)`, `malformedURL(scheme:)` — these reach Detail, Reader, Comments, and the error toast.
Existing ids: `detail_view`, `reading_view`, `reading_page_indicator`.

**Per-screen assertion helper pattern** (`DeepLinkSchemeUITests.swift:90-110`) — same `file:line:` threading:
```swift
    private func assertGalleryDestination(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.requireForeground(file: file, line: line)
        app.requireElement("detail_view", matching: .scrollView, file: file, line: line)
        …
    }
```
Replace the body with `try app.performAccessibilityAudit(for: [...]) { issue in … return false }` per RESEARCH
§Pattern 7 (lines 597-616). No `#available` guards (iOS 26 floor, Pitfall 11). Handler logs every issue and returns
`true` only for an owner-approved, written exclusion. Run on a simulator that is **not** the D-09 logged-in one.

---

### Icon-only controls — `.accessibilityLabel` / `.accessibilityValue` (component)

**Analog A — combined element with catalog-fed label** (`GalleryListComponents/DownloadBadgeLabel.swift:12-27,56-58`):
```swift
        HStack(spacing: 4) {
            Image(systemSymbol: badge.symbol)
                .font(.caption.bold())
            Text(progressText)
                …
        }
        …
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)

    private var accessibilityText: String {
        [String(localized: statusText), String(localized: progressText)].joined(separator: " ")
    }
```
Use this for `RatingView` (ignore children, label `.rating`, value `.ratingOutOfFive(rating:)`).

**Analog B — state-dependent label computed from catalog keys** (`DetailFeature/DetailView+HeaderSection.swift:152,339-358`):
```swift
        .accessibilityLabel(downloadButtonAccessibilityLabel)

    var downloadButtonAccessibilityLabel: String {
        guard canDownload else { return String(localized: .accessibilityLogin) }
        guard !showsMetadataPreparation else {
            return String(localized: .accessibilityPreparing)
        }
        return downloadBadgeAccessibilityLabel
    }
```

**Analog C — decorative icon hidden, control labelled directly** (`SettingFeature/AppearanceSetting/AppearanceSettingView.swift:38-45`):
```swift
                    HStack {
                        Image(systemSymbol: .eye)
                            .accessibilityHidden(true)
                        Slider(value: Binding($setting.privacyMaskIntensity), in: 0...100, step: 10)
                            .accessibilityLabel(.privacyMask)
                        Image(systemSymbol: .eyeSlash)
                            .accessibilityHidden(true)
                    }
```
Use for the "Decorative → `.accessibilityHidden(true)`" class (TagCloudView spacer, chevrons, coin glyphs, etc.).

**Analog D — why most buttons are already labelled** (`SFSafeSymbolsExt/SFSafeSymbols+LocalizedStringResource.swift:4-15`):
`Label(_ titleResource:systemSymbol:)` makes the title the VoiceOver label and Voice Control name. Prefer converting
an icon-only `Image` inside a `Button` to `Label(.key, systemSymbol:).labelStyle(.iconOnly)` (as
`HeaderSection.swift:176-178` does for `.favorited`) over adding a separate `.accessibilityLabel` — avoids
over-labelling (Pitfall 7) and satisfies `label_text_image_shorthand`.

**Lint constraints:** `accessibility_text_argument` (no `Text(` inside accessibility modifiers),
`accessibility_empty_string`, `system_name_image_parameter` (always `Image(systemSymbol:)`), and the new
`accessibility_hardcoded_string` (no string literal).

---

### Custom tappables → native semantics (component, event-driven)

**Analog A — minimal modifier triple when a `Button` conversion is not viable**
(`DownloadsFeature/DownloadsView+Subviews.swift:397-413` `DownloadListRow`):
```swift
        GalleryDetailCell(
            gallery: download.gallery,
            …
        )
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: openAction)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(download.title)
```

**Analog B — state expressed by swapping two `Label`s, not by a stateful label string**
(`DetailView+HeaderSection.swift:162-190` `favoriteButton`): the unfavorited state is the `Menu` with a `.heart`
image; the favorited state is an overlaid `Button` with `Label(.favorited, systemSymbol: .heartFill)`. Copy this
idea for selected/toggled states: use `.isSelected` / `.accessibilityRepresentation { Toggle(…) }`, never
"Favorited"/"Not favorited" in a label (RESEARCH Anti-Patterns).

**Target sites and idioms:** RESEARCH §Pattern 3 table (lines 506-513) and §"The 10 `.onTapGesture` custom
tappables" (lines 886-898). Current `ExcludeToggle` shape (`EhSettingView+Sections3.swift:169-185`) is
`Color.clear.overlay { Image(systemSymbol: isOn ? .nosign : .circle) … }.onTapGesture { withAnimation { isOn.toggle() } … }` —
no label, no trait, no value; wrap with `.accessibilityRepresentation { Toggle(.key, isOn: $isOn) }`.
`AppIconRow` (`AppearanceSettingView.swift:108-118`) uses `.contentShape(.rect).onTapGesture { $setting.withLock(…) }`;
convert to `Button` + `.accessibilityAddTraits(isSelected ? .isSelected : [])`, hide the checkmark image.

Keep `hapticsClient.generateFeedback(.soft)` calls inside the new `Button` action (parity).

---

### Voice Control `.accessibilityInputLabels` (component)

**Analog:** `DownloadBadgeLabel.swift:56-58` — `String(localized: .key)` is the only catalog-to-`String` bridge
in use. There is **no** `LocalizedStringResource` overload on `accessibilityInputLabels` (RESEARCH, SDK-verified),
and `accessibility_text_argument` bans `[Text(.key)]`, so:
```swift
.accessibilityInputLabels([String(localized: .favorites), String(localized: .favoritesAlternate)])
```
Only add input labels where the spoken name must differ from / extend the visible text; `Label`-backed controls
already have a Voice Control name.

---

### Reduce Motion gating (~20 sites, component, event-driven)

**Analog A — computed `Animation`/`AnyTransition` selected by the environment read**
(`SystemNotification/View+Toast.swift:34,97-105`):
```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    …
    private var toastAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .bouncy
    }

    private var toastTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .bottom).combined(with: .opacity)
    }
```
Use for: reader panel slide (`ReadingView.swift:114`, `ControlPanel.swift:100-101`), inspector scale transition
(`DownloadsView+Subviews.swift:140-143` — `reduceMotion` is already in scope there), list diff transitions.

**Analog B — `nil` animation under reduce motion** (`DownloadsView+Subviews.swift:129-131,152-158`):
```swift
    private var progressAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
```
Use for: `ReadingView.swift:110,113` pan/zoom settle, `DetailView.swift:27-29` expand/collapse, list insert/remove
`.animation(…, value:)` sites, and `withAnimation(reduceMotion ? nil : .default) { … }` for the page jump
(`ReadingView.swift:351`) and comment scroll (`CommentsView.swift:93`).

**Analog C — gating folded into a `.animation(_:body:)` predicate with a WHY comment**
(`AppComponents/ViewModifiers.swift:9-24`):
```swift
public struct PrivacyMaskModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    …
            // Asymmetric on purpose: apply the mask instantly (`blur != 0`) but ease it out.
            // … Only the
            // return-to-active fade (`blur == 0`) is animated, and Reduce Motion skips both.
            .animation(reduceMotion || blur != 0 ? nil : .linear(duration: 0.1)) {
                $0.blur(radius: blur)
            }
```

**Spinning download icon** (`DetailView+HeaderSection.swift:137-141,158`) — today:
```swift
                .animation(
                    showsMetadataPreparation
                        ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                    value: showsMetadataPreparation
                )
    …
            .rotationEffect(.degrees(showsMetadataPreparation ? 360 : 0))
```
Under reduce motion replace the spin with a static symbol + `.symbolEffect(.pulse)` or a `ProgressView` — never a
slower spin (RESEARCH §Pattern 4; Apple names spinning explicitly).

**Leave ungated:** every `.contentTransition(.numericText())` and opacity crossfade (D-29; e.g.
`DownloadBadgeLabel.swift:17-20`, `HeaderSection.swift:170-172`). The `GalleryCardCell.swift:13-30` gradient is
already gated and documented — reference for the comment style.

---

### `AppComponents/CategoryView.swift` — adaptive badge text (component, transform)

**Analog:** itself. Two white-on-category sites (RESEARCH §"The second white-on-category site"):

`CategoryLabel` (`CategoryView.swift:28-37`) today:
```swift
    public var body: some View {
        Text(text)
            .font(font.bold())
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(insets)
            .background(
                Rectangle().foregroundStyle(color).clipShape(.rect(cornerRadius: cornerRadius))
            )
    }
```
Change: add `@Environment(\.self) private var environment` and
`.foregroundStyle(color.contrastingForeground(in: environment))`. `AppComponents` already imports `AppTools`
(`CategoryView.swift:2`), so the helper resolves without a `Package.swift` edit. `@Environment(\.self)` carries
`colorScheme` + `colorSchemeContrast`, so the asset's light/dark/HC variant resolves correctly.

`CategoryCell` (`CategoryView.swift:74-100`) today:
```swift
        Text(category.value)
            .bold()
            .foregroundStyle(.white)
            …
            .background {
                Rectangle()
                    .animation(.default) {
                        $0.foregroundStyle(
                            category.color(host: setting.galleryHost).opacity(isFiltered ? 0.3 : 1)
                        )
                    }
            }
            .onTapGesture {
                isFiltered.toggle()
                hapticsClient.generateFeedback(.soft)
            }
```
Change: same adaptive foreground (measure the 0.3-opacity excluded state against the composited sheet background —
surface to the owner if ambiguous, D-22 / Open Question 6); convert `.onTapGesture` to `Button` +
`.buttonStyle(.plain)` + `.accessibilityAddTraits(isFiltered ? [] : .isSelected)`; keep the haptic in the action.
The `.lineLimit(1)` on both is a round-1 **owner** item (D-04) — do not touch it in round 2.

---

### `<module>/Resources/Localizable.xcstrings` — `accessibility.*` keys (config)

**Analog:** `AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings`, existing keys
`accessibility.download`, `accessibility.downloaded`, `accessibility.downloading`, `accessibility.login`,
`accessibility.partial`, `accessibility.pause_action`, `accessibility.paused`, `accessibility.preparing`,
`accessibility.queued`, `accessibility.repair`, `accessibility.retry`, `accessibility.update`.

**Key naming → generated symbol:** `accessibility.pause_action` → `.accessibilityPauseAction`
(`DetailView+HeaderSection.swift:358`). Use snake_case after the `accessibility.` prefix.

**Plain key, six locales** (`accessibility.download`):
```json
"accessibility.download" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Download" } },
    "de" : { "stringUnit" : { "state" : "translated", "value" : "Herunterladen" } },
    "ja" : { "stringUnit" : { "state" : "translated", "value" : "ダウンロード" } },
    "ko" : { "stringUnit" : { "state" : "translated", "value" : "다운로드" } },
    "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "下载" } },
    "zh-Hant" : { "stringUnit" : { "state" : "translated", "value" : "下載" } }
  }
}
```

**Numeric-argument key with named `%#@variable@` substitutions** (`accessibility.downloading`, `en` + `ja` shown;
every locale repeats the `substitutions` block) — the CLAUDE.md labeled-format rule template:
```json
"en" : {
  "stringUnit" : { "state" : "translated", "value" : "Downloading %#@completed@ of %#@total@" },
  "substitutions" : {
    "completed" : {
      "argNum" : 1, "formatSpecifier" : "lld",
      "variations" : { "plural" : { "other" : { "stringUnit" : { "state" : "translated", "value" : "%arg" } } } }
    },
    "total" : {
      "argNum" : 2, "formatSpecifier" : "lld",
      "variations" : { "plural" : { "other" : { "stringUnit" : { "state" : "translated", "value" : "%arg" } } } }
    }
  }
},
"ja" : {
  "stringUnit" : { "state" : "translated", "value" : "%#@completed@ / %#@total@ ページをダウンロード中" },
  "substitutions" : { … same two substitutions … }
}
```
Generated call: `.downloadBadgeProgress(completed:total:)` style → e.g. `.ratingOutOfFive(rating:)`,
`.accessibilityPageOf(current:total:)`. Rules: `en` and `de` plural category sets must match; `ja`/`ko`/`zh-*` are
`other`-only; string args stay positional `%@`; never a bare `%lld` in the outer value. Keys land in the catalog of
the module that uses them (`DetailFeature`, `ReadingFeature`, `SettingFeature`, `AppComponents`, …), not in the
shared `Resources` catalog unless reused across modules (then add a hand-written label in
`AppPackage/Sources/Resources/ResourceStringSymbols.swift` per CLAUDE.md).

---

### Optional source-scan tests (Reduce Motion coverage / D-30 fallback)

**Analog:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` (doc comment lines 4-40
explain the pattern: repository-root walk + known-member guard + detection tokens assembled from fragments + per-file
equality table + separately counted joined total). Same helper set as `DownloadLogPrivacyInvariantTests`. Only build
this if the `accessibility_hardcoded_string` regex proves insufficient for a multi-line literal shape.

---

### `16-NUTRITION-LABEL.md` (planning doc)

**No repo analog.** Use the skill template at
`$HOME/.claude/skills/swift-accessibility-skill/SKILL.md` §"4) Prepare Nutrition Label recommendation":
header (`App version evaluated`, `Scope reviewed`), "You could claim" / "You should not claim" with reasons, the
common-task × 9-category matrix (`✅ / ❌ / —`), and a summary. Phrase as a recommendation, never a claim (D-21/D-22).

## Shared Patterns

### Catalog-keyed strings everywhere
**Source:** `DownloadBadgeLabel.swift:30-58`, `DetailView+HeaderSection.swift:339-358`,
`SFSafeSymbols+LocalizedStringResource.swift:9-15`
**Apply to:** every accessibility label/value/hint/input-label site, every new catalog key
Generated `LocalizedStringResource` symbols (`.accessibilityLogin`) go straight into the `LocalizedStringResource`
overloads; `String(localized: .key)` only where a `String` is required (`accessibilityInputLabels`, joined labels).
Enforced by the existing `accessibility_text_argument` + the new `accessibility_hardcoded_string` rules.

### Environment read at the animating/rendering view
**Source:** `View+Toast.swift:34`, `ViewModifiers.swift:10`, `GalleryCardCell.swift:13`, `DownloadsView+Subviews.swift:13,152`
**Apply to:** all Reduce Motion sites and `CategoryLabel`/`CategoryCell`
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.self) private var environment   // for Color.resolve(in:)
```
Never mirror these into TCA state (memory: "never mirror deps into TCA State"); never set them in `#Preview`
(read-only, Pitfall 10).

### Lint conformance for every Swift excerpt
**Source:** `.swiftlint.yml` (root) — read before writing
**Apply to:** all Swift files above
`Image(systemSymbol:)` only; `Label(.key, systemSymbol:)` initialiser; no `try?`; no `Binding(get:set:)`; no
`.onAppear`/`.onDisappear` without the exception protocol; `sorted_imports`; 120-char lines; single-line trailing
closures parenthesised; `Delegate` enum sibling of `Action`; tuples labeled. Suppressions require
`// reason:` + `// swiftlint:disable:next` **and** owner permission (D-19, CLAUDE.md).

### Repository-walk tests refuse vacuous passes
**Source:** `DownloadLogPrivacyInvariantTests.swift:37-45,301-308`
**Apply to:** `CategoryColorsetInvariantTests`, any optional source scan
`knownMembers` + `try #require(files.isEmpty == false)` + equality pins (exact 84, pinned hash), never `>=`.

### Sequential `xcodebuild`, spare simulator for UI tests
**Source:** memory "No overlapping xcodebuild test"; RESEARCH Pitfall 3
**Apply to:** every verification step in every plan
One `xcodebuild test` at a time; the UI-test plan runs on a simulator that is not the D-09 logged-in one; never
`erase`/`uninstall` that UDID.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `16-NUTRITION-LABEL.md` | planning doc | — | First Nutrition Label artifact in the repo; the skill's SKILL.md §4 template is the source |

## Metadata

**Analog search scope:** `.swiftlint.yml`, `.planning/phases/10-ui-polish/`, `.planning/phases/11-infra-refactor-lint-capstone/`,
`AppPackage/Sources/{AppTools,AppComponents,GalleryListComponents,DetailFeature,DownloadsFeature,SystemNotification,SettingFeature,HomeFeature,SFSafeSymbolsExt,AppLaunchAutomationClient}`,
`AppPackage/Tests/{AppToolsTests,AppModelsTests,DownloadsFeatureTests}`, `EhPandaUITests/`, `AppPackage/Package.swift`
**Files scanned:** 24 read in full or by targeted range
**Pattern extraction date:** 2026-08-23
