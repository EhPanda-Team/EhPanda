# Phase 17: Screenshot Automation, Visual Regression & OS 27 Modernization — Pattern Map

**Mapped:** 2026-10-02
**Scope:** Current tracked source; no builds, acquisition, runtime probes or source changes.
**Classification:** 22 implementation assignments below, plus the explicit layout census. Proposed names are planner choices, not existing APIs. Five primary pattern families cover launch configuration, offline replay, isolated stores, real reader overlays, and test orchestration. Capture algorithms without an existing analog are identified separately.

## File Classification

Paths below are repository-relative. `Sources/` and `Tests/` in this table mean `AppPackage/Sources/` and `AppPackage/Tests/`.

| New/modified file or bounded file group | Role | Data flow | Closest tracked analog | Quality |
|---|---|---|---|---|
| `Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift` | model/config | transform | same file | exact |
| `Sources/AppLaunchAutomationClient/AppLaunchAutomationClient.swift` | provider | request-response | same file | exact |
| `Sources/AppFeature/UITestSupport/UITestAutomation.swift` | service/config | event-driven | same file | exact |
| `Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift` | middleware | request-response/file-I/O | same file | exact |
| Proposed `Sources/AppFeature/UITestSupport/CaptureSceneConfiguration.swift` | model/config | transform | `AppLaunchAutomation.swift` | role-match |
| Proposed `Sources/AppFeature/UITestSupport/CaptureFixtureManifest.swift` | model | file-I/O | `Sources/AppModels/Download/DownloadedGallery+Manifest.swift` | role-match |
| Proposed `Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift` | service | event-driven | `UITestAutomation.swift` | exact role/flow |
| `App/EhPandaApp.swift`, `Sources/AppFeature/DataFlow/AppReducer.swift` | controller | event-driven | existing preparation/launch automation | exact |
| `Sources/ReadingFeature/Support/LiveTextHandler.swift`, `ReadingView.swift` | service/component | event-driven | existing handler/reader wiring | exact |
| Proposed `Tests/VisualPipelineContractTests/*.swift` | test | transform/file-I/O | `Tests/AppFeatureTests/TabBarSettingPresentationTests.swift` | role-match |
| Proposed `Tests/VisualSnapshotTests/*.swift`, baseline/resource directories | test | batch/render | isolated store pattern; no snapshot suite exists | partial |
| Proposed `EhPandaVisualTests/FullContentHost.swift` | component/utility | render/transform | current app content roots; no complete host analog | none |
| Proposed `EhPandaVisualTests/NativePresentationSnapshotTests.swift` | test | event-driven/render | `EhPandaUITests/Support/DeepLinkLauncher.swift` | role-match |
| Proposed `EhPandaUITests/MarketingCaptureUITests.swift` and capture support | test/controller | event-driven/file-I/O | `DeepLinkLauncher.swift` | exact role/flow |
| Proposed visual fixture/matrix JSON resources | config/model | batch/file-I/O | existing UI fixture directory and test plans | partial |
| Proposed `scripts/visual/acquire-fixtures.*` | utility | request-response/file-I/O | replay boundary only; no acquisition tool | none |
| Proposed `scripts/visual/run-regression.*`, `export-marketing.*`, `report.*` | utility | batch/file-I/O | `.github/workflows/test.yml` invocation/error policy | partial |
| `AppPackage/Package.swift` | config | transform | existing target/dependency helpers | exact |
| `EhPanda.xcodeproj/project.pbxproj`, shared scheme; proposed `VisualTests.xctestplan`, `MarketingCapture.xctestplan` | config | batch | existing UI target, scheme, `UITests.xctestplan` | exact role/flow |
| `.github/workflows/test.yml`, release workflows | config | batch | current test workflow | exact |
| `AltStore.json`, proposed local handoff contract/inventory | config/model | file-I/O | existing `apps[].screenshots` string array | role-match |
| Layout census files below and their corresponding tests | component/controller/test | render/event-driven | existing size-class sites and navigation tests | exact/role-match |

No new production fixture module is required by this map. If the planner creates one, add its root `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml`. Keep test assets and SnapshotTesting outside release product dependencies.

## Pattern Assignments

### 1. Launch configuration and preparation

**Sources:** `AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift:40-49,87-103`; `AppLaunchAutomationClient.swift:1-26`; `AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift:54-88`.

```swift
public static var current: Self? {
    #if DEBUG
    resolve(environment: ProcessInfo.processInfo.environment)
    #else
    nil
    #endif
}

@DependencyClient
public struct AppLaunchAutomationClient: Sendable {
    public var current: @Sendable () -> AppLaunchAutomation?
}
```

Copy DEBUG gating and Sendable, value-based configuration. Extend explicit scene/configuration inputs rather than adding another unconditional process-environment reader. Existing resolver silently ignores unknown tab/refusal values; mandatory capture configuration instead needs actionable validation failures. Credentials already have launch fields; they are not fixture schema fields.

The current preparation signature is:

```swift
static func prepare(
    environment: [String: String],
    now: Date = .now
) -> Configuration?
```

`UITestAutomation.swift:70-85` registers the replay protocol and performs dependency overrides inside one `prepareDependencies` operation. Preserve this ordering. `App/EhPandaApp.swift:8` calls preparation before app construction. `AppReducer.swift:181-195,454-462` supplies the existing launch-route seam; seed real feature destinations and presentation actions, rather than a parallel marketing UI. Capture readiness must cover initial effects as well as seeded state.

### 2. Offline request and asset replay

**Source:** `AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift:1-38,48-84`.

```swift
import Foundation
import Synchronization

final class UITestStubURLProtocol: URLProtocol {
    private static let fixtureDirectory = Mutex<URL?>(nil)

    override static func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
}
```

The actual read/error pattern, lines 32-37:

```swift
do {
    let data = try Data(contentsOf: fixtureDirectory.appending(path: fixtureName))
    finish(statusCode: 200, data: data, url: url)
} catch {
    finish(statusCode: 404, data: Data(), url: url)
}
```

Reuse synchronization and URLProtocol delivery, but replace prefix-based HTML mapping with explicit URL/asset entries, MIME types, checksum/path validation and unknown-request accounting. Current responses always declare HTML; this is unsuitable for cover/preview/reader images. A 404 alone is insufficient diagnostics for a capture gate. Verify all image loaders traverse the controlled boundary or inject their real client seams. Acquisition is a separate explicit online operation; capture is fail-closed offline.

### 3. Shared settings and deterministic store ownership

**Source:** `AppPackage/Tests/AppFeatureTests/TabBarSettingPresentationTests.swift:112-156`. This is the closest reusable isolated-store pattern, not a production state reset:

```swift
let appStorage = UserDefaults.inMemory
let inMemoryStorage = InMemoryStorage()

return withDependencies {
    $0.defaultAppStorage = appStorage
    $0.defaultInMemoryStorage = inMemoryStorage
} operation: {
    var initialState = AppReducer.State()
    // Construct the store inside this dependency scope.
}
```

The store's dependency closure also installs both storage instances, `.analyticsClient = .noop`, `.cookieClient = .noop`, controlled `continuousClock`, and injected launch/device/download clients. Copy the two-level scoping: shared properties initialize during state construction. Do not construct state first and attempt isolation afterward.

`AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift:53-62,95-104,109-117,141-145` defines persisted `setting`, `user`, three filters, history keywords, quick searches and gallery history. Capture configuration must isolate these, cookies, caches and download storage before launch. Marketing Filters uses `Filter()` defaults; Laboratory's isolated setting sets `bypassSNIFiltering` enabled. `LaboratorySettingView.swift:21-23` already renders the real `.bypassSniFiltering` card with `.purple`; preserve it. Test the configured state, not just its pixels.

### 4. Downloads must be coherent manifest fixtures

**Sources:** `AppPackage/Sources/AppModels/Download/DownloadedGallery+Manifest.swift:9-37,55-73`; `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestFactories.swift:61-115`.

```swift
public var completedPageCount: Int {
    pages.values.filter({ !$0.isEmpty }).count
}

public var isComplete: Bool {
    !pages.isEmpty && completedPageCount == pages.count
}
```

The test factory constructs `DownloadManifest` first, with `pages: [Int: String]`, then initializes `DownloadedGallery(manifest:folderURL:folderName:localCoverURL:localPageURLs:modificationDate:displayStatus:lastError:)`. Copy the model ownership, not the factory's placeholder hashes or `.now`. Real capture files need actual hashes, selected gallery identities, fixed dates and coherent operation statuses. Simulated progress/queue state may be injected through the client; completeness must remain manifest-derived. Missing-file/hash mismatch reconciliation and the same-run deletion invariant remain production rules. Use capture-owned folders; do not seed or clear the user's library.

### 5. Live Text uses the actual reader overlay

**Sources:** `AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift:20-25,45-60`; `Support/LiveTextView.swift:10-18,20-99`; `ReadingViewComponents.swift:264-273`.

```swift
@Observable
@MainActor
final class LiveTextHandler {
    var enablesLiveText = false
    var liveTextGroups = [Int: [LiveTextGroup]]()
    private(set) var focusedLiveTextGroup: LiveTextGroup?
}
```

```swift
image(url: imageURL).scaledToFit().overlay(
    LiveTextView(
        liveTextGroups: liveTextGroups,
        focusedLiveTextGroup: focusedLiveTextGroup,
        tapAction: liveTextTapAction
    )
    .visible(enablesLiveText)
)
```

Inject saved selected-page recognition groups at the handler/analysis seam and keep this renderer. `ReadingView.swift:31,125-126,353-356,426` owns the handler, animations, group plumbing and analysis deduplication. Deterministic groups prevent later Vision work overwriting them. `AppModels/Support/LiveText.swift:98-114,129-136` provides `LiveTextGroup.init?(blocks:)` and `LiveTextBlock.init(id:text:bounds:)`; assign stable block IDs and group `id` explicitly. Bounds are normalized page coordinates. No flattened highlight image or fake reader replacement.

## Shared Patterns and Target Ownership

### Native capture versus hosted rendering

`EhPandaUITests/Support/DeepLinkLauncher.swift:3-9,42-59,62-73` supplies `@MainActor` launch helpers, test-bundle resources, `launchEnvironment`, and identifier-based waits:

```swift
func launchStubbed(extraEnvironment: [String: String] = [:]) throws {
    try configureStubbedLaunch(extraEnvironment: extraEnvironment)
    launch()
}
```

The existing helper pins English. New capture helpers must configure each requested locale explicitly and avoid repeated accumulation of launch arguments. Wait for loaded images, route identity, selected gallery/page and stable layout; existence alone is insufficient. Keep XCTest in UI targets. Swift Testing owns manifest/matrix/export negative tests. Native framebuffer assertions cover toolbars, menus, dialogs, sheets and status chrome; hosted snapshots cover complete content and selected components. Native frames can be compared with SnapshotTesting, retaining the same strict reference/report accounting.

### Full-content host candidates and bounds

| Actual source | Host shape | Proof required |
|---|---|---|
| `HomeFeature/HomeView.swift:30-70`, `HomeView+Sections.swift` | ScrollView, custom viewport-dependent sections | fixed width; preserve visible-section policy; prove every expected item and final section |
| `DetailFeature/DetailView.swift:66-188` | ScrollView | complete trailing content after layout/image readiness |
| `DetailFeature/Comments/CommentsView.swift:37-38` | ScrollViewReader + List | all rows materialized; final comment visible |
| `DownloadsFeature/DownloadsView.swift:76-104` | List/empty branch | all finite fixture rows, including trailing row |
| `FiltersFeature/FiltersView.swift:30-50` | NavigationStack + Form | full sections while keeping native form behavior |
| `ReadingFeature/ReadingView.swift:166,232-254` | AdvancedList and horizontal LazyHStack | explicit reader mode/page scenario; do not turn paged reading into a marketing long image |

There is no proven complete-content host in tracked source. Follow RESEARCH's bounded height convergence/item census gate; a tall frame or `.sizeThatFits` alone is not evidence. Own the experimental host in a dedicated hosted visual target. Do not duplicate screens into eager substitute views. Failure pauses implementation for orchestrator direction.

### Registration and CI

`AppPackage/Package.swift:193-229` has typed `target(module:dependencies:resources:swiftSettings:plugins:)` and `testTarget(...)` helpers; lines 800-806 register AppFeatureTests, and 1011-1028 define iOS 27 and product filtering. Add SnapshotTesting only to test dependencies; register any new enum dependency/module cases consistently. Do not copy existing exceptional warning/lint suppressions.

Use a dedicated hosted Xcode visual target for controller/window rendering if the feasibility gate needs a test host; package contract tests remain independent of native presentation. Actual-app capture stays an XCTest UI target. The current project has an EhPandaUITests target (`project.pbxproj:213-234`) but no existing visual target to claim is runnable. Coordinate project edits with the orchestrator; staged probe/target changes already exist.

The shared `EhPanda.xcscheme:25-38` lists FeatureTests and UITests. `UITests.xctestplan:11-14` retries failures three times; copy its target-reference shape, not its retry policy. New visual plans disable retries. Record final target names, identifiers and executable filters after registration.

`.github/workflows/test.yml:1-8,64-73` currently triggers push/manual and runs FeatureTests on iPhone Air, iOS 27.0. Add explicit every-PR full regression execution and complete release gating, both families, all coordinates and artifact/report retention. Existing workflow is not complete visual coverage. Never inject acquisition credentials into CI. Compare with `record: .never`; candidate recording and owner-approved baseline promotion are separate operations.

### Native modernization and stable presentations

Reuse the current effective roots, not legacy workarounds. `FiltersView.swift:42` applies `.scrollEdgeEffectStyle(.soft, for: .top)` to Form. `ReadingView.swift:85,115,254` applies policy to independent reader roots. `DetailView.swift:214-284` contains distinct presentation roots. `DownloadsView.swift:259-260` scopes its row confirmation to the action source. Inventory each separate sheet/cover and preserve anchors, `.inlineLarge` roots and native search behavior. The scroll-edge inventory remains authoritative; new hosts/presentations need their own attachment.

## Post-Snapshot Idiom Layout Census

Run this work only after full snapshot coverage. The direct source read is `DeviceClient/DeviceClient.swift:49`, `UIDevice.current.userInterfaceIdiom`; callers are the audit surface.

| Tracked source under `AppPackage/Sources/` | Current decision | Owner/action |
|---|---|---|
| `HomeFeature/HomeView+Sections.swift:400` | `.pad` plus regular width, Toplists second column | Home layout; remove idiom dependency in favor of traits/fitting |
| `HomeFeature/GalleryCardCell.swift:61` | tablet bypass of long-title behavior | GalleryCard layout; test text and geometry across classes |
| `SearchFeature/SearchRootView+Keywords.swift:44` | keyword arrangement | Search layout |
| `AppComponents/TagSuggestionView.swift:30,92` | phone arrangement in two subviews | suggestion layout |
| `AppComponents/NewDawnView.swift:43` | 0.5/0.6 width multiplier | greeting layout |
| `ReadingFeature/ReadingView.swift:100` | phone landscape settings close control | reader presentation/layout |
| `DetailFeature/GalleryNavigation.swift:11-18` | injected `deviceType` chooses present versus push | navigation contract; update Home/Favorites/Search/Downloads callers and `GalleryNavigationTests` coherently |
| `AppFeature/View/TabBar/TabBarReducer.swift:39-49` | tablet Settings sheet versus inline | tab presentation contract; update `TabBarSettingPresentationTests` and provide layout traits from UI rather than guessing them in a reducer |

Existing good analogs: `HomeView.swift:15,23` reads horizontal size class and passes `GalleryViewport(...isRegularWidth:)`; `HomeView+Sections.swift:496` sizes from container width and class; `ReadingToolbar.swift:9,27` uses class for placement; `ControlPanel.swift:170,211,240-244` uses class for layout. Size class is not a window-management-mode detector.

Retain or separately justify non-layout uses: `AppComponents/ErrorInfoView.swift:57` diagnostics, `AnalyticsClient.swift:49-50` orientation telemetry, `AppReducer.swift:248-249` timing, and reader orientation/capability reads. Search both `deviceType` and derived flags; do not globally remove DeviceClient.

## No Analog Found / Explicit New Contracts

- Full-content materialization/convergence, baseline promotion, matrix accounting, HTML diff browsing and byte-identical cold-rerun proof have no complete tracked implementation. RESEARCH specifies the gates; do not treat the historical probe as a reusable production implementation.
- Acquisition needs versioned provenance, checksummed assets and provisional/final selection declarations. Public synthetic regression fixtures and local real marketing fixtures have different distribution ownership.
- Marketing export requests exactly 384 coordinates with all outcomes. Regression requests 576 coordinates per expanded scenario. Both require validated environment and state; no reduced-window axis.
- `AltStore.json:22-32` currently has legacy screenshot URLs, including retired SlideMenu. This is only the string-array consumer shape. The separate designer owns promotional composition, screen list/count/matrix/copy/dimensions. Capture owns source screenshots and metadata; contract tests validate the designer's intended references locally. Do not copy obsolete filenames or publish from this phase.
- Final owner gallery identifiers, set assignments/order/pages and affected regenerated captures are a pre-closure checkpoint. Provisional selection is authorized now; no selection question blocks planning.

## Metadata

**Analog search scope:** tracked App shell, AppPackage sources/tests, XCTest UI support, shared scheme/test plans, project registration, workflows and AltStore configuration.
**Tracked-source gate:** candidates resolved from `git ls-files`; primary analog paths rechecked explicitly. No ignored runtime mirrors or other local projects used.
**Skills applied:** `pfw-composable-architecture`, `pfw-snapshot-testing`; root lint and project instructions reviewed. New reducers use `Feature`, projected/scoped bindings, sorted imports, controlled dependencies, explicit error handling and real actor/Mutex isolation; no new suppressions.
**Validation performed:** read-only source inspection. No runtime/full-content/library-integration/repeatability claims established by this map.
