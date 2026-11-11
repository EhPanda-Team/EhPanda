<h1 align="center">EhPanda</h1>

<h4 align="center">iOS 版非官方 E-Hentai App</h4>

<p align="center">
<img src="https://user-images.githubusercontent.com/31207151/105609404-0acbff00-5de4-11eb-9e88-f3c6e0ba9d44.png" width="400"></img>
</p>

<p align="center">
  <a href="/README.md">English</a>・
  <a href="/READMEs/README.de.md">Deutsch</a>・
  <a href="/READMEs/README.ko.md">한국어</a>・
  <a href="/READMEs/README.jpn.md">日本語</a>・
  <a href="/READMEs/README.cht.md">繁體中文</a>・
  <a href="/READMEs/README.chs.md">简体中文</a>
</p>

## 安裝步驟
1. 從 [Releases](https://github.com/EhPanda-Team/EhPanda/releases) 下載 IPA 檔案。
2. 用 [AltStore](https://altstore.io) 這類工具安裝到你的裝置。

<sub>需要 iOS / iPadOS 27.0 或以上版本。</sub>

## 社群
[![Twitter](https://img.shields.io/badge/Twitter-2CA5E0?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/ehpandaapp)
[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/BSBE9FCBTq)
[![Telegram](https://img.shields.io/badge/Telegram-858585?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/ehpanda)

## 免責聲明
App 內的內容都來自 E-Hentai，由該站的使用者上傳。

**存取 E-Hentai 內容的風險由你自行承擔。**

## 分析
EhPanda 會向 [TelemetryDeck](https://telemetrydeck.com) 傳送匿名分析資料，讓維護者了解有多少人使用本 App 以及哪些功能重要。**分享多少由你在首次開啟 App 時選擇，之後可以隨時在「設定 → 一般 → 分析」中更改。在你做出選擇之前，不會傳送任何內容。** 共有三個層級：

- **最少**：僅傳送 EhPanda 已安裝的資訊，以及 App 的取得來源。
- **基本**：在「最少」之外，還會傳送 App 的使用頻率、你使用的頁面和功能、裝置型號和 App 版本等技術資訊，以及發生的錯誤類型。
- **完整**：在「基本」之外，還會傳送你的閱讀和下載情況，以及主要設定。

無論哪個層級，資料中都絕不包含畫廊的識別碼、權杖或標題，任何畫廊或頁面連結，搜尋關鍵字文字，標籤的值，使用者名稱，Cookie 或任何其他憑證，以及檔案路徑。

在「最少」層級下，EhPanda 每次安裝只傳送一次安裝訊號。其中只包含 App 的取得來源（GitHub、AltStore、SideStore 或 AltStore PAL）和為本次安裝產生的隨機識別碼，不包含任何裝置資訊。每個官方下載檔案都標有它的發布位置，因此這個訊號反映的是你使用的下載檔案，而不是你的安裝方式。TelemetryDeck SDK 永遠不會啟動。

在「基本」層級下，EhPanda 傳送同樣的安裝訊號，啟動 TelemetryDeck SDK，並額外傳送：
- App 的使用頻率：SDK 本身的工作階段訊號與統計數字，例如首次開啟的日期、工作階段次數、使用過的天數與工作階段的長度；
- 你使用的頁面和功能：開啟的標籤頁與首頁區塊、篩選與快速搜尋面板、已儲存的搜尋、標籤點按（僅傳送標籤的命名空間，絕不傳送其值），以及以特徵形式傳送的搜尋（字詞數、是否使用標籤語法、關鍵字長度、結果數量的大致範圍），而非文字本身；完成首次啟動的畫面，以及你在那裡選擇的層級；在設定中更改層級（更改前與更改後的層級）；以及留言管理：封鎖、解除封鎖、顯示已收合的留言、你對發表前警告的回應，以及檢舉的結果（已傳送、失敗、無法使用或在網站上開啟）；
- 每個事件還會帶上 App 的取得來源；
- 發生的錯誤類型，包括登入失敗與 Cloudflare 驗證；
- SDK 自動為每個事件加入的一組標準技術資訊：裝置型號與架構，螢幕尺寸、縮放比例與方向，作業系統版本，App 版本與建置編號，是否為除錯或模擬器建置，你的語言、地區、文字排列方向與時區，該事件傳送時的日期與時刻，以及你的系統外觀與輔助使用設定（淺色或深色模式、文字大小、粗體文字、減少動態效果、減少透明度、反相顏色、增加對比、不以顏色來區分）。

在「完整」層級下，還會傳送你開啟的畫廊（僅傳送分類與各命名空間的標籤數量，絕不傳送畫廊本身），以頁數與時間長度區間表示的閱讀紀錄，下載結果（例如完成或失敗），以及隨每個事件一併傳送的五項 App 設定的目前值：畫廊網站、登入狀態、閱讀方向、雙頁模式與標籤翻譯。

在「基本」與「完整」層級下，事件會附帶 TelemetryDeck 內建的匿名安裝識別碼，該識別碼會在裝置上完成雜湊後才傳送。此識別碼不會連結到你本人，並會在 iOS 重新產生裝置的供應商識別碼時重設，也就是同一開發者的所有 App 都被刪除時。TelemetryDeck 不保留 IP 位址。資料的處理方式請參閱 [TelemetryDeck 隱私權政策](https://telemetrydeck.com/privacy)。

官方發行版在建置時會包含分析憑證，由發布工作流程從儲存庫密鑰中取得，因此會傳送你所選層級允許的內容。未包含這些憑證的建置不會傳送任何內容，無論選擇了哪個層級：從原始碼自行建置的版本以及 Fork 版本，都會因缺少憑證而關閉分析功能。
