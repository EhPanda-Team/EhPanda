# Phase 1: Isolated Dependency Modernization - Context

**Gathered:** 2026-07-10T00:49:22+09:00
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase modernizes the isolated dependency surface without changing user-facing behavior: replace `SwiftyOpenCC` and `UIImageColors` with app-owned local modules, migrate `SwiftCommonMark` usage to Apple `swift-markdown`, remove `DeprecatedAPI` only if domain fronting can be preserved, and update `Colorful` while keeping the Home card gradient concept intact.

</domain>

<decisions>
## Implementation Decisions

### Local Consumed Dependencies
- **D-01:** `SwiftyOpenCC` and `UIImageColors` should become app-owned local modules in `AppPackage/Sources`, not external fork repositories.
- **D-02:** These modules do not need to support users outside EhPanda. Shape their APIs to best fit this app; keep the current API only if it remains the best fit.
- **D-03:** Treat the imported code as full modernization work, not simple vendoring: latest Swift/tooling, latest APIs, bug fixes, removed restrictions, tests/lint/docs where practical, and parity evidence before adoption.
- **D-04:** Prefer clean-room local modules: import or rewrite only the needed implementation into app-specific modules with best-fit APIs and no public-library compatibility burden.
- **D-05:** Consumed package modules should use the original package name, not `*Ext`. `*Ext` is reserved for modules that extend a real external package.
- **D-06:** New local modules under `AppPackage/Sources` must include `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml`.

### Markdown Migration
- **D-07:** Migrate tag-translation markdown parsing with best-fit behavior plus fixture lock: preserve intended outputs, but allow fixes to obvious parser limitations or bugs when fixtures document the intended behavior.
- **D-08:** `DetailFeature` should not directly depend on the markdown package. Any needed markdown behavior should go through a local helper/module.
- **D-09:** Apple `swift-markdown` exposes the product/target name `Markdown`. If app helper code extends that real external package, name the helper module `MarkdownExt`; do not create a conflicting app-owned `Markdown` module.
- **D-10:** Require focused fixtures for `parseTexts`, `parseLinks`, and `parseImages`, including current edge cases and intentional bug fixes.

### Domain Fronting / DeprecatedAPI
- **D-11:** The design around the DF networking stream path may be rethought freely, but the domain fronting feature must be preserved.
- **D-12:** If research proves the current deprecated API path is the only viable way to keep domain fronting working, skip the `DeprecatedAPI` removal rather than remove or weaken domain fronting.
- **D-13:** Evidence for a skip must combine documented technical proof with technical request verification. Full E2E proof is not locally feasible because the feature targets SNI filtering conditions requiring testers physically located in China.
- **D-14:** Preserve current request semantics exactly: domain-to-IP replacement, `Host` header behavior, cookie/header handling, redirect/response propagation, and custom trust handling.
- **D-15:** If a viable non-deprecated implementation exists, use a direct replacement. Real-world verification will be handled by user-arranged testers in China.

### Color And Visual Parity
- **D-16:** For the local `UIImageColors` replacement, preserve the package's existing behavior. This is a tech-stack/latest-API refactor, not an algorithm or visual redesign.
- **D-17:** For latest `Colorful`, preserve the same animated-gradient concept, but minor polish is allowed if it looks better.
- **D-18:** Automated coverage should be technical tests only where deterministic, such as stable color extraction behavior on fixtures.
- **D-19:** Final visual judgment for `UIImageColors` and `Colorful` belongs in the user verification step; automated tests must not pretend to prove subjective visual parity.

### the agent's Discretion
- Keep current APIs or behavior where they are already the best fit for EhPanda.
- Skip `DeprecatedAPI` removal if documented research shows domain fronting cannot be preserved without the current API.
- Choose deterministic technical tests for visual/color work where the exposed local code makes them useful.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/ROADMAP.md` — Phase 1 goal, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` — DEP-01, DEP-02, DEP-03, DEP-06, and DEP-07 acceptance criteria.
- `.planning/PROJECT.md` — Milestone constraints, parity bar, local-module architecture, and dependency-reduction goals.

### Codebase Maps
- `.planning/codebase/STACK.md` — Current dependency pins, toolchain, package layout, and build constraints.
- `.planning/codebase/INTEGRATIONS.md` — External services and request/auth/storage integration context.
- `.planning/codebase/ARCHITECTURE.md` — App-shell plus local package architecture, client/feature patterns, lint expectations.

### Package And Module Structure
- `AppPackage/Package.swift` — Single source of truth for dependencies, products, targets, Swift settings, and SwiftLint plugin wiring.
- `AppPackage/Sources/SystemNotificationExt/.swiftlint.yml` — Existing local-module SwiftLint parent config example.

### Markdown
- `AppPackage/Sources/CommonMarkExt/MarkdownUtil.swift` — Current parse helpers and behavior to fixture-lock or intentionally improve.
- `AppPackage/Sources/TagTranslationFeature/TagTranslation+Markdown.swift` — Current tag-translation markdown call sites.
- `AppPackage/Sources/DetailFeature/DetailView.swift` — Direct `CommonMark` import to eliminate or route through helper code.
- `https://github.com/swiftlang/swift-markdown/blob/main/Package.swift` — Confirms the external product/target name is `Markdown`.

### Domain Fronting
- `AppPackage/Sources/NetworkingFeature/DFExtensions.swift` — Current `DeprecatedAPI.getCFReadStream` usage and request-to-stream construction.
- `AppPackage/Sources/NetworkingFeature/DFRequest.swift` — DF request creation, cookie/header handling, and stream setup.
- `AppPackage/Sources/NetworkingFeature/DFStreamHandler.swift` — Response, redirect, data, error, and trust handling.
- `AppPackage/Sources/NetworkingFeature/DFURLProtocol.swift` — URLProtocol bridge for DF request behavior.

### Color And Gradients
- `AppPackage/Sources/LibraryClient/LibraryClient.swift` — Current `UIImageColors.getColors` integration and async wrapper.
- `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` — Current `ColorfulView` gradient surface and fallback colors.
- `AppPackage/Sources/HomeFeature/HomeReducer.swift` — Home state shape for extracted card colors.
- `AppPackage/Sources/HomeFeature/HomeReducer+Body.swift` — Color-analysis effect flow.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppPackage/Package.swift`: centralized dependency and target definitions; Phase 1 changes should be planned here rather than in the Xcode project.
- Existing per-module `.swiftlint.yml` files: new local consumed modules should follow the same parent config pattern.
- `FileClientTests`: existing deterministic tag-translation cache tests can guide additional fixture-based coverage around converted translations.

### Established Patterns
- App-owned code lives under `AppPackage/Sources/<Module>` and is linted through the SwiftLint build-tool plugin.
- `*Ext` module names mean extension code around a real external package; consumed local packages should use the package/domain name instead.
- Side-effect seams use client modules, but pure parsing/conversion helpers can stay as local modules when injection is unnecessary.

### Integration Points
- Dependency declarations and product references connect through `AppPackage/Package.swift`.
- Markdown behavior feeds `TagTranslationFeature` and currently has a direct stray import in `DetailFeature`.
- Domain fronting flows through `DFURLProtocol`, `DFRequest`, `DFExtensions`, and `DFStreamHandler`.
- Color extraction flows from Home image success into `LibraryClient.analyzeImageColors`, then into `GalleryCardCell` colors and `ColorfulView`.

</code_context>

<specifics>
## Specific Ideas

- Domain fronting is a feature for bypassing SNI filtering. Local E2E validation is not possible without the relevant network conditions; user-arranged testers in China are needed for final confirmation.
- `SystemNotificationExt` should eventually be renamed to `SystemNotification` under the clarified module naming convention, but that cleanup is not part of Phase 1 unless directly coupled.

</specifics>

<deferred>
## Deferred Ideas

- Rename `SystemNotificationExt` to `SystemNotification` as a module naming cleanup outside Phase 1 unless directly coupled.

</deferred>

---

*Phase: 1-Isolated Dependency Modernization*
*Context gathered: 2026-07-10T00:49:22+09:00*
