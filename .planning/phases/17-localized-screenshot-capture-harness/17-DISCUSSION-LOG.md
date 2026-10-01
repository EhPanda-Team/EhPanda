# Phase 17: Screenshot Automation, Visual Regression & OS 27 Modernization - Discussion Log

> **Audit trail only.** Do not use this log as input to planning, research or execution. Current decisions are captured in `17-CONTEXT.md`; this log retains alternatives, corrections and superseded intermediate answers.

**Dates:** 2026-09-23 through 2026-10-02
**Phase:** 17-localized-screenshot-capture-harness
**Areas discussed:** Gallery fixtures and scenarios, Devices and capture positions, Baseline storage and review, Website and AltStore assets

Choice markers appear only where the recorded answer identifies an option number; free-text corrections are preserved below each table. The owner supplied the website contract before discussion resumed. No other local project was inspected for this synthesis.

## Gallery fixtures and scenarios

### Which areas should we discuss?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Gallery fixtures and scenarios |  |
| 2 | Devices and capture positions |  |
| 3 | Baseline storage and review |  |
| 4 | Website and AltStore assets |  |

**Recorded response and notes:** All four areas. The owner requested Taiwanese Mandarin for subsequent user-facing discussion.

---

### Should normal snapshot-test scenes and marketing captures share the owner's selected gallery set?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Use one principal gallery fixture set for normal tests and marketing, supplemented by special test cases |  |
| 2 | Use separate marketing and test gallery fixture sets within the same capture workflow |  |

**Recorded response and notes:** The owner corrected the premise: swift-snapshot-testing snapshots and marketing screenshots must use separate capture workflows. View snapshots have different rendering characteristics and do not constitute full-screen screenshots with OS status bars. Marketing needs fixed 9:41 time and removal of the Dynamic Island capsule area. These presentation requirements must not complicate or destabilize snapshot tests. Adopt swift-snapshot-testing for test snapshots and a separate actual-app screenshot workflow for marketing, with separate output images and regression references. This supersedes the ROADMAP requirement that marketing select images from the same capture pipeline. Sharing underlying fixture data remains optional, not a constraint. This does not decide or remove existing requirements for native toolbar/menu/sheet coverage; their verification approach remains for research and planning.

---

### How should marketing gallery content be arranged across Home, Detail, Reading and other screens?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Use a fixed gallery set across screens (recommended) |  |
| 2 | Choose galleries independently for each screen |  |

**Recorded response and notes:** Use one fixed gallery set across the marketing flow. The same gallery must not appear more than once on the same screen, including different sections of that screen. Reusing a gallery across different screens is allowed and supports a coherent browsing/reading flow. Owner: '1，但是同一個畫面中不要出現重複的畫廊'.

---

### When should the owner select the real galleries?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Select during planning after the required quantities and content conditions are known (recommended) | ✓ |
| 2 | Provide the gallery URLs now |  |

**Recorded response and notes:** During planning, first identify the required quantities and content conditions, then have the owner provide gallery URLs. Gallery selection does not block this discussion or context capture. The owner selected option 1.

---

### How should snapshot-test edge cases such as long titles, many tags and large page counts be supplied?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Use real data primarily and supplement missing edge cases with explicitly identified test-only data (recommended) |  |
| 2 | Use real data for every case without fabricating content |  |

**Recorded response and notes:** The owner delegates all test-data choices to the agent: real, synthetic or mixed data are permitted according to test needs. Marketing screenshots must use real data throughout. Owner: '測試時想用什麼都可以 / 展示用的截圖必須都用真實資料'. This supersedes any earlier requirement to use real-gallery fixtures for every snapshot test; it does not relax the requirement for real marketing data or reproducible offline runs.

---

### Continue to devices and capture positions or discuss fixture rules further?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Continue to devices and capture positions (recommended) | ✓ |
| 2 | Discuss fixture rules further |  |

**Recorded response and notes:** Continue to devices and capture positions. The owner selected option 1.

---

## Devices and capture positions

### Which devices should marketing screenshots use?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Use the existing iPhone Air and iPad Pro 11-inch (M5) (recommended) | ✓ |
| 2 | Use a smaller and larger device size for each family |  |

**Recorded response and notes:** Use the existing iPhone Air and iPad Pro 11-inch (M5), one fixed device size for each family. The owner selected option 1. This does not yet decide snapshot-test sizes or iPad window variants.

---

### Should snapshot tests include reduced iPad window layouts?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Full-screen plus narrower window layouts (recommended) |  |
| 2 | Full-screen portrait and landscape only |  |

**Recorded response and notes:** No inclusion decision yet. The owner requested feasibility research before presenting implementable choices: 先去 research 是否能擷取到縮小視圖，不要給我實際不可用的選項. An isolated runtime probe on iPadOS 27 passed three configured container sizes; see 17-WINDOW-SNAPSHOT-PROBE.md. Research establishes view-layout capture, not actual OS window-resize automation. Future technical options must be grounded in research before asking the owner to choose.

---

### After the feasibility research, should extra reduced-width iPad snapshot configurations be included?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Full-size plus fixed narrower view-layout snapshots (recommended) |  |
| 2 | Full-size portrait and landscape layouts only |  |

**Recorded response and notes:** No. Owner: 那我覺得不需要測試多一個縮小視圖了. Do not add a separate reduced-window/narrow-container iPad snapshot dimension. Retain the existing full-size phone/tablet portrait and landscape scope. This supersedes the preceding pending-inclusion note.

---

### For long pages, should marketing capture produce one image at a fixed position or multiple images at different positions?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | One image per screen at a chosen fixed position (recommended) |  |
| 2 | Additional images for important content farther down the same screen |  |

**Recorded response and notes:** The owner selected one image per screen with a modification: 1, 但是改變尺寸來擷取到完整畫面. Record the request to adjust dimensions to capture the complete screen/content. The exact meaning and capture approach are pending clarification; do not assume approval of stitching, view snapshots for marketing, or a specific full-content capture mechanism.

---

### Owner-added task after snapshot implementation.

**Recorded response and notes:** Add a task AFTER the snapshot testing implementation: audit existing layout decisions for dependencies on device type and replace those layout branches with size-class-based decisions. Owner wording: 目前的 layout 實作有沒有依賴於 device type 的 case 存在？應該避免這樣做，改用 size class. Include device-idiom checks reached through clients and derived helper flags, not just direct UIDevice reads. This task concerns layout decisions; it is not a request to remove legitimate non-layout device capability checks. Use the completed snapshot coverage to assess the changes. This is a current-phase owner-requested addition to the modernization work, not a deferred idea or authorization to implement it before snapshots.

---

### Does adjusting dimensions to capture complete content apply to test snapshots or also to marketing screenshots?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Test snapshots: adjust container height to capture the complete content in one image | ✓ |
| 2 | Also marketing screenshots: include all scrollable content in a long image |  |

**Recorded response and notes:** Only test snapshots. The owner selected option 1. Test snapshots should adjust container height to encompass the complete content. Marketing images remain normal device-size screenshots, one image per screen at a selected fixed capture position. This resolves the earlier ambiguous full-content image request. Research/planning must establish a working full-content capture approach for actual scroll/list/lazy containers; the narrow-width probe alone does not establish that capability.

---

### Continue to baseline storage and review, or discuss devices and capture coverage further?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Continue to baseline storage and review (recommended) | ✓ |
| 2 | Discuss devices and capture coverage further |  |

**Recorded response and notes:** Continue to baseline storage and review. The owner selected option 1.

---

## Baseline storage and review

### Who should visually review new or updated snapshot baselines?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Agent reviews all results first, owner gives final approval (recommended) | ✓ |
| 2 | Owner directly reviews all results from grouped previews and diffs |  |

**Recorded response and notes:** The agent first checks the complete result set and surfaces layout issues and differences; the owner gives final approval to accept baselines. The owner selected option 1. Ordinary comparison runs never overwrite references; baseline updates are explicit operations.

---

### How should Phase 17 snapshot reference images be stored?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Commit publicly suitable baseline images alongside the tests (recommended) | ✓ |
| 2 | Keep baselines in separate versioned storage and fetch them before running tests |  |

**Recorded response and notes:** Commit snapshot baselines alongside test source in this repository, using test data appropriate for public distribution. The owner selected option 1 and reported deleting the old Phase 16 screenshots: phase 16 的截圖已經被我清除了. Old Phase 16 image files must not be assumed available; their deletion does not rescind the recorded phase dispositions. The Phase 17 baseline decision supersedes the earlier carry-forward assumption that its reference images must remain outside the repository. It does not authorize committing real-gallery marketing assets indiscriminately.

---

### How much of the snapshot matrix should each PR run?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Reduced matrix for PRs, complete matrix before release (recommended) |  |
| 2 | Complete matrix for every PR | ✓ |

**Recorded response and notes:** Run the COMPLETE snapshot matrix for EVERY PR, accepting the longer runtime. The owner selected option 2 over the recommended reduced development subset. Keep the complete matrix available as a release gate as previously scoped; do not substitute sampled PR coverage.

---

### How should image differences be presented for review?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Browsable, filterable side-by-side comparison report (recommended) | ✓ |
| 2 | Image files grouped by case with a failure list, without an additional browsing interface |  |

**Recorded response and notes:** Provide a browsable comparison report, grouped by screen, with baseline/actual/diff images side by side and filters for locale, text size and device. The owner selected option 1.

---

### Continue to website and AltStore delivery or discuss baseline management further?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Continue to website and AltStore assets (recommended) | ✓ |
| 2 | Discuss baseline and regression workflow further |  |

**Recorded response and notes:** Continue to website and AltStore delivery. The owner selected option 1.

---

## Website and AltStore assets

### Should the website and AltStore share the current eight-screen website sequence or retain their existing separate selections?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Use the current eight-screen website sequence for both consumers (recommended) |  |
| 2 | Keep separate existing selections: eight website screens and ten AltStore screens |  |

**Recorded response and notes:** The owner rejected choosing by the existing page lists and requested a fresh feature-oriented selection: 以功能導向重新思考應該擷取哪些頁面. Select marketing scenes according to the user capability each demonstrates, rather than inheriting the current eight or ten slots. The revised scene list, ordering and whether both consumers share it remain pending owner discussion.

---

### Resume the interrupted Phase 17 discussion?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Resume the previous discussion, retaining confirmed decisions |  |
| 2 | Start the discussion again |  |

**Recorded response and notes:** The owner explicitly authorized continuing the discussion on 2026-10-01 and supplied a confirmed website capture contract before continuing. Preserve the three completed areas and discuss remaining marketing-delivery choices. The supplied implementation instructions are requirements for subsequent research/planning/execution within this discussion workflow, not an instruction to start implementation now.

---

### Which website marketing screen states are now locked?

**Recorded response and notes:** The owner supplied the confirmed website consumer requirements. Export exactly these eight identities and states: home = populated HomeView dashboard; detail = populated DetailView gallery detail; comments = readable, populated CommentsView gallery comments; filters = FiltersView in the maintainer's chosen state; reading = fully loaded gallery page in the normal ReadingView reader; reading-live-text = ReadingView with Live Text active and recognized regions highlighted; downloads = realistic, populated DownloadsView items; laboratory = LaboratorySettingView with the network-bypass setting visible. Every screen is populated except Laboratory, which may legitimately be sparse. Do not capture the retired slide-menu screen or infer identities from legacy filenames. This resolves the previously pending website scene selection; the AltStore selection and precise unspecified screen configuration remain open.

---

### What is the required website export matrix and device convention?

**Recorded response and notes:** Capture every combination of the eight states, locales en/de/ko/ja/zh-Hant/zh-Hans, light/dark appearance, iphone/ipad device families and nonexplicit/explicit content sets: 384 expected coordinates, 192 per device family. Use one fixed documented simulator model per family in portrait, pin OS/runtime and record actual pixel dimensions. Preserve the previously selected iPhone Air and iPad Pro 11-inch (M5) unless superseded by the owner. The iPhone batch may be delivered first, with incomplete coverage explicitly reported. This portrait marketing matrix does not narrow the separate snapshot-test orientation or Dynamic Type matrix. No website image format is required: export the capture tool's native format without unnecessary conversion; the consumer converts later.

---

### Who controls website gallery selection, content sets and simulated screen state?

**Recorded response and notes:** The maintainer chooses EVERY gallery and assigns it to nonexplicit or explicit. Never select, discover or substitute galleries automatically, impose category-based selection/filtering requirements, or infer content-set labels from app categories. Every gallery visible in Home/detail/comments/reading/Live Text/downloads must come from that supplied selection; honor chosen reader pages and ordering. Provide clear configuration for gallery selections, reader pages and screen-specific state, and verify the actual applied selections/state before capture. Missing selections require an exact list of owner inputs needed while independent tooling work continues. Deterministically simulate Live Text highlights and download items THROUGH THE APP'S REAL UI, with selected real galleries, normal-looking state and no mock/debug labels. This is an explicit allowance for simulated presentation/operation state, not for invented marketing gallery content. Retain the earlier no-duplicate-gallery-on-one-screen decision and fixed gallery flow, separately within each owner-defined content set. Chrome-only screens may look identical between sets, but proposed asset sharing must be recorded explicitly; never silently substitute locale/theme/device/set.

---

### What quality and reproducibility requirements apply to website captures?

**Recorded response and notes:** Inspect current app/tooling first, reuse suitable mechanisms and verify screen names/navigation against code. Build and drive the repository's actual app locally in iOS Simulators with capture-only setup isolated from release behavior. Verify screen identity, locale, appearance, device and configured selections before capture; wait for images/layout to settle; reject unintended loading/error/empty/transient states. Pin status-bar values, timestamps, ordering, scroll positions, animation state and simulated progress. Verify byte-identical reruns for unchanged app/runtime/inputs and report unresolved nondeterminism instead of claiming deterministic output without evidence. Retain the earlier 9:41 marketing status-bar and Dynamic Island capsule-removal requirements; feasibility remains for research. Credentials come only from the local environment and must remain out of tracked files, logs, screenshots and CI secrets. Retain deliberate real-gallery fixture acquisition and offline capture runs from prior phase scope. Provide one documented full-export command with optional filters for individual combinations.

---

### What local delivery and inventory contract does the website require?

**Recorded response and notes:** Deliver captured image files, a machine-readable inventory covering EVERY expected coordinate including missing/failed captures, capture instructions and a results report. Suggested layout: images/<set>/<screen>/<device>-<locale-token>-<theme>.<extension>. Filename locale tokens are lowercase zh-hant/zh-hans; metadata keeps canonical zh-Hant/zh-Hans. Each inventory entry records screen ID and app view/state; locale/theme/device family/content set; relative path, actual format, dimensions, byte count and SHA-256; simulator model and OS/runtime; app commit/build and capture configuration identifier; selected gallery/page references without credentials; capture outcome, state-verification results and any sharing declaration. Retain the phase-level requirement to describe text size/orientation, fixture version and rendering environment. Keep exports local. The website consumer stages files, generates a labelled thumbnail sheet, obtains maintainer review, converts as needed and promotes approved images. Icon assets are already supplied: no icon work. Report export location, commands, coverage counts, reproducibility results and remaining gaps. Consumer-side staging/conversion/promotion is not part of this repository's local export work.

---

### Should AltStore use the website screen list, a smaller selection, or a separate list?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Reuse the eight website screen states |  |
| 2 | Select a smaller subset of those eight states |  |
| 3 | Define a separate AltStore screen list |  |

**Recorded response and notes:** The owner specified that AltStore should use App Store-style promotional images with deliberate visual design, rather than standalone raw screenshots. Actual app screenshots are source material for the designed images. The owner did not choose an AltStore screen list, count, locale/theme/content-set matrix, composition, copy, dimensions or device-frame treatment; do not infer those choices from the website contract.

---

### Who owns the AltStore promotional-image design?

**Recorded response and notes:** The owner explicitly requested recording this work for a separate designer agent: 請記錄這些由另外的 designer agent 去做. The owner then instructed: 不用 impeccable / 你不用參與 AltStore 圖片設計. The current agent must not use impeccable for this task or participate in AltStore image design. Record a separate designer-agent responsibility/task in Phase 17 planning for the App Store-style promotional assets; keep unresolved design decisions with that designer rather than asking or choosing them here. Continue the app screenshot-capture, fixture, verification and local delivery discussion. This is an ownership instruction for subsequent work, not a request to dispatch a designer or create a new chat now. Website raw-capture requirements remain locked and unchanged.

---

### Which state should the website Filters screenshot show?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Default state, with no adjusted filter conditions | ✓ |
| 2 | Some filter conditions configured, with the exact conditions supplied by the owner |  |
| 3 | Specify the state during planning together with gallery selections and reader pages |  |

**Recorded response and notes:** The owner selected option 1: show FiltersView in its default state, without adjusting filter conditions. Reset capture configuration to the app defaults rather than inheriting personal persisted filter values. This resolves the previously unspecified maintainer-chosen Filters state for the website export.

---

### Which network-bypass state should the website Laboratory screenshot show?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Enabled, showing the normal purple-card appearance (recommended) | ✓ |
| 2 | Disabled, preserving the app default |  |

**Recorded response and notes:** The owner selected option 1: enable the network-bypass setting in LaboratorySettingView, showing its normal enabled purple-card appearance. This resolves the website Laboratory state; a sparse screen is legitimate as already specified. Apply this state only in the isolated capture configuration.

---

### Write Phase 17 context or continue discussing screenshot details?

| Option | Description | Selected |
| --- | --- | --- |
| 1 | Write Phase 17 CONTEXT.md for research and planning | ✓ |
| 2 | Continue discussing other unclear screenshot details |  |

**Recorded response and notes:** The owner selected option 1 on 2026-10-02: write Phase 17 CONTEXT.md for research and planning. All four discussion areas are complete. Gallery selections and reader pages remain planning inputs as previously agreed; AltStore design is assigned to a separate designer agent.

---

## Agent discretion and separate ownership

- The capture/testing agent may choose real, synthetic or mixed snapshot-test data. Marketing gallery selections belong to the owner.
- Researchers/planners establish feasible capture methods and exact technical integration within the locked matrix, quality and delivery contract.
- AltStore promotional-image design and its unresolved design choices belong to a separate designer agent. The current agent does not design those images or use impeccable for this task.
- Planning first identifies required gallery quantities and content conditions; the owner then supplies selections, set assignments, pages and ordering.

## Deferred Ideas

None. The designer responsibility and post-snapshot size-class layout audit remain current-phase work. Public publishing and website-consumer staging/conversion/promotion are outside the local capture handoff.
