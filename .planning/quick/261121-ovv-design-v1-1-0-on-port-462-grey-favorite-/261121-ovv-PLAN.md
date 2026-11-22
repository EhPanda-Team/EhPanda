---
phase: 261121-ovv-design-v1-1-0-on-port-462-grey-favorite-
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
  - AppPackage/Sources/AppModels/Gallery/Gallery.swift
  - AppPackage/Sources/AppModels/Gallery/UserRatingTint.swift
  - AppPackage/Sources/ParserFeature/Parser+Types.swift
  - AppPackage/Sources/ParserFeature/Parser+List.swift
  - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
  - AppPackage/Sources/DetailFeature/DetailReducer.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
  - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
  - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
  - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings
  - AppPackage/Tests/AppModelsTests/GalleryStatusFieldsTests.swift
  - AppPackage/Tests/ParserFeatureTests/List/GalleryStatusParserTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DetailFavoriteStateTests.swift
  - AppPackage/Tests/GalleryListComponentsTests/GalleryRatingTintRenderTests.swift
autonomous: true
requirements: [QUICK-261121-ovv]

estimate:
  tokens: 150000
  raw_tokens: 150000
  tasks: 4
  confidence: low

must_haves:
  truths:
    - "A favorite's heart in a list row or grid cell is drawn in the secondary foreground, the same for every favorites folder; GalleryFavoriteHeart reads no slot colour (Owner item 4)."
    - "List rows (GalleryDetailCell) keep the heart before the page count, 8 apart, at .footnote; grid cells (GalleryThumbnailCell) put it on the page-count line after the count or download badge, 8 apart, in that line's .footnote; the grid's rating line is exactly the rating again; a cell that is not a favorite is structurally unchanged (Owner item 4)."
    - "The stars in list rows, grid cells and the detail page's facts strip (DescScrollRatingItem) carry no user-rating colour; Gallery no longer stores a rating colour, and Gallery JSON that still has the old key decodes (Owner item 5)."
    - "The detail page's rating button reads Edit Rating once the fetched detail page says the user has rated (galleryDetail.userRating > 0) and Rate Gallery before; dragging the stars never flips it; the action still toggles the rating row, which keeps the user's rating in the site's colour (Owner item 6)."
    - "edit_rating exists in en, de, ja, ko, zh-Hans and zh-Hant with the orchestrator's native values (Owner item 6)."
    - "The Read button's ring has a 2.5-pt stroke and a 4-pt inset at default size, the download ring's geometry (Owner item 8)."
    - "The detail favorite button still tints with Defaults.FavoriteColor, and the Favorites site-settings folder dots are untouched (Owner items 7 and 9)."
  artifacts:
    - path: "AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift"
      provides: "The secondary-coloured favorite heart"
      contains: ".foregroundStyle(.secondary)"
    - path: "AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift"
      provides: "The grid's page-count line with a favorite's heart after the count"
      contains: "private var pageCountWithFavoriteHeart: some View"
    - path: "AppPackage/Sources/DetailFeature/DetailView+Subviews.swift"
      provides: "ActionSection's Rate Gallery / Edit Rating title and previews of both labels"
      contains: "private var ratingButtonTitle: LocalizedStringResource"
    - path: "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings"
      provides: "edit_rating in six locales"
      contains: "\"edit_rating\""
    - path: "AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift"
      provides: "The Read ring's 2.5-pt stroke"
      contains: "private var readRingLineWidth: CGFloat = 2.5"
    - path: "AppPackage/Tests/AppModelsTests/GalleryStatusFieldsTests.swift"
      provides: "Decoding of Gallery JSON that still carries the removed rating-colour key"
      contains: "func jsonThatStillCarriesTheListRatingColourDecodes()"
  key_links:
    - from: "AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift"
      to: "AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift"
      via: "pageCountWithFavoriteHeart: HStack(spacing: 8) of pageCountOrDownloadBadge then GalleryFavoriteHeart, used by both branches of pageCountAndLanguageArrangement"
      pattern: "GalleryFavoriteHeart\\(gallery: gallery\\)"
    - from: "AppPackage/Sources/DetailFeature/DetailView+Subviews.swift"
      to: "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings"
      via: "the generated LocalizedStringResource symbol .editRating of key edit_rating"
      pattern: "\\? \\.editRating : \\.rateGallery"
    - from: "AppPackage/Sources/DetailFeature/DetailView+Subviews.swift"
      to: "AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift"
      via: "galleryDetail.userRating, replaced by fetchGalleryDetailDone after rateGalleryDone's success refetches the page (anyGalleryOpsDone)"
      pattern: "galleryDetail\\.userRating > 0"
---

<objective>
Apply the owner's Screens v1.1.0 design to `port/462` (owner items 4 to 9): grey favorite hearts (and the grid heart
on the page-count line), stars without the user-rating colour in lists, grids and the facts strip (with the now-dead
list-side rating colour removed from the model, parser and reducer), an Edit Rating label once the site has the
user's rating, and the Read ring's 2.5-pt stroke. Items 7 and 9 are verified unchanged.

Purpose: the list says only "a favorite" and "the average"; the user's own rating and the folder colour live on the
detail page, as the design specifies.
Output: four signed commits on `port/462` and `261121-ovv-SUMMARY.md` (not committed).
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@AGENTS.md
@.swiftlint.yml
@.planning/quick/261113-h72-port-462-dyphire-part-1/261113-h72-SUMMARY-part2.md
@AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift
@AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
@AppPackage/Sources/DetailFeature/DetailView+Subviews.swift

### Execution fidelity

Follow this plan exactly. If anything cannot be done exactly as written (ambiguity, conflicting requirements, missing
information, unexpected repository state, a lint rule or compiler error that forces a different shape, a test that
fails, a gate that prints anything but its EXPECT value, or any deviation at all), stop immediately and ask the
orchestrator. Do not choose, invent or implement a solution on your own. The only latitude this plan grants is
re-wrapping the comment prose it gives so every line stays within 120 columns (the wording is fixed), and the known
FavoritesFeatureTests flake rule under TEST.

### Where you work

- Only the linked worktree that is the current directory (branch `port/462`, HEAD `7268c40bc` when this plan was
  written; develop's tip is `02373e7db`). Every path is relative to it. The main checkout at `$HOME/Fork/EhPanda` holds
  another session's uncommitted work: never read it, write it, build in it or run git against it. The one exception
  is reading `$HOME/Fork/EhPanda/AGENTS.local.md` (read-only) to unlock gpg if a commit fails because the gpg cache
  expired.
- Never edit the design repository; this plan carries every design value you need.
- Never use bare `git stash`. Never push. Do not commit this PLAN, the SUMMARY or STATE.md (the orchestrator does).
- Scratch: `.capture/ovv/` for logs and scripts; derived data `.capture/dd-port-462` (both under the gitignored
  `/.capture/`). Generated docs carry no absolute home paths (write `$HOME/...` or repo-relative) and name no other
  local project.
- Code comments you write use roles and dates ("design decision, 2026-11-21"), never agent names or message IDs.

### Settled facts this plan relies on (checked by the planner against the tree and the boards)

- Board `GalleryThumbnailCell.dc.html`: the heart sits inside the count group after the badge or page count, 8 apart,
  and inherits the stats line's `.footnote` and secondary colour; board `GalleryFavoriteHeart.dc.html`: the heart is
  secondary and has no font of its own. So the grid heart takes the line's font and style and gets no `.font` of its
  own. A nested `.foregroundStyle(.secondary)` inside the line's `.secondary` does not compound (measured: both resolve
  to the same grey).
- `Gallery` decodes through a handwritten `init(from:)` over a private `CodingKeys` enum; a keyed container ignores
  keys that are not in the enum, so JSON that still has `userRatingTint` keeps decoding once the case is removed.
- `Parser.ThumbnailPanelInfo.userRatingTint` (in `Parser+Types.swift`) only feeds `Gallery.userRatingTint`, so it goes
  too; `Parser.RatingResult.userRatingTint` feeds the detail parser and stays.
- "Rated" for the Edit Rating label is `galleryDetail.userRating > 0`: the site's own page value. A drag across the
  stars changes only `DetailReducer.State.userRating` (the row's value); `galleryDetail` is replaced only by
  `fetchGalleryDetailDone`, which `anyGalleryOpsDone` triggers after `rateGalleryDone` succeeds. `ActionSection`
  already receives `galleryDetail`, so no new parameter is needed. `DetailView` passes `store.galleryDetail ?? .empty`.
- The VisualSnapshotTests scenario `gallery-detail-rating` sets `state.userRating = 7` with
  `galleryDetail.userRating: 0`, so it keeps reading Rate Gallery and its `.wholeLabel(String(localized: .rateGallery))`
  reveal step keeps working. `GalleryDetail.preview` has `userRating: 4.0`, which is why the previews below set the
  site rating explicitly.
- The DetailFeature catalog is not key-sorted; `rate_gallery` occupies lines 86 to 126 (line 126 is `    },`, line 127
  is `    "rename_folder": {`), and the file has no trailing newline.

### Reference shapes (exact code the tasks point to)

S1, the whole of `GalleryFavoriteHeart.swift` after Task 1:

```swift
public import AppModels
import SFSafeSymbols
public import SwiftUI

/// The filled heart a list row or grid cell shows for a gallery in the user's favorites, in the secondary colour of
/// the page count beside it: it says only that the gallery is a favorite. The slot's colour stays on the detail
/// page's favorite button (design decision, 2026-11-21). Nothing is drawn for a gallery that is not a favorite.
///
/// The heart has no font of its own: each cell gives it the `.footnote` of the line it sits on.
///
/// The heart carries the favorited state to VoiceOver, so it is a labelled element rather than decoration.
public struct GalleryFavoriteHeart: View {
    private let gallery: Gallery

    public init(gallery: Gallery) {
        self.gallery = gallery
    }

    public var body: some View {
        if gallery.isFavorite {
            Image(systemSymbol: .heartFill)
                .foregroundStyle(.secondary)
                .accessibilityLabel(.favorited)
        }
    }
}
```

S2, the grid cell's rating statement in `body` after Task 1 (identical to develop `02373e7db`):

```swift
                if showsRating {
                    rating
                        .accessibilityIdentifier("gallery-grid-rating-\(gallery.id)")
                }
```

S3, the grid cell's new property, inserted directly above `@ContentBuilder private var pageCountOrDownloadBadge`:

```swift
    /// A favorite's heart follows the page count (or download badge), 8 apart, in the line's own font and style
    /// (design decision, 2026-11-21). A cell that is not a favorite is exactly the page count, as before.
    @ContentBuilder private var pageCountWithFavoriteHeart: some View {
        if gallery.isFavorite {
            HStack(spacing: 8) {
                pageCountOrDownloadBadge
                GalleryFavoriteHeart(gallery: gallery)
            }
        } else {
            pageCountOrDownloadBadge
        }
    }

```

S4, `ActionSection`'s title property, inserted directly after the closing brace of `isRatingEnabled` (one blank line
before it):

```swift
    /// Edit Rating once the site has the user's rating, Rate Gallery before (design decision, 2026-11-21). The
    /// label reads the fetched page, not the row's `userRating`: a drag across the stars moves only the row's value,
    /// so a first rating turns it into Edit Rating once the site has accepted it and the page has been fetched again,
    /// never mid-gesture.
    private var ratingButtonTitle: LocalizedStringResource {
        galleryDetail.userRating > 0 ? .editRating : .rateGallery
    }
```

S5, the preview helper and the four previews that replace the current helper and its two previews (everything from
`@MainActor private func previewActionSection` to the closing brace of `#Preview("Actions (rating shown)")`):

```swift
@MainActor private func previewActionSection(
    siteUserRating: Float, userRatingTint: UserRatingTint?, userRating: Int, showUserRating: Bool
) -> some View {
    var galleryDetail = GalleryDetail.preview
    galleryDetail.userRating = siteUserRating
    galleryDetail.userRatingTint = userRatingTint
    return ActionSection(
        galleryDetail: galleryDetail,
        userRating: userRating,
        showUserRating: showUserRating,
        showUserRatingAction: {},
        updateRatingAction: { _ in },
        confirmRatingAction: { _ in },
        findSimilarAction: {}
    )
}

#Preview("Actions") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(siteUserRating: 0, userRatingTint: nil, userRating: 0, showUserRating: false)
    }
}

#Preview("Actions (rating shown)") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(siteUserRating: 0, userRatingTint: nil, userRating: 7, showUserRating: true)
    }
}

#Preview("Actions (rated)") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(siteUserRating: 3.5, userRatingTint: .green, userRating: 7, showUserRating: false)
    }
}

#Preview("Actions (rated, rating shown)") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(siteUserRating: 3.5, userRatingTint: .green, userRating: 7, showUserRating: true)
    }
}
```

S6, the 41 catalog lines inserted after line 126 (values written by the orchestrator; literal characters, never
`\u` escapes):

```json
    "edit_rating": {
      "extractionState": "manual",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Edit Rating"
          }
        },
        "de": {
          "stringUnit": {
            "state": "translated",
            "value": "Bewertung ändern"
          }
        },
        "ja": {
          "stringUnit": {
            "state": "translated",
            "value": "評価を変更"
          }
        },
        "ko": {
          "stringUnit": {
            "state": "translated",
            "value": "별점 수정"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "修改评分"
          }
        },
        "zh-Hant": {
          "stringUnit": {
            "state": "translated",
            "value": "修改評分"
          }
        }
      }
    },
```

S7, the test that replaces the two rating-colour tests in `GalleryStatusFieldsTests.swift`:

```swift
    // Builds that kept the list's rating colour wrote it into the JSON. The model has no such key any more, so it is
    // ignored and the rest decodes (design decision, 2026-11-21).
    @Test
    func jsonThatStillCarriesTheListRatingColourDecodes() throws {
        var rated = Gallery.preview
        rated.hasRated = true
        var old = try object(of: rated)
        old["userRatingTint"] = "blue"
        let gallery = try decode(old)
        #expect(gallery.hasRated)
        #expect(gallery.title == Gallery.preview.title)
    }
```

### Verification conventions (used by every task)

- Shorthands (define them in every shell you run a gate in):
  `HRT=AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift`,
  `THC=AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift`,
  `DTC=AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift`,
  `SUB=AppPackage/Sources/DetailFeature/DetailView+Subviews.swift`,
  `HDR=AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift`,
  `CAT=AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings`, `S=AppPackage/Sources`, `T=AppPackage/Tests`,
  and the executable-line counter `ex() { grep -v '^[[:space:]]*//' "$2" | grep -cF -- "$1"; }` (comment and doc-comment
  lines excluded, fixed-string match), with `set -o pipefail` on so a failing `git` inside a pipeline is seen. A counting gate is judged by the number it
  prints (`grep -c` prints 0 and exits 1 when nothing matches, which is the expected outcome of a `EXPECT==0` gate); a
  `git` error message anywhere in a gate's output means the gate failed. Gate baselines are written `[HEAD=<value at 7268c40bc> EXPECT<op><value>]`.
  Run each task's gates after its edits and before its COMMIT, except the signature check, which runs after it. A
  task's gates are checked at that task only (later tasks legitimately change some counts).
- BASELINE (once, at the start of Task 1, before any edit; the first build is long, run it in the background and wait
  for it): `mkdir -p .capture/ovv && xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath .capture/dd-port-462 > .capture/ovv/build-baseline.log 2>&1`;
  then `grep -q '\*\* BUILD SUCCEEDED \*\*' .capture/ovv/build-baseline.log && grep -E ': (warning|error): ' .capture/ovv/build-baseline.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u > .capture/ovv/warnings-baseline.txt`.
  Then the SwiftLint binary of the build's plug-in:
  `SWIFTLINT="$(find "$PWD/.capture/dd-port-462/SourcePackages/artifacts" -path '*SwiftLintBinary.artifactbundle/macos/swiftlint' -type f | head -1)"`
  (stop and ask if it is empty), and the lint baseline over every directory this plan touches:
  `for d in $S/GalleryListComponents $S/AppModels $S/ParserFeature $S/NetworkingFeature $S/DetailFeature $T/AppModelsTests $T/ParserFeatureTests $T/DownloadsFeatureTests $T/GalleryListComponentsTests; do (cd "$d" && "$SWIFTLINT" lint --quiet) || echo "LINT FAILED $d"; done > .capture/ovv/lint-baseline.txt 2>&1`,
  which must be empty. Record the baseline warning count (`wc -l < .capture/ovv/warnings-baseline.txt`) and the lint
  result in the SUMMARY. If the baseline build fails or the lint baseline is not empty, stop and report (the
  orchestrator resolved rebase conflicts in HeaderSectionActionSpacingTests, ReduceMotionGatingSourceTests and
  DetailView+HeaderSection.swift).
- BUILD (task N): the baseline build command into `.capture/ovv/build-taskN.log`; it must print
  `** BUILD SUCCEEDED **`, and
  `grep -E ': (warning|error): ' .capture/ovv/build-taskN.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u | comm -13 .capture/ovv/warnings-baseline.txt - > .capture/ovv/new-warnings-taskN.txt; test ! -s .capture/ovv/new-warnings-taskN.txt`
  must succeed (no warning or error the baseline did not have).
- LINT (task N): the lint loop above, limited to the directories the task names, into `.capture/ovv/lint-taskN.txt`;
  the file must be empty. (The build log can lose plug-in lint output, so the direct run is the lint gate.)
- TEST (Tasks 2 and 4 only): one test invocation on the machine at a time. Before starting, `pgrep -x xcodebuild` and
  `pgrep -x xctest` must both print nothing; if either prints a pid, another session's run is in flight: wait for it
  to end (re-check every few minutes) and never kill anything. The simulator is this project's `EhPanda iPhone Air`,
  id B2A29E3D-244F-42EC-B015-0E4F7B60E329. The command:
  `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=B2A29E3D-244F-42EC-B015-0E4F7B60E329' -derivedDataPath .capture/dd-port-462 -collect-test-diagnostics never -skip-testing:VisualSnapshotTests -resultBundlePath .capture/ovv/<name>.xcresult > .capture/ovv/<name>.log 2>&1`
  plus the `-only-testing:` filters the task names, if any. Then
  `grep -E 'Test run with [0-9]+ tests|\*\* TEST (SUCCEEDED|FAILED) \*\*' .capture/ovv/<name>.log` and
  `xcrun xcresulttool get test-results summary --path .capture/ovv/<name>.xcresult`: read the per-bundle counts and
  report any failure verbatim. A known flake exists in FavoritesFeatureTests (LoginReturnObservationTests) under full
  load: if that is the only failure, re-run the same command with `-only-testing:FavoritesFeatureTests` into
  `<name>-favorites`; it must pass. Any other failure: stop and ask.
- COMMIT (task N): `git add -- <exactly the task's files>` (Task 2 stages its deleted file with `git rm --`);
  `git diff --cached --name-only | sort` must list exactly those files; `TZ=Asia/Shanghai git commit -m "<the task's message>"`
  as the configured identity with its GPG key (signing is on in the repository config; never pass `--no-verify` or
  `--no-gpg-sign`, never bypass a hook). Then `git log -1 --format='%G? %aI %cI'` must print `G` and two dates ending
  `+08:00`. If the commit fails because gpg's cache has expired, follow the unlock steps in
  `$HOME/Fork/EhPanda/AGENTS.local.md` and retry the same command. Messages carry no attribution lines.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Grey favorite hearts, and the grid heart on the page-count line (Owner item 4)</name>
  <files>AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift, AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift</files>
  <read_first>
    - AGENTS.md (whole) and .swiftlint.yml (`sorted_imports`, `line_length` 120 and `multiline_function_chains` are errors)
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift (whole)
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift (whole)
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift (`pageCountWithFavoriteHeart`, the list row's pattern; NOT edited)
  </read_first>
  <action>
    First run BASELINE (see Verification conventions) on the untouched tree and stop if it is not clean.

    1. `GalleryFavoriteHeart.swift`: make the file read exactly as shape S1. That drops the AppTools import (the
       slot-colour palette was its only use), replaces the slot-colour expression in `.foregroundStyle(...)` with
       `.secondary`, and rewrites the doc comment (the heart says only "a favorite"; the slot's colour stays on the
       detail page's favorite button; no font of its own). If the build then reports a symbol missing from this file,
       stop and ask.
    2. `GalleryThumbnailCell.swift`, `body`: replace the whole favorite-aware rating statement (the 15 lines that start
       at `if gallery.isFavorite {` inside the text column's VStack, including its one-line comment about the heart
       trailing the rating, its inner HStack, Spacer and caption-sized heart, and its `else if` branch) with shape S2,
       develop's statement verbatim (`git show 02373e7db:AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift`
       shows it at the same place).
    3. Same file: insert shape S3 (`pageCountWithFavoriteHeart`) directly above `@ContentBuilder private var
       pageCountOrDownloadBadge`, after the `languageText` property and its blank line. Then, in
       `pageCountAndLanguageArrangement`, replace `pageCountOrDownloadBadge` with `pageCountWithFavoriteHeart` in both
       branches (the `HStack(spacing: 10)` one keeps its `.frame(maxWidth: .infinity, alignment: .leading)` on the new
       name; the `AdaptiveStack` one is the bare name). The heart gets no `.font` here: `pageCountAndLanguage` already
       applies `.font(.footnote)` and `.foregroundStyle(.secondary)` to the whole line, as the board does.
    4. Same file: in the doc comment of `pageCountAndLanguage`, change only its first line to
       `/// The cell's stat group, spread across it: page count (or the download badge) and a favorite's heart leading,`
       (the second line, starting `/// language trailing.`, and the rest stay).
    5. `GalleryDetailCell.swift` is not edited: its heart already precedes the count in an `HStack(spacing: 8)` with
       `.font(.footnote)`, and its colour now comes from the heart itself.

    Then BUILD, LINT (directory `AppPackage/Sources/GalleryListComponents`) and COMMIT with the message
    "lists: grey favorite hearts on the count line". There is no unit test for this task (no test renders the heart).
  </action>
  <verify>
    <automated>BASELINE, BUILD and LINT with N=1 pass. Gates (with the shorthands): `ex '.foregroundStyle(.secondary)' $HRT` prints 1 [HEAD=0 EXPECT==1]; `ex 'FavoriteColor' $HRT` prints 0 [HEAD=1 EXPECT==0]; `ex 'accentColor' $HRT` prints 0 [HEAD=1 EXPECT==0]; `ex 'import AppTools' $HRT` prints 0 [HEAD=1 EXPECT==0]; `ex '.accessibilityLabel(.favorited)' $HRT` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: dropping the heart's VoiceOver label]; `ex 'pageCountWithFavoriteHeart' $THC` prints 3 [HEAD=0 EXPECT==3]; `ex 'HStack(spacing: 8)' $THC` prints 1 [HEAD=0 EXPECT==1]; `ex 'HStack(spacing: 6)' $THC` prints 0 [HEAD=1 EXPECT==0]; `ex 'Spacer(minLength: 0)' $THC` prints 0 [HEAD=1 EXPECT==0]; `ex '.font(.caption)' $THC` prints 1 [HEAD=2 EXPECT==1]; `ex 'if showsRating {' $THC` prints 1 [HEAD=2 EXPECT==1]; `ex 'gallery-grid-rating-' $THC` prints 1 [HEAD=2 EXPECT==1]; `ex 'GalleryFavoriteHeart(gallery: gallery)' $THC` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: losing or duplicating the grid heart]; `ex 'if gallery.isFavorite {' $THC` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: drawing the heart group for a cell that is not a favorite]; `ex 'pageCountOrDownloadBadge' $THC` prints 3 [HEAD=3 EXPECT==3 GUARD MUTATION: leaving a bare count use in the arrangement]; `git diff --quiet -- $DTC` exits 0 [HEAD=0 EXPECT==0 GUARD MUTATION: any edit to the list row]; `git diff --cached --name-only` before the commit lists exactly $HRT and $THC; after the commit `git log -1 --format='%G? %aI %cI'` prints G and two +08:00 dates.</automated>
  </verify>
  <done>Every favorite's heart is secondary whatever its folder; the grid shows it after the count or badge on the count line, 8 apart, in the line's footnote; the grid rating line is develop's again; the list row is byte-identical; build has no new warning, lint is empty, and the signed +08:00 commit "lists: grey favorite hearts on the count line" exists.</done>
</task>

<task type="auto">
  <name>Task 2: Plain stars everywhere outside the rating row, and removal of the dead list rating colour (Owner item 5)</name>
  <files>AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift, AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift, AppPackage/Sources/DetailFeature/DetailView+Subviews.swift, AppPackage/Sources/AppModels/Gallery/Gallery.swift, AppPackage/Sources/AppModels/Gallery/UserRatingTint.swift, AppPackage/Sources/ParserFeature/Parser+Types.swift, AppPackage/Sources/ParserFeature/Parser+List.swift, AppPackage/Sources/NetworkingFeature/Request+Detail.swift, AppPackage/Sources/DetailFeature/DetailReducer.swift, AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift, AppPackage/Tests/AppModelsTests/GalleryStatusFieldsTests.swift, AppPackage/Tests/ParserFeatureTests/List/GalleryStatusParserTests.swift, AppPackage/Tests/DownloadsFeatureTests/DetailFavoriteStateTests.swift, AppPackage/Tests/GalleryListComponentsTests/GalleryRatingTintRenderTests.swift (deleted)</files>
  <read_first>
    - AppPackage/Sources/AppModels/Gallery/Gallery.swift (lines 95 to 205: properties, CodingKeys, both inits)
    - AppPackage/Sources/AppModels/Gallery/UserRatingTint.swift (the doc comment of `color`)
    - AppPackage/Sources/ParserFeature/Parser+Types.swift (ThumbnailPanelInfo; RatingResult stays)
    - AppPackage/Sources/ParserFeature/Parser+List.swift (the four `Gallery(...)` builders and `parseThumbnailPanel`)
    - AppPackage/Sources/DetailFeature/DetailReducer.swift (`applyFavoriteState`), DetailReducer+Fetch.swift (`rateGalleryDone`)
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift (`item(for:)`, `DescScrollRatingItem`)
    - The four test files listed in files
  </read_first>
  <action>
    Removals and comment rewrites only; nothing else changes. Everything named KEEP below must stay byte-identical:
    `UserRatingTint` and its colours, `GalleryDetail.userRatingTint`, `Parser.RatingResult.userRatingTint`, the star-class
    parsing in `Parser+Shared.swift`, `Parser+Detail.swift`, `Gallery.hasRated` and every place that sets it,
    `UserRatingTintColorTests.swift` (not list-specific) and `GalleryDetailParserTests.swift`.

    Views:
    1. `GalleryDetailCell.swift`, `ratingAndPageCount`: delete the one-line comment above `RatingView(rating: gallery.rating)`
       (it says the user's own rating draws the stars in the site's colour) and the `.foregroundStyle(...)` line that
       reads the gallery's rating colour. The block then matches develop.
    2. `GalleryThumbnailCell.swift`, `rating`: delete the same one-line comment and the same `.foregroundStyle(...)`
       line after `.font(.caption)`. The property then matches develop.
    3. `DetailView+Subviews.swift`: revert `DescScrollRatingItem` to develop (`git show 02373e7db:AppPackage/Sources/DetailFeature/DetailView+Subviews.swift`):
       the call in `item(for:)` becomes `DescScrollRatingItem(title: info.title, rating: info.rating)`; delete the
       struct's two-line stored colour property (its `///` line and the `let`), and the `.foregroundStyle(...)` line
       under its `RatingView(rating: rating)`. Do not touch `ActionSection` (its open row keeps the colour).

    Model, parser, request, reducer:
    4. `Gallery.swift`: delete the stored colour property with its two `///` lines (the ones about `irr`, `irg`,
       `irb`); remove `userRatingTint` from the third `case` line of `CodingKeys`, which becomes
       `case isExpunged, hasRated, favoriteTagIndex, favoriteTagName`; delete its `decodeIfPresent` line in
       `init(from:)`; delete its parameter from the memberwise `init` and its `self.` assignment. Keep the comment above
       `CodingKeys` as it is.
    5. `UserRatingTint.swift`: replace the first sentence of the doc comment of `color` (the one that ends with an
       agent name and message ID) so the comment reads, in full:
       `/// The colour the stars of this rating are drawn in, in the detail page's open rating row, the one place the`
       `/// user's own rating shows (design decision, 2026-11-21). The system's plain colours are too light on the white`
       `/// light-mode row (`.green` is about 2.2:1), so light mode takes darker values; dark mode takes the system's dark`
       `/// ones.` The type's own doc comment and all code stay.
    6. `Parser+Types.swift`: in `ThumbnailPanelInfo` delete the colour property and its `///` line (the two lines after
       `hasRated`). `RatingResult` is KEEP.
    7. `Parser+List.swift`: delete the four `userRatingTint: panelInfo.userRatingTint,` argument lines (one per
       `Gallery(...)` builder) and the `userRatingTint:` argument line of the `ThumbnailPanelInfo(...)` call in
       `parseThumbnailPanel`. The `hasRated:` lines stay.
    8. `Request+Detail.swift`, `getGallery(from:and:)`: delete the `userRatingTint: detail.userRatingTint,` argument;
       `hasRated: detail.userRating > 0,` stays.
    9. `DetailReducer.swift`, `applyFavoriteState(from:)`: delete its last line, the copy of the detail's colour onto
       `gallery`; `gallery.hasRated = detail.userRating > 0` stays and the doc comment stays.
    10. `DetailReducer+Fetch.swift`: the two-line comment above `case .rateGalleryDone(let result):` names a star colour
        that no longer exists; replace it with
        `// A gesture the site accepted is applied at once (the favorite button's colour, the rated mark); the`
        `// detail page the success then refetches confirms it.` (same indentation). No code changes in this file.

    Tests:
    11. `git rm -- AppPackage/Tests/GalleryListComponentsTests/GalleryRatingTintRenderTests.swift` (it pins the removed
        list colour; nothing else uses its private helpers).
    12. `GalleryStatusParserTests.swift`: delete the test `aRatedRowCarriesTheColourOfItsStarClass` with the two comment
        lines above its `@Test`; delete the test `everyUserRatingClassGivesTheRowItsColour` (its `@Test(arguments:...)`
        line through its closing brace); in `pagesWithNothingToMarkMarkNothing` and in
        `thePlainAverageStarClassIsNotARating` delete the one `#expect` line each that reads the row's colour. Keep one
        blank line between the remaining tests.
    13. `GalleryStatusFieldsTests.swift`: in `theMarksRoundTrip` delete the line that sets the colour and the `#expect`
        that reads it back; replace the test `jsonWrittenBeforeTheRatingColourExistedStillDecodes` (with its two comment
        lines) by shape S7, in the same place; delete the test `aRatingColourTheModelDoesNotKnowIsRejected` (its
        `@Test` line through its closing brace and the blank line after it).
    14. `DetailFavoriteStateTests.swift`: delete the four lines that set or expect a colour: the `detail.` assignment
        of `.green` and the `#expect` on `store.state.gallery` against `.green` in
        `aFetchedFavoriteDetailGivesTheGalleryItsSlotAndItsRating`, and the `detail.` assignment of `nil` and the
        `#expect` against `nil` in `aFetchedDetailThatNoLongerSaysFavoriteClearsAStaleSlot`.

    Then BUILD, LINT (directories `$S/GalleryListComponents $S/AppModels $S/ParserFeature $S/NetworkingFeature
    $S/DetailFeature $T/AppModelsTests $T/ParserFeatureTests $T/DownloadsFeatureTests $T/GalleryListComponentsTests`),
    TEST with name `task2` and `-only-testing:AppModelsTests -only-testing:ParserFeatureTests
    -only-testing:DownloadsFeatureTests -only-testing:GalleryListComponentsTests -only-testing:NetworkingFeatureTests
    -only-testing:DetailFeatureTests`, and COMMIT with the message "lists, detail: stars in the plain colour" (the 13
    edited files plus the deletion).
  </action>
  <verify>
    <automated>BUILD and LINT with N=2 pass; TEST `task2` passes with 0 failures, and `grep -E ': (warning|error): ' .capture/ovv/task2.log | grep -E 'GalleryStatusFieldsTests|GalleryStatusParserTests|DetailFavoriteStateTests'` prints nothing. Gates: `git grep -l 'userRatingTint' -- $S | wc -l` prints 5 [HEAD=11 EXPECT==5], and the five paths `git grep -l 'userRatingTint' -- $S | sort` lists are exactly `AppPackage/Sources/AppModels/Gallery/GalleryDetail.swift`, `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift`, `AppPackage/Sources/ParserFeature/Parser+Detail.swift`, `AppPackage/Sources/ParserFeature/Parser+Shared.swift`, `AppPackage/Sources/ParserFeature/Parser+Types.swift`; `grep -c 'userRatingTint' $SUB` prints 1 [HEAD=4 EXPECT==1]; `grep -c 'userRatingTint' $S/ParserFeature/Parser+Types.swift` prints 1 [HEAD=2 EXPECT==1]; `grep -c 'RatingTint' $S/AppModels/Gallery/Gallery.swift` prints 0 [HEAD=5 EXPECT==0]; `ex 'hasRated' $S/AppModels/Gallery/Gallery.swift` prints 5 [HEAD=5 EXPECT==5 GUARD MUTATION: removing hasRated with the colour]; `ex 'hasRated: panelInfo.hasRated,' $S/ParserFeature/Parser+List.swift` prints 4 [HEAD=4 EXPECT==4 GUARD MUTATION: deleting a hasRated argument with its neighbour]; `ex 'hasRated: detail.userRating > 0,' $S/NetworkingFeature/Request+Detail.swift` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: deleting the hasRated argument]; `ex 'gallery.hasRated = detail.userRating > 0' $S/DetailFeature/DetailReducer.swift` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: deleting the rated copy with the colour copy]; `ex 'state.gallery.hasRated = true' $S/DetailFeature/DetailReducer+Fetch.swift` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: editing code under the rewritten comment]; `grep -c "stars'" $S/DetailFeature/DetailReducer+Fetch.swift` prints 0 [HEAD=1 EXPECT==0]; `grep -c 'msg 5212' $S/AppModels/Gallery/UserRatingTint.swift` prints 0 [HEAD=1 EXPECT==0]; `git diff --numstat 02373e7db -- $SUB | cut -f1` prints 3 [HEAD=7 EXPECT==3]; `git diff --numstat 02373e7db -- $SUB | cut -f2` prints 0 [HEAD=1 EXPECT==0]; `git diff --numstat 02373e7db -- $DTC | cut -f1` prints 16 [HEAD=18 EXPECT==16]; `git diff --numstat 02373e7db -- $DTC | cut -f2` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: deleting a develop line of the list row]; `git diff 02373e7db -- $THC | grep -c 'RatingTint'` prints 0 [HEAD=1 EXPECT==0]; `test -e $T/GalleryListComponentsTests/GalleryRatingTintRenderTests.swift` fails [HEAD=present EXPECT==absent]; `git grep -l 'userRatingTint' -- $T | wc -l` prints 2 [HEAD=5 EXPECT==2], and those two are `AppPackage/Tests/AppModelsTests/GalleryStatusFieldsTests.swift` and `AppPackage/Tests/ParserFeatureTests/Gallery/GalleryDetailParserTests.swift`; `grep -c 'RatingTint' $T/AppModelsTests/GalleryStatusFieldsTests.swift` prints 1 [HEAD=5 EXPECT==1]; `grep -c 'RatingTint' $T/ParserFeatureTests/List/GalleryStatusParserTests.swift` prints 0 [HEAD=7 EXPECT==0]; `grep -c 'RatingTint' $T/DownloadsFeatureTests/DetailFavoriteStateTests.swift` prints 0 [HEAD=4 EXPECT==0]; `grep -c '@Test' $T/ParserFeatureTests/List/GalleryStatusParserTests.swift` prints 8 [HEAD=10 EXPECT==8]; `grep -c '@Test' $T/AppModelsTests/GalleryStatusFieldsTests.swift` prints 6 [HEAD=7 EXPECT==6]; `git diff --quiet 7268c40bc -- $T/AppModelsTests/UserRatingTintColorTests.swift $T/ParserFeatureTests/Gallery/GalleryDetailParserTests.swift $S/ParserFeature/Parser+Shared.swift $S/ParserFeature/Parser+Detail.swift $S/AppModels/Gallery/GalleryDetail.swift` exits 0 [HEAD=0 EXPECT==0 GUARD MUTATION: any edit to a KEEP file]; the staged list is exactly the 14 paths in files; after the commit the signature check prints G and two +08:00 dates.</automated>
  </verify>
  <done>No list row, grid cell or facts-strip star carries a user-rating colour; Gallery, ThumbnailPanelInfo, the list parser, Request+Detail and DetailReducer no longer carry the list colour while the detail page's colour and everything KEEP is untouched; old Gallery JSON with the key decodes (pinned by the new test); the affected test targets pass; the signed +08:00 commit "lists, detail: stars in the plain colour" exists.</done>
</task>

<task type="auto">
  <name>Task 3: Edit Rating once the site has the user's rating (Owner item 6)</name>
  <files>AppPackage/Sources/DetailFeature/DetailView+Subviews.swift, AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings</files>
  <read_first>
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift (`ActionSection` through the end of its previews)
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings (lines 80 to 130 only: the `rate_gallery` entry)
  </read_first>
  <action>
    1. Catalog (per the orchestrator's targeted-script rule; never rewrite the file with json.dump and never use the
       Write or Edit tool on the catalog): write `.capture/ovv/insert_edit_rating.py` that reads `$CAT` as UTF-8,
       splits it on `\n`, asserts that line 86 is `    "rate_gallery": {`, line 126 is `    },`, line 127 is
       `    "rename_folder": {` and that `"edit_rating"` occurs nowhere, inserts the 41 lines of shape S6 (held in the
       script as literal characters, no `\u` escapes) after line 126, joins with `\n` (the file keeps having no trailing
       newline) and writes it back as UTF-8. Run it with `python3 -I .capture/ovv/insert_edit_rating.py`. After writing
       the script, grep it for the six values to confirm the non-ASCII characters landed literally.
    2. `ActionSection`: insert shape S4 (`ratingButtonTitle`) after `isRatingEnabled`, and change the Rate Gallery
       button's title from the fixed `.rateGallery` resource to `Text(ratingButtonTitle)` (keep `.bold()` and the
       icon). The source of "rated" is `galleryDetail.userRating`, never the row's `userRating` (see Settled facts).
    3. The open rating row keeps `galleryDetail.userRatingTint` exactly as it is; add, as the first line inside that
       row's `HStack {` (above `RatingView(rating: Float(userRating) / 2)`, at its indentation), the two-line comment
       `// The user's own rating shows here and nowhere else, in the site's colour for it`
       `// (design decision, 2026-11-21).`
    4. Replace the preview helper and its two previews with shape S5 (four previews: unrated, unrated with the row open,
       rated, rated with the row open in green).

    Then BUILD, LINT (directory `AppPackage/Sources/DetailFeature`) and COMMIT with the message
    "detail: Edit Rating once the gallery is rated". (Its UI has no unit test; Task 4's full run compiles and runs
    every target.)
  </action>
  <verify>
    <automated>BUILD and LINT with N=3 pass. Gates: `git diff --numstat -- $CAT | cut -f1` prints 41 [HEAD=absent EXPECT==41]; `git diff --numstat -- $CAT | cut -f2` prints 0 [HEAD=absent EXPECT==0]; `python3 -I -c 'import json; d=json.load(open("AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings", encoding="utf-8"))["strings"]; k=list(d); e=d["edit_rating"]; v={l: u["stringUnit"]["value"] for l, u in e["localizations"].items()}; s={u["stringUnit"]["state"] for u in e["localizations"].values()}; assert k.index("edit_rating") - k.index("rate_gallery") == 1 and e["extractionState"] == "manual" and s == {"translated"} and v == {"en": "Edit Rating", "de": "Bewertung ändern", "ja": "評価を変更", "ko": "별점 수정", "zh-Hans": "修改评分", "zh-Hant": "修改評分"}; print("ok")'` prints ok and exits 0 [HEAD=error:1 EXPECT==present]; `ex 'private var ratingButtonTitle: LocalizedStringResource' $SUB` prints 1 [HEAD=0 EXPECT==1]; `ex 'galleryDetail.userRating > 0 ? .editRating : .rateGallery' $SUB` prints 1 [HEAD=0 EXPECT==1]; `ex 'Text(ratingButtonTitle)' $SUB` prints 1 [HEAD=0 EXPECT==1]; `ex '.rateGallery' $SUB` prints 1, now the ternary's [HEAD=1 EXPECT==1 GUARD MUTATION: losing the Rate Gallery label]; `ex 'galleryDetail.userRatingTint.map(' $SUB` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: removing the open row's colour]; `grep -c 'shows here and nowhere else' $SUB` prints 1 [HEAD=0 EXPECT==1]; `ex 'previewActionSection(' $SUB` prints 5 [HEAD=3 EXPECT==5]; `ex '#Preview("Actions' $SUB` prints 4 [HEAD=2 EXPECT==4]; `ex 'siteUserRating: 3.5, userRatingTint: .green' $SUB` prints 2 [HEAD=0 EXPECT==2]; the staged list is exactly $SUB and $CAT; after the commit the signature check prints G and two +08:00 dates.</automated>
  </verify>
  <done>The rating button reads Edit Rating once the fetched page has the user's rating and Rate Gallery before, with the same toggle action; the open row keeps the site's colour; edit_rating ships natively in six locales beside rate_gallery as a 41-line insertion; previews show both labels; the signed +08:00 commit "detail: Edit Rating once the gallery is rated" exists.</done>
</task>

<task type="auto">
  <name>Task 4: The Read ring's 2.5-pt stroke, the full test run, and items 7 and 9 checked (Owner items 7, 8, 9)</name>
  <files>AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift</files>
  <read_first>
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift (lines 55 to 80: the ring metrics; lines 205 to 220: `favoriteColor`)
  </read_first>
  <action>
    1. `DetailView+HeaderSection.swift`: set the default of the Read ring's `@ScaledMetric` stroke to 2.5, so the line
       reads `@ScaledMetric(relativeTo: .callout) private var readRingLineWidth: CGFloat = 2.5`; `readRingInset`
       stays 4. Replace the two comment lines directly above `readRingInset` with
       `// 4pt in from the Read button's edge and 2.5pt thick at default (.large), the download ring's inset and stroke, so`
       `// the two rings match (design decision, 2026-11-21). Both scale with the button, which scales on the same metric,`
       `// so the ring keeps its place at every size.` Nothing else in the file changes.
    2. Item 7 (no code change): the favorite button keeps `favoriteColor`, read from `Defaults.FavoriteColor`.
       Item 9 (no code change): the Favorites site-settings folder dots (`SettingFeature`) stay as they are. The gates
       below confirm both.

    Then BUILD, LINT (directory `AppPackage/Sources/DetailFeature`), TEST with name `task4` and no `-only-testing`
    filter (the whole FeatureTests plan minus VisualSnapshotTests; HeaderSectionActionSpacingTests and
    ReduceMotionGatingSourceTests must pass unchanged; if either fails, stop and ask with its message, do not edit it),
    and COMMIT with the message "detail: the Read ring's stroke is 2.5 pt".
  </action>
  <verify>
    <automated>BUILD and LINT with N=4 pass; TEST `task4` passes with 0 failures (or only the FavoritesFeatureTests flake, re-run alone and passing), per-bundle counts recorded. Gates: `ex 'private var readRingLineWidth: CGFloat = 2.5' $HDR` prints 1 [HEAD=0 EXPECT==1]; `ex 'private var readRingInset: CGFloat = 4' $HDR` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: changing the Read ring's inset]; `ex 'progressRingLineWidth: CGFloat = 2.5' $HDR` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: changing the download ring's stroke]; `grep -q '3pt thick' $HDR` fails [HEAD=present EXPECT==absent]; `git diff -U0 7268c40bc -- $HDR | grep '^[-+][^-+]' | grep -v -e 'readRingLineWidth' -e '^[-+][[:space:]]*//'` prints nothing [HEAD=absent EXPECT==absent GUARD MUTATION: any code change besides the stroke]; item 7: `ex 'Defaults.FavoriteColor.color(at: galleryDetail.favoriteTagIndex ?? gallery.favoriteTagIndex)' $HDR` prints 1 [HEAD=1 EXPECT==1 GUARD MUTATION: dropping the favorite button's slot colour] and `ex 'favoriteColor' $HDR` prints 2 [HEAD=2 EXPECT==2 GUARD MUTATION: un-tinting the favorite button]; item 9: `git diff --quiet 7268c40bc -- $S/SettingFeature $S/AppTools` exits 0 [HEAD=0 EXPECT==0 GUARD MUTATION: any edit to the site-settings dots or the palette]; the staged list is exactly $HDR; after the commit the signature check prints G and two +08:00 dates.</automated>
  </verify>
  <done>The Read ring draws a 2.5-pt stroke 4 pt in, the download ring's geometry; the favorite button and the site-settings folder dots are unchanged; the full FeatureTests plan minus VisualSnapshotTests is green; the signed +08:00 commit "detail: the Read ring's stroke is 2.5 pt" exists.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| site HTML to parser | List and detail pages are untrusted input; this plan only removes a field the list parser derived from them |
| stored JSON to model | `Gallery` JSON written by earlier builds of this branch is decoded again after a key is removed |
| catalog file to build | The string catalog is edited by a script and compiled into generated symbols |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261121-ovv-01 | Tampering | `DetailFeature/Resources/Localizable.xcstrings` edit | medium | mitigate | The script asserts three anchor lines and the key's absence before inserting S6 once; Task 3's gates require `git diff --numstat` of 41 added and 0 deleted lines and a JSON reload that checks key position, extraction state, states and all six values. |
| T-261121-ovv-02 | Denial of service | `Gallery.init(from:)` after the colour key is removed | medium | mitigate | The keyed container ignores keys outside `CodingKeys`; S7 (`jsonThatStillCarriesTheListRatingColourDecodes`) pins that JSON still carrying the key decodes with its other marks. |
| T-261121-ovv-03 | Information disclosure | list hearts no longer show the folder colour | low | accept | The change discloses less than before (only "a favorite"); the folder colour stays on the detail page, behind the user's own navigation. |
| T-261121-ovv-SC | Tampering | npm/pip/cargo installs | low | accept | This plan installs no package and changes no `Package.swift` dependency; nothing to vet. |
</threat_model>

<verification>
- BASELINE once; then BUILD and LINT after every task (no new warning, empty lint), TEST after Tasks 2 and 4 (Task 4:
  the whole FeatureTests plan minus VisualSnapshotTests, 0 failed, per-bundle counts recorded).
- Every gate in the four `<verify>` blocks prints its EXPECT value at its task.
- `git log --format='%G? %aI %cI %s' 7268c40bc..HEAD` lists exactly four commits, each `G` with two +08:00 dates, in
  order: "lists: grey favorite hearts on the count line", "lists, detail: stars in the plain colour",
  "detail: Edit Rating once the gallery is rated", "detail: the Read ring's stroke is 2.5 pt".
- `git status --short` afterwards shows nothing but the untracked plan directory and `.capture/` stays ignored.
- Every touched Swift file is at most 1000 lines (`wc -l`).
</verification>

<success_criteria>
- Hearts are secondary in lists and grids; the grid heart follows the count on its line; the grid rating line is
  develop's; non-favorite cells unchanged (item 4).
- No user-rating colour outside the detail page's open rating row; the dead list colour is gone from model, parser,
  request and reducer, with old JSON still decoding (item 5).
- Edit Rating appears once the site has the user's rating, in six native locales, without flipping mid-drag (item 6).
- The Read ring is 2.5 pt (item 8); favorite button colour and site-settings dots unchanged (items 7, 9).
- `261121-ovv-SUMMARY.md` written with frontmatter `status: complete` and these sections: the four commits (hash,
  message, signature line); the gates (baseline warning count, each task's BUILD/LINT result, the gate outputs, the
  `task2` and `task4` per-bundle test counts); "Open for the owner" with the item-5 finding below; and "Snapshots to
  re-record" as below. It is not committed.
- "Open for the owner" (record verbatim in substance): E-Hentai list pages give only the user's own rating for a
  gallery the user has rated. In every Favorites list fixture
  (`AppPackage/Sources/TestingSupport/Resources/Parser/List/Favorites*List.html`) a rated row has a single star
  element, `class="ir irb" style="background-position:0px -1px"` (the user's 5 stars), and no average anywhere in the
  row. So a rated gallery's list row and grid cell still show the user's own rating, now in the plain colour; the
  design's "always the average" cannot be met from the list page alone. No workaround was built (no detail fetch, no
  hiding); the owner decides. The detail page's facts strip does show the average (`Parser+Detail` reads
  `#rating_label`).
- "Snapshots to re-record": run `git grep -n -E "favoriteTagIndex|favoriteTagName|isFavorited: true|userRating|readingProgress|showsUserRating" -- AppPackage/Tests/VisualSnapshotTests EhPandaUITests AppPackage/Sources/AppFeature/UITestSupport`
  and record the hits. The planner's reading: no VisualSnapshotTests scenario sets a favorite slot, a list rating
  colour, a site-confirmed user rating or reading progress, so none is expected to change; `gallery-detail-rating`
  keeps Rate Gallery and plain stars (`galleryDetail.userRating` is 0, the row's value is 7). The Appshot marketing
  captures `home` and `detail` run on live account data and change only if that account has a favorite in Home (grey
  heart on the count line), a rated gallery (Edit Rating; list stars without colour) or a read gallery (thinner Read
  ring). Do not run or re-record anything.
</success_criteria>

<output>
Create `.planning/quick/261121-ovv-design-v1-1-0-on-port-462-grey-favorite-/261121-ovv-SUMMARY.md` when done
</output>
