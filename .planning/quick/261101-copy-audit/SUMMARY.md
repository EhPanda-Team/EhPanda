# App-wide copywriting audit

Owner request (2026-11-01): audit all UI copy for literal translation and unnatural wording, aiming for
quality localization that respects the text length the UI prefers. English is the base language, but
its usage is also in scope (owner's example: "Give a Rating").

## Status

Applied. The owner approved every severity on 2026-11-01 ("不論分級，全部按你的建議"), then asked on 2026-11-02 for a
second look because some languages had drifted apart.

- The audit's proposals are in [proposals.json](proposals.json), with the brief in [AUDIT-GUIDE.md](AUDIT-GUIDE.md).
- [cross-language-review.json](cross-language-review.json) records the later corrections and supersedes
  `proposals.json` where the two differ. The live catalogs are the final authority.
- The review page (https://claude.ai/artifact/19RM3BrwtJqaByb4fmi2Z5, private) was not used for row decisions; its
  `decisions` collection is empty.

## Scope and result

Covered 942 translatable keys (1,005 minus 63 non-translated constants) in 24 catalogs and six locales.

| Locale | P0 | P1 | P2 | P3 | Total | Name-list share |
| --- | --- | --- | --- | --- | --- | --- |
| en | 14 | 12 | 76 | 53 | 155 | 18 |
| zh-Hant | 29 | 55 | 92 | 126 | 302 | 87 |
| zh-Hans | 16 | 17 | 92 | 72 | 197 | 29 |
| ja | 16 | 35 | 81 | 73 | 205 | 18 |
| ko | 64 | 33 | 103 | 61 | 261 | 79 |
| de | 182 | 15 | 67 | 33 | 297 | 163 |

The audit said no user-facing string was hard-coded in Swift outside previews. That was wrong. The error details
screen built its context rows, device name and two action names in code, so they were English in every locale. They
now come from catalogs, and `ContextKey` has a localized `label`.

## Cross-language review

The first pass compared each language with English only, so nobody compared the languages with each other. The owner
found the result: `cookie_value.none` read 未设置 in zh-Hans and 無 in zh-Hant, and `laboratory` meant a lab in four
languages and experimental features in two. Their rule, 2026-11-02: word-for-word is not required, but the concept,
information and scope must match. zh-Hans and zh-Hant differ only in regional vocabulary and script.

- Side-by-side pass: 951 keys read in six languages. 193 findings: 154 accepted, 29 adjusted, 10 kept with reasons.
- Pair check: zh-Hant was converted to Simplified by script, regional vocabulary was normalized, and the 375 remaining
  differences were read one by one. Together with the last on-screen review this changed 46 more strings, such as
  清空 to 清除, 全部清空 to 全部移除, and 历史记录 to 浏览记录. The side-by-side pass had missed these.
- Kept on purpose: 申訴 for Copyright Claim, SNI 阻断, 屏蔽 and 排除, `not_my_president`, ko Watched, 归档 and 壓縮檔 for
  Archive, and the `ja` Home card descriptions, which are fragments and carry no sentence ending.
- The E-Hentai settings page still has wording differences between zh-Hans and zh-Hant, because that page changes only
  for real errors, punctuation and the site's newer text. Punctuation in 15 of its zh-Hant strings was corrected. Its
  mix of 你 and 您 and the English glosses in zh-Hant `display_mode.*` were left alone.

## Everyday-usage baseline

Owner decision (2026-11-01): every language follows what its readers see every day in mainstream apps and sites,
and zh-Hant means Taiwanese Mandarin. Apple's wording only breaks ties. The first pass was briefed to match Apple's
apps, so a second, narrower pass reviewed that bias per language ([brief](BASELINE-GUIDE.md)).

- zh-Hant: 複製, 剪貼簿, 篩選, App 圖示, 紀錄, 壓縮檔 and 內容庫 replace 拷貝, 剪貼板, 過濾條件, App 圖像, 記錄, 封存檔 and 資料庫.
- ja: long-vowel forms (ユーザー, フィルター, デベロッパー), 削除 over 消去, インポート, アプリ, and フォロー中 for Watched.
- zh-Hans: 账号, 内容库, 移动网络, 跟随系统, 查看全部 and 人评分.
- ko: 불러오기, 초기화, 삭제, 더블 탭, 모바일 데이터 and 아이디 replace 로드, 재설정, 지우기, 이중 탭, 셀룰러 and 사용자 이름.
- de: Speichern, Bibliothek, Fotos and Design replace Sichern, Mediathek, Fotomediathek and Erscheinungsbild.
- en: Apple's wording is already everyday English; only Turkey and Czech Republic were kept against the first pass.

The orchestrator's review of this pass also fixed a miss across locales: zh-Hant, zh-Hans, ko and de still sent users
to the wrong screen for cookies. Many usage judgments rest on the reviewers' editorial experience rather than
measurements.

## Country and language names

Owner decision (2026-11-01): the 317 country and language names stay app-defined in the catalogs instead of moving
to the system `Locale` API, because the system names cannot be used without special cases. On macOS and iOS 27.2,
Taiwan reads correctly in all 27 tested language and region pairs, but the API names China 中國大陸, 中国大陆, China
mainland, China, Festland, 中国本土 and 중국 본토, and names `EU` 歐盟 where the site means Europe. A planned test on a
China-sold iPad was cancelled by the same decision, so that device is unmeasured.

## Rules applied

Owner decisions (2026-11-01):

- Count wording is solved with String Catalog plural variations, not code. That covers `pages`, `ratings_count` and
  `stars`, plus `favorited_unit` and `page_count_unit`, which became count-driven keys whose variants hold only the unit.
- A changed English term that names something also changes its l10n keys, filenames, type names and other identifiers,
  so one term is used everywhere.
- The E-Hentai settings page mirrors the site's latest text. English changes only to follow the site or fix a real
  grammar error. Translations change only for real errors, punctuation, app-wide terms and the site's newer text, and
  no further than needed. Generic strings such as Cancel and the language and country names are exempt.
- English proper nouns across the app follow the site: Front Page, My Tags, Browse Expunged Galleries, Hentai@Home,
  Posted, Length and All-Time. Jump and Seek stay, so `jump_page` and `date_seek` need no rename.
- The row that opens the site's settings uses `host_settings`, the page's own title (E-Hentai Settings or ExHentai
  Settings), to tell it apart from the app's settings. This is a deliberate exception to following the site's navigation,
  where E-Hentai says My Settings and ExHentai says Settings. `account_configuration` is gone, and `AccountSection` takes
  the selected site's name.
- Library is 內容庫 and 内容库. The Asian Porn category keeps 亞洲, 亚洲 and アジア.
- English uses Log In / Log Out, with login only as a noun.

## Renames

| Old term | New term | Scope |
| --- | --- | --- |
| Frontpage | Front Page | keys, types, cases, files and tests |
| Quick Search Words | Saved Searches | keys, models and cases; the Quick Search screen keeps its name |
| Quota Exceeded | Image Limit Reached | keys, error kinds and download failure codes |
| Authentication Required | Login Required | keys, error kinds and download failure codes |
| Validate | Verify | the download verification feature's keys, cases and types |
| Gallery Infos | Gallery Info | detail types, files and metadata key |

Other key renames: `communicating` to `sending_request`, `code_level_contributors` to `code_contributors` (and the
Constant catalog's `code_contributor.*`), `detect_links_from_clipboard` to `detect_links_in_clipboard`,
`retry_failed_pages_automatically` to `auto_retry_failed_pages`. `inspect_pages` merged into `download_status`.

These stored or wire names stay, because changing them would lose user data or break decoding:

- `GalleryListScope.frontPage = "frontpage"`, the matching `GalleryListPresentation` coding key, `SearchSurface.frontPage`
  and the accessibility identifier `gallery-layout-frontpage`.
- The AppStorage key `quickSearchWords` behind `.savedSearches`, and the analytics event `Search.quickSearchWordUsed`.
- The raw values `imageLimitReached = "quotaExceeded"` and `loginRequired = "authenticationRequired"`.
- Setting properties that are persisted by name: `maximumScaleFactor`, `doubleTapScaleFactor`, `displayJapaneseTitle`,
  `showTagsSearchSuggestion`, `enableTagsExtension` and `detectLinksFromClipboard`.
- `GalleryListDisplayMode.row`, `BrowsingCountry+EnglishName.swift`'s site names, and the capture fixture key
  `Home.frontpage`, which `Scripts/visual` also reads.

The validation names in `DownloadClient+ResponseValidation*`, `validatedChildURL`, `validateDecodedManifest` and
`validatedCachedAssetData` stay because they mean input validation, not the Verify feature.

## Verification

Results on the final tree, 2026-11-02:

- Full unit plan without the visual gate: 1,395 tests, 1,384 passed, 10 expected failures, 1 failed. The failure is
  `GalleryCoverLayoutTests.richSlideshowGrowsForMetadataWithoutClipping(.large)`, which reports a height of 2000 and
  fails the same way on the unmodified base commit.
- Standalone SwiftLint over every source and test directory: no violations. The catalog rules for labeled numeric
  arguments, coherent plural categories and filled non-translated keys: no problems.

UI tests ran one class at a time, before a final rebase that only brought in tag database commits:

| Class | Passed | Skipped | Failed |
| --- | --- | --- | --- |
| GalleryLayoutUITests | 3 | 0 | 0 |
| GalleryCardUITests | 3 | 0 | 0 |
| LibraryPresentationUITests | 5 | 0 | 0 |
| DeepLinkSmokeUITests | 1 | 0 | 0 |
| ReadingOrientationUITests | 1 | 2 | 0 |
| AccessibilityAuditUITests | 25 | 1 | 3 |

The three failures are `testHomeRootAudit`, `testPopularAudit` and `testHistoryAudit`. They fail the same way on the
unmodified base commit, so the copy did not cause them. One `GalleryCardUITests` case passed only on the plan's retry.

Screens: a throwaway test, not committed, captured 44 surfaces plus dialogs, the error details screen and logged-in
states on an iPhone Air simulator at the default text size, and the six locales were read side by side. No text was cut
off. After the last string changes, English, Korean and both Chinese locales were captured again; the only German or
Japanese change after their last capture is Japanese VoiceOver labels.

Audit checks, 2026-11-01:

- Every finding's `current` value was compared with the live catalogs, and placeholders and Markdown were compared
  between current and proposed.
- Widths of constrained strings were measured with CoreText using the system font. Proposals fix 15 overflows.
  27 remain over a one-line budget, most of them on the E-Hentai settings page, whose text mirrors the site.
- The logged-in `uconfig.php` was read in the owner's Chrome. With proposals applied, 121 of the 136 mirrored English
  strings match the live page, 2 differ by the intended grammar fixes, and 13 are the app's own short labels with no
  matching text on the site. ExHentai's `uconfig.php` has the same settings text, compared line by line.
- `home.php` and `mytags` were read the same way, as read-only, and account values were not recorded. `home.php` confirms
  the Image Limits heading and `mytags` confirms Watched. `home.php` returns 404 on ExHentai, so Image Limits is E-Hentai
  only.

## Not verified

- The contents of the E-Hentai settings page were not rendered, because that needs a real login. Neither were the
  confirm dialogs for deleting a saved search, clearing history and deleting a download, iPad, or larger text sizes.
- No human native speaker has reviewed the copy. German, Japanese and Korean should get one before release.
- `show_search_range_indicator` needs the owner to confirm actual behavior.
- Favorites parameters `sn`, `st` and `sf` were not tested. `f_sr` and `f_sp` were removed by the toggles task without
  comparing results on ExHentai.
- Screenshots on the website and in marketing are stale from these copy changes, and 24 Filters website screenshots
  already needed retaking.

## Facts worth keeping

- The advanced search form on E-Hentai and ExHentai no longer shows `f_sname`, `f_stags`, `f_sdesc`, `f_storr`, `f_sdt1`
  or `f_sdt2`, and another session's result comparison found both sites ignore them, with only indirect evidence for
  `f_sdt2`. The owner chose on 2026-11-01 to remove the six toggles and strings in that session, so the audit withdrew
  their 18 proposals.
- `download_badge.*` status strings are VoiceOver-only; the badge shows only the progress.
- Detail info-strip column titles render with `.textCase(.uppercase)` in an 80 pt column at 375 pt.
- Filter grid `CategoryCell` is 100 pt wide at body size with a one-line limit, tighter than the category chip.
- `Greeting.swift:74` uses a comma rather than "and" when there are exactly two rewards.
- The site names the image quota mostly with "limit": the Image Limits heading, "account limit" and "image viewing
  limits", with "image quota" once. `home.php` also lets users reset the limit by spending GP, while
  `app_error.image_limit_reached_solution` only says to wait.
- `ToastMessageView` keeps its subtitle to one line at the default text size. `.error(ErrorInfo)` toasts open the details
  screen when tapped, but `.error(caption:)` and `.success(caption:)` do not, so their text must fit.
- zh-Hans punctuation sits low and left in PingFang SC, so a full-width ？ can look half-width in a screenshot. Check the
  code point before calling it wrong.
