---
phase: 261121-neo-design-v1-1-0-on-develop-history-grid-no
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/GalleryListComponents/GalleryList.swift
  - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
  - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings
  - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
  - AppPackage/Tests/HostedViewTests/HeaderSectionDownloadLabelTests.swift
autonomous: true
requirements: [QUICK-261121-neo]

estimate:
  tokens: 160000
  raw_tokens: 160000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "History in the grid layout: the notice has 16 pt above it and 16 pt below it before the first row, the grid's own row gap, at every text size (fixed, not scaled); the list layout is unchanged (Owner item 1)."
    - "The download ring of a queued, downloading or paused gallery is drawn over the whole glass download button, 4 pt in from its edge with a 2.5-pt stroke, both @ScaledMetric relative to .callout; the pause or play glyph inside it is .callout semibold (Owner item 2)."
    - "Every download-button icon (cloud, trash, update arrows, error, wrench, signed-out cloud) is drawn at 1.1 times the scaled .callout size and both heart and heart.fill at 1.15 times; every glass circle keeps actionIconButtonSize, so the three buttons stay evenly spaced (Owner item 2)."
    - "A queued download shows the download ring, not a spinner: the track is 12 butt-capped dashes, the arc is the pages already saved, the glyph is pause.fill (Owner item 3)."
    - "Queued, downloading and paused are one button view: when the download starts the dashes cross-fade into the solid track over 0.3 s and the arc grows from where it is; under Reduce Motion the track switches at once, and the Reduce Motion inventory pins that gate as a documented exception to D-29 (Owner item 3)."
    - "VoiceOver reads a queued download as 'Queued. Pause download', or 'Queued, 47 of 114. Pause download' once pages are saved, from the new key accessibility.queued_progress in six locales (Owner item 3)."
  artifacts:
    - path: "AppPackage/Sources/GalleryListComponents/GalleryList.swift"
      provides: "GridList: the notice and the grid in one VStack spaced by the grid's row gap, the grid extracted into `grid`"
      contains: "VStack(spacing: Self.rowSpacing)"
    - path: "AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift"
      provides: "The full-button download ring with its dashed waiting track, the glyph scales and the queued VoiceOver label"
      contains: "private struct DownloadRingDashes: Shape"
    - path: "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings"
      provides: "accessibility.queued_progress in en, de, ja, ko, zh-Hans and zh-Hant"
      contains: "accessibility.queued_progress"
    - path: "AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift"
      provides: "The Reduce Motion inventory with the ring track's gate and its documented exception"
      contains: "\"DetailFeature/DetailView+HeaderSection.swift\": 1"
    - path: "AppPackage/Tests/HostedViewTests/HeaderSectionDownloadLabelTests.swift"
      provides: "The download button's VoiceOver label in the queued and downloading states"
  key_links:
    - from: "AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift"
      to: "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings"
      via: "String(localized: .accessibilityQueuedProgress(completed:total:)) in downloadBadgeAccessibilityLabel"
      pattern: "accessibilityQueuedProgress\\("
    - from: "AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift"
      to: "AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift"
      via: "the track pair's `.animation(reduceMotion ? nil : ...)` ternary, counted by the per-file census"
      pattern: "reduceMotion \\? nil : \\.easeInOut\\(duration: 0\\.3\\)"
    - from: "AppPackage/Sources/GalleryListComponents/GalleryList.swift"
      to: "AppPackage/Sources/GalleryListComponents/GalleryList.swift"
      via: "GridList.rowSpacing shared by the VStack gap, the notice's top padding and the LazyVGrid row spacing"
      pattern: "Self\\.rowSpacing"
---

<objective>
Implement three owner-approved v1.1.0 design changes on pages that already ship, on branch `design/v110-develop`
(cut from `develop` at 7dabc282b), one signed commit each, in this order:

1. History grid notice (Owner item 1): the notice above the grid gets 16 pt above and 16 pt below it, the grid's own
   row gap, so it reads as the grid's header and not as a caption of the first covers.
2. Detail header metrics (Owner item 2): the download ring takes the full 48-pt button (4 pt in, 2.5-pt stroke, both
   scaled on `.callout`), its pause/play glyph grows from 10 pt to `.callout` semibold, and the outline glyphs are
   drawn larger (download icons 1.1x, both hearts 1.15x) so the three glyphs read as one size.
3. Queued download ring (Owner item 3): the queued spinner becomes the download ring with a 12-dash track and the
   saved-pages arc, `pause.fill` inside; queued, active and paused are one view so the start of the download
   cross-fades the track (instant under Reduce Motion) and grows the arc; VoiceOver reads "Queued. Pause download" or
   "Queued, n of m. Pause download".

Purpose: the owner reshaped these with the design session (design snapshot 6d1bd6d, 2026-11-21).
Output: three commits on `design/v110-develop` and `261121-neo-SUMMARY.md` in this quick directory.

Decomposition: three self-contained view changes to existing, proven code in the fixed order the orchestrator set;
no tracer task (equivalent to `--no-tracer`: no new architecture to prove).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@AGENTS.md
@.swiftlint.yml
@.planning/STATE.md
@AppPackage/Sources/GalleryListComponents/GalleryList.swift
@AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
@AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
@AppPackage/Tests/HostedViewTests/HeaderSectionActionSpacingTests.swift
@AppPackage/Tests/HostedViewTests/LaidOutElements.swift

### Execution fidelity

Follow this plan exactly. If anything cannot be done exactly as written (ambiguity, conflicting requirements, missing
information, unexpected repository state, a lint rule or compiler error that forces a different shape, a test that
fails, or any deviation at all), stop immediately and ask the orchestrator. Do not choose, invent or implement a
solution on your own. The only latitude this plan grants is wrapping comment prose to stay within 120 columns
(the wording is fixed) and the Reduce Motion counts rule in Task 3, which the orchestrator set.

### Where you work

- Only the linked worktree that is the current directory (branch `design/v110-develop`). Every path here is relative
  to it. The main checkout at `$HOME/Fork/EhPanda` holds another session's uncommitted work: never read it, write it,
  build in it or run git against it. The one exception is reading `$HOME/Fork/EhPanda/AGENTS.local.md` (read-only)
  to unlock gpg if a commit fails because the gpg cache expired.
- Never edit the design repository; this plan carries every design value you need (below).
- Never use bare `git stash`. Never push. Do not commit this PLAN, the SUMMARY or STATE.md (the orchestrator does).
- Scratch: `.capture/neo/` for logs and scripts, derived data `.capture/dd-design-develop` (both under the gitignored
  `/.capture/`). Generated docs carry no absolute home paths (write `$HOME/...` or repo-relative) and name no other
  local project.

### Design values (from the owner's approved design; already decided)

- History grid: 16 above the notice and 16 below it before the first row; fixed at every text size.
- Download ring: drawn in the whole glass button (48 pt at default: the 32-pt label plus the glass style's padding),
  4 pt in from its edge, 2.5-pt stroke, track in the tint at 18 %, arc in the tint, round-capped, from 12 o'clock
  clockwise; an arc of 0 draws nothing. Glyph inside: `.callout` semibold (the buttons' own glyph size).
- Glyph scales: download-button icons 1.1x `.callout`, heart 1.15x for `heart` and `heart.fill` alike. Measured ink at
  `.callout`: cloud 20 x 18 pt, heart 16 x 14.75, book 18.5 x 14.5.
- Queued: track of 12 butt-capped dashes, each 60 % of its 30-degree segment (a 5 / 3.333 dash pattern over a path
  length of 100), the first starting at 12 o'clock and running clockwise; arc = pages already saved; glyph
  `pause.fill`. Into downloading: 0.3 s cross-fade of the dashes into the solid track, arc grows from where it is;
  Reduce Motion: the track switches at once.

### Verification conventions (used by every task)

- Shorthands: `H=AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift`,
  `G=AppPackage/Sources/GalleryListComponents/GalleryList.swift`, and the executable-line counter
  `ex() { grep -v '^[[:space:]]*//' "$2" | grep -cF -- "$1"; }` (comment lines excluded, fixed-string match). Gate
  baselines are written `[HEAD=<count at 7dabc282b> EXPECT<op><value>]`. Run every gate of a task after its edits
  and before its COMMIT, except the signature check, which runs after it.
- BASELINE (once, before any edit, at the untouched HEAD; the first build is long, run it in the background):
  `mkdir -p .capture/neo && xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath .capture/dd-design-develop > .capture/neo/build-baseline.log 2>&1`;
  then `grep -q '\*\* BUILD SUCCEEDED \*\*' .capture/neo/build-baseline.log && grep -E ': (warning|error): ' .capture/neo/build-baseline.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u > .capture/neo/warnings-baseline.txt`.
  Then the SwiftLint binary of the build's plug-in:
  `SWIFTLINT="$(find "$PWD/.capture/dd-design-develop/SourcePackages/artifacts" -path '*SwiftLintBinary.artifactbundle/macos/swiftlint' -type f | head -1)"`
  (stop and ask if it is empty), and the lint baseline
  `for d in AppPackage/Sources/GalleryListComponents AppPackage/Sources/DetailFeature AppPackage/Tests/AppToolsTests AppPackage/Tests/HostedViewTests; do (cd "$d" && "$SWIFTLINT" lint --quiet) || echo "LINT FAILED $d"; done > .capture/neo/lint-baseline.txt 2>&1`,
  which must be empty. Record the baseline warning count and the lint result in the SUMMARY. If the baseline build
  fails or the lint baseline is not empty, stop and ask.
- BUILD (task N): the same build command into `.capture/neo/build-taskN.log`; it must print `** BUILD SUCCEEDED **`,
  and `grep -E ': (warning|error): ' .capture/neo/build-taskN.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u | comm -13 .capture/neo/warnings-baseline.txt - > .capture/neo/new-warnings-taskN.txt; test ! -s .capture/neo/new-warnings-taskN.txt`
  must succeed (no warning or error the baseline did not have).
- LINT (task N): the lint loop above, limited to the directories the task names, into `.capture/neo/lint-taskN.txt`;
  the file must be empty. (The build log can lose plug-in lint output, so the direct run is the lint gate.)
- TEST (Tasks 2 and 3; Task 1 has no test that renders the grid): one test invocation on the machine at a time.
  Before starting, `pgrep -x xcodebuild` and `pgrep -x xctest` must both print nothing; if either prints a pid,
  another session's run is in flight: wait for it to end (re-check every few minutes) and never kill it. The
  simulator is this project's `EhPanda iPhone Air`, id B2A29E3D-244F-42EC-B015-0E4F7B60E329. The command:
  `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=B2A29E3D-244F-42EC-B015-0E4F7B60E329' -derivedDataPath .capture/dd-design-develop -collect-test-diagnostics never -skip-testing:VisualSnapshotTests -resultBundlePath .capture/neo/<name>.xcresult > .capture/neo/<name>.log 2>&1`
  plus the `-only-testing:` filter the task names, if any. Then
  `grep -E 'Test run with [0-9]+ tests|\*\* TEST (SUCCEEDED|FAILED) \*\*' .capture/neo/<name>.log` and
  `xcrun xcresulttool get test-results summary --path .capture/neo/<name>.xcresult`: read the per-bundle counts and
  report any failure verbatim. A known flake exists in FavoritesFeatureTests (LoginReturnObservationTests) under full
  load: if that is the only failure, re-run the same command with `-only-testing:FavoritesFeatureTests` into
  `<name>-favorites`; it must pass. Any other failure: stop and ask.
- COMMIT (task N): `git add -- <exactly the task's files>`; `git diff --cached --name-only` must list exactly those
  files; `TZ=Asia/Shanghai git commit -m "<the task's message>"` as the configured identity with its GPG key (signing
  is on in the repository config; never pass `--no-verify` or `--no-gpg-sign`, never bypass a hook). Then
  `git log -1 --format='%G? %aI %cI'` must print `G` and two dates ending `+08:00`. If the commit fails because gpg's
  cache has expired, follow the unlock steps in `$HOME/Fork/EhPanda/AGENTS.local.md` and retry the same command.
</context>

<tasks>

<task type="auto">
  <name>Task 1: History grid: the notice is set off by the grid's row gap above and below it</name>
  <precondition>`git branch --show-current` prints `design/v110-develop`, `git rev-parse --short=9 HEAD` prints `7dabc282b`, and `git status --porcelain` lists nothing but this quick directory (untracked); otherwise stop and ask.</precondition>
  <files>AppPackage/Sources/GalleryListComponents/GalleryList.swift</files>
  <read_first>
    - AGENTS.md (whole) and .swiftlint.yml (custom rules; `multiline_function_chains`, `line_length` 120 and `file_length` 1000 are errors)
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift: `NoticeBottomReporter` (about line 216) and `GridList` (about lines 327-418)
  </read_first>
  <action>
    Run BASELINE first (Verification conventions). Then edit only `GridList` in `AppPackage/Sources/GalleryListComponents/GalleryList.swift` (per Owner item 1 and the orchestrator's Item 1 decision); `DetailList` and everything above `// MARK: GridList` stay byte-identical.

    1. Directly below the line `@ScaledMetric(relativeTo: .callout) private var minCellWidth: CGFloat = 180`, add `private static let rowSpacing: CGFloat = 16` with this doc comment above it: "The gap between grid rows, and the space above and below the notice. The notice is the grid's header, not a caption of the first covers, so the grid's own row gap sets it off on both sides (owner decision, 2026-11-21). A fixed 16 at every text size, like the row gap it matches, so not a `@ScaledMetric`."

    2. In `body`, the `ScrollView`'s content becomes, in order: a `VStack(spacing: Self.rowSpacing)` holding (a) the existing `if let notice` block, whose `ListNoticeView(notice: notice)` keeps `.padding(.horizontal)` and `.modifier(NoticeBottomReporter(bottom: noticeBottom))` and then gets `.padding(.top, Self.rowSpacing)` as its last modifier, with the own-line comment "// After the reporter, so the bottom it reports stays the label's own." directly above that padding line, and (b) `grid`; then, as the VStack's sibling after it, the existing `if let pageNumber, pageNumber.hasNextPage()` / `FetchMoreFooter(...)` block unchanged. The ScrollView's modifiers (`.scrollEdgeEffectStyle(.soft, for: .top)`, `.scrollPosition(id: $scrollPositionID, anchor: .top)`) are unchanged.

    3. Below `body`, add `private var grid: some View` containing the existing `LazyVGrid` moved verbatim (its `ForEach` and every modifier inside it unchanged) with its trailing `.scrollTargetLayout()` and `.padding(.horizontal)`, except that its row spacing argument becomes `spacing: Self.rowSpacing` on its own line: the `LazyVGrid(` call puts `columns: [GridItem(.adaptive(minimum: minCellWidth), spacing: 12, alignment: .top)],` on one line and `spacing: Self.rowSpacing` on the next (one line would pass 120 columns).

    Then BUILD, LINT (directory `AppPackage/Sources/GalleryListComponents`) and COMMIT with the message "Give the History grid notice its own space".
  </action>
  <verify>
    <automated>BASELINE, BUILD and LINT with N=1 pass. Gates (with the shorthands): `ex 'private static let rowSpacing: CGFloat = 16' $G` prints 1 [HEAD=0 EXPECT==1]; `ex 'VStack(spacing: Self.rowSpacing)' $G` prints 1 [HEAD=0 EXPECT==1]; `ex 'Self.rowSpacing' $G` prints 3 [HEAD=0 EXPECT==3]; `ex '.padding(.top, Self.rowSpacing)' $G` prints 1 [HEAD=0 EXPECT==1]; `ex 'private var grid: some View' $G` prints 1 [HEAD=0 EXPECT==1]; `ex 'spacing: 16' $G` prints 0 [HEAD=1 EXPECT==0]; the padding follows the reporter: `awk '/NoticeBottomReporter\(bottom: noticeBottom\)/{r=NR} /padding\(\.top, Self\.rowSpacing\)/{p=NR} END{exit !(p>r && p-r<=2)}' $G` exits 0 [HEAD=1 EXPECT==0]; nothing above GridList changed: `git diff -U0 HEAD -- $G > .capture/neo/task1.diff && awk '/^@@/{split($2,a,","); if (substr(a[1],2)+0 < 328) bad=1} END{exit bad}' .capture/neo/task1.diff` exits 0; `wc -l < $G` is at most 1000. After the commit, `git log -1 --format='%G? %aI %cI'` prints G and two +08:00 dates.</automated>
  </verify>
  <done>In the History grid the notice sits 16 pt below the top of the scroll content and 16 pt above the first row, at every text size; the row gap is the same constant; the list layout is untouched; build has no new warning, lint is empty, and the signed +08:00 commit "Give the History grid notice its own space" exists.</done>
</task>

<task type="auto">
  <name>Task 2: Detail header: full-button download ring and glyphs of one size</name>
  <files>AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift</files>
  <read_first>
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift (whole; the metrics at lines 40-53, `downloadButton`, `downloadIconLabel`, `favoriteButton`, `readButton`, `progressIndicator`)
    - AppPackage/Tests/HostedViewTests/HeaderSectionActionSpacingTests.swift (it measures the three buttons with no download badge)
    - AppPackage/Sources/AppComponents/ViewModifiers.swift (`visible(_:)`, used in Task 3)
  </read_first>
  <action>
    Edit `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` only (per Owner item 2 and the orchestrator's Item 2 decision). The queued state keeps its shipped spinner in this commit; Task 3 replaces it.
    <!-- planner-discipline-allow: isDeterminate -->
    <!-- planner-discipline-allow: queuedSpinner -->

    1. Metrics. Keep `actionIconButtonSize`, `actionIconFontSize` and `actionIconFont` with their comments. Directly below `actionIconFont` add, under one own-line `//` comment block, `private static let downloadIconScale: CGFloat = 1.1`, `private static let heartIconScale: CGFloat = 1.15`, and two computed fonts, each written over three lines (declaration line, body line, closing brace): `private var downloadIconFont: Font` returning `.system(size: actionIconFontSize * Self.downloadIconScale, weight: .semibold)` and `private var heartIconFont: Font` returning `.system(size: actionIconFontSize * Self.heartIconScale, weight: .semibold)`. The comment: "The download and favourite glyphs are drawn larger than `.callout` so the three buttons' glyphs read as one size (owner decision, 2026-11-21): the Read button's book is a solid shape on a solid button, and the outline glyphs beside it look smaller at the same point size. Measured ink at `.callout`: cloud 20 x 18 pt, heart 16 x 14.75, book 18.5 x 14.5. The heart's factor applies to `heart` and `heart.fill` alike, so it keeps its size when tapped. Both multiply `actionIconFontSize`, so they scale with Dynamic Type exactly as the book does; every glass circle keeps `actionIconButtonSize`." Keep the existing 10-pt `.caption2` centre-glyph metric and its comment unchanged in this task (the queued spinner below still reads it; Task 3 deletes both). Replace the comment above the two ring metrics with: "2.5pt thick and 4pt in from the button's edge at default (.large). The ring is drawn over the whole glass button (48pt at default: the 32pt label and the glass style's padding), so it traces the button's own circle instead of sitting as a smaller disc inside the label (owner decision, 2026-11-21). Both scale on the button's own metric, so the ring keeps its place and weight as the button grows." Keep `progressRingLineWidth` at 2.5 and change `progressRingInset` from 3 to 4 (both stay `@ScaledMetric(relativeTo: .callout)`).

    2. Glyph fonts. In `downloadIconLabel` change `.font(actionIconFont)` to `.font(downloadIconFont)` (this covers the menu cloud, the preparing cloud, trash, the update arrows, the error and wrench glyphs and the signed-out cloud). In `favoriteButton` change `.font(actionIconFont)` to `.font(heartIconFont)` on both the `heart` label and the `heart.fill` overlay label. Frames stay `actionIconButtonSize`. The Read button keeps `actionIconFont`.

    3. Ring branch of `downloadButton` (the `if let progress = activeDownloadProgress` branch): the `Button(action: downloadAction)` label becomes the centre glyph, `Image(systemSymbol: activeDownloadIconSymbol)` with, one per line, `.font(actionIconFont)`, `.foregroundStyle(downloadButtonTint)`, `.frame(width: actionIconButtonSize, height: actionIconButtonSize)`, `.contentShape(.circle)`, `.accessibilityHidden(true)`, under the own-line comment "// Decorative: the button announces the status and the action through `downloadButtonAccessibilityLabel`, so the glyph would only be read twice." After the existing `.buttonStyle(.glass(.regular.interactive()))` and `.buttonBorderShape(.circle)`, add `.overlay { downloadProgressRing(fraction: progress) }` (overlay body on its own line).

    4. Queued branch (`else if let progress = queuedDownloadProgress`): rewrite it as `else if queuedDownloadProgress != nil` whose `Button(action: downloadAction)` label is `queuedSpinner`; its glass style and circle border shape stay.
    <!-- planner-discipline-allow: queuedDownloadProgress -->

    5. Replace `progressIndicator(progress:isDeterminate:centerSymbol:)` with two members at the same place:
       (a) `private func downloadProgressRing(fraction: Double) -> some View`, doc comment "The download ring, drawn over the whole glass button rather than inside its label: a track in the tint at 18 % and an arc in the tint from 12 o'clock clockwise for the pages saved, so an arc of 0 draws nothing. It neither takes touches nor speaks: the button under it does both." Body: `Circle()` then `.stroke(downloadButtonTint.opacity(0.18), lineWidth: progressRingLineWidth)`, then `.overlay` holding the existing arc unchanged (`Circle()`, `.trim(from: 0, to: fraction)`, `.stroke(downloadButtonTint, style: .init(lineWidth: progressRingLineWidth, lineCap: .round))`, `.rotationEffect(.degrees(-90))`, `.animation(.default, value: fraction)`), then the own-line comment "// The stroke is centred on its path, so the path sits half a line width past the inset." and `.padding(progressRingInset + progressRingLineWidth / 2)`, then `.allowsHitTesting(false)` and `.accessibilityHidden(true)`.
       (b) `private var queuedSpinner: some View`, doc comment "The queued state as shipped: a small spinner around the cloud glyph, inside the label." Body: `ProgressView()`, `.progressViewStyle(.circular)`, `.tint(downloadButtonTint)`, `.controlSize(.small)`, then `.overlay` holding `Image(systemSymbol: downloadIconSymbol)` with `.font(.system(size: progressCenterSymbolSize, weight: .semibold))`, `.foregroundStyle(downloadButtonTint)`, `.accessibilityHidden(true)` (keep the old decorative-glyph comment above that Image), then `.frame(width: actionIconButtonSize, height: actionIconButtonSize)`.
    <!-- planner-discipline-allow: ProgressView() -->
    <!-- planner-discipline-allow: progressCenterSymbolSize -->
    Every modifier goes on its own line (`multiline_function_chains` is an error). Nothing else in the file changes.

    Then BUILD, LINT (directory `AppPackage/Sources/DetailFeature`), TEST with name `task2` and `-only-testing:HostedViewTests` (HeaderSectionActionSpacingTests must pass unchanged: the frames are unchanged and it measures the no-badge state; if it fails, stop and ask with its message, do not edit it), and COMMIT with the message "Match the detail header glyphs and ring".
  </action>
  <verify>
    <automated>BUILD, LINT and TEST (task2, HostedViewTests) pass. Gates: `ex 'isDeterminate' $H` prints 0 [HEAD=5 EXPECT==0]; `ex '@ScaledMetric(relativeTo: .callout) private var progressRingInset: CGFloat = 4' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '@ScaledMetric(relativeTo: .callout) private var progressRingLineWidth: CGFloat = 2.5' $H` prints 1 (unchanged); `ex 'private static let downloadIconScale: CGFloat = 1.1' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'private static let heartIconScale: CGFloat = 1.15' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '.font(downloadIconFont)' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '.font(heartIconFont)' $H` prints 2 [HEAD=0 EXPECT==2]; `ex '.font(actionIconFont)' $H` prints 2 [HEAD=4 EXPECT==2]; `ex 'func downloadProgressRing(' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '.padding(progressRingInset + progressRingLineWidth / 2)' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '.allowsHitTesting(false)' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'private var queuedSpinner: some View' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'ProgressView()' $H` still prints 1 and `ex 'progressCenterSymbolSize' $H` still prints 2 (the shipped queued spinner stays until Task 3 deletes it); `wc -l < $H` is at most 1000. HeaderSectionActionSpacingTests passes (all arguments). Signed +08:00 commit verified.</automated>
  </verify>
  <done>The active and paused ring traces the 48-pt glass circle 4 pt in with a 2.5-pt stroke and a .callout semibold pause/play glyph, all scaling on .callout; download icons are 1.1x and both hearts 1.15x of the scaled .callout size with unchanged frames; the queued spinner is still the shipped one; build, lint and HostedViewTests pass; the signed +08:00 commit "Match the detail header glyphs and ring" exists.</done>
</task>

<task type="auto">
  <name>Task 3: Queued download on the download ring: dashed waiting track, saved-pages arc, pause glyph, VoiceOver label</name>
  <precondition>`xcrun simctl list devices | grep -cF 'EhPanda iPhone Air (B2A29E3D-244F-42EC-B015-0E4F7B60E329)'` prints 1, and `test ! -d AppPackage/Tests/VisualSnapshotTests/Baseline` succeeds (no approved snapshot baseline in the tree, observed at 7dabc282b); otherwise stop and ask.</precondition>
  <files>AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift, AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings, AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift, AppPackage/Tests/HostedViewTests/HeaderSectionDownloadLabelTests.swift</files>
  <read_first>
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift (as left by Task 2)
    - AppPackage/Sources/AppComponents/ViewModifiers.swift (`visible(_:)`: opacity plus accessibility hiding)
    - AppPackage/Sources/AppModels/Download/DownloadProgress.swift (`fraction`, `displayPageCount`)
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings: the entries `accessibility.downloading` (the template), `accessibility.queued`, `accessibility.pause_action` (en "Pause download")
    - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift (whole: doc comment, the three tables, the totals)
    - AppPackage/Tests/HostedViewTests/HeaderSectionActionSpacingTests.swift and LaidOutElements.swift (the Host pattern and `frame(labelled:)`)
    - Skills to load: swiftui-pro, swift-testing-pro
  </read_first>
  <action>
    All per Owner item 3 and the orchestrator's Item 3 decision.
    <!-- planner-discipline-allow: activeDownloadProgress -->
    <!-- planner-discipline-allow: relativeTo: .caption2 -->
    <!-- planner-discipline-allow: case .inactive: return .playFill -->

    A. `DetailView+HeaderSection.swift`, state:
    1. Delete `queuedDownloadProgress` and `activeDownloadProgress`. In their place add `private var downloadRing: (fraction: Double, isWaiting: Bool)?` with the doc comment "The download ring of a queued, downloading or paused gallery. The arc is the pages already saved, the queued state included, so a resumed download keeps its arc while it waits its turn; `isWaiting` is the queued state, whose track is dashed. `nil` for every other state, which shows a glyph." Body: `guard let badge = downloadBadge,` / `[.queued, .active, .inactive].contains(badge.status)` / `else { return nil }` (three lines, as the old guard), then `return (fraction: badge.progress.fraction, isWaiting: badge.status == .queued)`.
    2. `activeDownloadIconSymbol` becomes the single expression `downloadBadge?.status == .inactive ? .playFill : .pauseFill`, with the doc comment "The glyph inside the download ring is the action a tap performs: pause while the download is queued or running, play to resume a paused one."
    3. In `downloadIconSymbol` delete the `.inactive` case (now unreachable: the ring branch takes every paused gallery).
    4. Delete the 10-pt `.caption2` centre-glyph metric `progressCenterSymbolSize` with its comment, and delete `queuedSpinner`.

    B. `downloadButton`: merge the ring branch and the queued branch into one. The `Group` becomes `if let ring = downloadRing { ... } else if downloadBadge == nil { <the Menu, unchanged> } else { <the trailing Button, unchanged> }`, keeping the Group's `.disabled(isDownloadActionDisabled)` and `.accessibilityLabel(downloadButtonAccessibilityLabel)`. Above `if let ring = downloadRing` put the own-line comment "// Queued, downloading and paused are one button, so when a download starts the dashed track cross-fades and the arc grows instead of one button replacing another." The ring branch is Task 2's ring-branch Button unchanged except that its overlay calls `downloadProgressRing(fraction: ring.fraction, isWaiting: ring.isWaiting)`.

    C. `downloadProgressRing(fraction: Double, isWaiting: Bool) -> some View`, replacing Task 2's version. Doc comment: "The download ring, drawn over the whole glass button rather than inside its label: a track in the tint at 18 % and an arc in the tint from 12 o'clock clockwise for the pages saved, so an arc of 0 draws nothing. While the download waits its turn the track is twelve dashes (``DownloadRingDashes``); when it starts they cross-fade into the solid track over 0.3s while the arc grows from where it is, one view throughout. Under Reduce Motion the track switches at once (owner decision, 2026-11-21), a deliberate exception to D-29, which leaves an opacity change ungated. It neither takes touches nor speaks: the button under it does both." Body, every modifier on its own line: a `ZStack` holding (1) `Circle()`, `.stroke(downloadButtonTint.opacity(0.18), lineWidth: progressRingLineWidth)`, `.visible(!isWaiting)` and (2) `DownloadRingDashes()`, then `.stroke(` with its two arguments on their own lines, `downloadButtonTint.opacity(0.18),` and `style: .init(lineWidth: progressRingLineWidth, lineCap: .butt)`, closing `)`, then `.visible(isWaiting)`; after the ZStack, `.animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isWaiting)` written on one line with no trailing comment; then the arc `.overlay` exactly as in Task 2; then the own-line stroke-centring comment, `.padding(progressRingInset + progressRingLineWidth / 2)`, `.allowsHitTesting(false)`, `.accessibilityHidden(true)`. Do not mention the gate value's name in any trailing comment on a code line (the Reduce Motion census counts executable lines).

    D. New file-scope shape, in a new `// MARK: DownloadRingDashes` section placed between the `// MARK: HeaderSection Accessibility` extension and `// MARK: HeaderSection Previews`: `private struct DownloadRingDashes: Shape` with `private static let dashCount = 12` and `private static let dashShare = 0.6`. Doc comment: "The download ring's track while the download waits its turn: twelve dashes on the circle inscribed in the rect, each covering 60 % of its 30-degree segment, the first starting at 12 o'clock and running clockwise (the design's dash pattern, 5 on and 3.333 off over a path length of 100). Stroked with butt caps, so the gaps stay open at every size. A shape rather than a dashed `StrokeStyle`: a dash pattern is given in points, so it would need the ring's measured circumference to land twelve whole dashes, where the shape divides whatever circle it is given." `func path(in rect: CGRect) -> Path`: `let center = CGPoint(x: rect.midX, y: rect.midY)`, `let radius = min(rect.width, rect.height) / 2`, `let segment = 360 / Double(Self.dashCount)`, `var path = Path()`, then `for index in 0..<Self.dashCount`: `var dash = Path()` and `dash.addRelativeArc(center: center, radius: radius, startAngle: .degrees(-90 + segment * Double(index)), delta: .degrees(segment * Self.dashShare))` (arguments wrapped over lines as needed for 120 columns), then `path.addPath(dash)`; return `path`. Put the own-line comment "// Each dash is its own subpath, so no line joins one dash to the next; a positive delta runs clockwise in SwiftUI's y-down space." above `var dash = Path()`.

    E. VoiceOver (`downloadBadgeAccessibilityLabel`): the `.queued` case becomes `let queued = progress.completedPageCount == 0` / `? String(localized: .accessibilityQueued)` / `: String(localized: .accessibilityQueuedProgress(` / `completed: progress.completedPageCount, total: progress.displayPageCount` / `))`, then `return [queued, String(localized: .accessibilityPauseAction)]` / `.joined(separator: ". ")` (the `.active` case's shape).

    F. Previews: directly after `#Preview("Downloading")` add `#Preview("Queued")` with `downloadBadge: .init(status: .queued, progress: .init(completedPageCount: 0, pageCount: 114))` and `#Preview("Queued, resumed")` with `downloadBadge: .init(status: .queued, progress: .init(completedPageCount: 47, pageCount: 114))`, each in the existing preview shape (`@Previewable @AccessibilityFocusState var readButtonFocused: Bool`, `withDependencies` with `$0.cookieClient = .previewLoggedIn`, `previewHeaderSection(readButtonFocus: $readButtonFocused, downloadBadge: ...)`).

    G. String catalog. Create `.capture/neo/add_queued_progress.py` with the Write tool, typing every value as literal UTF-8 characters (never `\u` escapes: the Write tool turns them into characters). The script: reads `AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings` as UTF-8 text; parses it with `json.loads` and aborts if `accessibility.queued_progress` already exists; deep-copies `strings["accessibility.downloading"]` as the new entry (`extractionState` `manual`; locales en, de, ja, ko, zh-Hans, zh-Hant in that order; substitutions `completed` argNum 1 and `total` argNum 2, `lld`, plural `other` only with `%arg`, state `translated`) and replaces only each locale's `stringUnit.value` with these values, verbatim: en `Queued, %#@completed@ of %#@total@`; de `In der Warteschlange, %#@completed@ von %#@total@ heruntergeladen`; ja `ダウンロード待ち、%#@total@ページ中%#@completed@ページ取得済み`; ko `다운로드 대기 중, 총 %#@total@페이지 중 %#@completed@페이지 받음`; zh-Hans `等待中，已下载 %#@completed@ 页，共 %#@total@ 页`; zh-Hant `等待中，已下載 %#@completed@ 頁，共 %#@total@ 頁`. It serializes only the entry with `json.dumps(entry, ensure_ascii=False, indent=2, separators=(',', ': '))`, prefixes every line after the first with four spaces, asserts that the text `\n    "accessibility.remove_from_favorites": {` (newline, four spaces) occurs exactly once, and inserts `\n    "accessibility.queued_progress": ` + entry + `,` immediately before it, so the new key directly follows `accessibility.queued`; it writes the text back as UTF-8 with no other change (the file ends without a trailing newline; keep that). It does not re-dump the whole file: the file has three closing braces at irregular indentation (lines 1922, 2071 and 2220 at HEAD) that a whole-file dump would rewrite. Run it with `python3 -I .capture/neo/add_queued_progress.py`. Do not commit the script.

    H. Reduce Motion inventory, `AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift`: in the suite's doc comment change "The first launch (Phase 18 UI-SPEC C-1) is the other:" to "The first launch (Phase 18 UI-SPEC C-1) is another:", and after that paragraph (before the comment-moderation paragraph, separated by `///` lines) add the paragraph "The Detail header's download ring is a third: while a download waits its turn the ring's track is twelve dashes, and when the download starts they cross-fade into the solid track over 0.3s, an opacity change D-29 would leave ungated. The owner's design for the ring switches the track at once under Reduce Motion (2026-11-21)." In `expectedTernaryPredicates` insert `"DetailFeature/DetailView+HeaderSection.swift": 1,` between the `DetailFeature/Comments/CommentsView.swift` and `DetailFeature/DetailView+Subviews.swift` entries, preceded by the own-line comment "// The download ring's dashed track switches at once under Reduce Motion (owner decision, 2026-11-21)."; set `expectedTernaryPredicateTotal` to 37; set the `DetailFeature/DetailView+HeaderSection.swift` entry of `expectedGateMentions` to 4, preceded by the own-line comment "// The read, the spin and the pulse it composes, and the ring track's ternary."; set `expectedGateMentionTotal` to 81. Re-derive these four numbers from the live source after the edits with the census commands in verify; if an observed count differs from 1, 37, 4 or 81, use the observed count in the table and report the difference in the SUMMARY (orchestrator rule). `expectedEnvironmentReads` is unchanged.

    I. New test `AppPackage/Tests/HostedViewTests/HeaderSectionDownloadLabelTests.swift` (planner addition to pin the owner's VoiceOver copy; imports as in HeaderSectionActionSpacingTests: AppModels, ComposableArchitecture, CookieClient, `@testable import DetailFeature`, Foundation, SwiftUI, Testing, sorted). Doc comment on the suite: "The download button's VoiceOver label names the state and the action a tap performs; a queued download reads like a running one, with its saved pages once there are any (owner decision, 2026-11-21)." `@MainActor struct HeaderSectionDownloadLabelTests` with a `private struct Host: View` holding `@AccessibilityFocusState var readFocus: Bool`, `private let downloadBadge: DownloadBadge`, an explicit `init(downloadBadge: DownloadBadge)`, and a body building `HeaderSection` with the spacing test's arguments except `galleryDetail: .preview` and `downloadBadge: downloadBadge`; a helper `private func isRead(_ label: String, for badge: DownloadBadge) throws -> Bool` that builds `LaidOutElements(of: Host(downloadBadge: badge), width: 402, size: .large)` inside a multi-line `withDependencies { $0.cookieClient = .noop } operation: { ... }` and returns `elements.frame(labelled: label) != nil`; and three tests: `aQueuedDownloadWithNothingSavedReadsQueuedAndPause` expects `"Queued. Pause download"` for `.init(status: .queued, progress: .init(completedPageCount: 0, pageCount: 114))`; `aQueuedDownloadWithSavedPagesReadsThem` expects `"Queued, 47 of 114. Pause download"` for status `.queued`, 47 of 114; `aRunningDownloadKeepsItsLabel` expects `"Downloading 47 of 114. Pause download"` for status `.active`, 47 of 114. Each is `#expect(try isRead(<label>, for: <badge>))`.

    J. Snapshot impact (read-only; do not run the snapshot harness): `run-snapshot-local.sh` writes Reduce Motion and application-accessibility defaults into the simulator, and the tree has no approved baseline to compare with, so nothing is captured here. Run `grep -n -B1 'Page\.detail(\|Page\.history(\.grid)' AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog*.swift` and list in the SUMMARY every scenario key it shows (expected: `history-grid` and the `gallery-detail-*` keys) as the scenarios whose baselines need re-recording by the owner: `history-grid` for the notice spacing, every `gallery-detail-*` for the larger download and heart glyphs, `gallery-detail-downloading` also for the ring geometry; and state that no scenario renders a queued download.

    Then BUILD, LINT (directories `AppPackage/Sources/DetailFeature`, `AppPackage/Tests/AppToolsTests`, `AppPackage/Tests/HostedViewTests`), TEST with name `task3` and no `-only-testing:` filter (the whole plan minus VisualSnapshotTests; this is the final run), and COMMIT the four files with the message "Show queued downloads on the progress ring". Write `261121-neo-SUMMARY.md` in this quick directory (frontmatter `status: complete`): commits with hash, message and the `%G? %aI %cI` line; the baselines; every gate's output; the observed Reduce Motion counts; per-bundle test counts; the snapshot scenario list; any pause and the orchestrator's answer.
  </action>
  <verify>
    <automated>BUILD, LINT and TEST (task3, whole plan minus VisualSnapshotTests) pass; ReduceMotionGatingSourceTests, HeaderSectionActionSpacingTests and HeaderSectionDownloadLabelTests pass. Gates: `ex 'ProgressView()' $H` prints 0 [HEAD=1 EXPECT==0]; `ex 'progressCenterSymbolSize' $H` prints 0 [HEAD=2 EXPECT==0]; `ex 'relativeTo: .caption2' $H` prints 0 [HEAD=1 EXPECT==0]; `ex 'queuedDownloadProgress' $H` prints 0 [HEAD=2 EXPECT==0]; `ex 'activeDownloadProgress' $H` prints 0 [HEAD=2 EXPECT==0]; `ex 'queuedSpinner' $H` prints 0 (Task 2 left 2); `ex 'case .inactive: return .playFill' $H` prints 0 [HEAD=2 EXPECT==0]; `ex 'downloadBadge?.status == .inactive ? .playFill : .pauseFill' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'if let ring = downloadRing' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'Button(action: downloadAction)' $H` prints 2 [HEAD=3 EXPECT==2]; `ex 'private struct DownloadRingDashes: Shape' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'DownloadRingDashes()' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'addRelativeArc(' $H` prints 1 [HEAD=0 EXPECT==1]; `ex 'lineCap: .butt' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '.animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isWaiting)' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '.accessibilityQueuedProgress(' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '#Preview("Queued")' $H` prints 1 [HEAD=0 EXPECT==1]; `ex '#Preview("Queued, resumed")' $H` prints 1 [HEAD=0 EXPECT==1]; `wc -l < $H` at most 1000. Census: `grep -v '^[[:space:]]*//' $H | grep -o 'reduceMotion ?' | wc -l` prints 1 [HEAD=0 EXPECT==1]; `grep -v '^[[:space:]]*//' $H | grep -o 'reduceMotion' | wc -l` prints 4 [HEAD=3 EXPECT==4]; `find AppPackage/Sources -name '*.swift' -exec grep -hv '^[[:space:]]*//' {} + | grep -o 'reduceMotion ?' | wc -l` prints 37 [HEAD=36 EXPECT==37]; the same with `grep -o 'reduceMotion'` prints 81 [HEAD=80 EXPECT==81]. Catalog: after `git diff --numstat -- AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings > .capture/neo/task3.numstat` succeeds, `cut -f1 .capture/neo/task3.numstat` prints 221 [HEAD=absent EXPECT==221] and `cut -f2 .capture/neo/task3.numstat` prints 0 [HEAD=absent EXPECT==0] (221 lines added, none removed); `python3 -I -c "import json; s=json.load(open('AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings', encoding='utf-8'))['strings']; k=list(s); e=s['accessibility.queued_progress']; d=s['accessibility.downloading']; assert k.index('accessibility.queued_progress') == k.index('accessibility.queued') + 1; assert list(e['localizations']) == ['en', 'de', 'ja', 'ko', 'zh-Hans', 'zh-Hant']; assert all(e['localizations'][l]['substitutions'] == d['localizations'][l]['substitutions'] for l in e['localizations']); assert e['localizations']['en']['stringUnit'] == {'state': 'translated', 'value': 'Queued, %#@completed@ of %#@total@'}; print('ok')"` prints ok and exits 0 [HEAD=error:1 EXPECT==0]. Snapshot list recorded. Signed +08:00 commit verified.</automated>
  </verify>
  <done>A queued download shows the full-button ring with a 12-dash butt-capped track, the saved-pages arc and pause.fill; queued, downloading and paused share one button view, the track cross-fades over 0.3 s into the solid one when the download starts (at once under Reduce Motion) and the arc grows from where it was; VoiceOver reads "Queued. Pause download" or "Queued, 47 of 114. Pause download"; the new key exists in six locales and the diff adds only it; the Reduce Motion inventory pins the new gate with its documented exception; the whole FeatureTests plan minus VisualSnapshotTests passes; the signed +08:00 commit "Show queued downloads on the progress ring" exists; the SUMMARY lists the snapshot scenarios needing re-recording.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app state → VoiceOver | The download button's label speaks the page counts the badge already holds; no new data source. |
| script → string catalog | A scratch script rewrites a shipped resource file; a malformed write would break every locale of the module. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261121-neo-01 | Information disclosure | queued VoiceOver label (page counts) | low | accept | The same counts are already spoken by the Downloading and Paused labels and drawn by the ring; nothing leaves the device. |
| T-261121-neo-02 | Tampering | `Localizable.xcstrings` edit | medium | mitigate | The script inserts one serialized entry at a single asserted anchor instead of re-dumping the file; Task 3's gates require `git diff --numstat` of 221 added and 0 deleted lines and a JSON reload that checks key order, locales, substitutions and the en value. |
| T-261121-neo-03 | Denial of service | Reduce Motion users and the new cross-fade | low | mitigate | The only new animation is gated (`reduceMotion ? nil : ...`) and pinned by ReduceMotionGatingSourceTests with the exception documented in its doc comment. |
| T-261121-neo-SC | Tampering | npm/pip/cargo installs | low | accept | This plan installs no package and changes no `Package.swift` dependency; nothing to vet. |
</threat_model>

<verification>
- BASELINE once; then BUILD and LINT after every task (no new warning, empty lint), TEST after Tasks 2 and 3 (Task 3:
  the whole FeatureTests plan minus VisualSnapshotTests, 0 failed, per-bundle counts recorded).
- Every gate in the three `<verify>` blocks prints its EXPECT value.
- Three signed commits with `G` and +08:00 author and committer dates, messages "Give the History grid notice its own
  space", "Match the detail header glyphs and ring", "Show queued downloads on the progress ring".
- Every touched Swift file is at most 1000 lines.
</verification>

<success_criteria>
- History's grid notice has 16 pt above and below it at every text size; the list layout is unchanged.
- The download ring is the full-button ring in every ring state (queued, downloading, paused) with the design's
  inset, stroke and glyph; the outline glyphs are 1.1x and 1.15x; the three buttons stay evenly spaced.
- The queued ring waits with dashes and the saved-pages arc, cross-fades into downloading as one view (instant under
  Reduce Motion), and speaks the owner's VoiceOver copy, proven by the hosted label test.
- SUMMARY written (`status: complete`) with baselines, gate output, Reduce Motion counts, test counts and the snapshot
  scenarios the owner must re-record.
</success_criteria>

<output>
Create `.planning/quick/261121-neo-design-v1-1-0-on-develop-history-grid-no/261121-neo-SUMMARY.md` when done
</output>
