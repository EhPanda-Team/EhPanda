# Phase 17: Screenshot Automation, Visual Regression & OS 27 Modernization - Context

**Gathered:** 2026-09-23 through 2026-10-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Build reusable offline fixtures, a complete visual-regression matrix and automated snapshot assertions, plus a separate actual-app marketing screenshot workflow. Produce the website's local screenshot export and assign AltStore promotional-image design to a separate designer agent. After snapshot coverage is implemented, audit device-type-dependent layout and replace those layout decisions with size-class-based decisions.

Preserve the iOS/iPadOS 27 modernization already implemented in quick task `260921-f5u` and the owner-approved Phase 16 accessibility behavior and limitations. Research remaining capture and native-presentation requirements against the current source and SDK. This discussion authorizes context capture; implementation and public publishing are later workflow steps.

The decisions below supersede conflicting older Phase 17 roadmap wording. No separate Phase 17 SPEC.md exists. The confirmed website capture contract supplied by the owner is fully recorded here; no lookup in another local project is required.

</domain>

<decisions>
## Implementation Decisions

### Separate test and marketing workflows

- **D-01:** Adopt `swift-snapshot-testing` for test snapshots. Marketing must use a separate workflow that builds and drives the actual app in iOS Simulators and captures normal device-size screenshots. Keep their output images and regression references separately identifiable. Sharing underlying fixture data is optional. Marketing's status-bar and device-chrome requirements must not complicate or destabilize snapshot tests.
- **D-02:** Snapshot-test data may be real, synthetic or mixed, chosen by the agent for test needs. Marketing gallery content must be real. The agent may choose provisional marketing galleries under the owner's 2026-10-02 delegation; final content uses the owner's identifiers before phase closure. Do not carry forward the old requirement that every test use the marketing galleries.
- **D-03:** Retain explicit acquisition/refresh of real-gallery metadata, covers, previews and required reader assets into reusable versioned fixtures, with provenance and checksums. Capture and regression runs consume saved fixtures offline, make no live-gallery requests and do not depend on a real account or personal library. Credentials and private session state must not enter fixtures.

### Owner-selected marketing content

- **D-04:** During planning, determine required gallery quantities and content characteristics. The owner deferred choosing galleries on 2026-10-02 and explicitly authorized the agent to choose provisional galleries at its discretion; do not wait for those choices or ask again now. The owner will provide chosen gallery identifiers before closing Phase 17. Record the remaining final set assignments, ordering, reader pages and scene inputs as a pre-closure checkpoint; regenerate and revalidate affected captures with the final selections. Content needs must not become imposed category-based gallery selection or filtering requirements.
- **D-05:** The agent chooses real provisional marketing galleries under the owner's delegation and records that provenance explicitly. Before phase closure, replace them with the owner's final identifiers and `nonexplicit`/`explicit` assignments; never infer set labels from app categories. Every visible gallery in Home, Detail, Comments, Reading, Live Text and Downloads must come from the active declared selection. Use one fixed gallery flow within each selected content set; reuse across different screens is allowed, but the same gallery must never appear twice on one screen, including across its sections. Honor configured ordering and reader pages. Provisional captures are not final accepted marketing delivery.
- **D-06:** The website contract explicitly permits deterministic simulation of Live Text highlights and download items **through the app's real UI**. Simulated download items reference selected real galleries; Live Text highlights belong to the selected real reader page. They must look like normal use, with no mock/debug labels. This permits controlled presentation and operation state, not invented marketing gallery content.

### Snapshot matrix and capture extent

- **D-07:** Inventory current app screens and meaningful states, including separately presented sheets, native menus/dialogs, empty/loading/error states, reader panels and previews. Preserve the full regression scope: every supported app locale (`en`, `de`, `ja`, `ko`, `zh-Hans`, `zh-Hant`), all supported Dynamic Type sizes, portrait and landscape, iPhone and iPad, and light/dark appearance. Maintain an explicit machine-readable matrix; report each requested coordinate as captured, failed or justified not applicable. Do not replace full coverage with representative samples. The website's eight-state portrait matrix does not narrow regression coverage.
- **D-08:** Test snapshots should adjust container height to capture complete content in one image. Research must establish a working method for the app's actual ScrollView/List/lazy content; the reduced-width probe does not establish full-content capture. Marketing remains one normal device-size image per screen/state at a selected fixed capture position. No marketing long-image or stitching decision was made.
- **D-09:** Do **not** add a separate reduced-window/narrow-container iPad snapshot dimension. Retain full-size phone/tablet portrait and landscape scope. The historical reduced-width feasibility probe established configured view-layout rendering, not actual iPadOS window-resize automation; its older library presets are not approved production dimensions.
- **D-10:** Freeze the rendering environment, time/time zone, stable IDs and data ordering, image readiness, animation state and simulator configuration. Research/planning determines coherent snapshot dimensions, safe areas, traits and scale without inferring current hardware geometry from a library preset name. Native toolbar/menu/sheet verification remains required and must not be replaced solely by isolated view snapshots.

### Baselines, review and PR coverage

- **D-11:** Commit snapshot baselines alongside test source in this repository, using test data suitable for public distribution. This supersedes carrying Phase 16's outside-repository image rule into Phase 17 test baselines; it does not authorize indiscriminately committing real-gallery marketing assets. The owner deleted old Phase 16 screenshots: do not assume those image files remain available. Their absence does not rescind recorded owner dispositions.
- **D-12:** The agent first visually reviews the **complete** snapshot result set and surfaces layout issues and differences. The owner gives final approval to accept new or changed baselines. Routine comparisons never overwrite references; baseline recording/updating is an explicit operation. Existing defects must not silently become approved baselines.
- **D-13:** Run the **complete snapshot matrix for every PR**, accepting longer runtime. Also retain the complete matrix as a release gate. Do not substitute sampled PR coverage. Optional individual-case filters may help local investigation but must declare reduced coverage.
- **D-14:** Provide a browsable comparison report grouped by screen, with baseline/actual/diff side by side and filters for locale, text size and device. Keep actionable failures and actual/reference/diff artifacts. Pin rendering characteristics, document any justified comparison tolerance, and prove regression detection with a controlled layout change that fails and passes again after removal. Snapshot equality alone does not establish initial layout correctness.

### Locked website screen states

- **D-15:** Export these eight identities. Verify names and navigation against current code; do not identify screens through legacy filenames or capture the retired slide-menu screen.

| Export ID | App view | Required state |
| --- | --- | --- |
| `home` | `HomeView` | Populated Home dashboard |
| `detail` | `DetailView` | Populated gallery detail |
| `comments` | `CommentsView` | Readable, populated gallery comments |
| `filters` | `FiltersView` | App-default filter state; no adjusted conditions |
| `reading` | `ReadingView` | Fully loaded chosen gallery page in the normal reader |
| `reading-live-text` | `ReadingView` | Live Text active, with recognized regions highlighted |
| `downloads` | `DownloadsView` | Realistic, populated items referencing selected galleries |
| `laboratory` | `LaboratorySettingView` | Network-bypass setting visible and **enabled**, using its normal purple-card appearance |

Every state must be populated except Laboratory, which may legitimately be sparse. Reset Filters to app defaults rather than inheriting personal persisted settings. Capture-only Laboratory state belongs in isolated capture configuration.

### Website capture matrix and quality

- **D-16:** Capture every combination of the eight states, six locales (`en`, `de`, `ko`, `ja`, `zh-Hant`, `zh-Hans`), light/dark appearance, `iphone`/`ipad` families and `nonexplicit`/`explicit` sets: **384 expected coordinates, 192 per family**. Use portrait orientation and one fixed documented simulator model per family: **iPhone Air** and **iPad Pro 11-inch (M5)**, as already selected. Pin OS/runtime and record actual pixel dimensions. The iPhone batch may be delivered first, with incomplete coverage explicitly reported. The website has no separate Dynamic Type axis; pin and document the configured text size rather than adding an unrequested marketing dimension.
- **D-17:** Inspect existing app/tooling and reuse suitable mechanisms. Build and drive this repository's actual app locally, with capture-only setup isolated from release behavior and test assets excluded from the release payload. Before each capture verify screen identity, locale, appearance, device and the actual configured selections/state. Wait for images and layout to settle; reject unintended loading, error, empty or transient states. Legitimate Laboratory sparsity is not a failure.
- **D-18:** Pin status-bar values, timestamps, ordering, scroll position, animation state and simulated progress. Marketing status-bar time is **9:41** and the owner requested removal of the Dynamic Island capsule area. Research must establish the working capture/chrome method; do not assume this is implemented. Verify **byte-identical reruns** for unchanged app, runtime and inputs, and report any unresolved nondeterminism. Read credentials only from the local environment; keep them out of tracked files, logs, screenshots and CI secrets.
- **D-19:** Chrome-only screens may look identical between content sets. Explicitly record any proposed asset sharing; never silently substitute another locale, appearance, device or content set. Every expected coordinate remains represented in the inventory.

### Website export contract and local handoff

- **D-20:** No image format is required. Export the format natively supported by capture tooling without unnecessary conversion; the website consumer handles conversion later. Suggested layout: `images/<set>/<screen>/<device>-<locale-token>-<theme>.<extension>`. Use lowercase filename tokens `zh-hant`/`zh-hans`; retain canonical `zh-Hant`/`zh-Hans` locale identifiers in metadata.
- **D-21:** Deliver image files, a machine-readable inventory covering **every expected coordinate including missing or failed captures**, capture instructions and a results report. Each inventory entry records:
  - Screen ID and app view/state; locale, appearance, device family and content set.
  - Relative path, actual format, actual dimensions, byte count and SHA-256.
  - Simulator model, OS/runtime, rendering environment, text size and orientation.
  - App commit/build, capture configuration identifier and fixture version.
  - Selected gallery/page references, without credentials.
  - Outcome, state-verification results and any asset-sharing declaration.
- **D-22:** Provide one documented command for the full export, with optional filters for individual combinations. Return export location, commands, coverage counts, reproducibility results and remaining gaps. Keep export local: the website consumer stages files, generates a labelled thumbnail sheet, obtains maintainer review, converts as needed and promotes approved images. Icon assets are already supplied; no icon work. Validate the local consumer contract/importability without treating public publishing as part of capture.

### AltStore designer ownership

- **D-23:** AltStore requires **App Store-style promotional images with deliberate visual design**, using app screenshots as source material. Standalone raw screenshots do not satisfy that requirement. Record a separate task/responsibility for a **designer agent** to create those promotional assets. The current capture/discussion agent must not participate in AltStore image design or use `impeccable` for this task; the owner explicitly instructed this.
- **D-24:** No AltStore screen list, count, order, locale/appearance/content-set matrix, composition, copy, dimensions or device-frame treatment was selected. Leave those decisions to the separately assigned designer rather than inheriting the website's eight-state list or 384-coordinate matrix. The capture pipeline remains responsible for screenshot source material and metadata; coordinate any additional inputs with the designer during planning. Record consumer-compatible delivery and validate intended `AltStore.json` references without choosing the design or publishing assets. The owner asked to record designer ownership, not to dispatch a designer or create another chat during discussion.

### Existing modernization and subsequent layout audit

- **D-25:** The iOS/iPadOS 27 minimum, Swift 6.4 toolchain, native overflow/priority controls, title/search behavior and soft top-edge migration already landed in quick task `260921-f5u`. Plan against current implementation and coverage rather than repeating a platform upgrade or restoring withdrawn workarounds. The older quick-task W-38 pending wording is historical; current Phase 16 verification records owner-approved closure and remaining bounded evidence. Preserve native `.inlineLarge` root titles, sheet-specific title behavior and search focus/query/orientation behavior at standard, AX1, AX3 and AX5 sizes, including cold entry and live size changes on iPhone/iPad.
- **D-26:** Keep the app-owned top-edge policy `.scrollEdgeEffectStyle(.soft, for: .top)` at each effective scroll/page hierarchy and each independent presentation root. Owned UIKit hosts use their equivalent native property. Preserve system-owned scroll internals. The page inventory is authoritative for existing attachment points; new capture-relevant pages/presentations follow the same policy. Retain native overflow action behavior, Picker/Toggle marks and correct stable action-source alert/popover anchors.
- **D-27:** **After snapshot implementation**, audit layout decisions that depend on device type and replace those branches with size-class-based decisions. Include client-mediated device idiom reads and derived helper flags, not only direct UIDevice reads. Use the completed snapshot coverage to assess changes. This is an owner-added current-phase task, not a deferred idea. Legitimate non-layout capability checks remain outside this audit's removal scope. Size class does not identify an iPadOS window-management mode; retain appropriate container-responsive fitting where needed.

### Agent discretion and research obligations

The owner delegates test-data choices (D-02). Researcher/planner determines the technical mechanisms for fixtures, snapshot integration, deterministic actual-app capture, matrix execution and comparison reporting while respecting locked coverage, output and ownership decisions. Do not present unsupported technical options to the owner: first establish feasibility through primary documentation/current SDK inspection and relevant runtime evidence.

Research must resolve full-content capture for real scroll/list/lazy screens, native menu/dialog/sheet coverage, coherent current device dimensions/traits, status-bar/capsule presentation and repeatability. The prior probe is bounded evidence only; it also reported upstream SDK deprecation warnings, so it is not proof of a clean integration. Follow repository lint rules without suppressions or bypasses.

The agent may supply provisional gallery URLs, set assignments, reader pages/order and Home/Comments/Downloads scene inputs. Final owner identifiers and any missing final assignments are required before closure, with regeneration and revalidation under D-04/D-05. AltStore design decisions belong to its designer. No pending todo matched this phase.

The owner also requested research into Xcode 27's agent-oriented features and preview access on 2026-10-02. The research records current MCP/RenderPreview capabilities, successful project rendering and destination/determinism limits; use verified preview tooling as a development/review aid while preserving D-01's two capture workflows.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.** Repository paths are relative. No external requirements document is needed: the owner's confirmed website contract is captured in D-04 through D-06 and D-15 through D-22.

### Scope and repository rules

- `.planning/ROADMAP.md` — Phase 17 scope; same-pipeline and mandatory-real-test-data wording is superseded by D-01/D-02, and completed modernization is accounted for by D-25.
- `.planning/PROJECT.md` — milestone parity, current target versions and source-reference privacy.
- `.planning/REQUIREMENTS.md` — current requirements and superseding accessibility dispositions.
- `AGENTS.md` — reducer naming, localization/lint rules, download SSOT/deletion invariant, source-reference privacy, native navigation/search and top-edge policy.
- `.swiftlint.yml` — authoritative rules; read before writing Swift.

### Prior accessibility and modernization evidence

- `.planning/phases/16-dynamic-type-accessibility/16-CONTEXT.md` — historical decisions; current verification/sweep supersede historical pending or withdrawn requirements.
- `.planning/phases/16-dynamic-type-accessibility/16-VERIFICATION.md` — current approved completion, accepted/deferred/unmeasured limits and W-38 evidence boundary.
- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — current owner dispositions and closing gates; old screenshot files were deleted.
- `.planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/260921-f5u-SUMMARY.md` — already-landed modernization, with historical verification caveats.
- `.planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/260921-f5u-VERIFICATION.md` — native UI/runtime evidence and limits.
- `.planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/COVERAGE.md` — custom/native API migration coverage.
- `.planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md` — effective host and presentation-root attachments.
- `.planning/quick/260930-o3m-align-live-text-localized-names-with-app/260930-o3m-SUMMARY.md` — current localized Live Text names; preserve these in localized capture.
- `.planning/phases/17-localized-screenshot-capture-harness/17-WINDOW-SNAPSHOT-PROBE.md` — reduced-container feasibility, geometry/trait limits and owner-excluded matrix dimension.

### Existing automation and consumer seams

- `AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift` — DEBUG launch navigation/configuration; account environment inputs are not offline fixtures.
- `AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift` — DEBUG fixture/URLProtocol and dependency preparation.
- `AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift` — current fixed-route fixture implementation; not an arbitrary-gallery acquisition system.
- `AltStore.json` — existing consumer references, including retired screen identities that must not dictate new artwork selection.

### Snapshot implementation sources carried from the feasibility discussion

- `https://github.com/pointfreeco/swift-snapshot-testing/blob/main/Sources/SnapshotTesting/Snapshotting/UIViewController.swift` — upstream controller capture implementation; verify the actually pinned version during research.
- `https://github.com/pointfreeco/swift-snapshot-testing/blob/main/Sources/SnapshotTesting/Snapshotting/SwiftUIView.swift` — upstream SwiftUI hosting/layout capture; prior probe pins its tested commit separately.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `AppLaunchAutomationClient` exposes DEBUG-only initial-tab, gallery navigation and optional download/account configuration. It provides navigation seams but does not implement the website matrix or deterministic arbitrary scene capture.
- `UITestAutomation` prepares DEBUG-only fixture networking and dependency overrides. `UITestStubURLProtocol` currently maps a small fixed set of routes to HTML fixtures; reuse appropriate isolation patterns without pretending these routes already support all owner-selected galleries/assets.
- `PreviewSupport`, `TestingSupport` and existing model/test factories provide deterministic test support and saved resources. Verify identities and suitability for public baselines; older maps describe historical code and are not current evidence by themselves.
- `EhPandaUITests` provides real-app launch/navigation, reader, accessibility and native-presentation coverage. Existing package tests use Swift Testing/TCA TestStore. Build and test through Xcode, with one xcodebuild test invocation at a time.

### Established Patterns

- Thin app shell in `App/`, all logic and dependencies in local `AppPackage/`; centralized TCA navigation and injected clients are existing integration patterns.
- Shared persisted settings must be reset/scoped for capture instead of inheriting an owner's personal state. Capture setup stays isolated from release behavior/payload.
- `ReadingView` uses `LiveTextHandler` and real Live Text overlay components; investigate a deterministic capture seam that renders those components rather than drawing fake labels over an exported image.
- `DownloadsView` uses existing row/state presentation. Simulated state must preserve the download manifest's SSOT and user-owned-folder deletion invariant; screenshot tooling is not permission to weaken production behavior.

### Integration Points

- Website view sources: `AppPackage/Sources/HomeFeature/HomeView.swift`, `AppPackage/Sources/DetailFeature/DetailView.swift`, `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift`, `AppPackage/Sources/FiltersFeature/FiltersView.swift`, `AppPackage/Sources/ReadingFeature/ReadingView.swift`, `AppPackage/Sources/DownloadsFeature/DownloadsView.swift`, and `AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift`.
- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` and `AppPackage/Sources/AppFeature/RootView.swift` coordinate actual navigation/presentation.
- `AppPackage/Package.swift` is the dependency declaration boundary; `EhPanda.xcodeproj` supplies the app/UI-test build and simulator execution boundary. Current source declares Swift 6.4 and iOS 27.
- Fixture acquisition, capture commands, inventory/results and baseline reporting need explicit tooling/target ownership in the plans; the designer task separately owns AltStore composition.

</code_context>

<specifics>
## Specific Ideas

- Owner: "測試時想用什麼都可以／展示用的截圖必須都用真實資料" — flexible test data, real selected marketing content.
- Owner: "同一個畫面中不要出現重複的畫廊" — no duplicate gallery within a marketing screen.
- Full-content height adjustment applies to test snapshots only; website captures keep normal portrait device dimensions.
- A filterable, screen-grouped baseline/actual/diff report is a required review tool.
- Owner: "AltStore 採用偏 App Store 風格的圖片" and "請記錄這些由另外的 designer agent 去做" — designer ownership is recorded without choosing a visual direction here.
- Website filenames use lowercase Chinese locale tokens; metadata preserves canonical locale casing.

</specifics>

<deferred>
## Deferred Ideas

None. AltStore designer work and the post-snapshot layout audit are current-phase responsibilities. Final owner content inputs remain required before phase closure; provisional selections allow development to continue. Consumer-side website staging/conversion/promotion and public publishing remain outside this local capture handoff.

</deferred>

---

*Phase: 17-localized-screenshot-capture-harness*
*Context completed: 2026-10-02*
