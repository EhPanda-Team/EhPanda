# Phase 7 Privacy-Mask Root Inventory

This inventory is the durable D-16 coverage contract. A runtime root means the app root or the root
view returned by a production `.sheet` or `.fullScreenCover` presentation. Each root below maps to
one, and only one, executable `.privacyMask()` application.

The inventory enumerates 39 runtime roots: one app root and 38 production modal roots. The number 39
is derived from the `ROOT-*` rows below; it is not an independently maintained coverage target.

## Runtime roots and sole mask sites

| Root | Runtime root | Presentation modifier | Sole `.privacyMask()` application |
|------|--------------|-----------------------|-----------------------------------|
| ROOT-01 | App `TabView` root | — | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:68 |
| ROOT-02 | App-level New Dawn sheet | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:69 | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:71 |
| ROOT-03 | App-level Settings sheet | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:73 | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:78 |
| ROOT-04 | App-level gallery-detail sheet | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:80 | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:92 |
| ROOT-05 | Comments post/edit-comment sheet | AppPackage/Sources/DetailFeature/Comments/CommentsView.swift:83 | AppPackage/Sources/DetailFeature/Comments/CommentsView.swift:101 |
| ROOT-06 | Detail-search quick-search sheet | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:36 | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:44 |
| ROOT-07 | Detail-search filters sheet | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:46 | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:50 |
| ROOT-08 | Detail post-comment sheet | AppPackage/Sources/DetailFeature/DetailView.swift:179 | AppPackage/Sources/DetailFeature/DetailView.swift:194 |
| ROOT-09 | Detail New Dawn sheet | AppPackage/Sources/DetailFeature/DetailView.swift:196 | AppPackage/Sources/DetailFeature/DetailView.swift:198 |
| ROOT-10 | Detail tag-details sheet | AppPackage/Sources/DetailFeature/DetailView.swift:200 | AppPackage/Sources/DetailFeature/DetailView.swift:202 |
| ROOT-11 | Detail reader full-screen cover | AppPackage/Sources/DetailFeature/DetailView.swift:208 | AppPackage/Sources/DetailFeature/DetailView.swift:216 |
| ROOT-12 | Detail archives sheet | AppPackage/Sources/DetailFeature/DetailView.swift:218 | AppPackage/Sources/DetailFeature/DetailView.swift:229 |
| ROOT-13 | Detail torrents sheet | AppPackage/Sources/DetailFeature/DetailView.swift:232 | AppPackage/Sources/DetailFeature/DetailView.swift:241 |
| ROOT-14 | Detail folder-manager sheet | AppPackage/Sources/DetailFeature/DetailView.swift:243 | AppPackage/Sources/DetailFeature/DetailView.swift:248 |
| ROOT-15 | Detail system activity/share sheet | AppPackage/Sources/DetailFeature/DetailView.swift:250 | AppPackage/Sources/DetailFeature/DetailView.swift:252 |
| ROOT-16 | Preview-grid reader full-screen cover | AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift:65 | AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift:73 |
| ROOT-17 | Torrents system activity/share sheet | AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift:44 | AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift:46 |
| ROOT-18 | Download Inspector navigation-stack sheet | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:48 | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:54 |
| ROOT-19 | Downloads folder-manager sheet | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:56 | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:61 |
| ROOT-20 | Downloads reader full-screen cover | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:63 | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:71 |
| ROOT-21 | Favorites quick-search sheet | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:50 | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:58 |
| ROOT-22 | Favorites date-seek sheet | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:60 | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:70 |
| ROOT-23 | Frontpage filters sheet | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:32 | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:36 |
| ROOT-24 | Frontpage date-seek sheet | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:38 | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:48 |
| ROOT-25 | Popular filters sheet | AppPackage/Sources/HomeFeature/Popular/PopularView.swift:30 | AppPackage/Sources/HomeFeature/Popular/PopularView.swift:34 |
| ROOT-26 | Watched quick-search sheet | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:40 | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:48 |
| ROOT-27 | Watched filters sheet | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:50 | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:54 |
| ROOT-28 | Watched date-seek sheet | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:56 | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:66 |
| ROOT-29 | Reader settings sheet | AppPackage/Sources/ReadingFeature/ReadingView.swift:86 | AppPackage/Sources/ReadingFeature/ReadingView.swift:105 |
| ROOT-30 | Reader system activity/share sheet | AppPackage/Sources/ReadingFeature/ReadingView.swift:107 | AppPackage/Sources/ReadingFeature/ReadingView.swift:110 |
| ROOT-31 | Search-root filters sheet | AppPackage/Sources/SearchFeature/SearchRootView.swift:35 | AppPackage/Sources/SearchFeature/SearchRootView.swift:39 |
| ROOT-32 | Search-root quick-search sheet | AppPackage/Sources/SearchFeature/SearchRootView.swift:41 | AppPackage/Sources/SearchFeature/SearchRootView.swift:52 |
| ROOT-33 | Search-results quick-search sheet | AppPackage/Sources/SearchFeature/SearchView.swift:33 | AppPackage/Sources/SearchFeature/SearchView.swift:41 |
| ROOT-34 | Search-results filters sheet | AppPackage/Sources/SearchFeature/SearchView.swift:43 | AppPackage/Sources/SearchFeature/SearchView.swift:47 |
| ROOT-35 | Search-results date-seek sheet | AppPackage/Sources/SearchFeature/SearchView.swift:49 | AppPackage/Sources/SearchFeature/SearchView.swift:59 |
| ROOT-36 | Account web-view sheet | AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift:48 | AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift:51 |
| ROOT-37 | App-activity-log run-picker sheet | AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:49 | AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:51 |
| ROOT-38 | Host-settings web-view sheet | AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift:48 | AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift:51 |
| ROOT-39 | Login web-view sheet | AppPackage/Sources/SettingFeature/Login/LoginView.swift:69 | AppPackage/Sources/SettingFeature/Login/LoginView.swift:74 |

System activity/share sheets remain in the runtime inventory because their production presentation
roots are explicitly masked. They are not exclusions merely because their rendered content is
system-owned.

## Presentation-modifier exclusions

The source tree contains 41 `.sheet`/`.fullScreenCover` modifiers. Thirty-eight are the production
modal roots above. The remaining three are preview-only presentation harnesses and do not create
runtime app roots:

| Exclusion | Presentation modifier | Reason |
|-----------|-----------------------|--------|
| EXCLUSION-01 | AppPackage/Sources/AppComponents/NewDawnView.swift:174 | `NewDawnView_Previews` preview harness |
| EXCLUSION-02 | AppPackage/Sources/DetailFeature/Components/TagDetailView.swift:126 | `TagDetailView_Previews` preview harness |
| EXCLUSION-03 | AppPackage/Sources/ReadingFeature/ReadingView.swift:438 | `ReadingView_Previews` preview harness |

Thus the modifier reconciliation is `38 production modal roots + 3 preview exclusions = 41 source
presentation modifiers`. Adding the app root yields the 39 inventoried runtime roots.

## Expected executable mask counts by file

| File | Expected count |
|------|---------------:|
| AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift | 4 |
| AppPackage/Sources/DetailFeature/Comments/CommentsView.swift | 1 |
| AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift | 2 |
| AppPackage/Sources/DetailFeature/DetailView.swift | 8 |
| AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift | 1 |
| AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift | 1 |
| AppPackage/Sources/DownloadsFeature/DownloadsView.swift | 3 |
| AppPackage/Sources/FavoritesFeature/FavoritesView.swift | 2 |
| AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift | 2 |
| AppPackage/Sources/HomeFeature/Popular/PopularView.swift | 1 |
| AppPackage/Sources/HomeFeature/Watched/WatchedView.swift | 3 |
| AppPackage/Sources/ReadingFeature/ReadingView.swift | 2 |
| AppPackage/Sources/SearchFeature/SearchRootView.swift | 2 |
| AppPackage/Sources/SearchFeature/SearchView.swift | 3 |
| AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift | 1 |
| AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift | 1 |
| AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift | 1 |
| AppPackage/Sources/SettingFeature/Login/LoginView.swift | 1 |

## Re-runnable bijective audit

Run from the repository root:

```sh
set -eu

inventory=.planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md

# Derive the expected count from the enumerated runtime-root rows.
roots=$(grep -Ec '^\| ROOT-[0-9]+ \|' "$inventory")
mask_sites=$(sed -nE 's/^\| ROOT-[^|]*\|[^|]*\|[^|]*\| ([^ ]+) \|$/\1/p' "$inventory")
unique_mask_sites=$(printf '%s\n' "$mask_sites" | sort -u | wc -l | tr -d ' ')
root_presentations=$(sed -nE 's/^\| ROOT-[^|]*\|[^|]*\| ([^ ]+) \|[^|]*\|$/\1/p' "$inventory" \
    | grep -v '^—$')
excluded_presentations=$(sed -nE 's/^\| EXCLUSION-[^|]*\| ([^ ]+) \|.*$/\1/p' "$inventory")
inventory_presentations=$(printf '%s\n%s\n' "$root_presentations" "$excluded_presentations")
unique_inventory_presentations=$(printf '%s\n' "$inventory_presentations" | sort -u | wc -l | tr -d ' ')

# Count executable applications, excluding the API declaration and documentation token.
masks=$(grep -rn 'privacyMask()' AppPackage/Sources \
    | grep -v 'func privacyMask' \
    | grep -v 'AppSharedKeys' \
    | wc -l \
    | tr -d ' ')

presentations=$(grep -rEn '\.(sheet|fullScreenCover)[[:space:]]*\(' AppPackage/Sources \
    | wc -l \
    | tr -d ' ')
exclusions=$(grep -Ec '^\| EXCLUSION-[0-9]+ \|' "$inventory")
modal_roots=$((roots - 1))

test "$roots" -eq "$unique_mask_sites"
test "$masks" -eq "$roots"
test "$presentations" -eq "$((modal_roots + exclusions))"
test "$presentations" -eq "$unique_inventory_presentations"

# Every inventoried site must still be an executable application at the recorded source line.
printf '%s\n' "$mask_sites" | while IFS=: read -r source_file line; do
    sed -n "${line}p" "$source_file" | grep -q 'privacyMask()'
done

# Every presentation modifier must appear exactly once as a root or exclusion.
printf '%s\n' "$inventory_presentations" | while IFS=: read -r source_file line; do
    sed -n "${line}p" "$source_file" | grep -Eq '\.(sheet|fullScreenCover)[[:space:]]*\('
done

printf 'runtime roots=%s, unique mask sites=%s, executable masks=%s, presentations=%s, exclusions=%s\n' \
    "$roots" "$unique_mask_sites" "$masks" "$presentations" "$exclusions"
```

The invariant is bijective: the inventory has one unique source site per root, every recorded site
still contains an executable application, every executable application is accounted for by the same
derived total, and every presentation modifier is either a production modal root or a documented
preview exclusion. A duplicate mask or an uncovered root breaks the equality instead of being hidden
by a raw-count target.
