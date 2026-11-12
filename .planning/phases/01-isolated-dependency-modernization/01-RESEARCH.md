# Phase 01: isolated-dependency-modernization - Research

**Researched:** 2026-07-10
**Domain:** SwiftPM dependency modernization, local Swift modules, markdown parsing, image color analysis, CFNetwork domain-fronting, SwiftUI animated gradients
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

Source: `.planning/phases/01-isolated-dependency-modernization/01-CONTEXT.md` [VERIFIED: codebase grep]

### Locked Decisions

#### D-01: Local package vs forked repos for SwiftyOpenCC and UIImageColors

SwiftyOpenCC and UIImageColors should become app-owned local modules inside `AppPackage/Sources`, not forked Git repos. This lets EhPanda own modernization, tests, linting, and API shape directly.

#### D-02: API shape for local SwiftyOpenCC / UIImageColors modules

Use the best-fit API for the app, not necessarily the old package API. Keep current API names only when they remain the cleanest app-facing boundary.

#### D-03: Modernization scope for imported local module code

Do the full modernization rather than the smallest compile-only import: update to latest recommended APIs where practical, clean up old Swift idioms, add tests/lint/docs as useful, remove unused restrictions, and fix obvious issues when parity evidence allows it.

#### D-04: Import scope for local module code

Prefer a clean-room local module over copying full upstream packages. Import/rewrite only the implementation the app actually needs, plus any minimum support code required for correctness.

#### D-05: Module naming convention

For consumed package modules, use the original package name as the module name, not `*Ext`. Reserve `*Ext` for modules that extend a real external package that still exists.

#### D-06: SwiftLint coverage for new local modules

Every new local module under `AppPackage/Sources` must include its own `.swiftlint.yml` with the correct `parent_config` back to the root config.

#### D-07: Tag markdown migration behavior

Migrate tag markdown parsing with the best-fit behavior and fixture-lock it. Parity with current behavior is the baseline, but intentional fixes for current edge-case bugs are acceptable if the tests document the change clearly.

#### D-08: Detail markdown boundary

`DetailFeature` should not depend directly on the markdown package unless necessary. Prefer a helper/module boundary so UI code stays insulated from parser implementation.

#### D-09: swift-markdown package naming

Apple's package is `swift-markdown`, but its SwiftPM product/target module is `Markdown`. Helper code that extends or wraps the real package should be named `MarkdownExt`, not `SwiftMarkdown`.

#### D-10: Markdown fixture scope

Write focused fixture tests for `MarkdownUtil.parseTexts`, `MarkdownUtil.parseLinks`, and `MarkdownUtil.parseImages`, including edge cases that are intentionally fixed during migration.

#### D-11: Domain-fronting stream path design freedom

The networking/domain-fronting path may be rethought if needed; we are not required to keep the same internal CFStream shape.

#### D-12: DeprecatedAPI removal may be skipped if it is the only viable path

If research shows the current deprecated CFStream API is the only viable way to preserve domain-fronting behavior, skip removal rather than weakening domain-fronting support.

#### D-13: Domain-fronting skip evidence standard

If skipping DeprecatedAPI removal, evidence should combine documented technical proof plus technical request verification. Full end-to-end local proof is not realistic because the failure mode depends on China/SNI/network conditions.

#### D-14: Domain-fronting behavior that must be preserved

Preserve request semantics: domain-to-IP replacement, Host header, cookie/header handling, redirect/response propagation, and custom trust handling.

#### D-15: Domain-fronting replacement success standard

If a viable replacement exists, use it as a direct replacement and rely on real-world verification by testers in China for final proof.

#### D-16: UIImageColors behavior

Preserve package behavior for UIImageColors. No intentional semantic changes are needed; modernization should keep output parity.

#### D-17: Colorful behavior

Use the latest Colorful while preserving the animated-gradient concept in `GalleryCardCell`. Minor polish is acceptable if the visual intent remains.

#### D-18: Automated coverage scope

Automated coverage should focus on what is technically and deterministically testable. Do not overbuild UI/network tests that cannot provide stable proof.

#### D-19: Human visual verification

Final visual judgment for UIImageColors and Colorful can stay with the user during verification.

### the agent's Discretion

No explicit discretion section was present in CONTEXT.md. [VERIFIED: codebase grep]

### Deferred Ideas (OUT OF SCOPE)

#### F-01: Rename `SystemNotificationExt`

`SystemNotificationExt` currently extends the local `SystemNotification` module. Its naming is out of scope for this dependency-modernization phase and can be handled later.
</user_constraints>

## Summary

This phase is mostly a dependency-surface reduction, not a feature rewrite. The safest plan starts with parity fixtures for each seam, then swaps one dependency boundary at a time: local `SwiftyOpenCC`, local `UIImageColors`, `SwiftCommonMark` -> `swift-markdown` through `MarkdownExt`, a DEP-06 domain-fronting spike/checkpoint, and finally latest `Colorful` validation in `GalleryCardCell`. [VERIFIED: codebase grep]

The highest-risk item is DEP-06. The installed Xcode 26.6 iPhoneOS 26.5 SDK still marks the CFHTTP stream APIs used by `DeprecatedAPI.getCFReadStream` as deprecated and directs HTTP work to `NSURLSession`; however, the current domain-fronting implementation depends on IP host replacement, original `Host` header, cookies from the original URL, manual redirect propagation, and custom trust evaluation against the original domain. No high-confidence direct warning-free replacement was found during research. [VERIFIED: Xcode 26.6 SDK headers] [VERIFIED: codebase grep]

**Primary recommendation:** Plan Phase 01 as five isolated parity-first swaps, with DEP-06 split into a required evidence spike and a conditional implementation path: remove `DeprecatedAPI` only if a non-deprecated replacement preserves D-14 semantics; otherwise keep it and document the D-12/D-13 skip evidence. [VERIFIED: 01-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Chinese tag conversion | AppPackage local module plus FileClient parsing boundary | AppModels | Converter implementation belongs in a local dependency module; `TagTranslation` conversion is app data adaptation used by `FileClient`. [VERIFIED: codebase grep] |
| Dominant-color extraction | AppPackage local module | LibraryClient/HomeFeature | Pixel analysis belongs behind a local `UIImageColors` module; `LibraryClient` remains the async app-facing boundary. [VERIFIED: codebase grep] |
| Markdown tag parsing | MarkdownExt helper module | TagTranslationFeature/DetailFeature | Parser dependency should stay behind `MarkdownExt`; `DetailFeature` should not depend directly on `Markdown`. [VERIFIED: 01-CONTEXT.md] |
| Domain-fronting stream setup | NetworkingFeature/DFClient | URLSession/CFNetwork system frameworks | Request rewriting, stream handling, redirects, cookies, and trust evaluation are networking-tier concerns. [VERIFIED: codebase grep] |
| Gallery animated gradient | HomeFeature UI | Colorful package or app-owned gradient view | `GalleryCardCell` owns the view integration; latest Colorful may still compile but `ColorfulView` is deprecated upstream. [VERIFIED: official git] |
| Dependency manifest ownership | AppPackage/Package.swift | Package.resolved | All third-party dependencies are declared in `AppPackage/Package.swift`, not the Xcode project. [VERIFIED: AGENTS.md] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEP-01 | SwiftyOpenCC/OpenCC modernization with unchanged `ChineseConverter` behavior and clean build | Current seam is `OpenCCExt/TagTranslation+ChtConverted.swift`; upstream local module candidate should expose app-needed conversion and fixture-lock traditional/HK/TW paths before C++/dictionary modernization. [VERIFIED: codebase grep] [VERIFIED: official git] |
| DEP-02 | UIImageColors modernization with unchanged `getColors` output | Current seam is `LibraryClient.analyzeImageColors`, which maps `getColors(quality: .lowest)` to primary/secondary/detail/background `Color`s; local module must preserve exact algorithm output on generated and fixture images. [VERIFIED: codebase grep] |
| DEP-03 | SwiftCommonMark removal and swift-markdown parity for `MarkdownUtil`/`TagTranslation`/`DetailView` | Current `MarkdownUtil` extracts paragraph text, link URLs, and valid image URLs from SwiftCommonMark; swift-markdown `Markdown` 0.8.0 provides `Document(parsing:)`, `MarkupWalker`, `Text`, `Link`, and `Image` APIs for replacement. [VERIFIED: codebase grep] [VERIFIED: official git] |
| DEP-06 | DeprecatedAPI removal if viable, with DF behavior unchanged | `DeprecatedAPI` wraps only `CFReadStreamCreateForHTTPRequest`; SDK headers deprecate this and related response/persistence properties. Replacement is uncertain because current DF semantics are CFStream-specific. [VERIFIED: Xcode 26.6 SDK headers] [VERIFIED: codebase grep] |
| DEP-07 | Latest Colorful with `GalleryCardCell` animated-gradient concept preserved | Latest official tag found is 1.1.1; public `ColorfulView` initializer shape is still compatible, but the view is deprecated on non-watchOS with an upstream recommendation to use a Metal replacement. [VERIFIED: official git] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Reducers must use the `Feature` suffix, for example `SettingFeature`. [VERIFIED: AGENTS.md]
- Before writing or changing Swift code, read the root `.swiftlint.yml`; suppressing SwiftLint rules or adding `swiftlint:disable` is forbidden without explicit permission. [VERIFIED: AGENTS.md]
- New modules under `AppPackage/Sources` must include `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml`. [VERIFIED: AGENTS.md]
- Numeric localized-format arguments must use named `%#@variable@` substitutions; string arguments remain positional. [VERIFIED: AGENTS.md]
- `.xcstrings` entries with `"shouldTranslate": false` must include all locales supported by the catalog. [VERIFIED: AGENTS.md]
- `.confirmationDialog` and `.alert` modifiers must stay attached to stable action-source controls if touched. [VERIFIED: AGENTS.md]
- Local reference project names must never be recorded in repository artifacts. [VERIFIED: AGENTS.md]
- `App/` is a thin app shell; app logic belongs in `AppPackage/`. [VERIFIED: AGENTS.md]
- All third-party dependencies are declared in `AppPackage/Package.swift`, not the Xcode project. [VERIFIED: AGENTS.md]
- Root SwiftLint rules relevant to this phase include error-level `force_try` and `force_unwrapping`, custom bans on `NSLock`, `@preconcurrency`, `@unchecked Sendable`, unreasoned `swiftlint:disable`, and SFSafeSymbols bypasses. [VERIFIED: .swiftlint.yml]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `SwiftyOpenCC` local target | Local AppPackage module; upstream OpenCC latest tag found `ver.1.4.0` | Own the app-needed Chinese conversion code and dictionaries without a third-party Swift wrapper dependency. | CONTEXT locks local ownership and behavior parity; OpenCC is the underlying conversion engine already used by the current dependency. [VERIFIED: 01-CONTEXT.md] [VERIFIED: official git] |
| `UIImageColors` local target | Local AppPackage module; upstream package latest tag found `2.2.0` | Own the dominant-color algorithm used by `LibraryClient.analyzeImageColors`. | CONTEXT locks local ownership and output parity; the app uses only `getColors(quality:)`/completion behavior. [VERIFIED: 01-CONTEXT.md] [VERIFIED: codebase grep] |
| `swift-markdown` / product `Markdown` | `0.8.0` semver tag dated 2026-05-07 | Parse markdown for tag text, links, and images through `MarkdownExt`. | Official Swift package replaces `SwiftCommonMark`; product/target naming matches D-09. [VERIFIED: official git] [VERIFIED: 01-CONTEXT.md] |
| `Colorful` | `1.1.1` tag dated 2024-07-04 | Render the animated background gradient in `GalleryCardCell` if build warnings remain acceptable. | Latest official tag preserves the current initializer shape, so it is the narrowest DEP-07 upgrade path. [VERIFIED: official git] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `SwiftLintPlugins` | Existing package pin | Enforce lint rules across modules. | Every target already uses the SwiftLint build-tool plugin; new local modules need local `.swiftlint.yml`. [VERIFIED: codebase grep] |
| `Testing` | Swift 6.3.3 toolchain | Unit and fixture tests. | Existing test targets use Swift Testing, and the project is on Xcode 26.6/Swift 6.3.3 locally. [VERIFIED: codebase grep] [VERIFIED: environment probe] |
| `CustomDump` | Existing transitive project dependency | Structured parity assertions with readable diffs. | Use `expectNoDifference` when comparing arrays/structs if the test target already has or can reasonably add CustomDump. [VERIFIED: pfw-custom-dump skill] |
| `Foundation` URL/Data APIs | SDK-provided | URL validation, HTTP request construction, cookies, streams. | `MarkdownUtil.parseImages` currently validates candidate image URLs; DF code relies on URLRequest, HTTPCookieStorage, streams, and SecTrust. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Local `SwiftyOpenCC` target | Keep external `SwiftyOpenCC` fork | Rejected by D-01; local target gives direct modernization, lint, and fixture control. [VERIFIED: 01-CONTEXT.md] |
| Local `UIImageColors` target | Keep external `UIImageColors` fork | Rejected by D-01/D-16; local target is simpler because the app uses a small API surface. [VERIFIED: 01-CONTEXT.md] |
| `swift-markdown` `MarkdownExt` | Hand-written regex parser | Rejected because markdown edge cases are parser-owned; D-09 names the intended package/product boundary. [VERIFIED: 01-CONTEXT.md] |
| Latest `ColorfulView` | App-owned SwiftUI gradient view | Use app-owned view only if latest `ColorfulView` deprecation warnings break the clean-build standard or visual parity is poor. [VERIFIED: official git] [VERIFIED: .planning/ROADMAP.md] |
| Non-deprecated URLSession DF path | Current CFStream path hidden behind DeprecatedAPI | Use URLSession only if D-14 semantics are preserved; otherwise D-12 says skip dependency removal rather than weaken DF. [VERIFIED: 01-CONTEXT.md] |

**Installation / manifest shape:**

```swift
// AppPackage/Package.swift
.package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
.package(url: "https://github.com/Lakr233/Colorful.git", exact: "1.1.1"),

// Local targets under AppPackage/Sources
.target(module: .cOpenCC, publicHeadersPath: "include", sources: ["source.cpp", "src", "deps/marisa-0.2.6"], swiftSettings: nil),
.target(module: .swiftyOpenCC, dependencies: [.module(.cOpenCC)], resources: [.copy(.dictionary)], plugins: swiftLintPlugins),
.target(name: "UIImageColors", plugins: [.swiftLint]),
.target(name: "MarkdownExt", dependencies: [.markdown], plugins: [.swiftLint]),
```

The exact manifest syntax must follow the existing `Module`/`TargetDependency` helper enums in `AppPackage/Package.swift`, not ad hoc literal dependencies. [VERIFIED: codebase grep] [CITED: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html]

**Version verification:** `git ls-remote --tags` and local bare clones were used for Git-based SwiftPM packages because there is no npm/PyPI/crates registry for these dependencies. `Colorful` latest official tag found: `1.1.1`. `swift-markdown` latest semver tag found: `0.8.0`. `UIImageColors` latest official tag found: `2.2.0`. OpenCC latest official tag found: `ver.1.4.0`. [VERIFIED: official git]

## Package Legitimacy Audit

The GSD package-legitimacy seam supports npm, PyPI, and crates, but not SwiftPM Git URL packages; the attempted Swift ecosystem check failed with an unsupported-ecosystem error. These packages were therefore verified through official GitHub remotes/tags, local resolved checkouts, and `Package.swift` manifests. [VERIFIED: gsd-tools] [VERIFIED: official git]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `swift-markdown` | SwiftPM Git URL | Latest semver tag `0.8.0` dated 2026-05-07 | N/A | `github.com/swiftlang/swift-markdown` | OK | Approved as the DEP-03 replacement. [VERIFIED: official git] |
| `Colorful` | SwiftPM Git URL | Latest tag `1.1.1` dated 2024-07-04 | N/A | `github.com/Lakr233/Colorful` | OK with API warning | Approved, but planner must check whether `ColorfulView` deprecation violates clean-build criteria. [VERIFIED: official git] |
| `SwiftyOpenCC` external package | SwiftPM Git URL | Current pin `2.0.0-beta` | N/A | Current resolved checkout | REMOVED | Replace with local AppPackage module. [VERIFIED: codebase grep] |
| `UIImageColors` external package | SwiftPM Git URL | Current/latest tag `2.2.0` | N/A | Current resolved checkout | REMOVED | Replace with local AppPackage module. [VERIFIED: codebase grep] [VERIFIED: official git] |
| `SwiftCommonMark` | SwiftPM Git URL | Current pin `1.0.0` | N/A | Current resolved checkout | REMOVED | Replace with `swift-markdown`/`MarkdownExt`. [VERIFIED: codebase grep] |
| `DeprecatedAPI` | SwiftPM Git URL | Current branch `main` wraps one deprecated CFStream call | N/A | Current resolved checkout | CONDITIONAL | Remove only if DEP-06 replacement succeeds; otherwise keep and document D-12 skip. [VERIFIED: codebase grep] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: official git]
**Packages flagged as suspicious [SUS]:** none from registry-squatting signals; `DeprecatedAPI` is functionally obsolete rather than suspicious. [VERIFIED: codebase grep]

## Architecture Patterns

### System Architecture Diagram

```text
Tag DB / tag markdown / gallery image / network request
        |
        v
AppPackage feature/client boundary
        |
        +--> FileClient -> local SwiftyOpenCC -> converted TagTranslation output
        |
        +--> TagTranslationFeature -> MarkdownExt -> Markdown.Document walker -> text/link/image fields
        |
        +--> LibraryClient -> local UIImageColors -> [primary, secondary, detail, background]
        |
        +--> HomeFeature/GalleryCardCell -> latest Colorful or app-owned gradient view -> visual UAT
        |
        +--> DFClient/NetworkingFeature -> request rewrite -> stream/session path
                                    |
                                    +--> if non-deprecated path preserves D-14: remove DeprecatedAPI
                                    |
                                    +--> otherwise: keep CFStream path and attach D-12/D-13 skip evidence
```

### Recommended Project Structure

```text
AppPackage/
|-- Sources/
|   |-- SwiftyOpenCC/        # Local converter implementation, dictionaries, local .swiftlint.yml
|   |-- UIImageColors/       # Local dominant-color implementation, local .swiftlint.yml
|   |-- MarkdownExt/         # swift-markdown adapter replacing CommonMarkExt
|   |-- FileClient/          # TagTranslation CHT conversion call site after OpenCCExt removal
|   |-- LibraryClient/       # Async color-analysis boundary
|   |-- NetworkingFeature/   # Domain-fronting request/stream/session path
|   `-- HomeFeature/         # GalleryCardCell Colorful integration
`-- Tests/
    |-- SwiftyOpenCCTests/
    |-- UIImageColorsTests/
    |-- MarkdownExtTests/
    |-- TagTranslationFeatureTests/
    `-- NetworkingFeatureTests/
```

### Pattern 1: Fixture-First Parity Swap

**What:** Capture current behavior in tests before replacing each dependency seam. [VERIFIED: 01-CONTEXT.md]
**When to use:** DEP-01, DEP-02, DEP-03, and deterministic DEP-06 request semantics. [VERIFIED: .planning/ROADMAP.md]
**Example:**

```swift
@Suite("MarkdownUtil parity")
struct MarkdownUtilTests {
  @Test("extracts paragraph text in current order")
  func parseTexts() {
    #expect(MarkdownUtil.parseTexts("hello [site](https://example.com)") == ["hello ", "site"])
  }
}
```

Source: Swift Testing project pattern and current `MarkdownUtil` seam. [VERIFIED: swift-testing-pro skill] [VERIFIED: codebase grep]

### Pattern 2: App-Owned Local Dependency Module

**What:** Import only the app-used implementation surface into `AppPackage/Sources/<PackageName>` and expose the narrow app API. [VERIFIED: 01-CONTEXT.md]
**When to use:** `SwiftyOpenCC` and `UIImageColors`. [VERIFIED: 01-CONTEXT.md]
**Example:**

```swift
// AppPackage/Sources/UIImageColors/.swiftlint.yml
parent_config: ../../../.swiftlint.yml
```

Source: AGENTS.md new-module SwiftLint rule. [VERIFIED: AGENTS.md]

### Pattern 3: Markdown Walker Adapter

**What:** Keep `Markdown` behind `MarkdownExt` and collect text/link/image fields via a walker rather than exposing parser nodes to features. [VERIFIED: 01-CONTEXT.md] [VERIFIED: official git]
**When to use:** DEP-03 `MarkdownUtil.parseTexts`, `parseLinks`, and `parseImages`. [VERIFIED: .planning/ROADMAP.md]
**Example:**

```swift
import Markdown

struct LinkCollector: MarkupWalker {
  var links: [String] = []

  mutating func visitLink(_ link: Link) {
    if let destination = link.destination {
      links.append(destination)
    }
    descendInto(link)
  }
}
```

Source: swift-markdown 0.8.0 `MarkupWalker` and `Link.destination` APIs. [VERIFIED: official git]

### Pattern 4: DEP-06 Evidence Checkpoint

**What:** Treat domain-fronting modernization as a spike with an explicit branch: implement only if D-14 semantics can be preserved; otherwise keep the deprecated path and document skip evidence. [VERIFIED: 01-CONTEXT.md]
**When to use:** Before removing `DeprecatedAPI` from `Package.swift`. [VERIFIED: codebase grep]
**Example evidence targets:** request URL host replacement, `Host` header preservation, cookies for the original URL, redirect response propagation, and trust evaluation against original domain. [VERIFIED: 01-CONTEXT.md] [VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **Removing `DeprecatedAPI` by simply inlining `CFReadStreamCreateForHTTPRequest`:** This removes the package but not the SDK deprecation warning. [VERIFIED: Xcode 26.6 SDK headers]
- **Letting `DetailFeature` import `Markdown`:** D-08 asks for a helper/module boundary, and the current `CommonMark` import in `DetailView` appears unused. [VERIFIED: 01-CONTEXT.md] [VERIFIED: codebase grep]
- **Keeping `OpenCCExt` as a consumed dependency name after localizing the converter:** D-05 reserves `*Ext` names for real external package extensions; the `TagTranslation` conversion should move to an app-owned non-Ext boundary or into `FileClient`. [VERIFIED: 01-CONTEXT.md] [VERIFIED: codebase grep]
- **Using `swiftlint:disable` to import old package code quickly:** AGENTS.md forbids suppressions without explicit permission, and root SwiftLint bans force unwrap, `NSLock`, and several legacy patterns. [VERIFIED: AGENTS.md] [VERIFIED: .swiftlint.yml]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown parsing | Regex or ad hoc token scanning | `swift-markdown` `Markdown` through `MarkdownExt` | Markdown links/images/text have nesting and escaping rules; D-09 already selects the official package boundary. [VERIFIED: 01-CONTEXT.md] [VERIFIED: official git] |
| Chinese conversion | Manual simplified/traditional string map | Local `SwiftyOpenCC` backed by OpenCC dictionaries/algorithm | The current behavior uses OpenCC dictionaries and region-specific options; manual maps would miss phrase and regional variants. [VERIFIED: codebase grep] |
| Dominant-color algorithm redesign | New color clustering algorithm | Localized/modernized UIImageColors algorithm | DEP-02/D-16 require unchanged primary/secondary/detail/background output. [VERIFIED: 01-CONTEXT.md] |
| HTTP/TLS semantics | Custom TLS or crypto | System trust APIs and existing DF semantics | The existing code uses `SecTrustEvaluateWithError`; do not hand-roll certificate validation. [VERIFIED: Xcode 26.6 SDK headers] [VERIFIED: swift-security-expert skill] |
| SwiftPM dependency editing | Literal dependency strings scattered through manifest | Existing `Module`/`TargetDependency` helper enums | `AppPackage/Package.swift` already centralizes products, modules, test targets, and plugins. [VERIFIED: codebase grep] |

**Key insight:** The phase is about owning narrow seams, not inventing new domain algorithms. The planner should preserve algorithmic behavior first, then modernize implementation details within that locked boundary. [VERIFIED: 01-CONTEXT.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Tag translation cache/database content may contain already converted strings, but no runtime records store dependency package names as keys. Verified through FileClient and integrations docs. [VERIFIED: codebase grep] | No data migration for dependency names. Use fixtures to ensure newly parsed/converted records stay compatible. |
| Live service config | No external service config for these package names was found in planning docs or code seams. Domain fronting behavior depends on live network conditions, not stored service config. [VERIFIED: .planning/codebase/INTEGRATIONS.md] | None. DEP-06 final proof remains human/network verification per D-15. |
| OS-registered state | No launchd/systemd/registered process state tied to these package names was found. [VERIFIED: codebase grep] | None. |
| Secrets/env vars | Planning docs state there is no external secret store for this phase; no env var names reference these packages. [VERIFIED: .planning/codebase/INTEGRATIONS.md] | None. |
| Build artifacts | `AppPackage/Package.resolved` and Xcode SourcePackages/DerivedData contain old dependency pins/checkouts. [VERIFIED: codebase grep] | Update `Package.swift`/`Package.resolved`; run a clean Xcode build/test after resolution. If stale package checkouts cause confusion, clean DerivedData outside source control. |

**Nothing found in category:** Stored live service config, OS registration, and secrets/env var runtime state were explicitly checked through planning docs and code grep. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: OpenCC Dictionary Modernization Changes Output

**What goes wrong:** Updating from the current OpenCC submodule snapshot to OpenCC `ver.1.4.0` may change conversion dictionaries or `.ocd` behavior, breaking DEP-01 parity. [VERIFIED: official git]
**Why it happens:** OpenCC release notes include dictionary and Darts format changes across versions. [VERIFIED: official git]
**How to avoid:** Fixture-lock current outputs for Traditional, HK, TW, and custom `"full color" -> "全彩"` behavior before changing dictionaries. [VERIFIED: codebase grep]
**Warning signs:** Failing conversion fixtures after replacing dictionaries or C++ internals. [VERIFIED: codebase grep]

### Pitfall 2: UIImageColors Renderer Modernization Alters Pixels

**What goes wrong:** Replacing deprecated `UIGraphicsBeginImageContextWithOptions` with `UIGraphicsImageRenderer` can alter scale, color space, alpha, or interpolation enough to change dominant colors. [VERIFIED: Xcode 26.6 SDK headers]
**Why it happens:** The current algorithm samples resized raw RGBA bytes and is sensitive to input rasterization. [VERIFIED: codebase grep]
**How to avoid:** Use generated deterministic images plus real fixture images; compare RGBA components for background/primary/secondary/detail before and after. [VERIFIED: 01-CONTEXT.md]
**Warning signs:** Tests fail only for gradients, transparent images, or very small images. [VERIFIED: codebase grep]

### Pitfall 3: swift-markdown Traversal Scope Drift

**What goes wrong:** New parsing may include headings, lists, nested images, or text that SwiftCommonMark currently ignores because `MarkdownUtil` only walks top-level paragraph blocks. [VERIFIED: codebase grep]
**Why it happens:** `MarkupWalker` naturally descends through all document children unless the adapter deliberately preserves paragraph scope. [VERIFIED: official git]
**How to avoid:** Add fixtures for paragraph-only behavior and any intentional fixes called out by D-07/D-10. [VERIFIED: 01-CONTEXT.md]
**Warning signs:** `TagTranslation.displayValue`, image URL extraction, or link arrays change on existing fixtures. [VERIFIED: codebase grep]

### Pitfall 4: DEP-06 Removes the Package but Keeps the Warning

**What goes wrong:** Inlining `CFReadStreamCreateForHTTPRequest` removes `DeprecatedAPI` but still emits a deprecation warning on the app target. [VERIFIED: Xcode 26.6 SDK headers]
**Why it happens:** `DeprecatedAPI` currently hides one deprecated SDK call in a dependency target. [VERIFIED: codebase grep]
**How to avoid:** Plan a non-deprecated implementation spike first; if none preserves D-14, keep the package and document D-12/D-13 skip evidence. [VERIFIED: 01-CONTEXT.md]
**Warning signs:** Build warnings mention `CFReadStreamCreateForHTTPRequest`, `kCFStreamPropertyHTTPResponseHeader`, or persistent connection stream properties. [VERIFIED: Xcode 26.6 SDK headers]

### Pitfall 5: Latest Colorful Compiles but Adds Deprecation Warnings

**What goes wrong:** `ColorfulView` exists in Colorful 1.1.1 with compatible initializer shape, but upstream marks it deprecated on non-watchOS. [VERIFIED: official git]
**Why it happens:** The upstream package recommends a Metal replacement for CPU reasons. [VERIFIED: official git]
**How to avoid:** Upgrade in isolation, run the clean build, and switch to an app-owned gradient view only if the deprecation violates the project build standard. [VERIFIED: .planning/ROADMAP.md]
**Warning signs:** Xcode warnings at `GalleryCardCell.swift` around `ColorfulView`. [VERIFIED: official git] [VERIFIED: codebase grep]

### Pitfall 6: Package Target Dependencies Leak Through Transitives

**What goes wrong:** Test targets directly depend on transitive dependencies rather than the module under test. [VERIFIED: pfw-testing skill]
**Why it happens:** Package manifest cleanup can tempt broad test-target dependency lists. [VERIFIED: codebase grep]
**How to avoid:** Test `MarkdownExt`, `SwiftyOpenCC`, and `UIImageColors` through their public APIs; add direct test dependencies only where the target is the subject under test. [VERIFIED: pfw-testing skill]
**Warning signs:** Test target dependencies include `Markdown`, `OpenCC`, or UI packages when testing a higher-level feature boundary. [VERIFIED: pfw-testing skill]

## Code Examples

Verified patterns from official sources and current code seams:

### PackageDescription Local and Remote Dependencies

```swift
.package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
.package(url: "https://github.com/Lakr233/Colorful.git", exact: "1.1.1"),
.target(name: "MarkdownExt", dependencies: [.markdown], plugins: [.swiftLint])
```

Source: Swift PackageDescription dependency/product/target APIs and existing manifest helper pattern. [CITED: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html] [VERIFIED: codebase grep]

### swift-markdown Text Collector Shape

```swift
import Markdown

struct TextCollector: MarkupWalker {
  var texts: [String] = []

  mutating func visitText(_ text: Text) {
    texts.append(text.string)
  }
}
```

Source: swift-markdown 0.8.0 `MarkupWalker` and `Text.string`. [VERIFIED: official git]

### Domain-Fronting Request Semantics Test Shape

```swift
@Suite("Domain-fronting request semantics")
struct DomainFrontingRequestTests {
  @Test("replaces URL host but preserves Host header")
  func hostReplacement() throws {
    var request = URLRequest(url: #require(URL(string: "https://example.com/path")))
    request.setValue("example.com", forHTTPHeaderField: "Host")

    let replaced = request.domainIPReplaced()

    #expect(replaced.value(forHTTPHeaderField: "Host") == "example.com")
    #expect(replaced.url?.path == "/path")
  }
}
```

Source: current `URLRequest.domainIPReplaced()` behavior and Swift Testing `#require` pattern. [VERIFIED: codebase grep] [VERIFIED: swift-testing-pro skill]

### UIImageColors Parity Assertion Shape

```swift
@Test("preserves extracted color tuple")
func generatedFixtureColors() throws {
  let colors = #require(image.getColors(quality: .lowest))

  #expect(colors.primary.rgbaTuple == expected.primary)
  #expect(colors.secondary.rgbaTuple == expected.secondary)
  #expect(colors.detail.rgbaTuple == expected.detail)
  #expect(colors.background.rgbaTuple == expected.background)
}
```

Source: current `getColors(quality:)` API and DEP-02 parity requirement. [VERIFIED: codebase grep] [VERIFIED: .planning/ROADMAP.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| External SwiftyOpenCC package pinned to `2.0.0-beta` with OpenCC submodule around `ver.1.1.2` | Local app-owned `SwiftyOpenCC` target, optionally informed by OpenCC `ver.1.4.0` but constrained by parity | OpenCC latest tag found 2026-07-01 | New OpenCC internals may improve modernization, but dictionary/output changes must not break DEP-01 parity. [VERIFIED: official git] |
| External UIImageColors package tag `2.2.0` using older UIKit image context APIs | Local app-owned `UIImageColors` target using modern UIKit APIs where output stays identical | UIKit headers mark old image context APIs deprecated in Xcode 26.6 SDK | Renderer modernization needs fixture proof because pixel output drives color selection. [VERIFIED: Xcode 26.6 SDK headers] |
| SwiftCommonMark package and `CommonMarkExt` helper | `swift-markdown` package product `Markdown` and `MarkdownExt` helper | swift-markdown latest semver tag found 2026-05-07 | Official Swift parser removes `SwiftCommonMark` and matches D-09 naming. [VERIFIED: official git] |
| External `DeprecatedAPI` wrapper around `CFReadStreamCreateForHTTPRequest` | Non-deprecated path if viable; otherwise documented skip and keep wrapper | CFHTTP stream APIs deprecated since iOS 9 in current SDK headers | Direct removal is not enough; preserving domain-fronting behavior has priority. [VERIFIED: Xcode 26.6 SDK headers] [VERIFIED: 01-CONTEXT.md] |
| Colorful 1.0.1 with comment avoiding 1.1.x deprecation | Colorful 1.1.1 or app-owned gradient if warnings block clean build | Latest Colorful tag found 2024-07-04 | Public initializer remains, but deprecation warning risk is real. [VERIFIED: official git] |

**Deprecated/outdated:**

- `SwiftCommonMark`: replace with `swift-markdown`/`MarkdownExt`. [VERIFIED: 01-CONTEXT.md]
- `UIImageColors` old `UIGraphicsBeginImageContextWithOptions` resizing path: modernize only with output parity. [VERIFIED: Xcode 26.6 SDK headers]
- `DeprecatedAPI` wrapper: remove only if warning-free non-deprecated DF path works. [VERIFIED: Xcode 26.6 SDK headers] [VERIFIED: 01-CONTEXT.md]
- `OpenCCExt` naming after localizing converter: D-05 says `*Ext` is for extending real external packages. [VERIFIED: 01-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A URLSession-based HTTPS replacement may not preserve current domain-fronting behavior because TLS/SNI/trust behavior is not a documented drop-in match for the current IP-host plus original-domain trust model. [ASSUMED] | Open Questions / DEP-06 | Planner might overestimate replacement viability; mitigate by making DEP-06 a spike with D-12 skip path. |

## Open Questions - RESOLVED

1. **DEP-06 viability resolution path:** `01-06-PLAN.md` Task 1 runs the evidence spike and records D-12 through D-15 semantics evidence in `01-DEP06-EVIDENCE.md`; Task 2 is the blocking `Approve the DEP-06 branch` checkpoint; Task 3 implements only the selected removal or documented-retention branch. This resolves the planning question without claiming that a warning-free replacement is already viable: the implementation outcome remains intentionally evidence-dependent until the checkpoint. [RESOLVED BY PLAN: 01-06 Task 1, Task 2 checkpoint, Task 3]

2. **OpenCC engine and dictionary parity resolution path:** `01-01-PLAN.md` Task 2 first locks default, HK, TW, and custom conversion outputs. `01-03-PLAN.md` Task 1 then vendors the internal `copencc` C++ bridge and required licenses, makes `SwiftyOpenCC` depend on `.module(.cOpenCC)`, adds typed `Path.dictionary`, copies resources with `.copy(.dictionary)`, and loads `.ocd2` files through `Bundle.module`. Task 2 proves the bridge opens and applies the bundled default/HK/TW dictionaries by comparing distinct regional conversions with the Wave 0 fixtures. Dictionary data that changes locked output is not adopted for DEP-01. [RESOLVED BY PLAN: 01-01 Task 2; 01-03 Task 1 and Task 2]

3. **Colorful clean-build acceptability resolution path:** `01-07-PLAN.md` Task 1 adopts the research-approved latest Colorful package; Task 2 requires the current Colorful API and a warning-free package build, and records a blocker rather than deleting or replacing Colorful if that cannot be achieved; Task 3 runs the full test plan and records visual UAT. This resolves how acceptability is decided while leaving the actual clean-build result to execution evidence. [RESOLVED BY PLAN: 01-07 Task 1, Task 2, Task 3]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Xcode / `xcodebuild` | Build, package resolution, tests | yes | Xcode 26.6 build 17F113 | None; project is Xcode-build constrained. [VERIFIED: environment probe] |
| Swift toolchain | SwiftPM manifest and tests | yes | Apple Swift 6.3.3 | None. [VERIFIED: environment probe] |
| iPhoneOS SDK | iOS build and SDK deprecation checks | yes | iPhoneOS 26.5 SDK | None. [VERIFIED: environment probe] |
| iPhoneSimulator SDK | Test execution | yes | iPhoneSimulator 26.5 SDK; iPhone Air id `ADE09605-A44E-4F00-BE12-235970217355` | None; verified with `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -showdestinations`. [VERIFIED: package workspace destinations] |
| Git | SwiftPM tag verification and commits | yes | 2.53.0 | None. [VERIFIED: environment probe] |
| Network access | Fetch new SwiftPM versions | restricted in sandbox | Available through approved escalations during research | Use existing pins if network is unavailable; planner should include package resolution verification. [VERIFIED: environment probe] |

**Missing dependencies with no fallback:** none; the package workspace exposes the confirmed iPhone Air simulator on iOS 26.5 with id `ADE09605-A44E-4F00-BE12-235970217355`. [VERIFIED: package workspace destinations]

**Missing dependencies with fallback:** none. The destination was locked with `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -showdestinations`. [VERIFIED: package workspace destinations]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing on Swift 6.3.3 [VERIFIED: codebase grep] [VERIFIED: environment probe] |
| Config file | `AppPackage/Tests/FeatureTests.xctestplan` [VERIFIED: codebase grep] |
| Quick run command | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` [VERIFIED: package workspace destinations] |
| Full suite command | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` [VERIFIED: package workspace destinations] |

The package workspace/scheme was verified to expose iPhone Air on iOS 26.5 with destination id `ADE09605-A44E-4F00-BE12-235970217355` by `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -showdestinations`. [VERIFIED: package workspace destinations]

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| DEP-01 | `ChineseConverter` and tag CHT conversion produce locked outputs for default/HK/TW options and custom `"full color"` case | unit/integration | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:SwiftyOpenCCTests -only-testing:FileClientTests` | No, Wave 0 adds `AppPackage/Tests/SwiftyOpenCCTests` and targeted FileClient fixture. [VERIFIED: codebase grep] |
| DEP-02 | `getColors(quality: .lowest)` returns identical background/primary/secondary/detail for deterministic image fixtures | unit | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:UIImageColorsTests` | No, Wave 0 adds `AppPackage/Tests/UIImageColorsTests`. [VERIFIED: codebase grep] |
| DEP-03 | `MarkdownUtil.parseTexts/parseLinks/parseImages`, `TagTranslation` markdown output, and `DetailView` dependency boundary stay correct | unit/integration | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:MarkdownExtTests -only-testing:TagTranslationFeatureTests` | No, Wave 0 adds `MarkdownExtTests`; TagTranslation tests may need a new target. [VERIFIED: codebase grep] |
| DEP-06 | Domain-fronting request rewriting, headers/cookies/body handling, redirects, and trust-host selection stay semantically unchanged | unit plus manual technical verification | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:NetworkingFeatureTests` | Partial; `NetworkingFeatureTests` exists but lacks DF-specific tests. [VERIFIED: codebase grep] |
| DEP-07 | `GalleryCardCell` builds on latest Colorful and visual animated-gradient concept is preserved | build plus manual visual UAT | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test` plus user visual verification | No stable automated UI visual test; acceptable per D-18/D-19. [VERIFIED: 01-CONTEXT.md] |

### Sampling Rate

- **Per task commit:** run the complete command in the touched requirement's `Phase Requirements -> Test Map` row. [VERIFIED: pfw-testing skill]
- **Per wave merge:** run the `Full suite command` in `Test Framework`. [VERIFIED: .planning/config.json]
- **Phase gate:** run the `Full suite command` in `Test Framework` before `$gsd-verify-work`; it must be green, followed by user visual verification for DEP-02/DEP-07 and tester evidence for DEP-06 if replacement is implemented. [VERIFIED: 01-CONTEXT.md]

### Wave 0 Gaps

- [ ] `AppPackage/Tests/SwiftyOpenCCTests` - covers DEP-01 converter parity. [VERIFIED: codebase grep]
- [ ] `AppPackage/Tests/UIImageColorsTests` - covers DEP-02 deterministic color parity. [VERIFIED: codebase grep]
- [ ] `AppPackage/Tests/MarkdownExtTests` - covers DEP-03 parser adapter parity. [VERIFIED: codebase grep]
- [ ] `AppPackage/Tests/TagTranslationFeatureTests` - covers DEP-03 app-level markdown-derived properties if not already covered by `MarkdownExtTests`. [VERIFIED: codebase grep]
- [ ] `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` - covers DEP-06 technical semantics. [VERIFIED: codebase grep]
- [x] Confirmed iPhone Air on iOS 26.5 with id `ADE09605-A44E-4F00-BE12-235970217355` using `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -showdestinations`. [VERIFIED: package workspace destinations]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | This phase does not change login/authentication flows. [VERIFIED: .planning/codebase/INTEGRATIONS.md] |
| V3 Session Management | yes, indirectly | Preserve cookie handling in DF requests; do not overwrite unrelated headers when injecting cookies. [VERIFIED: codebase grep] |
| V4 Access Control | no | No authorization boundary changes in scope. [VERIFIED: .planning/codebase/INTEGRATIONS.md] |
| V5 Input Validation | yes | Validate markdown image URLs through structured URL parsing and full-string validation; do not broaden untrusted markdown behavior without fixtures. [VERIFIED: codebase grep] |
| V6 Cryptography | yes | Use system trust APIs; do not hand-roll certificate validation or crypto. [VERIFIED: Xcode 26.6 SDK headers] [VERIFIED: swift-security-expert skill] |

### Known Threat Patterns for Swift/iOS Dependency Modernization

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Supply-chain package substitution | Tampering | Remove unnecessary external packages; verify SwiftPM Git remotes/tags before adding/updating packages. [VERIFIED: official git] |
| Markdown URL spoofing or broadening | Spoofing/Tampering | Keep URL validation and fixture-lock accepted/rejected image URL cases. [VERIFIED: codebase grep] |
| Domain-fronting trust regression | Spoofing/Information Disclosure | Preserve original-domain trust evaluation and document real-world verification needs. [VERIFIED: codebase grep] [VERIFIED: 01-CONTEXT.md] |
| Cookie/header loss during DF rewrite | Tampering/Repudiation | Add tests for Host header, cookie merge semantics, body preservation, and redirect propagation. [VERIFIED: codebase grep] |
| Deprecated network API hidden in local code | Tampering/Operational risk | Do not inline deprecated CFStream calls unless D-12 skip path is explicitly documented. [VERIFIED: Xcode 26.6 SDK headers] |

## Sources

### Primary (HIGH/MEDIUM confidence)

- `.planning/phases/01-isolated-dependency-modernization/01-CONTEXT.md` - locked phase decisions D-01 through D-19 and F-01. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `.planning/STATE.md` - phase requirements, success criteria, milestone constraints. [VERIFIED: codebase grep]
- `.planning/codebase/STACK.md`, `ARCHITECTURE.md`, `INTEGRATIONS.md` - package layout, build constraints, feature/client patterns, integration risks. [VERIFIED: codebase grep]
- `AGENTS.md` and root `.swiftlint.yml` - project constraints and lint rules. [VERIFIED: codebase grep]
- `AppPackage/Package.swift`, `Package.resolved`, and relevant `AppPackage/Sources` files - exact seams and target dependencies. [VERIFIED: codebase grep]
- Xcode 26.6 iPhoneOS 26.5 SDK headers: `CFHTTPStream.h`, `UIGraphics.h`, `SecTrust.h` - deprecations and trust API availability. [VERIFIED: Xcode 26.6 SDK headers]
- Official Git remotes/tags for `swiftlang/swift-markdown`, `Lakr233/Colorful`, `BYVoid/OpenCC`, and current resolved package checkouts. [VERIFIED: official git]
- Swift PackageDescription documentation - package, product, dependency, local path, and target APIs. [CITED: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html]

### Secondary (MEDIUM confidence)

- GSD research-plan/cache/classify seams - provider plan, cache storage, confidence classification, and unsupported Swift ecosystem package-legitimacy result. [VERIFIED: gsd-tools]
- Loaded project skills: `pfw-spm`, `pfw-testing`, `swift-testing-pro`, `pfw-dependencies`, `pfw-custom-dump`, `swift-security-expert`. [VERIFIED: local skills]

### Tertiary (LOW confidence)

- DEP-06 URLSession/SNI replacement concern is marked `[ASSUMED]` because no official documentation proving equivalence or non-equivalence was found in this session. [ASSUMED]

## Metadata

**Confidence breakdown:**

- Standard stack: MEDIUM - package tags and local code seams were verified, but SwiftPM package-legitimacy seam does not support Swift packages. [VERIFIED: official git] [VERIFIED: gsd-tools]
- Architecture: HIGH - based on project planning docs, AGENTS.md, Package.swift, and exact source seams. [VERIFIED: codebase grep]
- Pitfalls: MEDIUM - most are source/SDK verified; DEP-06 replacement viability remains uncertain by design. [VERIFIED: Xcode 26.6 SDK headers] [ASSUMED]

**Research date:** 2026-07-10
**Valid until:** 2026-08-09 for package/version facts; re-check tags and SDK deprecations before implementation if delayed.
