# Search range indicator setting

Owner request (2026-11-02): make the search range indicator setting read like the site's. The app showed a header,
Search Range Indicator, over a toggle, Show Search Range Indicator. Both sites ask "Which display style would you like
for the search range indicator?" with Normal and Disabled.

## Changes

`426618bfa` makes the section work like Display Mode above it.

- The header is now the site's question, in all six languages.
- The toggle is now a picker with Normal and Disabled, which becomes an inline list at accessibility text sizes.
- `EhSetting.showSearchRangeIndicator` is now `searchRangeIndicatorStyle`, an enum whose raw values are the site's `pp`
  values. The form still posts `pp` 0 or 1, and a page with neither option checked now fails to parse, as it does for
  Display Mode.
- `show_search_range_indicator` is removed. New keys are `search_range_indicator_description`,
  `search_range_indicator_style.normal` and `search_range_indicator_style.disabled`.

The row keeps the label Search Range Indicator rather than Display Style, because the Multi-Page Viewer section already
has a Display Style row. Two rows with one name would be ambiguous for VoiceOver and Voice Control.

The setting only changes what the website shows, because the parser does not read the site's range bar.

## Verification

- `FeatureTests` without `VisualSnapshotTests`: 1,400 tests, 1,390 passed, 10 expected failures, 0 failed, and no test
  passed only on a retry. This count moves between 9 and 10 on earlier runs too, because
  `defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges` makes a live request whose duration decides whether
  it records an issue.
- A new parser test reads the site's page with Disabled checked.
- A temporary render, not committed, drew the section at standard size in English, German, Japanese, Korean and both
  Chinese scripts, and in English at AX3. No text was cut off.
- The Chinese pair differs only in existing regional words: 搜尋 and 搜索, 停用 and 禁用.
- SwiftLint reports no violations.

Not verified: the page itself needs a login, so the section was not seen inside the running app, and the picker's menu
was not opened on screen. AX5 was not seen for this section. Changing the setting was not submitted to the site.

## Chinese alignment

The owner then asked to align three older differences on this page with zh-Hans (`c0adb7b75`).

- Normal under thumbnail size changes from 正常 to 普通.
- The Display Mode question changes from 你想 and 哪一種 to 你希望 and 哪種.
- The Display Mode options lose their English names in parentheses, Minimal changes from 最小 to 最小化, and Minimal+ becomes
  最小化 +. `thumbnail_load_timing_description` names the Minimal mode, so it follows. 延伸 stays, as Taiwan's word for 扩展.

An app build passed and the compiled zh-Hant values read back as above. The section was not rendered again and the unit
tests were not rerun, because this change touches only those catalog values and no test reads them.

## Item-by-item pass

A scripted comparison covered the keys that the settings views and model files reference. After converting zh-Hant to
Simplified, 100 of those 147 keys differed. The owner asked for these to be aligned item by item, changing a string only
where the meaning differs and leaving differences of wording or regional vocabulary. The English text decided which side
to change.

- zh-Hant, 19 strings (`c0adb7b75`). The clearest errors were `favorites_sort_order.favorited_time`, which said favorited
  order rather than time, and the two Hentai@Home `No` options with descriptions, which kept English and called
  Donator-only a feature. `archiver_behavior_description` also misread "clicked or copied elsewhere". The rest are
  `gallery_name_description` and `gallery_name_display`, `excluded_languages`, the rest of the Archiver options, the
  other favorites sort option, `gallery_name.japanese`, thumbnail size Large and Small, the Hath Perk note, an added
  `(1~5)`, and when rather than how for thumbnail loading.
- zh-Hans, 3 strings (`c0adb7b75`), where it had drifted from the English. `load_through_hath_setting.any_client` said all
  rather than any, `ratings_color_description` dropped that yellow is for normal stars, and
  `thumbnail_load_timing.on_mouse_over_description` dropped that the delay may be slight.

An app build passed after each change, and sample compiled values in both scripts read back correctly. The strings were
not rendered, and the unit tests were not rerun, because only catalog values changed and a search found no test reading
these strings.

The owner then had the two Hentai@Home `No` options reworded in both scripts (`c0adb7b75`), to 不使用 [現代 / HTTPS] and
不使用 [舊式 / HTTP]. 不透過 and 不通过 read as fragments once the menu is open and the row's title is out of view, while 不使用
pairs with 只使用 in the same menu and matches the Japanese 使わない. An app build passed and the compiled values read back
correctly.

95 keys still differ after conversion, and all were read side by side. They differ only in wording or regional vocabulary,
such as 排除 and 屏蔽, 壓縮檔 and 归档, 列數 and 行数, so they stay. German, Japanese and Korean were not part of this pass.
