# 19-26 Heights: the measuring runs, the proposal and the findings

This is the record of plan 19-26. Task 1 measured the whole matrix and wrote the proposal and the findings below;
the owner's answers (Task 2, `## Owner decisions`) and the applied counts, the verification sample and the timing
ratio (Task 3) are added to this file by those tasks. Task 1 changed no provider file: no height is committed yet.

The measuring mode takes no picture (`19-20-PROBES.md`): every run below holds one line per coordinate in its
`heights.jsonl`, and no picture of any state was taken at its measured height. Wherever a picture is asked for, the
record says `none`. The raw lines, the proposal (`proposal.json`) and the logs stay under
`.capture/agent-work/phase19-26` (`$W` below), which git ignores.

The runs measured the working tree at `f0dd8559f` (a documentation commit made one minute before the first run
started). The last commit that touches `AppPackage`, `Scripts` or `App` is `d78bbf204` (19-31), so every run measured
the app after the fixes of 19-21 to 19-25 and the two step stages of 19-30.

## Runtime

Owner decision, 2026-11-24: the two phase simulators were recreated on
`com.apple.CoreSimulator.SimRuntime.iOS-27-2` after the pinned iOS 27.0 runtime (24A434) was removed from this Mac,
and the owner chose 27.2 over reinstalling 27.0. The hosted gate still pins 27.0
(`Scripts/visual/regression-environment.json`). The question was asked by the orchestrator, with the options measure
on 27.2 and verify on the hosted 27.0 run, reinstall 27.0 locally, or move the hosted pin to 27.2, and the owner
settled it on 2026-11-25. The answer, verbatim: 「本機 27.2 量，hosted 驗證（建議）」.

So the measuring runs and the committed heights are 27.2 values, and the hosted run A of 19-27 (27.0) checks them
with the same `page-height` check. A coordinate that needs more on 27.0 fails there and comes back as a finding in
19-28; the check is never loosened. A 27.0 page that needs less only leaves a few points of empty space at the bottom
of its picture.

## Runs

Every run is the measuring mode of `Scripts/visual/run-snapshot-local.sh --measure-heights` with the 22 classes of
`snapshot_shard.py classes` and one text size's six languages (`--config`, both themes): the iPhone with both
orientations in the process, `--workers 3`; the iPad portrait with `--orientation portrait --workers 3`; the iPad
landscape with `--orientation landscape` and no `--workers`. The iPhone ran on `EhPanda iPhone Air (phase19)` and the
iPad on `EhPanda iPad Pro 11-inch (M5) (phase19)`. The driver log of every finished run ends with `rc=1` and
`Snapshot run failed`; each of those runs holds `cannot-cover`, `did-not-converge` or `error` lines, which are the
findings below. Start and end come from the driver logs; the two last extra runs have no driver log, and their start
and end are from the orchestrator's background output. The end of the interrupted run is the time its
`xcodebuild.log` stops.

| Run (under `.capture/agent-work/phase19-26`) | Configurations | Start (UTC) | End (UTC) | Lines | measured | cannot-cover | did-not-converge | error | notApplicable | Note |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `phone-xSmall` | iPhone, both orientations, xSmall | 2026-11-25T02:21:54Z | 2026-11-25T05:27:33Z | 3,312 | 2,715 | 236 | 288 | 13 | 60 |  |
| `phone-large` | iPhone, both orientations, large | 2026-11-25T05:27:40Z | 2026-11-25T08:50:55Z | 3,312 | 2,678 | 236 | 312 | 26 | 60 |  |
| `phone-accessibility5` | iPhone, both orientations, accessibility5 | 2026-11-25T08:51:01Z | 2026-11-25T15:11:32Z | 3,300 | 2,400 | 480 | 322 | 38 | 60 | 12 lines missing |
| `pad-portrait-xSmall` | iPad portrait, xSmall | 2026-11-25T15:11:40Z | 2026-11-25T16:31:29Z | 1,656 | 1,306 | 168 | 132 | 14 | 36 |  |
| `pad-portrait-large` | iPad portrait, large | 2026-11-25T16:31:36Z | 2026-11-25T17:43:20Z | 1,656 | 1,311 | 168 | 132 | 9 | 36 |  |
| `pad-portrait-accessibility5` | iPad portrait, accessibility5 | 2026-11-25T17:43:26Z | 2026-11-25T19:39:14Z | 1,656 | 1,171 | 334 | 98 | 17 | 36 |  |
| `interrupted-pad-landscape-xSmall` | iPad landscape, xSmall, first start | 2026-11-25T19:39:20Z | 2026-11-25T23:45:38Z | 1,537 | 1,225 | 152 | 126 | 12 | 22 | interrupted, set aside, not an input |
| `pad-landscape-xSmall` | iPad landscape, xSmall, started again | 2026-11-26T12:40:07Z | 2026-11-26T17:40:10Z | 1,656 | 1,320 | 168 | 132 | 12 | 24 |  |
| `pad-landscape-large` | iPad landscape, large | 2026-11-26T17:40:10Z | 2026-11-26T22:02:36Z | 1,656 | 1,320 | 168 | 132 | 12 | 24 |  |
| `pad-landscape-accessibility5` | iPad landscape, accessibility5 | 2026-11-26T22:02:36Z | 2026-11-27T04:35:55Z | 1,656 | 1,151 | 356 | 105 | 20 | 24 |  |
| `phone-accessibility5-rerun` | iPhone, accessibility5, CommentsSnapshotTests, FavoritesSnapshotTests, SettingsPagesMoreSnapshotTests | 2026-11-27T04:35:55Z | 2026-11-27T06:06:37Z | 526 | 348 | 131 | 47 | 0 | 0 | extra run 1 |
| `phone-accessibility5-rerun2-favorites` | iPhone landscape, ja-accessibility5, FavoritesSnapshotTests | 2026-11-27T06:08:17Z | 2026-11-27T06:17:16Z | 10 | 8 | 0 | 2 | 0 | 0 | extra run 2a |
| `phone-accessibility5-rerun2-site-settings` | iPhone landscape, de-accessibility5, SettingsPagesMoreSnapshotTests | 2026-11-27T06:17:16Z | 2026-11-27T06:26:20Z | 18 | 14 | 4 | 0 | 0 | 0 | extra run 2b |

Over the twelve runs that are inputs of the proposal (every row above except the interrupted one; where a later line
of a key replaces an earlier one, the later line counts) the 19,872 coordinates of the matrix each have one
line: 15,372 measured, 2,318 cannot-cover,
1,662 did-not-converge, 160 error and 360 notApplicable. The 19,872 coordinates of the
matrix less the 360 not applicable ones are the 19,512 pictures of `baseline2`.

### Notes of the runs (where they differ from the plan's steps 1 and 2)

1. **pad-landscape-xSmall was interrupted and started again.** It was first started 2026-11-25T19:39:20Z and
   interrupted at 2026-11-26 08:45:38 +0900 (2026-11-25T23:45:38Z): its `xcodebuild.log` ends with
   `** BUILD INTERRUPTED **` and it holds 1,537 of the 1,656 lines. The measuring process stopped with the earlier
   conversation; it was not a test failure. The partial run was moved, not deleted, to
   `$W/interrupted-pad-landscape-xSmall` (driver log `$W/interrupted-driver-pad-landscape-xSmall.log`), so it lies
   outside the proposal's input (`propose --runs "$W"/phone-* "$W"/pad-*` does not match it). The run was started
   again from the beginning as `pad-landscape-xSmall`, then `pad-landscape-large` and `pad-landscape-accessibility5`
   followed.
2. **phone-accessibility5 had 12 lines missing** (3,300 of 3,312), all landscape, in `CommentsSnapshotTests`,
   `FavoritesSnapshotTests` and `SettingsPagesMoreSnapshotTests`. Under step 1's rule (a run lost to the simulator is
   run again for that class only, once) those three classes were run once more for the six accessibility5
   configurations: `phone-accessibility5-rerun` (526 lines; 516 of its coordinates were also in the first run and 10
   were new). It recovered 10 of the 12.
3. **Two lines were still missing after that,** `favorites-category-menu__ja__accessibility5__landscape__iphone__dark`
   and `settings-pages-site-settings__de__accessibility5__landscape__iphone__dark`. Each was the last coordinate of a
   test that reached the 600 s cap (`-maximum-test-execution-time-allowance 600`, `Scripts/visual/run-shard.sh` line
   292, unchanged): the first run's `xcodebuild.log` holds 11 `600.000 seconds` test failures (`testMenu` 2,
   `testCategoryMenu` 6, `testSiteSettings` 3) and the rerun's holds 2 (`testSiteSettings` and `testCategoryMenu`).
   Under step 2's rule (run the missing classes and configurations once more) they were run once more with
   `--orientation landscape`, so each test measures 2 coordinates instead of 4:
   `phone-accessibility5-rerun2-favorites` (`ja` accessibility5, `FavoritesSnapshotTests`, 10 lines) and
   `phone-accessibility5-rerun2-site-settings` (`de` accessibility5, `SettingsPagesMoreSnapshotTests`, 18 lines).
   Both coordinates now have lines: the first `did-not-converge` (need 22655 pt, 12 steps), the second
   `cannot-cover:TextEditorTextView` (need 27293 pt, 7 steps).
4. **Differences between the lines of the same key.** The later line replaces the earlier one in `propose` (the
   order of the shell glob: `phone-accessibility5`, `-rerun`, `-rerun2-favorites`, `-rerun2-site-settings`, then
   `phone-large`, `phone-xSmall` and the iPad runs).
   - `phone-accessibility5-rerun` against `phone-accessibility5`, on the 516 coordinates both measured: 513 lines are
     identical in every field and three differ:

     | Key | `phone-accessibility5` | `phone-accessibility5-rerun` (replaces it) |
     | --- | --- | --- |
     | `favorites-category-menu__ja__accessibility5__landscape__iphone__light` | `error` (`settle-timeout`, 6284 pt, 4 steps) | `did-not-converge` (22655 pt, 12 steps) |
     | `favorites-category-menu__ko__accessibility5__portrait__iphone__light` | `did-not-converge`, needed 16493 pt | `did-not-converge`, needed 16615 pt |
     | `favorites-category-menu__zh-Hans__accessibility5__portrait__iphone__light` | `did-not-converge`, needed 16337 pt | `did-not-converge`, needed 16355 pt |

   - `phone-accessibility5-rerun2-favorites` (10 lines) against the lines in force after the rerun: 9 coordinates
     were measured before and all 9 lines are identical in every field (status, need, steps, reason), including
     `favorites-category-menu__ja__accessibility5__landscape__iphone__light`, which agrees with the rerun's
     `did-not-converge` line that had replaced the first run's `error`; 1 coordinate is new (the `ja` landscape dark
     line named above). No difference.
   - `phone-accessibility5-rerun2-site-settings` (18 lines) against the lines in force after the rerun: 17
     coordinates were measured before (16 in `phone-accessibility5`, and `settings-pages-site-settings__de__accessibility5__landscape__iphone__light`
     only in the rerun) and all 17 lines are identical in every field; 1 coordinate is new (the `de` landscape dark
     line named above). No difference.
   - The other eight runs measure other configurations, so no coordinate is in two of them.

## Proposal

```sh
python3 Scripts/visual/snapshot_heights.py propose --runs "$W"/phone-* "$W"/pad-* --out "$W/proposal.json"
```

It returned 0 (no missing coordinate) and printed `118 scenarios proposed, 4,140 findings`. The
proposal is `$W/proposal.json`; it is not regenerated here, and the verify command of Task 1 regenerates a separate
`proposal-check.json` and compares the two. Rule of `propose`: per scenario, family, orientation and text size, the
tallest need over the six languages and both themes, rounded up to whole points and never under the device height; a
group with a `cannot-cover`, `did-not-converge` or `error` line gets no value, and each such line is a finding.

| Number | Value |
| --- | ---: |
| States in the inventory | 138 |
| States with at least one value in the proposal | 118 |
| States with all twelve values (the ones `apply` accepts) | 84 |
| of which every value is the device height, so they stay `.screen` | 9 |
| of which at least one value is taller than the device, so they get committed heights | 75 |
| States with some of the twelve values (`apply` refuses them until their findings are decided) | 34 |
| States with no value at all | 20 |
| States with findings (the last two rows together) | 54 |
| Groups (state, family, orientation, text size) that are applicable | 1,626 |
| Groups with a value | 1,279 |
| Groups without a value (they hold a finding line) | 347 |
| Groups whose value is taller than the device | 665 |
| Groups whose value is above the render server's limit of 8191 device pixels (the sliced path), iPhone / iPad | 94 / 26 |

### States that stay `.screen`

9 states (all twelve values equal the device height): `front-page-loading`, `popular-loading`, `reader-horizontal`, `reader-live-text`, `reader-two-page-spread`, `blocked-users-empty`, `settings-pages-activity-logs-empty`, `settings-pages-laboratory`, `watched-signed-out`.

### States with committed heights

75 states. Each cell is the proposed height in points for the text sizes xSmall/large/accessibility5.
The device heights are iPhone portrait 912, iPhone landscape 420, iPad portrait 1210 and iPad landscape 834.

| State | iPhone portrait | iPhone landscape | iPad portrait | iPad landscape |
| --- | --- | --- | --- | --- |
| `comments-blocked-row-collapsed` | 1331/1544/7630 | 973/1134/4018 | 1210/1210/3762 | 1002/1057/2720 |
| `comments-blocked-row-shown` | 1453/1702/8890 | 1038/1235/4578 | 1210/1210/4258 | 1067/1136/3048 |
| `comments-list` | 1424/1664/8651 | 1009/1203/4391 | 1210/1210/4071 | 1038/1104/2913 |
| `detail-pages-detail-search-grid` | 1297/1314/5760 | 788/978/8291 | 1210/1210/8877 | 834/834/3593 |
| `detail-pages-detail-search-list` | 1188/1188/4445 | 1078/1078/1956 | 1210/1210/2373 | 1143/1143/2125 |
| `detail-pages-folder-manager` | 912/912/2208 | 629/656/1668 | 1210/1210/1684 | 834/834/1611 |
| `detail-pages-gallery-info` | 1365/1457/4581 | 1239/1305/2656 | 1272/1338/2652 | 1272/1338/2431 |
| `detail-pages-previews` | 1730/1748/2286 | 2754/2805/3390 | 1940/1973/2429 | 1323/1344/1648 |
| `detail-pages-previews-loading` | 1730/1748/2286 | 2754/2805/3390 | 1940/1973/2429 | 1323/1344/1648 |
| `detail-pages-torrents-empty` | 912/912/2208 | 629/656/1668 | 1210/1210/1684 | 834/834/1611 |
| `downloads-active-failed` | 1184/1190/4534 | 1126/1132/2442 | 1210/1210/3772 | 1139/1145/2577 |
| `downloads-empty` | 912/912/1202 | 420/420/754 | 1210/1210/2577 | 962/1007/2577 |
| `downloads-list` | 1184/1190/4534 | 1126/1132/2442 | 1210/1210/3773 | 1139/1145/2577 |
| `favorites-empty` | 912/912/942 | 420/420/559 | 1210/1210/2344 | 863/902/2344 |
| `favorites-grid` | 1237/1257/5447 | 799/992/8051 | 1393/1414/6204 | 863/909/9035 |
| `favorites-list` | 1184/1190/4506 | 1126/1132/2414 | 1210/1210/3808 | 1139/1145/2344 |
| `agewall-ticked` | 912/912/1729 | 497/515/1509 | 1210/1210/1547 | 834/834/1547 |
| `agewall-unticked` | 912/912/1729 | 497/515/1509 | 1210/1210/1547 | 834/834/1547 |
| `analytics-choice-basic` | 912/912/3631 | 650/747/2766 | 1210/1210/2806 | 834/834/2806 |
| `analytics-choice-full` | 912/912/3631 | 650/747/2766 | 1210/1210/2806 | 834/834/2806 |
| `analytics-choice-minimal` | 912/912/3631 | 650/747/2766 | 1210/1210/2806 | 834/834/2806 |
| `analytics-choice-none` | 912/912/3631 | 650/747/2766 | 1210/1210/2806 | 834/834/2806 |
| `front-page-empty` | 912/912/912 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `front-page-error` | 912/912/913 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `front-page-grid` | 1297/1314/5760 | 788/978/8291 | 1210/1210/8877 | 834/834/3593 |
| `front-page-list` | 1188/1188/4445 | 1078/1078/1956 | 1210/1210/2373 | 1143/1143/2125 |
| `gallery-detail-downloading` | 912/912/2208 | 629/656/1668 | 1210/1210/1684 | 834/834/1611 |
| `gallery-detail-error` | 912/912/1567 | 542/562/1164 | 1210/1210/1210 | 834/834/1180 |
| `gallery-detail-loaded` | 912/912/2208 | 629/656/1668 | 1210/1210/1684 | 834/834/1611 |
| `gallery-detail-loading` | 912/912/1567 | 542/562/1164 | 1210/1210/1210 | 834/834/1180 |
| `gallery-detail-rating` | 912/912/2319 | 672/705/1779 | 1210/1210/1794 | 834/834/1722 |
| `history-empty` | 912/912/1133 | 430/450/606 | 1210/1210/1210 | 834/834/834 |
| `history-grid` | 1344/1362/6001 | 835/1026/8428 | 1210/1210/9014 | 834/834/3678 |
| `history-list` | 1238/1252/4632 | 1128/1131/2415 | 1210/1210/2456 | 1193/1196/2132 |
| `home-error` | 912/943/2590 | 856/903/2874 | 1210/1210/2837 | 862/896/2371 |
| `home-loading` | 912/943/2590 | 856/903/2874 | 1210/1210/2837 | 862/896/2371 |
| `home-populated` | 1712/1757/4271 | 1656/1725/4352 | 1809/1858/4605 | 1800/1856/4139 |
| `popular-error` | 912/912/913 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `popular-grid` | 1297/1314/5760 | 788/978/8291 | 1210/1210/8877 | 834/834/3593 |
| `popular-list` | 1188/1188/4445 | 1078/1078/1956 | 1210/1210/2373 | 1143/1143/2125 |
| `reader-loading` | 4736/4736/4736 | 10424/10424/10424 | 9399/9399/9399 | 834/834/834 |
| `reader-page-failed` | 4736/4736/4736 | 10424/10424/10424 | 9399/9399/9399 | 834/834/834 |
| `reader-vertical` | 4672/4672/4672 | 10214/10214/10214 | 9265/9265/9265 | 13532/13532/13532 |
| `report-form-loading` | 1424/1664/8651 | 1009/1203/4391 | 1210/1210/4071 | 1038/1104/2913 |
| `report-form-sent` | 1424/1664/8651 | 1009/1203/4391 | 1210/1210/4071 | 1038/1104/2913 |
| `search-results-empty` | 912/912/912 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `search-results-error` | 912/912/913 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `search-results-grid` | 1345/1368/5894 | 836/1032/8425 | 1210/1210/9011 | 834/834/3727 |
| `search-results-list` | 1236/1242/4579 | 1126/1132/2090 | 1210/1210/2183 | 1191/1197/2183 |
| `blocked-users-filled` | 912/912/962 | 420/420/580 | 1210/1210/1210 | 834/834/834 |
| `settings-account-invalid-cookies` | 1005/1048/2610 | 930/973/1964 | 1210/1210/1954 | 962/1005/1954 |
| `settings-account-signed-out` | 912/912/2144 | 796/816/1622 | 1210/1210/1674 | 834/848/1674 |
| `settings-login-empty` | 912/912/912 | 420/420/596 | 1210/1210/1210 | 834/834/834 |
| `settings-login-error` | 912/912/912 | 420/420/597 | 1210/1210/1210 | 834/834/834 |
| `settings-login-filled` | 912/912/912 | 420/420/597 | 1210/1210/1210 | 834/834/834 |
| `settings-root` | 912/912/1038 | 633/633/850 | 1210/1210/1210 | 834/834/865 |
| `settings-pages-about` | 1799/1893/4321 | 1683/1778/3181 | 1759/1854/3227 | 1759/1854/3165 |
| `settings-pages-activity-logs` | 912/912/2301 | 510/526/1507 | 1210/1210/1596 | 834/834/1063 |
| `settings-pages-app-icon` | 912/912/1440 | 683/683/774 | 1210/1210/1210 | 834/834/834 |
| `settings-pages-appearance` | 912/912/1860 | 587/615/1223 | 1210/1210/1275 | 834/834/1144 |
| `settings-pages-download` | 912/912/1730 | 420/434/1018 | 1210/1210/1210 | 834/834/846 |
| `settings-pages-general-basic` | 912/939/3143 | 846/887/1989 | 1210/1210/1920 | 834/863/1746 |
| `settings-pages-general-full` | 912/912/2892 | 832/871/1839 | 1210/1210/1820 | 834/851/1646 |
| `settings-pages-general-minimal` | 912/912/2892 | 832/871/1839 | 1210/1210/1770 | 834/851/1646 |
| `settings-pages-reading` | 912/920/3237 | 777/815/2032 | 1210/1210/2086 | 834/845/1905 |
| `settings-pages-site-settings-error` | 912/912/912 | 420/420/460 | 1210/1210/1210 | 834/834/834 |
| `shell-library-sidebar` | 912/912/912 | 420/420/420 | 1210/1210/2344 | 863/902/2344 |
| `shell-library-title-menu` | 1184/1190/4506 | 1126/1132/2414 | 1210/1210/1210 | 834/834/834 |
| `toplists-error` | 912/912/913 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `toplists-grid` | 929/940/2987 | 435/530/4187 | 1210/1210/4523 | 834/834/2452 |
| `toplists-list` | 912/912/2347 | 598/598/1199 | 1210/1210/1210 | 834/834/1127 |
| `watched-empty` | 912/912/912 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `watched-error` | 912/912/913 | 420/420/594 | 1210/1210/1210 | 834/834/834 |
| `watched-grid` | 1297/1314/5760 | 788/978/8291 | 1210/1210/8877 | 834/834/3593 |
| `watched-list` | 1188/1188/4445 | 1078/1078/1956 | 1210/1210/2373 | 1143/1143/2125 |

### States with some values

34 states. A `-` is a group without a value because it holds a finding line (see the findings below).

| State | iPhone portrait | iPhone landscape | iPad portrait | iPad landscape |
| --- | --- | --- | --- | --- |
| `app-wide-app-alert` | -/-/- | -/-/- | 1210/1210/- | -/-/- |
| `comments-block-confirmation` | 1424/1665/- | 1009/1203/- | 1210/1210/- | 1038/1104/- |
| `comments-menu` | 1424/1664/- | 1009/1203/- | 1210/1210/- | 1038/1104/- |
| `comments-posting-warning` | 1737/1985/- | 1216/1410/- | 1210/1210/4386 | 1441/1507/- |
| `detail-pages-archives` | 912/912/2208 | 629/656/- | 1210/1210/- | 834/834/- |
| `detail-pages-archives-insufficient-funds` | 912/912/2208 | 629/656/- | 1210/1210/- | 834/834/- |
| `detail-pages-folder-delete-confirmation` | 912/912/- | 629/656/- | 1210/1210/1684 | 834/834/1611 |
| `detail-pages-new-dawn` | 912/912/2208 | 629/656/1668 | 1210/1210/- | 834/834/- |
| `detail-pages-tag-detail` | 912/912/2208 | 629/656/1668 | 1210/1210/- | 834/834/- |
| `detail-pages-torrents` | 912/912/2208 | 629/656/1668 | 1210/1210/- | 834/834/- |
| `downloads-delete-confirmation` | 1184/1190/- | 1126/1132/- | 1210/1210/3773 | 1139/1145/- |
| `downloads-grid` | 1256/1276/5477 | 811/1005/8081 | 1412/1432/5874 | 962/1007/- |
| `downloads-inspector` | 1184/1190/4534 | 1126/1132/2442 | -/-/- | -/-/- |
| `downloads-inspector-error` | 1184/1190/4534 | 1126/1132/2442 | -/-/- | -/-/- |
| `downloads-move-confirmation` | 1184/1190/- | 1126/1132/- | 1210/1210/3773 | 1139/1145/2577 |
| `favorites-category-menu` | 1184/-/- | 1126/-/- | 1210/1210/1210 | 834/834/834 |
| `favorites-signed-out` | 912/912/912 | 420/420/499 | 1210/1210/- | 863/902/- |
| `front-page-search` | 912/912/- | -/-/- | 1210/1210/1210 | 834/834/- |
| `gallery-detail-delete-download-confirmation` | 912/912/- | 629/656/- | 1210/1210/- | 834/834/- |
| `gallery-detail-retry-confirmation` | 912/912/- | 629/656/- | 1210/1210/1684 | 834/834/- |
| `gallery-detail-sheet` | 912/912/912 | 420/420/420 | -/-/- | -/-/- |
| `history-clear-confirmation` | 1238/1252/4632 | 1128/1131/- | 1210/1210/2456 | 1193/1196/2132 |
| `quick-search-date-seek` | 1188/1188/4445 | 1078/1078/1956 | 1210/1210/- | 1143/1143/- |
| `reader-controls` | -/-/- | -/-/- | -/-/- | 834/834/834 |
| `reader-settings-sheet` | 4666/4666/4666 | 10201/10201/10201 | -/-/- | -/-/- |
| `reader-slider-scrub` | -/-/- | -/-/- | -/-/- | 834/834/834 |
| `report-form-error-alert` | 1424/1664/- | 1009/1203/- | -/-/- | -/-/- |
| `report-form-unavailable` | 1424/1664/8651 | 1009/1203/4391 | 1210/1210/- | 1038/1104/- |
| `settings-account-logout-confirmation` | 1005/1048/2858 | 930/973/- | 1210/1210/2078 | 962/1005/1954 |
| `settings-account-signed-in` | 1005/1048/- | 930/973/- | 1210/1210/- | 962/1005/1954 |
| `settings-pages-activity-logs-run-picker` | 912/912/- | 510/526/- | 1210/1210/- | 834/834/- |
| `settings-pages-general-cache-confirmation` | 912/939/- | -/-/- | 1210/1210/- | 834/863/- |
| `settings-pages-general-translations-confirmation` | 1143/1199/- | -/-/- | 1210/1210/2367 | 1062/1123/- |
| `toplists-period-menu` | 912/912/- | 598/598/- | 1210/1210/- | 834/834/- |

### States with no value

20 states, every group of which holds a finding line: `app-wide-error-info`, `app-wide-toast-failure`, `app-wide-toast-success`, `comments-post-empty`, `comments-post-filled`, `quick-search-delete-confirmation`, `quick-search-empty`, `quick-search-filters`, `quick-search-filters-reset-confirmation`, `quick-search-list`, `quick-search-word-editor`, `report-form-filled`, `report-form-ready`, `report-form-sending`, `search-clear-confirmation`, `search-root-empty`, `search-root-history`, `search-typing-suggestions`, `settings-pages-site-settings`, `settings-pages-site-settings-confirmation`.

### The tallest values

Per family, orientation and text size, the tallest proposed height over every state that has a value there. The
values are the tallest of the six languages and both themes.

| Family | Orientation | Text size | Device height (pt) | Tallest proposed height (pt) | State |
| --- | --- | --- | ---: | ---: | --- |
| iPhone | portrait | xSmall | 912 | 4736 | `reader-loading`, `reader-page-failed` |
| iPhone | portrait | large | 912 | 4736 | `reader-loading`, `reader-page-failed` |
| iPhone | portrait | accessibility5 | 912 | 8890 | `comments-blocked-row-shown` |
| iPhone | landscape | xSmall | 420 | 10424 | `reader-loading`, `reader-page-failed` |
| iPhone | landscape | large | 420 | 10424 | `reader-loading`, `reader-page-failed` |
| iPhone | landscape | accessibility5 | 420 | 10424 | `reader-loading`, `reader-page-failed` |
| iPad | portrait | xSmall | 1210 | 9399 | `reader-loading`, `reader-page-failed` |
| iPad | portrait | large | 1210 | 9399 | `reader-loading`, `reader-page-failed` |
| iPad | portrait | accessibility5 | 1210 | 9399 | `reader-loading`, `reader-page-failed` |
| iPad | landscape | xSmall | 834 | 13532 | `reader-vertical` |
| iPad | landscape | large | 834 | 13532 | `reader-vertical` |
| iPad | landscape | accessibility5 | 834 | 13532 | `reader-vertical` |

## Findings

54 states hold findings of the proposal (4,140 lines), and 13 states of the
design's `.screen` list measured taller than the screen. One row per state and kind; the coordinates are written as
family and orientation, the text sizes, then the languages and themes of the lines (a locale list is shown only when
it is not all six); coordinates that differ in their languages or themes are joined with ` + `. `Values` are what the
lines record: for `cannot cover`, `cannot cover: keyboard`, `cannot cover: popover` and `did not converge` the need
at the step where the measuring stopped (`last need`), which is not a finished need (a scroll view that does not
follow the window, a keyboard, or a need that follows the window height), and the number of growth steps; for
`error` the reason classes; for `design lists .screen but measures taller` the tallest measured need in points,
rounded up and never under the device height, for the text sizes xSmall/large/accessibility5 of each family and
orientation that measured taller (`*` marks a group that also holds a finding line of another kind, so the proposal
gives it no value). No row has a picture, because the measuring mode takes none. The states that 19-30-SUMMARY.md carries to this plan (the `cannot-cover:popover` states, the
`did-not-converge` states whose need follows the window height, the `cannot-cover:TextEditorTextView` and iPad
`UpdateCoalescingCollectionView` states, `comments-posting-warning`) all appear below under their kind. How a centred
alert card sits lower in a taller window is visible only in a picture, so this record cannot show it.

Reading of design §2 for the first kind. Design §2 says "Pages that never scroll (reader, alerts, full-screen states)
declare `.screen`" and names categories, not states. For this table the list is read as: the nine states of the
`reader` group, the two alert states by name (`app-wide-app-alert`, `report-form-error-alert`) and the six
`first-launch` states, which are full-screen covers (`agewall-*`, `analytics-choice-*`): `reader-controls`, `reader-horizontal`, `reader-live-text`, `reader-loading`, `reader-page-failed`, `reader-settings-sheet`, `reader-slider-scrub`, `reader-two-page-spread`, `reader-vertical`, `app-wide-app-alert`, `report-form-error-alert`, `agewall-ticked`, `agewall-unticked`, `analytics-choice-basic`, `analytics-choice-full`, `analytics-choice-minimal`, `analytics-choice-none`. Of
them, the states that measured taller than the device at some coordinate are the first rows; the others measured
the device height everywhere they measured or hold only findings of another kind. The rows of the first kind are not
finding lines of the proposal (they were measured, so the proposal gives them values, which `apply` would write
unless the owner decides otherwise).

| Kind | States | Lines |
| --- | ---: | ---: |
| design lists .screen but measures taller | 13 | 1,038 (measured lines above the device height, not finding lines) |
| cannot cover | 32 | 1,545 |
| cannot cover: keyboard | 5 | 576 |
| cannot cover: popover | 6 | 197 |
| did not converge | 17 | 1,662 |
| error | 10 | 160 |
| the five kinds of the proposal together | 54 (a state can hold several kinds) | 4,140 |

| State | Kind | Coordinates (lines) | Values | Picture |
| --- | --- | --- | --- | --- |
| `reader-controls` | design lists .screen but measures taller | [iPad portrait: xSmall,large; iPhone landscape: xSmall] (de,ja,ko,zh-Hans,zh-Hant, both themes) + [iPhone landscape, iPad portrait: accessibility5; iPhone portrait: xSmall] (all 6 locales, both themes) + iPhone portrait: large (en,de,ja,ko,zh-Hans, both themes) + iPhone landscape: large (en,de,ja,zh-Hant, both themes) + iPhone portrait: accessibility5 (ja,ko,zh-Hans,zh-Hant, both themes) (69 lines) | iPhone portrait 4666*/4666*/4666*; iPhone landscape 10230*/10230*/10230*; iPad portrait 9265*/9265*/9265* | none |
| `reader-loading` | design lists .screen but measures taller | iPhone both orientations, iPad portrait: all sizes (all 6 locales, both themes) (108 lines) | iPhone portrait 4736/4736/4736; iPhone landscape 10424/10424/10424; iPad portrait 9399/9399/9399 | none |
| `reader-page-failed` | design lists .screen but measures taller | iPhone both orientations, iPad portrait: all sizes (all 6 locales, both themes) (108 lines) | iPhone portrait 4736/4736/4736; iPhone landscape 10424/10424/10424; iPad portrait 9399/9399/9399 | none |
| `reader-settings-sheet` | design lists .screen but measures taller | iPhone both orientations: all sizes (all 6 locales, both themes) (72 lines) | iPhone portrait 4666/4666/4666; iPhone landscape 10201/10201/10201 | none |
| `reader-slider-scrub` | design lists .screen but measures taller | [iPhone portrait: accessibility5; iPad portrait: xSmall] (en,ja,ko,zh-Hans, both themes) + iPhone portrait: xSmall,large (en,ja,ko,zh-Hans,zh-Hant, both themes) + iPad portrait: accessibility5 (all 6 locales, both themes) + iPhone landscape: accessibility5 (en,de,ja,ko,zh-Hant, both themes) + iPhone landscape: xSmall (en,de,ko,zh-Hans,zh-Hant, both themes) + iPhone landscape: large (en,de,ko,zh-Hant, both themes) + iPad portrait: large (ja,ko,zh-Hans,zh-Hant, both themes) (61 lines) | iPhone portrait 4672*/4672*/4672*; iPhone landscape 10230*/10230*/10230*; iPad portrait 9277*/9277*/9277* | none |
| `reader-vertical` | design lists .screen but measures taller | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | iPhone portrait 4672/4672/4672; iPhone landscape 10214/10214/10214; iPad portrait 9265/9265/9265; iPad landscape 13532/13532/13532 | none |
| `report-form-error-alert` | design lists .screen but measures taller | iPhone both orientations: xSmall,large (all 6 locales, both themes) + iPhone portrait: accessibility5 (zh-Hans,zh-Hant, both themes) (52 lines) | iPhone portrait 1424/1664/8495*; iPhone landscape 1009/1203/420* | none |
| `agewall-ticked` | design lists .screen but measures taller | [iPhone landscape: all sizes; iPhone portrait, iPad landscape: accessibility5] (all 6 locales, both themes) + iPad portrait: accessibility5 (en,de,ja,ko, both themes) (68 lines) | iPhone portrait 912/912/1729; iPhone landscape 497/515/1509; iPad portrait 1210/1210/1547; iPad landscape 834/834/1547 | none |
| `agewall-unticked` | design lists .screen but measures taller | [iPhone landscape: all sizes; iPhone portrait, iPad landscape: accessibility5] (all 6 locales, both themes) + iPad portrait: accessibility5 (en,de,ja,ko, both themes) (68 lines) | iPhone portrait 912/912/1729; iPhone landscape 497/515/1509; iPad portrait 1210/1210/1547; iPad landscape 834/834/1547 | none |
| `analytics-choice-basic` | design lists .screen but measures taller | [iPhone landscape: all sizes; iPhone portrait, iPad both orientations: accessibility5] (all 6 locales, both themes) (72 lines) | iPhone portrait 912/912/3631; iPhone landscape 650/747/2766; iPad portrait 1210/1210/2806; iPad landscape 834/834/2806 | none |
| `analytics-choice-full` | design lists .screen but measures taller | [iPhone landscape: all sizes; iPhone portrait, iPad both orientations: accessibility5] (all 6 locales, both themes) (72 lines) | iPhone portrait 912/912/3631; iPhone landscape 650/747/2766; iPad portrait 1210/1210/2806; iPad landscape 834/834/2806 | none |
| `analytics-choice-minimal` | design lists .screen but measures taller | [iPhone landscape: all sizes; iPhone portrait, iPad both orientations: accessibility5] (all 6 locales, both themes) (72 lines) | iPhone portrait 912/912/3631; iPhone landscape 650/747/2766; iPad portrait 1210/1210/2806; iPad landscape 834/834/2806 | none |
| `analytics-choice-none` | design lists .screen but measures taller | [iPhone landscape: all sizes; iPhone portrait, iPad both orientations: accessibility5] (all 6 locales, both themes) (72 lines) | iPhone portrait 912/912/3631; iPhone landscape 650/747/2766; iPad portrait 1210/1210/2806; iPad landscape 834/834/2806 | none |
| `app-wide-error-info` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `UpdateCoalescingCollectionView` 24; last need 1554 to 2418 pt; steps 1 to 2 | none |
| `comments-block-confirmation` | cannot cover | iPad landscape: accessibility5 (de,ja, both themes) + iPhone portrait: accessibility5 (en,de,ja,ko, both themes) + iPhone landscape: accessibility5 (all 6 locales, both themes) + iPad portrait: accessibility5 (ko,zh-Hans,zh-Hant, both themes) (30 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 30; last need 3347 to 9155 pt; steps 4 to 5 | none |
| `comments-posting-warning` | cannot cover | iPhone portrait, iPad landscape: accessibility5 (de,ja, both themes) + iPhone landscape: accessibility5 (all 6 locales, both themes) (20 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 20; last need 3518 to 9028 pt; steps 4 to 5 | none |
| `detail-pages-archives` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `HostingScrollView` 24; last need 3058 to 3434 pt; steps 1 | none |
| `detail-pages-archives-insufficient-funds` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `HostingScrollView` 24; last need 2788 to 3164 pt; steps 1 | none |
| `detail-pages-folder-delete-confirmation` | cannot cover | iPhone portrait: accessibility5 (en, both themes) + iPhone landscape: accessibility5 (all 6 locales, both themes) (14 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 14; last need 1899 to 2570 pt; steps 2 | none |
| `detail-pages-new-dawn` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `HostingScrollView` 24; last need 1780 to 2168 pt; steps 2 | none |
| `detail-pages-tag-detail` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `HostingScrollView` 24; last need 2128 to 2602 pt; steps 1 to 2 | none |
| `detail-pages-torrents` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `UpdateCoalescingCollectionView` 24; last need 2374 to 2498 pt; steps 2 | none |
| `downloads-delete-confirmation` | cannot cover | iPad landscape: accessibility5 (de,ja, both themes) + iPhone portrait: accessibility5 (en, both themes) (6 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 6; last need 2597 to 4310 pt; steps 4 to 5 | none |
| `downloads-inspector` | cannot cover | iPad both orientations: all sizes (all 6 locales, both themes) (72 lines) | scroll view: `UpdateCoalescingCollectionView` 72; last need 1277 to 4481 pt; steps 1 to 3 | none |
| `downloads-inspector-error` | cannot cover | iPad both orientations: all sizes (all 6 locales, both themes) (72 lines) | scroll view: `UpdateCoalescingCollectionView` 72; last need 1277 to 4480 pt; steps 1 to 3 | none |
| `gallery-detail-delete-download-confirmation` | cannot cover | iPhone landscape: accessibility5 (all 6 locales, both themes) + iPhone portrait: accessibility5 (ja, both themes) + iPad landscape: accessibility5 (ja,zh-Hans,zh-Hant, both themes) + iPad portrait: accessibility5 (ko,zh-Hans,zh-Hant, both themes) (26 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 26; last need 1562 to 2221 pt; steps 2 | none |
| `gallery-detail-retry-confirmation` | cannot cover | iPhone portrait, iPad landscape: accessibility5 (de,ja,ko, both themes) + iPhone landscape: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 24; last need 1646 to 2512 pt; steps 2 | none |
| `gallery-detail-sheet` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `HostingScrollView` 24; last need 2830 to 3656 pt; steps 1 | none |
| `history-clear-confirmation` | cannot cover | iPhone landscape: accessibility5 (ko,zh-Hans,zh-Hant, both themes) (6 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 6; last need 2397 to 2521 pt; steps 3 | none |
| `quick-search-date-seek` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `UpdateCoalescingCollectionView` 24; last need 2279 to 2805 pt; steps 2 | none |
| `quick-search-delete-confirmation` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) + iPhone landscape: accessibility5 (ko,zh-Hant, both themes) (28 lines) | scroll view: `UpdateCoalescingCollectionView` 24, `_UIInterfaceActionGroupHeaderScrollView` 4; last need 1321 to 1435 pt; steps 1 to 2 | none |
| `quick-search-filters` | cannot cover | iPad both orientations: all sizes (all 6 locales, both themes) (72 lines) | scroll view: `UpdateCoalescingCollectionView` 72; last need 1480 to 3572 pt; steps 1 | none |
| `quick-search-filters-reset-confirmation` | cannot cover | iPad both orientations: xSmall,large (all 6 locales, both themes) + iPad portrait: accessibility5 (en,ja,ko,zh-Hans,zh-Hant, both themes) + iPad landscape: accessibility5 (ja,ko,zh-Hans,zh-Hant, both themes) (65 lines) | scroll view: `UpdateCoalescingCollectionView` 65; last need 1480 to 4067 pt; steps 1 | none |
| `quick-search-list` | cannot cover | iPad both orientations: accessibility5 (all 6 locales, both themes) (24 lines) | scroll view: `UpdateCoalescingCollectionView` 24; last need 1321 to 1364 pt; steps 1 to 2 | none |
| `reader-settings-sheet` | cannot cover | iPad both orientations: all sizes (all 6 locales, both themes) (72 lines) | scroll view: `UpdateCoalescingCollectionView` 72; last need 1076 to 14536 pt; steps 1 to 3 | none |
| `report-form-error-alert` | cannot cover | [iPad both orientations: all sizes; iPhone landscape: accessibility5] (all 6 locales, both themes) + iPhone portrait: accessibility5 (en,de,ja,ko, both themes) (92 lines) | scroll view: `UpdateCoalescingCollectionView` 72, `_UIInterfaceActionGroupHeaderScrollView` 12, `_UIInterfaceActionRepresentationsSequenceView` 8; last need 1072 to 8881 pt; steps 1 to 5 | none |
| `report-form-filled` | cannot cover | [iPad both orientations: all sizes; iPhone landscape: accessibility5] (all 6 locales, both themes) + iPhone both orientations: xSmall,large (ja,ko,zh-Hans,zh-Hant, both themes) + iPhone portrait: accessibility5 (en,de, both themes) (120 lines) | scroll view: `UpdateCoalescingCollectionView` 72, `VerticalTextView` 48; last need 1011 to 8495 pt; steps 1 to 5 | none |
| `report-form-ready` | cannot cover | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | scroll view: `VerticalTextView` 92, `UpdateCoalescingCollectionView` 52; last need 1029 to 8843 pt; steps 1 to 5 | none |
| `report-form-sending` | cannot cover | [iPad both orientations: all sizes; iPhone landscape: accessibility5] (all 6 locales, both themes) + iPhone both orientations: xSmall,large (ja,ko,zh-Hans,zh-Hant, both themes) + iPhone portrait: accessibility5 (en,de, both themes) (120 lines) | scroll view: `UpdateCoalescingCollectionView` 72, `VerticalTextView` 48; last need 1011 to 8495 pt; steps 1 to 5 | none |
| `report-form-unavailable` | cannot cover | iPad both orientations: accessibility5 (en,de,ja,ko, both themes) (16 lines) | scroll view: `HostingScrollView` 16; last need 3117 to 4405 pt; steps 4 to 5 | none |
| `search-clear-confirmation` | cannot cover | iPhone landscape: accessibility5 (all 6 locales, both themes) (12 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 12; last need 1553 to 2157 pt; steps 2 | none |
| `settings-account-logout-confirmation` | cannot cover | iPhone landscape: accessibility5 (en,ko,zh-Hans, both themes) (6 lines) | scroll view: `_UIInterfaceActionGroupHeaderScrollView` 6; last need 2042 to 2290 pt; steps 5 | none |
| `settings-account-signed-in` | cannot cover | iPhone both orientations, iPad portrait: accessibility5 (all 6 locales, both themes) (36 lines) | scroll view: `VerticalTextView` 36; last need 2026 to 2858 pt; steps 4 to 6 | none |
| `settings-pages-site-settings` | cannot cover | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | scroll view: `TextEditorTextView` 144; last need 5431 to 44369 pt; steps 4 to 7 | none |
| `settings-pages-site-settings-confirmation` | cannot cover | [iPhone portrait, iPad both orientations: all sizes; iPhone landscape: xSmall,large] (all 6 locales, both themes) (132 lines) | scroll view: `TextEditorTextView` 132; last need 5431 to 44369 pt; steps 4 to 7 | none |
| `app-wide-app-alert` | cannot cover: keyboard | [iPhone both orientations: all sizes; iPad portrait: accessibility5] (all 6 locales, both themes) (84 lines) | last need 749 to 1994 pt; steps 0 | none |
| `comments-post-empty` | cannot cover: keyboard | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | last need 892 to 5018 pt; steps 0 | none |
| `comments-post-filled` | cannot cover: keyboard | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | last need 892 to 5018 pt; steps 0 | none |
| `front-page-search` | cannot cover: keyboard | [iPhone landscape: all sizes; iPhone portrait, iPad landscape: accessibility5] (all 6 locales, both themes) (60 lines) | last need 471 to 1310 pt; steps 0 | none |
| `search-typing-suggestions` | cannot cover: keyboard | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | last need 807 to 2155 pt; steps 0 | none |
| `downloads-delete-confirmation` | cannot cover: popover | iPhone landscape: accessibility5 (all 6 locales, both themes) + iPhone portrait: accessibility5 (ko,zh-Hant, both themes) (16 lines) | need at the first taller hosting 2442 to 3889 pt; steps 1 | none |
| `downloads-move-confirmation` | cannot cover: popover | iPhone landscape: accessibility5 (all 6 locales, both themes) + iPhone portrait: accessibility5 (ko,zh-Hant, both themes) (16 lines) | need at the first taller hosting 2442 to 3889 pt; steps 1 | none |
| `quick-search-filters-reset-confirmation` | cannot cover: popover | iPad both orientations: accessibility5 (en,de, both themes) + iPhone both orientations: accessibility5 (all 6 locales, both themes) (31 lines) | need at the first taller hosting 1985 to 4253 pt; steps 1 | none |
| `settings-pages-general-cache-confirmation` | cannot cover: popover | [iPhone landscape: all sizes; iPhone portrait, iPad landscape: accessibility5] (all 6 locales, both themes) + iPad portrait: accessibility5 (ja, both themes) (62 lines) | need at the first taller hosting 832 to 3143 pt; steps 1 | none |
| `settings-pages-general-translations-confirmation` | cannot cover: popover | [iPhone landscape: all sizes; iPhone portrait, iPad landscape: accessibility5] (all 6 locales, both themes) (60 lines) | need at the first taller hosting 1030 to 3179 pt; steps 1 | none |
| `settings-pages-site-settings-confirmation` | cannot cover: popover | iPhone landscape: accessibility5 (all 6 locales, both themes) (12 lines) | need at the first taller hosting 12833 to 13699 pt; steps 1 | none |
| `app-wide-error-info` | did not converge | [iPhone both orientations: all sizes; iPad both orientations: xSmall,large] (all 6 locales, both themes) (120 lines) | last need 1118 to 2318 pt; steps 12 | none |
| `app-wide-toast-failure` | did not converge | [iPhone landscape, iPad both orientations: all sizes; iPhone portrait: xSmall,large] (all 6 locales, both themes) + iPhone portrait: accessibility5 (de,zh-Hans,zh-Hant, both themes) (137 lines) | last need 1118 to 1777 pt; steps 12 | none |
| `app-wide-toast-success` | did not converge | [iPhone landscape, iPad both orientations: all sizes; iPhone portrait: xSmall,large] (all 6 locales, both themes) + iPhone portrait: accessibility5 (en,zh-Hans,zh-Hant, both themes) (138 lines) | last need 1118 to 1784 pt; steps 12 | none |
| `comments-menu` | did not converge | iPhone both orientations, iPad both orientations: accessibility5 (all 6 locales, both themes) (48 lines) | last need 3786 to 11046 pt; steps 12 | none |
| `favorites-category-menu` | did not converge | iPhone both orientations: large,accessibility5 (all 6 locales, both themes) (48 lines) | last need 1802 to 24257 pt; steps 12 | none |
| `gallery-detail-sheet` | did not converge | iPad both orientations: xSmall,large (all 6 locales, both themes) (48 lines) | last need 1250 to 1626 pt; steps 12 | none |
| `quick-search-delete-confirmation` | did not converge | [iPhone portrait: all sizes; iPhone landscape, iPad both orientations: xSmall,large] (all 6 locales, both themes) + iPhone landscape: accessibility5 (en,de,ja,zh-Hans, both themes) (116 lines) | last need 1087 to 1975 pt; steps 12 | none |
| `quick-search-empty` | did not converge | [iPhone both orientations, iPad landscape: all sizes; iPad portrait: xSmall,large] (all 6 locales, both themes) (127 lines) | last need 1074 to 1735 pt; steps 12 | none |
| `quick-search-filters` | did not converge | iPhone both orientations: all sizes (all 6 locales, both themes) (72 lines) | last need 1384 to 4065 pt; steps 12 | none |
| `quick-search-filters-reset-confirmation` | did not converge | iPhone both orientations: xSmall,large (all 6 locales, both themes) (48 lines) | last need 1384 to 1604 pt; steps 12 | none |
| `quick-search-list` | did not converge | [iPhone both orientations: all sizes; iPad both orientations: xSmall,large] (all 6 locales, both themes) (120 lines) | last need 1087 to 1975 pt; steps 12 | none |
| `quick-search-word-editor` | did not converge | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | last need 1087 to 1975 pt; steps 12 | none |
| `search-clear-confirmation` | did not converge | [iPhone portrait, iPad both orientations: all sizes; iPhone landscape: xSmall,large] (all 6 locales, both themes) (132 lines) | last need 1081 to 2280 pt; steps 12 | none |
| `search-root-empty` | did not converge | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | last need 1074 to 1735 pt; steps 12 | none |
| `search-root-history` | did not converge | iPhone both orientations, iPad both orientations: all sizes (all 6 locales, both themes) (144 lines) | last need 1081 to 2280 pt; steps 12 | none |
| `settings-pages-activity-logs-run-picker` | did not converge | iPhone both orientations, iPad both orientations: accessibility5 (all 6 locales, both themes) (48 lines) | last need 7789 to 12859 pt; steps 12 | none |
| `toplists-period-menu` | did not converge | iPad both orientations: accessibility5 (de, both themes) + iPhone both orientations: accessibility5 (all 6 locales, both themes) (28 lines) | last need 1085 to 2895 pt; steps 12 | none |
| `app-wide-app-alert` | error | iPad landscape: all sizes (all 6 locales, both themes) (36 lines) | reasons: `interaction:no-keyboard:announced-hidden` 18, `interaction:no-keyboard:never-announced` 18 | none |
| `app-wide-toast-failure` | error | iPhone portrait: accessibility5 (en,de,ja,ko, both themes) (7 lines) | reasons: `settle-timeout:pixels` 7; need when it stopped 1393 to 1745 pt | none |
| `app-wide-toast-success` | error | iPhone portrait: accessibility5 (de,ja,ko, both themes) (6 lines) | reasons: `settle-timeout:pixels` 6; need when it stopped 1366 to 1681 pt | none |
| `detail-pages-archives` | error | iPhone landscape: accessibility5 (ja,ko, dark only) (2 lines) | reasons: `freeze-changed-pixels` 2; need when it stopped 1667 pt | none |
| `detail-pages-archives-insufficient-funds` | error | iPhone landscape: accessibility5 (ko,zh-Hant, dark only) (2 lines) | reasons: `freeze-changed-pixels` 2; need when it stopped 1667 pt | none |
| `downloads-grid` | error | iPad landscape: accessibility5 (ja, dark only) (1 line) | reasons: `freeze-changed-pixels` 1; need when it stopped 9065 pt | none |
| `favorites-signed-out` | error | iPad portrait: accessibility5 (de, dark only) + iPad landscape: accessibility5 (zh-Hans,zh-Hant, dark only) (3 lines) | reasons: `freeze-changed-pixels` 3; need when it stopped 1538 to 1892 pt | none |
| `quick-search-empty` | error | iPad landscape: accessibility5 (en,de,ja,ko,zh-Hans, dark only) + iPad portrait: accessibility5 (all 6 locales, both themes) (17 lines) | reasons: `freeze-changed-pixels` 17; need when it stopped 1115 to 1371 pt | none |
| `reader-controls` | error | iPhone landscape: large (de,ja,ko,zh-Hans,zh-Hant, both themes) + iPhone landscape: accessibility5 (de,ko,zh-Hans, both themes) + iPad portrait: accessibility5 (de,zh-Hans, both themes) + iPad portrait: xSmall (all 6 locales, both themes) + iPhone portrait: accessibility5 (en,de,ja,zh-Hans, both themes) + iPhone portrait: xSmall (en,ja, dark only) + iPad portrait: large (en,ja, both themes) + iPhone portrait: large (en,ja,ko,zh-Hans,zh-Hant, both themes) + iPhone landscape: xSmall (en,ko, both themes) (39 lines) | reasons: `settle-timeout:pixels` 30, `freeze-changed-pixels` 9; need when it stopped 4666 to 10230 pt | none |
| `reader-slider-scrub` | error | iPhone portrait: accessibility5 (de,ja,ko,zh-Hans,zh-Hant, both themes) + iPhone portrait: xSmall (de,ja,zh-Hant, both themes) + iPhone landscape: accessibility5 (de,ko,zh-Hans, both themes) + iPhone landscape: xSmall (en,de,ja, both themes) + iPhone landscape: large (all 6 locales, both themes) + iPad portrait: xSmall (en,de,ja,ko,zh-Hant, both themes) + iPhone portrait: large (en,de,ja,zh-Hans, both themes) + iPad portrait: large (en,de,ja,zh-Hant, both themes) + iPad portrait: accessibility5 (ja,ko, both themes) (47 lines) | reasons: `settle-timeout:pixels` 34, `freeze-changed-pixels` 13; need when it stopped 4672 to 10230 pt | none |

## Storage projection

Method (plan 19-26, Task 1): for each of the 19,512 keys, the size of its `baseline2` file
(`.capture/agent-work/baseline2/set`, 19,512 pictures at the device height) times the committed height over the
device height of its family and orientation, summed. The committed height of a key is the proposal's value for its
state, family, orientation and text size. A group without a proposal value (a finding) is counted at the device height,
which is what a `viewport-exempt` answer would give it, so the total is a lower bound: a `commit-measured` answer for
such a state adds to it. File size is taken as proportional to height, as the plan prescribes.

- `baseline2` today: 4.937 GB (4.598 GiB), 19,512 pictures.
- Projected with the proposal: **7.877 GB** (7.336 GiB), a factor of 1.60. That is
  2.877 GB over 19-12's 5 GB line, so the storage choice of 19-12 Task 3 (keep git anyway, compressed release
  assets with the same fingerprints, or lossless PNG optimisation that changes no pixel) comes back to the owner.
- 14,988 pictures take a proposal value; 4,524 pictures (1.793 GB at the device height) lie in
  groups with findings and are counted at the device height.
- By family: iPhone 1.586 GB to 3.153 GB, iPad 3.352 GB to 4.723 GB.
- Slices (one per device and language, the unit of 19-12's one-commit-per-slice plan): the largest is
  `ipad/de` at 0.812 GB, so every slice stays under the 1.8 GB line.

| Slice | Pictures | baseline2 (GB) | Projected (GB) | Factor | Under 1.8 GB |
| --- | ---: | ---: | ---: | ---: | --- |
| `iphone/en` | 1,626 | 0.264 | 0.525 | 1.99 | yes |
| `iphone/de` | 1,626 | 0.278 | 0.549 | 1.97 | yes |
| `iphone/ja` | 1,626 | 0.271 | 0.539 | 1.99 | yes |
| `iphone/ko` | 1,626 | 0.253 | 0.503 | 1.99 | yes |
| `iphone/zh-Hans` | 1,626 | 0.259 | 0.516 | 1.99 | yes |
| `iphone/zh-Hant` | 1,626 | 0.261 | 0.521 | 1.99 | yes |
| `ipad/en` | 1,626 | 0.563 | 0.793 | 1.41 | yes |
| `ipad/de` | 1,626 | 0.579 | 0.812 | 1.40 | yes |
| `ipad/ja` | 1,626 | 0.570 | 0.803 | 1.41 | yes |
| `ipad/ko` | 1,626 | 0.542 | 0.764 | 1.41 | yes |
| `ipad/zh-Hans` | 1,626 | 0.546 | 0.771 | 1.41 | yes |
| `ipad/zh-Hant` | 1,626 | 0.552 | 0.779 | 1.41 | yes |
| all 12 | 19,512 | 4.937 | 7.877 | 1.60 | |

The states whose proposed heights add the most (projected size minus `baseline2` size):

| State | Added by its proposed heights (GB) |
| --- | ---: |
| `favorites-grid` | 0.162 |
| `reader-settings-sheet` | 0.092 |
| `downloads-move-confirmation` | 0.085 |
| `downloads-list` | 0.082 |
| `downloads-active-failed` | 0.082 |
| `favorites-list` | 0.080 |
| `analytics-choice-minimal` | 0.079 |
| `analytics-choice-basic` | 0.078 |
| `downloads-grid` | 0.077 |
| `analytics-choice-none` | 0.070 |
| `report-form-loading` | 0.065 |
| `report-form-sent` | 0.064 |

## Owner decisions

Task 2 ran in five rounds, the last on 2026-11-28, asked in Taiwanese Mandarin; the answers are quoted verbatim. The
evidence each round saw is in `.capture/agent-work/phase19-26` (local) and in `19-26-HANDOFF.md`.

### The answers

Round 1 (2026-11-27 at the latest), the four kinds of the plan's question:
- Kind 1 (states design §2 lists as `.screen` that measured taller): 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」
- Kinds 2 (cannot cover), 3 (keyboard), 4 (popover): 「給我看範例」 (baseline2 pictures were shown).

Round 2 (2026-11-27 at the latest), a message in place of the answers:
「sheet 的狀況應當測量 sheet 內容
alert 組件不需要測量，所以只確認到存在 alert 就足夠
網站設定你沒給我看到高度到極限無法判斷

第三類拍不到鍵盤的話可以不拍這個狀態

第四類已經拍到 popover 存在，為什麼還要拉高？」

Site settings, after a picture at 7,600 pt: 「整頁有拍到那 7,150 不就可以了嗎」

The role of the `page-height` check: 「page height check 應該是用來在制定 baseline 時輔助判斷的工具，而不是 gate 本身。baseline 確定以後就只有在拍攝新 snapshot 時才會用到了」; asked whether compare mode should fail, add a note or not check: 「比對時不判失敗，只記一筆提示（建議）」, superseded by 「snapshot testing 很單純，就是比較 snapshot diffs」, then 「但 baseline 必須覆蓋整頁 這樣才能捕捉到變化」.

Round 3 (2026-11-27), the `did not converge` and `error` kinds:
- `app-wide-app-alert`: 「當 alert，維持螢幕高（建議）」
- The menus: 「選單可以按你推薦處理」 (the recommendation: keep the screen height, the menu's presence is enough).
- The Search root's 32 pt padding outside its floor: 「app 的邏輯有問題嗎？」, then 「修 App（建議）」 (`86c47193b`).
- The dark-theme `freeze-changed-pixels`: 「先查清楚再定高度」, then 「改用靜止判斷的規則（建議）」 (`4a87dc8b3`).
- The Filters Reset dialog's state left set on dismissal: 「先修這個」 (`eb8f4ee04`).

Round 4 (2026-11-27), the sheet-content design: sheet height 「貼合內容（建議）」; `reader-settings-sheet` 「當 sheet，整個內容都拍（建議）」;
the go-ahead 「開始實作」 (`063a110d8`, fixed in `abd193abd` and `4a40eebfb`).

Round 5 (2026-11-28), the heights: after `heights-for-approval.md` (the states added or changed against `proposal.json` and the
decision behind every empty cell), 「核准，進入 Task 3（建議）」: `proposal-sheets.json` is approved.

### Per state

The owner's C4 verdict ("這個適用於所有頁面") applies the full-page height to every page. The states below that keep
the screen height amend it, each by the owner's words quoted for its group.

| Decision | States | Owner's words |
| --- | --- | --- |
| Screen height, check skipped (reader) | `reader-controls`, `reader-horizontal`, `reader-live-text`, `reader-loading`, `reader-page-failed`, `reader-slider-scrub`, `reader-two-page-spread`, `reader-vertical` | 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」 |
| Screen height, check skipped (alerts and confirmation dialogs, including the popover ones) | `app-wide-app-alert`, `comments-block-confirmation`, `comments-posting-warning`, `detail-pages-folder-delete-confirmation`, `downloads-delete-confirmation`, `downloads-move-confirmation`, `gallery-detail-delete-download-confirmation`, `gallery-detail-retry-confirmation`, `history-clear-confirmation`, `quick-search-delete-confirmation`, `quick-search-filters-reset-confirmation`, `report-form-error-alert`, `search-clear-confirmation`, `settings-account-logout-confirmation`, `settings-pages-general-cache-confirmation`, `settings-pages-general-translations-confirmation`, `settings-pages-site-settings-confirmation` | 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」; 「第四類已經拍到 popover 存在，為什麼還要拉高？」; `app-wide-app-alert` 「當 alert，維持螢幕高（建議）」 |
| Screen height, check skipped (menus) | `comments-menu`, `favorites-category-menu`, `toplists-period-menu`, `settings-pages-activity-logs-run-picker` | 「選單可以按你推薦處理」 |
| Removed from the matrix (keyboard) | `search-typing-suggestions`, `front-page-search`, `comments-post-empty`, `comments-post-filled` | 「第三類拍不到鍵盤的話可以不拍這個狀態」 |
| The page's own height, after the need ignores a text view's own content (re-measured in Task 3) | `settings-pages-site-settings`, `settings-account-signed-in`, `report-form-ready`, `report-form-filled`, `report-form-sending` | 「整頁有拍到那 7,150 不就可以了嗎」 |
| The sheet's content, fitted (re-measured) | the 30 sheet states of `19-26-HANDOFF.md`'s sheet re-measure, except those above | 「sheet 的狀況應當測量 sheet 內容」, 「貼合內容（建議）」, 「當 sheet，整個內容都拍（建議）」 |
| The proposal | every other state of the inventory | 「核准，進入 Task 3（建議）」 |

The `page-height` check runs only when a baseline or a new snapshot is taken (candidate mode); compare mode compares
pictures only (the check's role above). The first-launch states (`agewall-*`, `analytics-choice-*`) take their
measured heights, the default of C4, since no answer exempts them.
