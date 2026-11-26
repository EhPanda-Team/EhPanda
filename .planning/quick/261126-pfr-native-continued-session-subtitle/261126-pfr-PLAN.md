---
phase: quick-261126-pfr
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/Resources/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionFoldTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionSubmissionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadProgressSeriesGuardTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
autonomous: true
requirements: [QUICK-261126-pfr]

estimate:
  tokens: 45000
  raw_tokens: 45000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "In every locale the continued-processing card subtitle is a native phrase with no middle dot. For (completed, total, galleries) = (6, 14, 2): en `6 of 14 pages in 2 galleries`, de `6 von 14 Seiten aus 2 Galerien`, ja `全14ページ中6ページ完了（ギャラリー2件）`, ko `총 14페이지 중 6페이지 완료 (갤러리 2개)`, zh-Hans `已下载 6 页，共 14 页（2 个画廊）`, zh-Hant `已下載 6 頁，共 14 頁（2 個畫廊）` (CONTEXT › Final catalog values)."
    - "The key keeps its three substitutions `completed`/`total`/`galleries` with argNum 1/2/3 and `lld`, en/de keep {other} for completed and {one, other} for total and galleries, ja/ko/zh-Hans/zh-Hant stay other-only, so the generated `continuedSessionSubtitle(completed:total:galleries:)` symbol and its callers compile unchanged and the card can still carry integers only."
    - "Only the 14 value lines of the `continued_session.subtitle` entry change in the catalog; nothing else in the file is rewritten (CONTEXT › Editing the catalog)."
    - "Every DownloadsFeatureTests literal and doc comment that quoted the card's English rendering, and the two DownloadClient doc comments that quote it, now quote the new rendering; the only middle dot left under AppPackage/Tests/DownloadsFeatureTests is the out-of-scope historical overlay quote at DownloadRunProgressOverlayTests.swift:14 (CONTEXT › Test literals and comments)."
    - "SwiftLint run directly reports nothing for AppPackage/Sources/DownloadClient and AppPackage/Tests/DownloadsFeatureTests, and DownloadsFeatureTests passes on `EhPanda iPhone Air (middle-dot)` (CONTEXT › Verification)."
    - "The whole change is one signed commit on the current branch with +08:00 author and committer dates, subject at most 50 characters, not pushed (CONTEXT › Commits)."
  artifacts:
    - path: "AppPackage/Sources/Resources/Resources/Localizable.xcstrings"
      provides: "`continued_session.subtitle` with the six locale values and the eight bare `%arg` substitution values from CONTEXT"
      contains: "%#@completed@ of %#@total@ in %#@galleries@"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift"
      provides: "Pinned renderings in the new form, including the two denominator waits on `of 12 pages` and `of 16 pages`"
      contains: "contains(\"of 12 pages\")"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift"
      provides: "Doc comment quoting the stalled card as `0 of N pages in 0 galleries`"
      contains: "0 of N pages in 0 galleries"
  key_links:
    - from: "AppPackage/Sources/Resources/Resources/Localizable.xcstrings"
      to: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionSubtitle.swift"
      via: "generated `.RLocalizable.continuedSessionSubtitle(completed:total:galleries:)`, labels derived from the en (source language) substitution names"
    - from: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionSubtitle.swift"
      to: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
      via: "`BackgroundProcessingClientSpy.progressUpdates[].subtitle` / `startSubtitles` compared against the English rendering"
---

<objective>
Replace the decorative middle dot in the continued-processing card subtitle (`continued_session.subtitle`) with
the native wording CONTEXT locks for each of the six locales, rewrite every test literal and doc comment that pins
the old English rendering, verify, and land it all in one signed commit.

Purpose: the owner's "No decorative middle dots" rule forbids a separator glyph between the card's counts; each
locale now reads the counts as a sentence fragment a native writer would use.

Output: the edited catalog entry, 13 rewritten test files, 2 rewritten source doc comments, one code commit.

Executor contract (owner rule): follow this plan exactly. If anything does not match it, including a catalog line
whose current text differs from the "old" column below, a replacement count that differs from the counts measured
here, a lint finding, a test failure, a build warning in a touched file, or any unexpected repository state, stop
immediately and ask the orchestrator. Do not choose, invent or apply a fix or deviation on your own. Do not rerun
a failed test run to see whether it passes.

Decomposition note: the plan does not lead with a separately committed tracer slice. The change rewrites values
only; the path catalog, generated symbol, `DownloadCoordinator.continuedSessionSubtitle(for:)`, client spy and test
assertion is unchanged and already proven, and CONTEXT › Commits locks a single atomic commit, which a committed
slice would break. Task 3's full DownloadsFeatureTests run is the end-to-end proof.

Planning-time measurements (HEAD `0d2f52d4f`, read-only): 182 lines under AppPackage/Tests/DownloadsFeatureTests
carry the middle dot (183 occurrences; line 14 of DownloadRunProgressOverlayTests.swift carries two and is out of
scope), so the CONTEXT mapping matches 181 test occurrences on 181 lines, plus 1 in
DownloadClient+WorkingManifestReconciliation.swift:26, together the 182 CONTEXT names. A live sweep found four more
pins of the old English rendering that the mapping's pattern cannot reach because they quote only part of the card;
Task 2 applies the same ` / ` to ` of ` rule to them (CONTEXT › Task Boundary: "updates every test literal and
source comment that pins the old English rendering"):
- DownloadContinuedSessionRunProofTests.swift:877 and :887 wait on the substrings `/ 12 pages` and `/ 16 pages`.
  Left alone, both waits could never be satisfied after the catalog change and the run would fail.
- DownloadContinuedSessionTests.swift:464 doc comment: the card text `2 / 2 pages`.
- DownloadClient+ContinuedSession.swift:859 doc comment: the card text `"0 / 4 pages"`.
Deliberately unchanged: the four `"0 / 4 pages"` arguments in DownloadContinuedSessionIdentityTests.swift
(lines 232, 237, 245, 249) are arbitrary inputs to the spy client's own `start`, not renderings of the catalog; the
pair notations such as `6 / 14`, `0 / 24` and `20 / 20` describe completed/total unit pairs, not the card text.
Simulating all edits in a scratch copy gave: every rewritten line at most 118 characters (no wrapping needed),
SwiftLint exit 0, and a diff of 16 files, 200 insertions, 200 deletions.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/quick/261126-pfr-native-continued-session-subtitle/261126-pfr-CONTEXT.md
@CLAUDE.md
@.swiftlint.yml
@AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionSubtitle.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write the six locale values into the catalog entry with line-anchored edits</name>
  <files>AppPackage/Sources/Resources/Resources/Localizable.xcstrings</files>
  <read_first>AppPackage/Sources/Resources/Resources/Localizable.xcstrings (lines 150 to 478 only: the `continued_session.subtitle` entry)</read_first>
  <action>
Implements CONTEXT › Final catalog values and CONTEXT › Editing the catalog. Edit exactly 14 lines of the
`continued_session.subtitle` entry and nothing else. Never parse and re-serialize the JSON: the file mixes
`"key" : value` and `"key": value` styles and a round-trip would rewrite unrelated entries.

Every changed line has the form INDENT + `"value" : "` + TEXT + `"`. INDENT is 12 spaces on the six outer
`stringUnit` lines and 22 spaces on the eight substitution lines. Change only TEXT, from the old column to the new
column:

| Line | Locale, field | Old TEXT | New TEXT |
| --- | --- | --- | --- |
| 156 | de outer | `%#@completed@ / %#@total@ · %#@galleries@` | `%#@completed@ von %#@total@ aus %#@galleries@` |
| 218 | en outer | `%#@completed@ / %#@total@ · %#@galleries@` | `%#@completed@ of %#@total@ in %#@galleries@` |
| 280 | ja outer | `%#@completed@ / %#@total@ · %#@galleries@` | `全%#@total@ページ中%#@completed@ページ完了（ギャラリー%#@galleries@件）` |
| 305 | ja total other | `%argページ` | `%arg` |
| 319 | ja galleries other | `%arg件のギャラリー` | `%arg` |
| 330 | ko outer | `%#@completed@ / %#@total@ · %#@galleries@` | `총 %#@total@페이지 중 %#@completed@페이지 완료 (갤러리 %#@galleries@개)` |
| 355 | ko total other | `%arg페이지` | `%arg` |
| 369 | ko galleries other | `갤러리 %arg개` | `%arg` |
| 380 | zh-Hans outer | `%#@completed@ / %#@total@ · %#@galleries@` | `已下载 %#@completed@ 页，共 %#@total@ 页（%#@galleries@ 个画廊）` |
| 405 | zh-Hans total other | `%arg 页` | `%arg` |
| 419 | zh-Hans galleries other | `%arg 个画廊` | `%arg` |
| 430 | zh-Hant outer | `%#@completed@ / %#@total@ · %#@galleries@` | `已下載 %#@completed@ 頁，共 %#@total@ 頁（%#@galleries@ 個畫廊）` |
| 455 | zh-Hant total other | `%arg 頁` | `%arg` |
| 469 | zh-Hant galleries other | `%arg 個畫廊` | `%arg` |

Exact characters matter (CONTEXT): ja and zh use the full-width `（` `）` and `，` with no space before `（`; ko uses
a half-width space, then half-width `(` `)`; zh puts exactly one half-width space between a number token and the
adjacent Han characters; no value ends with a period. The en and de substitution lines, every `argNum`, every
`formatSpecifier` and every `state` stay untouched. ja and ko put `%#@total@` first; `argNum` keeps the arguments
bound, as `accessibility.partial` in AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings already does for
ja, and the generated Swift symbol derives from the en (source language) value, whose order does not change.

How to apply it: write a short Python 3 script at `${TMPDIR:?}/261126-pfr-catalog.py` (outside the repository) that
reads the catalog as UTF-8 with `newline=''`, splits on `\n`, and for each of the 14 rows first asserts that the line
at that number equals INDENT + `"value" : "` + old TEXT + `"` exactly, then replaces it with INDENT +
`"value" : "` + new TEXT + `"`; it writes the file back as UTF-8 with `newline=''` joined on `\n`, so line endings and
the trailing newline are preserved. Run it with `python3 -I` from the repo root. If any assertion fails, stop and ask
the orchestrator. Do not commit in this task.
  </action>
  <verify>
    <automated>python3 -I - <<'PY'
import json
p = 'AppPackage/Sources/Resources/Resources/Localizable.xcstrings'
loc = json.load(open(p, encoding='utf-8'))['strings']['continued_session.subtitle']['localizations']
outer = {
    'de': '%#@completed@ von %#@total@ aus %#@galleries@',
    'en': '%#@completed@ of %#@total@ in %#@galleries@',
    'ja': '全%#@total@ページ中%#@completed@ページ完了（ギャラリー%#@galleries@件）',
    'ko': '총 %#@total@페이지 중 %#@completed@페이지 완료 (갤러리 %#@galleries@개)',
    'zh-Hans': '已下载 %#@completed@ 页，共 %#@total@ 页（%#@galleries@ 个画廊）',
    'zh-Hant': '已下載 %#@completed@ 頁，共 %#@total@ 頁（%#@galleries@ 個畫廊）',
}
rendered = {
    'de': '6 von 14 Seiten aus 2 Galerien',
    'en': '6 of 14 pages in 2 galleries',
    'ja': '全14ページ中6ページ完了（ギャラリー2件）',
    'ko': '총 14페이지 중 6페이지 완료 (갤러리 2개)',
    'zh-Hans': '已下载 6 页，共 14 页（2 个画廊）',
    'zh-Hant': '已下載 6 頁，共 14 頁（2 個畫廊）',
}
args = {'completed': 1, 'total': 2, 'galleries': 3}
def render(l, counts):
    text = loc[l]['stringUnit']['value']
    for name, n in counts.items():
        forms = loc[l]['substitutions'][name]['variations']['plural']
        form = forms['one' if n == 1 and 'one' in forms else 'other']['stringUnit']['value']
        text = text.replace('%#@' + name + '@', form.replace('%arg', str(n)))
    return text
assert set(loc) == set(outer), sorted(loc)
assert chr(0xB7) not in json.dumps(loc, ensure_ascii=False)
for l, value in outer.items():
    assert loc[l]['stringUnit'] == {'state': 'translated', 'value': value}, l
    subs = loc[l]['substitutions']
    assert set(subs) == set(args), l
    for name, num in args.items():
        assert subs[name]['argNum'] == num and subs[name]['formatSpecifier'] == 'lld', (l, name)
        cats = set(subs[name]['variations']['plural'])
        want = {'one', 'other'} if l in ('en', 'de') and name != 'completed' else {'other'}
        assert cats == want, (l, name, cats)
        if l not in ('en', 'de'):
            assert subs[name]['variations']['plural']['other']['stringUnit']['value'] == '%arg', (l, name)
    got = render(l, {'completed': 6, 'total': 14, 'galleries': 2})
    assert got == rendered[l], (l, got)
assert render('en', {'completed': 1, 'total': 1, 'galleries': 1}) == '1 of 1 page in 1 gallery'
assert render('de', {'completed': 1, 'total': 1, 'galleries': 1}) == '1 von 1 Seite aus 1 Galerie'
print('catalog OK')
PY
# [HEAD=error:1 EXPECT==present] prints "catalog OK"; at HEAD it fails on the middle-dot assertion
S=$(git diff --numstat -- AppPackage/Sources/Resources/Resources/Localizable.xcstrings) && printf '%s\n' "$S" | awk 'NF {print $1+0, $2+0}' | grep -c '^14 14$' # [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The check prints `catalog OK` (the catalog parses, all six outer values and the eight bare `%arg` values match
CONTEXT, the argNum/lld/category sets are intact, the rendered examples for (6, 14, 2) and the en/de (1, 1, 1)
singulars match, and no middle dot remains in the entry), and the catalog's numstat is exactly `14 14`. Nothing
committed.</done>
</task>

<task type="auto">
  <name>Task 2: Rewrite the pinned English renderings in the tests and the two source doc comments</name>
  <files>AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionFoldTests.swift, AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionSubmissionTests.swift, AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadProgressSeriesGuardTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift, AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift, AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift</files>
  <read_first>AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift (lines 860 to 900 only), AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift (lines 20 to 30 only)</read_first>
  <action>
Implements CONTEXT › Test literals and comments: the tests run in the simulator's English locale and pin the en
value written in Task 1, so every pinned rendering moves to the new English form. The noun forms (page/pages,
gallery/galleries) stay exactly as they are; only the two connectors change.

Write a short Python 3 script at `${TMPDIR:?}/261126-pfr-rewrite.py` (outside the repository), run it from the repo
root with `python3 -I`, reading and writing every file as UTF-8 with `newline=''`. It does two things:

(a) The CONTEXT mapping, as one regular expression. With Python's `re`, pattern (raw string)
`([0-9]+|\\\([A-Za-z_.]+\)) / ([0-9]+|N|\\\([A-Za-z_.]+\)) (pages?) · ([0-9]+|\\\([A-Za-z_.]+\)) (gallery|galleries)`
and replacement `\1 of \2 \3 in \4 \5`. Each number slot accepts a decimal integer or a Swift interpolation such as
`\(numerator)` or `\(step.completedUnitCount)`; the total slot also accepts `N`. Apply it with `subn` to every
`*.swift` file directly inside AppPackage/Tests/DownloadsFeatureTests/ and to
AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift, writing back only files with at
least one replacement. Assert that the total replacement count is exactly 182 (181 in the tests, 1 in the source
doc comment at line 26, which becomes `` `0 of N pages in 0 galleries` ``).

(b) Four partial quotes of the card that the pattern cannot reach (see the objective's planning-time measurements).
For each, assert that the old text occurs exactly once in its file, then replace it:
- DownloadContinuedSessionRunProofTests.swift: `contains("/ 12 pages")` becomes `contains("of 12 pages")`.
- DownloadContinuedSessionRunProofTests.swift: `contains("/ 16 pages")` becomes `contains("of 16 pages")`.
  Both are `waitUntil` barriers keyed on the denominator; `of 12 pages` matches only a denominator of 12 in the new
  rendering exactly as the old substring did in the old one.
- DownloadContinuedSessionTests.swift (doc comment, line 464): ``pushed `2 / 2 pages` `` becomes ``pushed `2 of 2 pages` ``.
- AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift (doc comment, line 859): `"0 / 4 pages"`
  becomes `"0 of 4 pages"`.

Leave untouched: the historical overlay quote at DownloadRunProgressOverlayTests.swift:14 (out of scope per CONTEXT);
the four `"0 / 4 pages"` spy-input arguments in DownloadContinuedSessionIdentityTests.swift; the completed/total pair
notations in prose (`6 / 14`, `0 / 24`, `20 / 20` and the like); every file outside the 15 listed. The new English
text is two characters longer per occurrence; measured at planning time the longest rewritten line is 118
characters, so no line needs wrapping. If any line would exceed 120 characters, stop and ask the orchestrator.
If any assertion fails, stop and ask the orchestrator. Do not commit in this task.
  </action>
  <verify>
    <automated>grep -rn '·' AppPackage/Tests/DownloadsFeatureTests | wc -l # [HEAD=182 EXPECT==1] comments included on purpose: doc comments quoting the card are in scope
grep -rln '·' AppPackage/Tests/DownloadsFeatureTests | grep -vc 'DownloadRunProgressOverlayTests\.swift$' # [HEAD=13 EXPECT==0] the one file left is DownloadRunProgressOverlayTests.swift (its line 14)
grep -rhoE ' of ([0-9]+|N) pages? in [0-9]+ galler(y|ies)' AppPackage/Tests/DownloadsFeatureTests | wc -l # [HEAD=0 EXPECT==181]
grep -rhoE 'contains\("of 1[26] pages"\)' AppPackage/Tests/DownloadsFeatureTests | wc -l # [HEAD=0 EXPECT==2]
grep -c 'pushed `2 of 2 pages`' AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift # [HEAD=0 EXPECT==1]
grep -rnE '/ [0-9N]+ pages?' AppPackage/Tests/DownloadsFeatureTests | grep -v 'DownloadContinuedSessionIdentityTests.swift' | wc -l # [HEAD=184 EXPECT==0]
grep -c '"0 / 4 pages"' AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift # [HEAD=4 EXPECT==4 GUARD MUTATION: rewriting the spy-input fixtures]
grep -c '0 of N pages in 0 galleries' AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift # [HEAD=0 EXPECT==1]
grep -c '"0 of 4 pages"' AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift # [HEAD=0 EXPECT==1]
grep -rnE '[0-9N] / [0-9N]+ pages?' AppPackage/Sources/DownloadClient | wc -l # [HEAD=2 EXPECT==0]
S=$(git diff --numstat -- AppPackage/Tests/DownloadsFeatureTests AppPackage/Sources/DownloadClient) && printf '%s\n' "$S" | awk 'NF {i+=$1; d+=$2; n++} END {print n+0, i+0, d+0}' | grep -c '^15 186 186$' # [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>Every gate prints its EXPECT value: one middle-dot line left in the test directory (DownloadRunProgressOverlayTests.swift:14),
181 new full renderings, both denominator waits on `of 12 pages` / `of 16 pages`, the `2 of 2 pages` and `"0 of 4 pages"`
doc quotes, no old slash form left outside the untouched Identity fixtures, and a test-plus-source diff of exactly
15 files with 186 insertions and 186 deletions. Nothing committed.</done>
</task>

<task type="auto">
  <name>Task 3: Lint, run DownloadsFeatureTests, and make the one signed +0800 commit</name>
  <files>AppPackage/Sources/Resources/Resources/Localizable.xcstrings, AppPackage/Tests/DownloadsFeatureTests/*.swift (the 13 files above), AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift, AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift</files>
  <precondition>The simulator `EhPanda iPhone Air (middle-dot)` (id 811DE720-3B21-4A00-B575-F980A031F185) exists (`xcrun simctl list devices | grep -c 811DE720-3B21-4A00-B575-F980A031F185` prints 1) and `xcodebuild -version` reports Xcode 27.2.</precondition>
  <action>
Implements CONTEXT › Verification and CONTEXT › Commits. Run from the repo root, in this order; stop and ask the
orchestrator at the first result that differs from what is stated here.

1. SwiftLint, directly (the app-scheme build does not lint test targets). Resolve the binary as the most recently
   modified match of
   `~/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`
   (`ls -t ... | head -1`; 0.65.1 at planning time) and run
   `lint --strict --quiet AppPackage/Sources/DownloadClient AppPackage/Tests/DownloadsFeatureTests`. Required: no
   output and exit 0 (it was clean at HEAD). Never add a `swiftlint:disable` or change a lint rule.

2. DownloadsFeatureTests, through the app scheme and test plan. Only one `xcodebuild test` may run on this Mac at a
   time and other projects' sessions may be testing, so start it with the Bash tool's `run_in_background` as one
   command that first waits until `pgrep -x xctest` finds nothing (a `until ! pgrep -x xctest >/dev/null; do sleep 15;
   done` loop; exact process name only, never a `-f` pattern, and never two waiters queued at once), then runs
   `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=811DE720-3B21-4A00-B575-F980A031F185' -only-testing:DownloadsFeatureTests -collect-test-diagnostics never`
   with stdout and stderr redirected to `${TMPDIR:?}/261126-pfr-downloads-tests.log`. `-collect-test-diagnostics never`
   is the project's standing flag (a failing run otherwise idles up to ten minutes in `simctl diagnose`); it does not
   change which tests run. Wait for the completion notification; xcodebuild buffers its output, so a short log while
   it runs is not a hang. Never kill the run, the simulator service or any xcodebuild process. The tests are Swift
   Testing: the result is the `Test run with N tests` line, `Executed 0 tests` is the empty XCTest counter, and
   "Network Error" lines from DownloadsFeatureTests are expected noise.
   Required: a `Test run with N tests ... passed` line, `** TEST SUCCEEDED **`, no failed test, and no `warning:` line
   that names Localizable.xcstrings, a file under DownloadsFeatureTests/, DownloadClient+ContinuedSession.swift or
   DownloadClient+WorkingManifestReconciliation.swift. Record N for the summary. A failure is a finding to report,
   not something to rerun.

3. Commit, only after 1 and 2 pass. Stage exactly the 16 files listed in this plan's `files_modified` by path (never
   `git add -A` or `git add .`: the untracked `.planning/quick/261126-pfr-native-continued-session-subtitle/` directory
   must stay out of this code commit). Confirm the staged set is those 16 files with 200 insertions and 200
   deletions, then commit with the machine's +0900 zone overridden to +0800:
   `T=$(TZ=Asia/Shanghai date +%Y-%m-%dT%H:%M:%S+08:00); GIT_AUTHOR_DATE="$T" GIT_COMMITTER_DATE="$T" git commit -S -m "Reword the continued-processing card subtitle"`.
   The message is exactly that 45-character subject: no body, no attribution or co-author lines. Do not push, merge,
   amend an earlier commit or touch any `.planning/` file in this commit.
  </action>
  <verify>
    <automated>"$(ls -t ~/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -1)" lint --strict --quiet AppPackage/Sources/DownloadClient AppPackage/Tests/DownloadsFeatureTests; echo "lint exit=$?" # [HEAD=0 EXPECT==0 GUARD MUTATION: a rewritten line over 120 characters] no findings printed, then "lint exit=0"
grep -cE 'Test run with [0-9]+ tests.* passed after' "${TMPDIR:?}/261126-pfr-downloads-tests.log" # [HEAD=error:2 EXPECT==1] record N from this line
grep -cE 'Test run with [0-9]+ tests.* failed after' "${TMPDIR:?}/261126-pfr-downloads-tests.log" # [HEAD=error:2 EXPECT==0]
grep -c '\*\* TEST SUCCEEDED \*\*' "${TMPDIR:?}/261126-pfr-downloads-tests.log" # [HEAD=error:2 EXPECT==1]
grep -E 'warning:' "${TMPDIR:?}/261126-pfr-downloads-tests.log" | grep -cE 'Localizable\.xcstrings|DownloadsFeatureTests/|DownloadClient\+(ContinuedSession|WorkingManifestReconciliation)\.swift' # [HEAD=error:2 EXPECT==0]
L=$(git log -1 --format='%G? %aI %cI %s') && printf '%s\n' "$L" | grep -cE '^G [0-9T:-]+\+08:00 [0-9T:-]+\+08:00 Reword the continued-processing card subtitle$' # [HEAD=0 EXPECT==1]
S=$(git show --numstat --format= HEAD) && printf '%s\n' "$S" | awk 'NF {i+=$1; d+=$2; n++} END {print n+0, i+0, d+0}' | grep -c '^16 200 200$' # [HEAD=0 EXPECT==1]
S=$(git status --short) && printf '%s\n' "$S" | grep -v '^$' | grep -vc '^?? \.planning/quick/261126-pfr-native-continued-session-subtitle/$' # [HEAD=0 EXPECT==0 GUARD MUTATION: staging any other file or leaving one modified] only the untracked planning directory remains</automated>
  </verify>
  <done>SwiftLint prints nothing and exits 0 for both directories; the DownloadsFeatureTests run reports
`Test run with N tests ... passed` and `** TEST SUCCEEDED **` with no warning in a touched file; HEAD is one new
commit `Reword the continued-processing card subtitle`, signature status `G`, author and committer dates both +08:00,
16 files, 200 insertions, 200 deletions; the working tree holds nothing else but the untracked planning directory;
nothing pushed.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app process to system UI | The continued-processing card renders in system UI, outside the app's privacy mask and App Switcher snapshot protection; whatever the localized value produces is readable by anyone glancing at the screen. |
| repository to signed history | The commit is the record the owner reviews; its provenance and scope must be checkable. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261126-pfr-01 | Information disclosure | `continued_session.subtitle` values, rendered by `DownloadCoordinator.continuedSessionSubtitle(for:)` | medium | mitigate | The new values add only fixed per-locale words; all three substitutions stay `lld` integers with argNum 1 to 3 (Task 1's check asserts `formatSpecifier == 'lld'` and the exact substitution set), so no gallery title or GID can reach the card; the existing title/GID absence loop in DownloadContinuedSessionTests keeps guarding it in Task 3's run. |
| T-261126-pfr-02 | Tampering | Localizable.xcstrings, unrelated entries | low | mitigate | Line-anchored edits that assert each old line before replacing it, no JSON re-serialization, and the numstat gate requiring exactly 14 changed lines in the catalog. |
| T-261126-pfr-03 | Repudiation | The code commit | low | mitigate | `git commit -S`; Task 3 verifies `%G?` is `G` and both dates are +08:00, and the staged set is the 16 named files only. |
| T-261126-pfr-SC | Tampering | npm/pip/cargo installs | low | accept | This plan installs no package; nothing to gate. |
</threat_model>

<verification>
- Task 1: `catalog OK` and catalog numstat `14 14`.
- Task 2: every grep gate at its EXPECT value; test-plus-source numstat `15 186 186`.
- Task 3: SwiftLint silent with exit 0; DownloadsFeatureTests `Test run with N tests ... passed` and
  `** TEST SUCCEEDED **`; commit `G`, +08:00 twice, `16 200 200`; nothing pushed.
</verification>

<success_criteria>
- All six locales carry the CONTEXT values exactly, with no middle dot anywhere in the entry.
- No pinned English rendering of the old form remains in DownloadsFeatureTests or DownloadClient doc comments; the
  out-of-scope overlay quote and the Identity spy-input fixtures are unchanged.
- DownloadsFeatureTests passes and SwiftLint is clean for both touched directories.
- Exactly one signed code commit, subject `Reword the continued-processing card subtitle`, +08:00 author and
  committer dates, 16 files, 200 insertions, 200 deletions, not pushed.
</success_criteria>

<output>
Create `.planning/quick/261126-pfr-native-continued-session-subtitle/261126-pfr-SUMMARY.md` when done (not part of
the code commit). Record the commit hash, the swiftlint binary path and version used, the `Test run with N tests`
line, and the deferred item from CONTEXT (the drained end state renders as `0 of 1 page in 0 galleries` because the
one-page progress floor reaches the text while the gallery count is zero; reported to the owner, not fixed here).
</output>
