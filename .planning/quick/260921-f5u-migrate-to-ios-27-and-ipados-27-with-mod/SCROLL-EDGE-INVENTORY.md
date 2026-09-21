# iOS 27 page and scroll-edge inventory

All paths below are relative to `AppPackage/Sources/`. The fourth column records verified source coverage; runtime evidence is recorded separately in `260921-f5u-VERIFICATION.md`. Every row is required; multiple rows can inherit from one documented ancestor. A successful source scan alone does not prove a visible blur.

Apply `.scrollEdgeEffectStyle(.soft, for: .top)` directly to each app-owned page content root (inside its NavigationStack, and before presentation modifiers); native List/Form/ScrollView/TextEditor descendants inherit it. Use explicit page modifiers at presented roots because sheet/cover boundaries must not rely on ancestor propagation. Do not modify row atoms merely to satisfy a text count. The effect becomes visible only when native scrolling and edge geometry permit it. Non-scrolling states still carry the page policy. Keep horizontal carousels' other edges unchanged.

| Page | File | Actual host / required coverage | Implementation evidence |
|---|---|---|---|
| Home | `HomeFeature/HomeView.swift` | main ScrollView; Home tab and iPad root | HomeView.swift main NavigationStack ScrollView; direct host. |
| Frontpage | `HomeFeature/Frontpage/FrontpageView.swift` | GalleryList wrapper; detail and thumbnail hosts inherit | GalleryList.swift shared list/thumbnail content root; Frontpage inherits. |
| Popular | `HomeFeature/Popular/PopularView.swift` | GalleryList wrapper; both modes inherit | GalleryList.swift shared list/thumbnail content root; Popular inherits. |
| Watched | `HomeFeature/Watched/WatchedView.swift` | GalleryList plus logged-out/empty branch | GalleryList.swift logged-in host; Watched NotLoginView has its own modifier. |
| Toplists | `HomeFeature/Toplists/ToplistsView.swift` | GalleryList; each ranking selection | GalleryList.swift shared ranking content root; Toplists inherits. |
| History | `HomeFeature/History/HistoryView.swift` | GalleryList; populated and empty | GalleryList.swift shared history content root; History inherits. |
| Search root | `SearchFeature/SearchRootView.swift` | main ScrollView; suggestions and history | SearchRootView.swift NavigationStack suggestions ScrollView; direct host. |
| Search results | `SearchFeature/SearchView.swift` | GalleryList; query and focused search | GalleryList.swift shared results content root; SearchView inherits. |
| Favorites | `FavoritesFeature/FavoritesView.swift` | GalleryList and login-required branch; iPhone/iPad container | GalleryList.swift logged-in host; Favorites NotLoginView has its own modifier. |
| Downloads | `DownloadsFeature/DownloadsView.swift` | List and empty branch | DownloadsView.swift downloadsList inside GalleryNavigationContainer; direct host. |
| Download inspector | `DownloadsFeature/DownloadsView+Subviews.swift` | DownloadInspectorView List and operation/error states | DownloadsView+Subviews.swift DownloadInspectorView List/Group root; direct host. |
| Gallery detail | `DetailFeature/DetailView.swift` | main ScrollView; push and iPad modal | DetailView.swift main content ScrollView; modifier is inside the caller-owned navigation/presentation root. |
| Previews | `DetailFeature/Previews/PreviewsView.swift` | ScrollView | PreviewsView.swift page ScrollView; direct host. |
| Comments | `DetailFeature/Comments/CommentsView.swift` | List inside ScrollViewReader | CommentsView.swift page List/ScrollViewReader root; direct host. |
| Post/edit comment | `DetailFeature/Components/PostCommentView.swift` | TextEditor native scroll host in sheet | PostCommentView.swift TextEditor scroll host; direct host. |
| Gallery information | `DetailFeature/GalleryInfos/GalleryInfosView.swift` | List | GalleryInfosView.swift page List root; direct host. |
| Detail search | `DetailFeature/DetailSearch/DetailSearchView.swift` | GalleryList; both modes | GalleryList.swift shared detail-search list/thumbnail root; inherits. |
| Archives | `DetailFeature/Archives/ArchivesView.swift` | both ScrollView layouts: fitting card layout and AX scroll layout | ArchivesView.swift pinned and scrolling ScrollView layouts; both direct hosts. |
| Torrents | `DetailFeature/Torrents/TorrentsView.swift` | List in sheet NavigationStack | TorrentsView.swift List and ActivityView presentation roots; direct hosts. |
| Tag detail | `DetailFeature/Components/TagDetailView.swift` | vertical ScrollView; horizontal image strip inherits | TagDetailView.swift vertical ScrollView inside NavigationStack; direct host. |
| Folder manager | `DetailFeature/FolderManager/FolderManagerView.swift` | List in sheet | FolderManagerView.swift sheet List root; direct host. |
| Filters | `FiltersFeature/FiltersView.swift` | Form | FiltersView.swift Form root; direct host. |
| Date seek | `DateSeekFeature/DateSeekPickerView.swift` | Form | DateSeekPickerView.swift Form root; direct host. |
| Quick search | `QuickSearchFeature/QuickSearchView.swift` | list and scrolling suggestions branches | QuickSearchView.swift list page root; direct host. |
| Quick-search word editor | `QuickSearchFeature/QuickSearchView.swift` | EditWordView Form destination | QuickSearchView.swift EditWordView Form destination; direct host. |
| Reader horizontal | `ReadingFeature/ReadingView.swift` | horizontalPagingList ScrollView plus reader page root | ReadingView.swift page root and horizontalPagingList ScrollView; direct hosts. |
| Reader vertical | `ReadingFeature/Support/AdvancedList.swift` | native vertical ScrollView; no app-owned UIScrollView bridge found | AdvancedList.swift vertical ScrollView; direct host. |
| Reader settings sheet | `ReadingSettingFeature/ReadingSettingView.swift` | Form; shared with Settings navigation | ReadingSettingView.swift Form root; direct host. |
| Settings | `SettingFeature/SettingView.swift` | main ScrollView; tab and iPad sheet | SettingView.swift main content ScrollView; direct host. |
| Account settings | `SettingFeature/AccountSetting/AccountSettingView.swift` | Form | AccountSettingView.swift Form and WebView sheet root; direct hosts. |
| Login | `SettingFeature/Login/LoginView.swift` | Login form responsive scrolling branch and fixed branch; web sheet wrappers | LoginView.swift form branches and web/challenge presentation roots; direct hosts. |
| Web login | `SettingFeature/Components/WebView.swift` | WKWebView.scrollView.topEdgeEffect.style = .soft; SwiftUI page root at presentation | WebView.swift owns the UIKit property; AccountSettingView/EhSettingView/LoginView apply the SwiftUI presentation-root modifier. |
| Web challenge | `SettingFeature/Components/ChallengeWebView.swift` | WKWebView.scrollView.topEdgeEffect.style = .soft; SwiftUI page root at presentation | ChallengeWebView.swift owns the UIKit property; LoginView applies the SwiftUI challenge presentation-root modifier. |
| General settings | `SettingFeature/GeneralSetting/GeneralSettingView.swift` | Form; system file importer | GeneralSettingView.swift Form root; direct host. File importer internals remain system-owned. |
| Activity logs | `SettingFeature/AppActivityLogs/AppActivityLogsView.swift` | main List | AppActivityLogsView.swift main List root; direct host. |
| Activity log run picker | `SettingFeature/AppActivityLogs/AppActivityLogsView.swift` | RunPickerSheet List in NavigationStack | AppActivityLogsView.swift RunPickerSheet NavigationStack List; direct host. |
| Appearance settings | `SettingFeature/AppearanceSetting/AppearanceSettingView.swift` | Form | AppearanceSettingView.swift Form root; direct host. |
| App icon picker | `SettingFeature/AppearanceSetting/AppearanceSettingView.swift` | AppIconView Form | AppearanceSettingView.swift AppIconView Form root; direct host. |
| Reading settings | `ReadingSettingFeature/ReadingSettingView.swift` | Form; Settings presentation | ReadingSettingView.swift Form root; direct host. |
| Download settings | `SettingFeature/Components/DownloadSettingView.swift` | Form | DownloadSettingView.swift Form root; direct host. |
| Laboratory settings | `SettingFeature/Components/LaboratorySettingView.swift` | ScrollView | LaboratorySettingView.swift ScrollView root; direct host. |
| About | `SettingFeature/Components/AboutView.swift` | Form | AboutView.swift Form root; direct host. |
| Site settings | `SettingFeature/EhSetting/EhSettingView.swift` | Form with menu/inline/segmented pickers; no additional pushed picker pages | EhSettingView.swift Form and WebView sheet root; direct hosts. |
| New Dawn | `AppComponents/NewDawnView.swift` | ScrollView with min-height and based-on-size bounce behavior | NewDawnView.swift single ScrollView content root; direct host. |
| Error information | `AppComponents/ErrorInfoView.swift` | Form in sheet | ErrorInfoView.swift sheet NavigationStack Form root; direct host. |
| System share sheet | `AppComponents/ActivityView.swift` | UIActivityViewController is system-owned; apply SwiftUI presentation-root modifier, no subview traversal | ReadingView/DetailView/TorrentsView ActivityView presentation roots; UIKit internals remain system-owned. |

## Discovery closure

Source discovery reconciled runtime navigation and presentations with the inventory, excluding previews and row-only components. Every inventoried app-owned scrolling page has the native soft/top modifier directly or through an identified content ancestor. GalleryList covers both detail and thumbnail List hosts. Settings' eleven enum-driven destinations and GalleryPath's five destinations are covered independently of their navigation containers. Site Settings pickers use menu/inline styles, with segmented controls where specified; no additional pushed picker pages exist. No runtime NavigationLink or popover was found. Native web authentication views configure their owned WKWebView scroll views. System share sheets and General Settings' file importer remain system-owned; their internal scrolling is not inspected or modified. This establishes source coverage only; visual effect, accessibility and interaction verification remain separate acceptance checks.

The App shell only hosts RootView and the inventoried tabs. The Share extension's handoff controller creates no content UI or scrolling host, so it adds no page to this inventory.

The reader currently uses native SwiftUI horizontal ScrollView and AdvancedList vertical ScrollView. The repository scan found WKWebView as the app-owned UIKit scroll-host bridge; do not invent a reader UIScrollView bridge. The existing web controllers implement cookie/clearance navigation protocols; preserve those protocols while setting their native top-edge style. UIActivityViewController owns its internal scrolling: document its system-managed effect separately and never introspect its private view hierarchy.

## Source audit

| Source | Requirement / constraint | Task | Status |
|---|---|---|---|
| GOAL | User request: iOS/iPadOS 27 modernization with behavior parity | 1–3 | COVERED |
| REQ | Minimum supported OS 27, selected Swift 6.4, CI and six READMEs consistent | 1 | COVERED |
| REQ | Latest applicable API replacements, including native overflow | 2 | COVERED |
| REQ | Soft top scroll edge on every page; AGENTS policy | 1–2 | COVERED |
| REQ | Tests run before refactoring and again after fixes on phone/tablet | 1, 3 | FeatureTests and migration UI cases passed on both devices; existing iPad W-38 remains carried. See verification record. |
| CONTEXT | No migration workarounds/bypasses; exact-plan executor checkpoint contract | all | COVERED |
| CONTEXT | Preserve inlineLarge roots, dialog anchors, localization, download invariants | 2–3 | COVERED |
| RESEARCH | Installed SDK and official docs confirm ToolbarOverflowMenu, priority, ContentBuilder, status-bar API, inherited scroll effect | 2 | COVERED |
| RESEARCH | Xcode27 dedicated CI runner exists; remote trust provisioning unverified | 1 | COVERED with explicit checkpoint |

This QUICK task has no roadmap-assigned requirement IDs, CONTEXT.md or RESEARCH.md. User requirements are identified as QUICK-27-01 through QUICK-27-05 in the plan; no existing phase requirements are claimed or changed.
