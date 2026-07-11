# Phase 02: Native Masonry Grid Swap - Pattern Map

**Mapped:** 2026-07-11
**Files analyzed:** 5 (2 create source, 1 edit source, 2 create test, 1 edit manifest)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `AppPackage/Sources/GalleryListComponents/MasonryLayout.swift` (CREATE) | component (SwiftUI `Layout`) | transform (geometry) | `AppPackage/Sources/AppComponents/TagCloudView.swift` (`FlowLayout: Layout`) | exact (same `Layout` protocol, same module family) |
| `AppPackage/Sources/GalleryListComponents/GenericList.swift` (EDIT) | component (view) | request-response (list render) | itself (`DetailList` sibling + current `WaterfallList`) | exact (in-file precedent) |
| `AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift` (CREATE) | test | batch (table-driven `@Test(arguments:)`) | `AppPackage/Tests/ImageColorsTests/ImageColorsParityTests.swift` | role-match (Swift Testing suite in an AppPackage test target) |
| `AppPackage/Tests/GalleryListComponentsTests/.swiftlint.yml` (CREATE) | config | — | `AppPackage/Tests/ImageColorsTests/.swiftlint.yml` | exact (identical one-line file) |
| `AppPackage/Package.swift` (EDIT) | config (SwiftPM manifest) | — | `.testTarget(module: .imageColorsTests …)` + `Module` enum + `.waterfallGrid` dep lines | exact (in-file precedent) |

## Pattern Assignments

### `AppPackage/Sources/GalleryListComponents/MasonryLayout.swift` (CREATE — component, `Layout`)

**Analog:** `AppPackage/Sources/AppComponents/TagCloudView.swift` — `private struct FlowLayout: Layout` (lines 32-92).

**`Layout` conformance shape** (`TagCloudView.swift:32-69`) — mirror the two required methods and the `cache: inout` parameter. Note this analog uses `inout ()` (cache-less); `MasonryLayout` upgrades to a real `Cache` struct per RESEARCH D-29, so the cache type is the intentional deviation:
```swift
private struct FlowLayout: Layout {
    let spacing: Double

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let frames = frames(
            for: subviews,
            maxWidth: proposal.width ?? .infinity
        )
        let size = frames.reduce(CGSize.zero) { size, frame in
            CGSize(
                width: max(size.width, frame.maxX),
                height: max(size.height, frame.maxY)
            )
        }
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let frames = frames(for: subviews, maxWidth: bounds.width)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + frames[index].minX,
                    y: bounds.minY + frames[index].minY
                ),
                proposal: ProposedViewSize(frames[index].size)
            )
        }
    }
```

**Degenerate-proposal idiom** (`TagCloudView.swift:75`) — the exact defensive pattern D-32 requires; `MasonryLayout` applies the same "finite-or-fallback" guard before deriving N:
```swift
    let maxWidth = maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude
```

**Placement loop** (`TagCloudView.swift:60-68`) — `for (index, subview) in subviews.enumerated()` + `subview.place(at:proposal:)` translating a precomputed origin by `bounds.minX/minY`. `MasonryLayout.placeSubviews` copies this exact loop shape, substituting the masonry plan's origins.

**Subview measurement** (`TagCloudView.swift:79`) — `subview.sizeThatFits(.unspecified)`. `MasonryLayout` measures at the fixed cell width instead (`.init(width: cellW, height: nil)`, D-29), but the call site shape is the same.

**SwiftLint note:** root `.swiftlint.yml` sets `force_unwrapping` and `force_try` to **error**. The WaterfallGrid parity source force-unwraps `heights.min()!` / `heights.max()!`; the new code must use `?? spacing` fallbacks (RESEARCH §Project Constraints). `line_length`/`file_length` 120/1000 at error.

---

### `AppPackage/Sources/GalleryListComponents/GenericList.swift` (EDIT — component, view)

**Analog:** in-file — the `private struct WaterfallList` (lines 150-238) being edited, plus the `DetailList` sibling (lines 83-147) for the untouched `List` idioms.

**Import to drop** (`GenericList.swift:6`):
```swift
import WaterfallGrid
```

**Column reads to delete** (`GenericList.swift:160-165`, D-34) — these die with the library; do NOT touch `DeviceUtil.isPadWidth` itself:
```swift
    private var columnsInPortrait: Int {
        DeviceUtil.isPadWidth ? 4 : 2
    }
    private var columnsInLandscape: Int {
        DeviceUtil.isPadWidth ? 5 : 2
    }
```

**Call site to swap** (`GenericList.swift:201-217`) — replace the `WaterfallGrid(galleries) { … }.gridStyle(…)` with `MasonryLayout { ForEach(galleries) { … } }.animation(nil, value: galleries)` (D-31). Preserve the inner `Button { navigateAction?(gallery) } label: { GalleryThumbnailCell(...) … }.buttonStyle(.borderless)` verbatim:
```swift
            WaterfallGrid(galleries) { gallery in
                Button {
                    navigateAction?(gallery)
                } label: {
                    GalleryThumbnailCell(
                        gallery: gallery,
                        translateAction: translateAction,
                        downloadBadge: downloadBadges[gallery.gid]
                    )
                    .tint(.primary).multilineTextAlignment(.leading)
                }
                .buttonStyle(.borderless)
            }
            .gridStyle(
                columnsInPortrait: columnsInPortrait, columnsInLandscape: columnsInLandscape,
                spacing: 15, animation: nil
            )
```

**Structure to PRESERVE (D-30)** — the enclosing `List { … }.listStyle(.plain)` (lines 195-237), the notice `Section` (lines 196-200), and the fetch-more footer / chevron `Button` branch (lines 218-234) are unchanged. `MasonryLayout` becomes the single eager row between them. The ancestor `.animation(.default, value: galleries)` at `GenericList.swift:77` stays; the new `.animation(nil, value: galleries)` on the grid subtree neutralizes it for placements only (RESEARCH Pattern 3).

---

### `AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift` (CREATE — test)

**Analog:** `AppPackage/Tests/ImageColorsTests/ImageColorsParityTests.swift` (lines 1-23) — Swift Testing suite that parity-locks a pure module function.

**Import + suite header** (`ImageColorsParityTests.swift:1-23`) — match the `import Testing` + `@testable`/plain module import + `@Suite struct` idiom. `MasonryLayout` and its pure functions are module-internal (never `public`; D-35's "private policy" means not an app-wide public breakpoint system, NOT file-scope `private` — a file-`private` type is unreachable by `@testable`), so tests need `@testable import GalleryListComponents` (which exposes `internal` symbols), unlike this analog's plain `import ImageColors`, which tests a `public` API:
```swift
import Testing
import Foundation
import SwiftUI
import UIKit
import ImageColors
…
@Suite
struct ImageColorsParityTests {
```

**Table-driven test idiom** — use `@Test(arguments: [...] as [(CGFloat, Int)])` for the `columnCount(for:)` sign-off table and plain `@Test func` + `#expect` for placement/degenerate cases (RESEARCH §Code Examples has the concrete table). This is the standard project idiom; `MarkdownExtTests/MarkdownUtilParityTests.swift` is a second reference for the same `@Suite`/`@Test`/`#expect` shape.

**Note:** `MasonryLayout.columnCount(for:)`, `cellWidth(containerWidth:columns:)`, and `masonryPlan(...)` must be at least `internal` (not `private`) so `@testable import` reaches them — the pure-function seam RESEARCH Pattern 2 specifies.

---

### `AppPackage/Tests/GalleryListComponentsTests/.swiftlint.yml` (CREATE — config)

**Analog:** `AppPackage/Tests/ImageColorsTests/.swiftlint.yml` — verified full contents (one line). Copy verbatim (project rule: new module needs a `parent_config` pointing at the package root config, three levels up from a `Tests/<Module>Tests/` dir):
```yaml
parent_config: ../../../.swiftlint.yml
```

---

### `AppPackage/Package.swift` (EDIT — SwiftPM manifest)

**Analog:** in-file precedents for every edit.

**WaterfallGrid dependency to remove** — four lines:
- `Package.swift:23` — package declaration:
  ```swift
      .package(url: "https://github.com/paololeonardi/WaterfallGrid", from: "1.0.0"),
  ```
- `Package.swift:49` — product alias:
  ```swift
      static let waterfallGrid: Self = .product(name: "WaterfallGrid", package: "WaterfallGrid")
  ```
- `Package.swift:301` — app/AppFeature target dependency (last entry in that list; remove the line and fix the trailing comma on line 300):
  ```swift
              .targetDependency(.waterfallGrid)
  ```
- `Package.swift:482` — `galleryListComponents` target dependency (last entry; remove and fix comma on line 481):
  ```swift
              .targetDependency(.waterfallGrid)
  ```

**`Module` enum case to ADD** (analog: existing test-target cases `Package.swift:122-124`, alphabetical-ish grouping under `// Test targets`):
```swift
    case imageColorsTests = "ImageColorsTests"
    case markdownExtTests = "MarkdownExtTests"
    case tagTranslationFeatureTests = "TagTranslationFeatureTests"
```
→ add `case galleryListComponentsTests = "GalleryListComponentsTests"`.

**`.testTarget` to ADD** (analog: `Package.swift:961-967`, the `imageColorsTests` entry — the closest shape: a single-module dependency + `swiftLintPlugins`):
```swift
    .testTarget(
        module: .imageColorsTests,
        dependencies: [
            .module(.imageColors)
        ],
        plugins: swiftLintPlugins
    ),
```
→ new entry: `module: .galleryListComponentsTests`, `dependencies: [.module(.galleryListComponents)]`, same `plugins: swiftLintPlugins`. Append inside the test-targets array (before the closing `]` at line 985; add a comma after the current final `tagTranslationFeatureTests` entry).

**Post-edit:** regenerate `AppPackage/Package.resolved` (`swift package resolve`) — it pins `waterfallgrid` at lines 266-272 and must drop the entry (RESEARCH §Runtime State Inventory). Confirm zero `WaterfallGrid` refs remain in `Package.swift` and `Package.resolved` (SR-4 build gate).

## Shared Patterns

### SwiftLint conformance (applies to all new Swift + the new test dir)
**Source:** root `.swiftlint.yml` (read before writing per project rule) + `AppPackage/Tests/ImageColorsTests/.swiftlint.yml`
**Apply to:** `MasonryLayout.swift`, `MasonryLayoutTests.swift`, and the new `.swiftlint.yml`.
- `force_unwrapping` / `force_try` are **errors** — no `!` / `try!`; use `?? spacing` fallbacks where the WaterfallGrid parity source force-unwrapped.
- `line_length` 120 / `file_length` 1000 at error.
- New test dir MUST carry `parent_config: ../../../.swiftlint.yml`.
- No `// swiftlint:disable` without explicit owner permission.

### Swift Testing (applies to the test file)
**Source:** `AppPackage/Tests/ImageColorsTests/ImageColorsParityTests.swift:1-23`, `AppPackage/Tests/MarkdownExtTests/MarkdownUtilParityTests.swift`
**Apply to:** `MasonryLayoutTests.swift`
`import Testing` + `@Suite struct` + `@Test`/`@Test(arguments:)` + `#expect`. Project standard is Swift Testing (not XCTest). Run one `xcodebuild test` invocation at a time.

### Pure-function-behind-Layout seam
**Source:** RESEARCH Pattern 1/2 (grounded in the `FlowLayout` `frames(for:maxWidth:)` private-helper split at `TagCloudView.swift:71-91`)
**Apply to:** `MasonryLayout.swift`
`FlowLayout` already factors its geometry into a private `frames(...)` helper the `Layout` methods call. `MasonryLayout` follows the same split but promotes the helpers to `static internal` (`columnCount(for:)`, `cellWidth(containerWidth:columns:)`, `masonryPlan(...)`) so the test target can reach them value-in/value-out — `LayoutSubviews` is not synthesizable in a unit test.

## No Analog Found

None. Every file has a concrete in-repo analog (the `Layout` protocol, `List` structure, Swift Testing suites, `.swiftlint.yml`, and SwiftPM manifest edits all have precedent).

## Metadata

**Analog search scope:** `AppPackage/Sources/AppComponents`, `AppPackage/Sources/GalleryListComponents`, `AppPackage/Tests/ImageColorsTests`, `AppPackage/Tests/MarkdownExtTests`, `AppPackage/Package.swift`, `AppPackage/Package.resolved`.
**Files scanned:** 7 (TagCloudView.swift, GenericList.swift, ImageColorsParityTests.swift, ImageColorsTests/.swiftlint.yml, Package.swift, Package.resolved, + test dir listing).
**Pattern extraction date:** 2026-07-11
