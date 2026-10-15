# Favorites、Search、Downloads 寬螢幕提案

2026-10-15。依據 `app-resizability` 與 `iphone-duo` skills、現有程式，以及原生 SwiftUI 模擬器實測。

截圖來自獨立原型，使用示例資料與封面佔位圖；沒有套用到正式 App。此輪驗證原生容器的靜態佈局，尚未驗證完整的資料流、旋轉／折疊連續操作或輔助使用矩陣。

## 建議

| 頁面 | A：建議方向 | B：替代方向 | 取捨 |
|---|---|---|---|
| Favorites | 收藏清單＋所選畫廊詳情，採 `NavigationSplitView` | 收藏分類側欄＋畫廊網格 | A 適合逐本看標籤、預覽、決定閱讀；B 適合頻繁切分類及大量掃封面，但詳細內容需要再開啟。 |
| Search | 搜尋條件／Quick Search＋結果，採 `NavigationSplitView` | 結果清單＋畫廊詳情，篩選維持 sheet | A 適合反覆調整條件；B 適合條件已確定、逐一查看結果。 |
| Downloads | 下載清單＋可收合的原生 `.inspector` | 資料夾側欄＋下載清單，狀態維持 sheet | A 可一邊看隊列、一邊暫停或檢查頁面；B 適合整理資料夾，但仍需來回開啟狀態。 |

Favorites 的 A、B 都合理，建議先選 A；若使用時以掃封面及分類切換為主，B 會更合適。Search、Downloads 建議 A。不要把三頁都固定成同一種左右各半的結構。

## 現有實作與變更範圍

- Favorites 已有分類、排序、原生搜尋與兩種畫廊顯示模式。分類目前在選單，畫廊詳情沿導航路徑開啟。提案保留這些功能，只改寬畫面承載方式。
- Search 現在先顯示建議／歷史，送出後 push 結果。A 將結果留在右欄，左欄保留條件與快捷搜尋；沒有查詢時仍顯示歷史／建議。改動條件後按 Search 才發出請求，不在每個 toggle 後自動連線，也不默默更動 Global／Watched 篩選範圍。
- Downloads 已有獨立的 `DownloadInspectorView`，目前以 sheet 呈現。最值得先做的是把它接到原生 inspector。點下載列仍直接閱讀；獨立的資訊按鈕選擇 inspector 對象。畫面中的 inspector 是已開啟狀態，並非要求進頁時一律占用空間。
- `GalleryList` 的 thumbnail 模式已會依可用空間增加欄數。主要機會在導航與資訊分工，不能把既有網格當成完全不支援寬度。正式版本保留 detail／thumbnail 設定；截圖只展示各方案較容易理解的一種。

來源：`AppPackage/Sources/FavoritesFeature/FavoritesView.swift`、`SearchFeature/SearchRootView.swift`、`SearchFeature/SearchView.swift`、`DownloadsFeature/DownloadsView.swift`、`DownloadsFeature/DownloadsView+Subviews.swift`、`GalleryListComponents/GalleryList.swift`。

## 兩份 skill 對方案的具體影響

1. **以目前視圖的可用空間決定佈局。** 依本地 size class、容器 bounds 及各邊 safe area；不以裝置型號或 `UIDevice.current.orientation` 推論寬度。保留使用者要求的橫向雙欄產品條件，同時讓 iPad 狹窄視窗退回單欄。
2. **讓原生容器管理導航與工具列。** 最終原型以 `NavigationSplitView` 取代兩個獨立 `NavigationStack` 並排。Duo 的 sidebar 保留水平控制，最右內容採垂直工具列；不藉停用垂直 bars 改變 tab bar 位置。
3. **把欄位與 sheet 分開設計。** 常駐詳情、可收合 inspector、modal sheet 是不同用途。左欄觸發 sheet 時指定右側，右欄觸發時指定左側；這需要明確的來源狀態與 `presentationPlacement`，不是 split view 的預設行為。popover／confirmation dialog 仍錨定觸發控制。
4. **摺線位置來自 reserved regions。** Duo 原型的裝飾摺線讀取 `.division`，包含 inactive region，便於全展開時維持視覺位置。iPad 採普通分隔線。原生 inspector 本身是輔助欄，不能因為它出現在右方就宣稱是沿摺線分半。
5. **不要在 resize 時重建整套導航。** 正式實作應由穩定的上層 feature 保存查詢、選取、路徑、載入結果與捲動位置；以原生欄位收合／展開調整呈現，不因尺寸變化重發搜尋或建立第二份下載狀態。
6. **ArrangementView 有明確邊界。** iOS 27.1 的 arrangement 適合兩個相關內容區的自動排列；導航容器放在它外面，也不把它塞進 List／ScrollView。它不會自動處理導航、選取或反側 sheet。若產品要求 Downloads 的兩邊永遠是沿 hinge 分開的同等 pane，就要另做 arrangement 方案並驗證，不能把 inspector 的寬度偏好當作保證。

目前 App 已宣告 launch screen、iPad 四個方向，沒有 `UIRequiresFullScreen`；此次未更動 plist 或 build settings。這些基礎條件通過，不代表三頁的完整 resize 行為已通過驗證。

## 原生實測與尚待驗證

已驗證：獨立原型使用目前 SDK 編譯成功、無編譯警告、SwiftLint 通過；iPad 橫向與 Duo 半折內螢幕的 A 方案均有原生截圖，iPad 另有 B 方案。`.inspector` 在 iPad 顯示約 400pt 的 trailing 欄，在這次 Duo 姿態會得到不同佈局。

尚未證明：兩欄 `NavigationSplitView` 加上欄寬偏好在所有姿態都精準沿 hinge；原生 inspector 在任何姿態都占右半邊；以及反側 sheet、焦點、鍵盤、捲動位置和完整 feature state 的連續性。這些列為落地驗收，不能由靜態截圖推論完成。

落地時依序驗證：寬 → 窄 → 寬、Duo 展開 → 半折 → 闔上、保有選取時 resize、搜尋鍵盤顯示時 resize、開啟 sheet 時 resize，以及標準／AX1／AX3／AX5 文字大小。閱讀器仍由既有全螢幕流程承載；下載狀態仍以既有持久化 manifest 為唯一依據。

## 截圖

| 頁面 | iPad A | iPad B | Duo A |
|---|---|---|---|
| Favorites | [清單＋詳情](ipad-favorites-recommended.png) | [分類＋網格](ipad-favorites-alternative.png) | [清單＋詳情](duo-favorites-recommended.png) |
| Search | [條件＋結果](ipad-search-recommended.png) | [結果＋詳情](ipad-search-alternative.png) | [條件＋結果](duo-search-recommended.png) |
| Downloads | [清單＋原生 inspector](ipad-downloads-recommended.png) | [資料夾＋清單](ipad-downloads-alternative.png) | [清單＋原生 inspector](duo-downloads-recommended.png) |

設計依據：`$HOME/.agents/skills/app-resizability/SKILL.md` 與其 orientation／idiom／safe-area 參考文件；`$HOME/.agents/skills/iphone-duo/SKILL.md` 與其 layout／bars 參考文件。沒有以通用視覺設計 skill 作為此版本的判斷依據。
