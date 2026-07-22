# Phase 7 Privacy-Mask Root Inventory

This inventory is the durable D-16 coverage contract. A runtime root means the app root or the root
view returned by a production `.sheet` or `.fullScreenCover` presentation. Each root below maps to
one, and only one, executable `.privacyMask()` application.

The inventory enumerates 42 runtime roots: one app root and 41 production modal roots. The number 42
is derived from the `ROOT-*` rows below; it is not an independently maintained coverage target.

## Runtime roots and sole mask sites

| Root | Runtime root | Presentation modifier | Sole `.privacyMask()` application |
|------|--------------|-----------------------|-----------------------------------|
| ROOT-01 | App `TabView` root | — | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:67 |
| ROOT-02 | App-level New Dawn sheet | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:68 | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:70 |
| ROOT-03 | App-level error-info sheet | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:72 | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:74 |
| ROOT-04 | App-level Settings sheet | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:76 | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:80 |
| ROOT-05 | App-level gallery-detail sheet | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:82 | AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:93 |
| ROOT-06 | Comments post/edit-comment sheet | AppPackage/Sources/DetailFeature/Comments/CommentsView.swift:98 | AppPackage/Sources/DetailFeature/Comments/CommentsView.swift:114 |
| ROOT-07 | Detail-search quick-search sheet | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:31 | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:38 |
| ROOT-08 | Detail-search filters sheet | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:40 | AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift:44 |
| ROOT-09 | Detail post-comment sheet | AppPackage/Sources/DetailFeature/DetailView.swift:180 | AppPackage/Sources/DetailFeature/DetailView.swift:193 |
| ROOT-10 | Detail New Dawn sheet | AppPackage/Sources/DetailFeature/DetailView.swift:195 | AppPackage/Sources/DetailFeature/DetailView.swift:197 |
| ROOT-11 | Detail tag-details sheet | AppPackage/Sources/DetailFeature/DetailView.swift:199 | AppPackage/Sources/DetailFeature/DetailView.swift:201 |
| ROOT-12 | Detail reader full-screen cover | AppPackage/Sources/DetailFeature/DetailView.swift:207 | AppPackage/Sources/DetailFeature/DetailView.swift:211 |
| ROOT-13 | Detail archives sheet | AppPackage/Sources/DetailFeature/DetailView.swift:213 | AppPackage/Sources/DetailFeature/DetailView.swift:223 |
| ROOT-14 | Detail torrents sheet | AppPackage/Sources/DetailFeature/DetailView.swift:226 | AppPackage/Sources/DetailFeature/DetailView.swift:234 |
| ROOT-15 | Detail folder-manager sheet | AppPackage/Sources/DetailFeature/DetailView.swift:236 | AppPackage/Sources/DetailFeature/DetailView.swift:240 |
| ROOT-16 | Detail system activity/share sheet | AppPackage/Sources/DetailFeature/DetailView.swift:242 | AppPackage/Sources/DetailFeature/DetailView.swift:244 |
| ROOT-17 | Preview-grid reader full-screen cover | AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift:56 | AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift:60 |
| ROOT-18 | Torrents system activity/share sheet | AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift:50 | AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift:52 |
| ROOT-19 | Download Inspector navigation-stack sheet | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:34 | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:40 |
| ROOT-20 | Downloads folder-manager sheet | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:42 | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:46 |
| ROOT-21 | Downloads reader full-screen cover | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:48 | AppPackage/Sources/DownloadsFeature/DownloadsView.swift:52 |
| ROOT-22 | Favorites quick-search sheet | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:55 | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:62 |
| ROOT-23 | Favorites date-seek sheet | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:64 | AppPackage/Sources/FavoritesFeature/FavoritesView.swift:73 |
| ROOT-24 | Frontpage filters sheet | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:32 | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:36 |
| ROOT-25 | Frontpage date-seek sheet | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:38 | AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift:47 |
| ROOT-26 | Popular filters sheet | AppPackage/Sources/HomeFeature/Popular/PopularView.swift:30 | AppPackage/Sources/HomeFeature/Popular/PopularView.swift:34 |
| ROOT-27 | Watched quick-search sheet | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:45 | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:52 |
| ROOT-28 | Watched filters sheet | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:54 | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:58 |
| ROOT-29 | Watched date-seek sheet | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:60 | AppPackage/Sources/HomeFeature/Watched/WatchedView.swift:69 |
| ROOT-30 | Reader settings sheet | AppPackage/Sources/ReadingFeature/ReadingView.swift:83 | AppPackage/Sources/ReadingFeature/ReadingView.swift:100 |
| ROOT-31 | Reader system activity/share sheet | AppPackage/Sources/ReadingFeature/ReadingView.swift:102 | AppPackage/Sources/ReadingFeature/ReadingView.swift:104 |
| ROOT-32 | Search-root filters sheet | AppPackage/Sources/SearchFeature/SearchRootView.swift:35 | AppPackage/Sources/SearchFeature/SearchRootView.swift:39 |
| ROOT-33 | Search-root quick-search sheet | AppPackage/Sources/SearchFeature/SearchRootView.swift:41 | AppPackage/Sources/SearchFeature/SearchRootView.swift:51 |
| ROOT-34 | Search-results quick-search sheet | AppPackage/Sources/SearchFeature/SearchView.swift:33 | AppPackage/Sources/SearchFeature/SearchView.swift:40 |
| ROOT-35 | Search-results filters sheet | AppPackage/Sources/SearchFeature/SearchView.swift:42 | AppPackage/Sources/SearchFeature/SearchView.swift:46 |
| ROOT-36 | Search-results date-seek sheet | AppPackage/Sources/SearchFeature/SearchView.swift:48 | AppPackage/Sources/SearchFeature/SearchView.swift:57 |
| ROOT-37 | Account web-view sheet | AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift:52 | AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift:55 |
| ROOT-38 | App-activity-log run-picker sheet | AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:53 | AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:55 |
| ROOT-39 | Host-settings web-view sheet | AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift:44 | AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift:47 |
| ROOT-40 | Login web-view sheet | AppPackage/Sources/SettingFeature/Login/LoginView.swift:73 | AppPackage/Sources/SettingFeature/Login/LoginView.swift:78 |
| ROOT-41 | Login Cloudflare challenge sheet (`ChallengeWebView`) | AppPackage/Sources/SettingFeature/Login/LoginView.swift:84 | AppPackage/Sources/SettingFeature/Login/LoginView.swift:96 |
| ROOT-42 | Login error-info sheet | AppPackage/Sources/SettingFeature/Login/LoginView.swift:98 | AppPackage/Sources/SettingFeature/Login/LoginView.swift:100 |

System activity/share sheets remain in the runtime inventory because their production presentation
roots are explicitly masked. They are not exclusions merely because their rendered content is
system-owned.

## Presentation-modifier exclusions

The source tree contains 43 `.sheet`/`.fullScreenCover` modifiers. Forty-one are the production
modal roots above. The remaining two are preview-only presentation harnesses and do not create
runtime app roots:

| Exclusion | Presentation modifier | Reason |
|-----------|-----------------------|--------|
| EXCLUSION-01 | AppPackage/Sources/DetailFeature/Components/TagDetailView.swift:134 | `TagDetailView` "Loaded" preview harness |
| EXCLUSION-02 | AppPackage/Sources/ReadingFeature/ReadingView.swift:459 | `ReadingView` "Loaded" preview harness |

Thus the modifier reconciliation is `41 production modal roots + 2 preview exclusions = 43 source
presentation modifiers`. Adding the app root yields the 42 inventoried runtime roots.

## Expected executable mask counts by file

| File | Expected count |
|------|---------------:|
| AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift | 5 |
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
| AppPackage/Sources/SettingFeature/Login/LoginView.swift | 3 |

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

## Reconciliation history

The document is a live contract against the tree, so every recorded `file:line` is re-derived
whenever the audit is re-run rather than being carried forward:

- **Phase 7 (07-11):** 39 runtime roots, 41 presentation modifiers, 3 preview exclusions.
- **Phase 12 (12-06):** 42 runtime roots, 43 presentation modifiers, 2 preview exclusions. Two roots
  are new this phase — the login Cloudflare challenge sheet (ROOT-41) and the login error-info sheet
  (ROOT-42). Two further corrections were required for the audit to hold: the app-level error-info
  sheet (ROOT-03) shipped in Phase 9 and had never been recorded, and the New Dawn preview harness
  stopped being a `.sheet` presentation when Phase 10 migrated `PreviewProvider` to `#Preview`, so it
  is no longer an exclusion. Every `file:line` in the tables above was re-derived from the current
  tree; the Phase 7 line numbers had drifted throughout.
