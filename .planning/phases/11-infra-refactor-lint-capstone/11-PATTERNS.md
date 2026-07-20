# Phase 11: Infra Refactor & Lint Capstone - Pattern Map

**Mapped:** 2026-07-20
**Files analyzed:** 7 work groups (1 new module + config + ~6 modification categories spanning ~300 files)
**Analogs found:** 7 / 7 (one group intentionally falls back to CONTEXT's reproduced design)

This is a refactor phase: most "files" are categories of edits, not new files. Patterns are mapped per work group.

## File Classification

| Work Group | Representative Files | Role | Data Flow | Closest Analog | Match Quality |
|------------|---------------------|------|-----------|----------------|---------------|
| G1: `.swiftlint.yml` rule enable/redefine | root `.swiftlint.yml` | config | — | existing active custom rules in same file | exact |
| G2: `try?` → do/catch + logger (D-04 A/B) | `AppPackage/Sources/ParserFeature/Parser+*.swift` | service/parser | transform | `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift` (logger use) + `ParserFeature/Logger+.swift` (init convention) | exact |
| G3: `try?` → propagation (D-03/D-04 C) | `Parser+List.swift`, owning reducers | reducer | request-response | `AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift` | exact |
| G4: lifecycle migration (D-06/D-07) | ~46 view sites + presenting reducers | reducer + view | event-driven | `FrontpageReducer.swift` (destination presentation) + `HomeReducer+Body.swift` (StackState path handling) | exact |
| G5: PreviewSupport module (D-09) | new `AppPackage/Sources/PreviewSupport/` | utility module | — | design reproduced in CONTEXT §Specifics; module scaffolding from `Package.swift` + `DownloadClient/.swiftlint.yml` | design-supplied |
| G6: test-isolation seams (D-12) | `FileClient`, Kingfisher-touching tests | client + test | file-I/O | `AppPackage/Sources/DownloadClient/DownloadStore.swift` (injectable rootURL) + `AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift` | exact |
| G7: retained-serialization rationale (D-14) | `DidLoginKeyTests.swift` | test | — | `AppPackage/Tests/FileClientTests/FileClientTests.swift:7-10` rationale comment | exact |

## Pattern Assignments

### G1: `.swiftlint.yml` rule work

**Analog:** the active rules in root `.swiftlint.yml` itself.

- **Rule shape to copy** — every active custom rule follows this form (e.g. `system_name_image_parameter`, lines 179–186):
```yaml
  system_name_image_parameter:
    name: "systemName / systemImage Parameter"
    regex: "\\b(?:systemName|systemImage)\\s*:"
    message: "..."
    excluded_match_kinds:
      - comment
      - string
    severity: error
```
- **Path-exclusion precedent** — the draft `unchecked_subscript_index_access` rule (lines 188–199, commented) already carries `excluded:` patterns (`".*/[^/]*Tests\\.swift$"`, `"\\[validatedIndex\\]"`); reuse this mechanism where a rule needs scoping. Note D-15: `optional_try` gets **no** Tests exclusion.
- **Draft rules to uncomment/redefine:** `binding_initializer` (lines 45–52 — replace regex with the D-05 narrowed `\bBinding\s*(?:<[^>]*>)?\s*\(\s*get\s*:` from RESEARCH), `lifecycle_modifiers` (99–106), `optional_try` (144–151), `single_line_trailing_closure` (162–169), `unchecked_subscript_index_access` (188–199). New `labeled_tuple_elements` rule: starting regex in RESEARCH Pattern 6.
- **Exception form** — policed by `swiftlint_disable_requires_reason` (lines 171–178): a `// reason: …` line must immediately precede `// swiftlint:disable:next <rule>`.
- **Stale exclusion:** `excluded: [EhPanda/App/Generated]` at file bottom points at a dead path — fix while touching the config (RESEARCH Pitfall 5).

### G2: do/catch + logger (D-04 Groups A/B)

**Analogs:** `AppPackage/Sources/ParserFeature/Logger+.swift` (all 7 lines) + `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift`.

**Logger init convention** (`Logger+.swift`, entire file — ParserFeature already has this extension):
```swift
import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "ParserFeature", category: category)
    }
}
```

**File-top logger declaration** (`LoginReducer.swift:9`):
```swift
private let logger = Logger(category: .init(describing: LoginReducer.self))
```
For Parser files, category is the file's parser concern (e.g. `.init(describing: Parser.self)`).

**Target sites** (`Parser+List.swift:10–29, 65, …`) currently look like:
```swift
galleries = (try? parseMinimalModeGalleries(doc: doc, parsesTags: false)) ?? []   // Group C
let tags = (try? parseGalleryTags(node: gltmNode)) ?? []                          // Group B
```
Group A/B replacement (RESEARCH Pattern 1): explicit `do { try … } catch { logger.error("Dropped …: \(error)"); return nil /* or [] */ }` — behavior identical, no `try?` survives. **Never log raw HTML/URLs/cookies** (Phase 8 privacy scan gate).

### G3: error propagation to reducers (D-03/D-04 Group C)

**Analog:** `AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift` lines 93–126 — the canonical typed-throws fetch + failure-state pattern every gallery-list reducer already uses:

```swift
case .fetchGalleries:
    guard state.loadingState != .loading else { return .none }
    state.loadingState = .loading
    ...
    return .run { send in
        do throws(AppError) {
            let response = try await FrontpageGalleriesRequest(host: host, filter: filter).response()
            await send(.fetchGalleriesDone(.success(response)))
        } catch {
            await send(.fetchGalleriesDone(.failure(error)))
        }
    }
    .cancellable(id: CancelID.fetchGalleries)

case .fetchGalleriesDone(let result):
    state.loadingState = .idle
    switch result {
    case .success(let response): ...
    case .failure(let error):
        state.loadingState = .failed(error)
    }
```

Group C fix: `Parser+List.swift:10–29` mode branches change `(try? …) ?? []` to plain `try` — the `throws` signature already reaches these reducers, and `.failed(error)` / Phase 9 ErrorInfo-toast handling already exists at every call site. Update `ParserFeatureTests` empty-list assertions to thrown-error assertions in the same plan (RESEARCH Pitfall 7).

### G4: presentation-driven lifecycle (D-06/D-07)

**Analogs:** `FrontpageReducer.swift:85–91` (destination presentation), `HomeReducer+Body.swift:29–49` (StackState `.path(.element(id:action:))` interception), `HomeReducer.swift:20,67` (StackState/StackActionOf shape).

**Presentation-as-state-transition** (`FrontpageReducer.swift:85–91`):
```swift
case .filtersButtonTapped:
    state.destination = .filters(FiltersReducer.State())
    return .none
```
Migration: the presenting case additionally returns the child's former onAppear effect (e.g. `.send` of the child's `.load` via the destination/path action), replacing the view-side hook.

**Path push** (`HomeReducer+Body.swift:41`):
```swift
state.path.appendGuardingDuplicate(.gallery(.detail(.init(gallery: gallery))))
```

**Delegate interception** (`HomeReducer+Body.swift:29–33`) — the pattern for a parent reacting to child path actions; use the same interception to fire the child's load on presentation.

**View-site shape being removed** (`FrontpageView.swift:50–56` — representative of ~25 sites):
```swift
.onAppear {
    if store.galleries.isEmpty {
        DispatchQueue.main.async {
            store.send(.fetchGalleries)
        }
    }
}
```
Note: most sites are fetch-if-empty-guarded (idempotent — once-per-presentation parity holds). Rename/remove the `.onAppear` TCA actions themselves or the lint regex still fires (RESEARCH Pitfall 2). `Delegate` enums stay siblings of `Action`; new sub-reducers take the `Feature` suffix.

### G5: PreviewSupport module (D-09) — NEW module

**Design source:** CONTEXT §Specifics + RESEARCH Pattern 4 (reproduced name-free; no codebase analog for the table itself). Scaffolding analogs:

**Package target** (`AppPackage/Package.swift` ~line 306 — copy shape):
```swift
.target(
    module: .appModels,
    dependencies: [ ... ],
    plugins: swiftLintPlugins
),
```

**Module lint stub** (`AppPackage/Sources/DownloadClient/.swiftlint.yml`, entire file):
```yaml
parent_config: ../../../.swiftlint.yml
```

**Checked subscript** (from CONTEXT, verbatim design):
```swift
public static subscript(index: Int) -> UUID {
    precondition(all.indices.contains(index), "index out of bounds")
    // reason: bounds are precondition-checked immediately above.
    // swiftlint:disable:next unchecked_subscript_index_access
    return all[index]
}
```

**Initial consumers** — the 5 files combining `#Preview` with `UUID()`:
`HomeFeature/GalleryRankingCell.swift`, `HomeFeature/GalleryCardCell.swift`, `SearchFeature/GalleryHistoryCell.swift`, `GalleryListComponents/Cells/GalleryThumbnailCell.swift`, `GalleryListComponents/Cells/GalleryDetailCell.swift`.

### G6: injectable seams (D-12)

**Production seam analog:** `AppPackage/Sources/DownloadClient/DownloadStore.swift:59–66` — injectable root with production default:
```swift
public let rootURL: URL

init(
    rootURL: URL = FileUtil.downloadsDirectoryURL,
    ...
) {
    self.rootURL = rootURL
```
and `DownloadClient.swift:38–42` threading it through. FileClient's tag-translation cache/import endpoints get the same shape.

**Test-side analog:** `AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift:10`:
```swift
func makeIsolatedDataCache() -> (cache: DataCache, rootURL: URL) {
```
(per-test isolated instance + UUID-scoped root; note this tuple return is itself a D-10 labeled-tuple example already done right). Same idiom for the Kingfisher `ImageCache` injection in the two DownloadImageParsing test suites.

**UUID-scoped fixture roots:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` (`writeFixtureToTemporaryFile` family) — already parallel-safe; the model for anything still writing shared paths.

### G7: retained-serialization rationale comments (D-14)

**Analog:** `AppPackage/Tests/FileClientTests/FileClientTests.swift:7–10`:
```swift
// Serialized: the tag-translation cache/import endpoints write fixed paths in the real Caches and
// Application Support directories, so parallel cases would race on the same files.
@Suite(.serialized)
```
Copy this comment shape onto every surviving `.serialized`/`@MainActor` (per D-14: DidLoginKeyTests needs one added — its rationale is the Sharing process-global weak reference cache). Ironically the FileClientTests comment itself becomes obsolete once the G6 seam lands — the suite drops `.serialized` instead.

## Shared Patterns

### Exception mechanism (D-01/D-02) — applies to all groups
**Source:** `.swiftlint.yml:171–178` (`swiftlint_disable_requires_reason`)
```swift
// reason: <why this genuinely cannot be implemented without the banned construct>
// swiftlint:disable:next optional_try
```
Executors write candidates in this form as they arise; owner reviews the batch at phase-end (CONTEXT exception-review flow).

**Interim lint noise is expected — leave the disables in place.** Until a rule's config flip lands (`lifecycle_modifiers`/`binding_initializer` at 11-11, `unchecked_subscript_index_access` at 11-17, `optional_try` at 11-24), a `disable:next` comment naming the still-commented-out rule id makes `superfluous_disable_command` emit a warning on every build. These warnings are expected for up to ~20 waves and do not fail builds — "builds clean" gates in plans mean zero *errors*. Never delete a pre-flip disable comment to silence this warning: it becomes load-bearing the moment the rule flips.

### Verification is the lint binary, not grep
**Source:** RESEARCH "Sweep/verification command". Every plan's zero-check:
```bash
SWIFTLINT="$HOME/Library/Developer/Xcode/DerivedData/AppPackage-glhpivzptobywqasgqylwdgfzzei/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint"
"$SWIFTLINT" lint --quiet --reporter json AppPackage/Sources AppPackage/Tests App ShareExtension
```
Pass explicit paths (never traverse `AppPackage/.build`). Flip each rule's config in the same commit as its last violation fix (Pitfall 10).

### TCA conventions (all reducer edits)
`Feature`-suffix reducers; `Scope(...child: Reducer.init)`; `Delegate` enum sibling of `Action` — enforced by active custom rules (`child_reducer_shorthand_*` in `.swiftlint.yml:53–80`).

## No Analog Found

| Work Group | Reason | Fallback |
|------|--------|----------|
| `labeled_tuple_elements` rule regex | Brand-new rule, no in-repo precedent | RESEARCH Pattern 6 starting shape; iterate against the ~35-site inventory (Claude's discretion per CONTEXT) |
| PreviewSupport UUID table body | Extracted from a reference project (name-free, absolute privacy rule) | Fully specified in CONTEXT §Specifics — no source access needed |

## Metadata

**Analog search scope:** root `.swiftlint.yml`, `AppPackage/Sources/{ParserFeature,HomeFeature,SettingFeature,DownloadClient,AppFeature}`, `AppPackage/Tests/{FileClientTests,ImageClientTests,DownloadsFeatureTests,CookieClientTests}`, `AppPackage/Package.swift`
**Files scanned:** ~25 read/grepped
**Pattern extraction date:** 2026-07-20
