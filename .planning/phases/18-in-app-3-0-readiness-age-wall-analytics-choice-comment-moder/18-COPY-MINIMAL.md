# EhPanda 3.0: analytics wording change for "Minimal"

APPROVED by the owner, msg 1805 (2026-11-05), all six languages. Author: Camo. Delivered in msg 1797. Written for owner msg 1795: "None" becomes "Minimal", which sends only the installation.
Everything not listed here in 18-COPY-FIRST-LAUNCH.md stays as approved (msg 1767).
Developer confirmation (msg 1798): under Minimal the analytics SDK never starts; the app sends one signal, once per install (D-06b).

**Revision 2 APPROVED by the owner, msg 1818 (2026-11-05):** owner msg 1812 adds the install channel to the Minimal signal (D-06c, developer msg 1814). The Minimal description in the table below is SUPERSEDED by Revision 2 at the end of this file; everything else stays as approved in msg 1805.

**Revision 3 APPROVED by the owner, msg 1839 (2026-11-05):** owner msg 1830 notes that the Basic description repeated Minimal's install line (the copywriter's draft is msg 1832). Basic's description now builds on Minimal ("Everything in Minimal, plus ..."); what Basic sends does not change (D-06d). Revision 3 at the end of this file supersedes the Basic description (`consent.level.basic.description`) in 18-COPY-FIRST-LAUNCH.md, in all six languages. Minimal (Revision 2), Full, `consent.title` and `consent.body` are unchanged. (Basic's description is superseded again by Revision 6, msg 1880.)

**Revision 5 APPROVED by the owner, msg 1864 (2026-11-05):** owner msgs 1844 and 1854 ask for a much shorter intro under the analytics title; version B of Revision 5 is approved (developer check msg 1858; D-06e). Revision 5 at the end of this file supersedes `consent.body` in this file's first table (msg 1805), and with it the original `consent.body` in 18-COPY-FIRST-LAUNCH.md, in all six languages. The purpose ("which features matter") and TelemetryDeck's name move to the Privacy Policy (website, Phase 20). Revision 4 (msg 1847) was not approved and is not used. Everything else stays as approved.

**Revision 6 APPROVED by the owner, msg 1880 (2026-11-05):** owner msg 1869 moves the screens and features from Full to Basic (developer mapping msg 1878; D-06f). Revision 6 at the end of this file supersedes the Basic description of Revision 3 (msg 1839) and the Full description (`consent.level.full.description`) in 18-COPY-FIRST-LAUNCH.md (msg 1767), in all six languages; both are retired. Its `consent.level.recommended` table is approved as well: the owner chose "Basic marked Recommended" (owner msg 1882, card 1873, options in msgs 1872 and 1874). Nothing is pre-selected; Basic only carries the label. The pre-selected variant (msg 1871) was not chosen, so the section heading's "Basic is the default" (the owner's ask in msg 1869) means recommended, not pre-selected. Minimal (Revision 2), `consent.title`, `consent.body` (Revision 5) and the level names are unchanged.

**Revision 7 (2026-11-08):** owner msg 2552 drops the install-source lookup; the app now knows only which download it is (its distribution channel), not how it was installed. The copywriter's wording (msg 2559) replaces "where you installed the app from" with "where you got the app from"; the owner was told in developer msg 2560 and did not object. Revision 7 at the end of this file supersedes Revision 2's `consent.level.minimal.description` in de, en, ko, zh-Hans and zh-Hant; ja already said 入手元 and is unchanged. Nothing else changes.

## What changes

1. The level name and its description (key renamed `consent.level.none` -> `consent.level.minimal`).
2. `consent.body` (superseded by Revision 5, msg 1864): "can send" becomes "sends", plus a short line saying the user picks how much. "Can send" implied a level that sends nothing, which no longer exists.
3. Order stays: Minimal, Basic, Full. Still none pre-selected.
4. Settings footer: unchanged rule (shows the selected level's description), so it picks up the new Minimal line automatically.
5. Drop the note "In ko, ja and zh, None reads as Don't share". It no longer applies.

## New strings

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.level.minimal | Minimal | Minimal | 최소 | 最小限 | 最少 | 最少 |
| consent.level.minimal.description | Sends only a signal that EhPanda is installed. | Sendet nur, dass EhPanda installiert ist. | EhPanda가 설치되어 있다는 사실만 보냅니다. | EhPanda がインストールされていることだけを送信します。 | 仅发送 EhPanda 已安装的信息。 | 僅傳送 EhPanda 已安裝的資訊。 |
| consent.body | EhPanda sends anonymous analytics to TelemetryDeck so its maintainers can see which features matter. You choose how much. Gallery titles, links and the text of your searches are never sent. | EhPanda sendet anonyme Analysedaten an TelemetryDeck, damit das Entwicklerteam sieht, welche Funktionen wirklich genutzt werden. Wie viel, entscheidest du. Galerietitel, Links und der Text deiner Suchanfragen werden nie gesendet. | EhPanda는 개발팀이 어떤 기능이 실제로 쓰이는지 파악할 수 있도록 익명 분석 데이터를 TelemetryDeck으로 보냅니다. 얼마나 보낼지는 직접 선택할 수 있습니다. 갤러리 제목, 링크, 검색한 내용은 절대 보내지 않습니다. | EhPanda は、どの機能がよく使われているかを開発チームが把握できるよう、匿名の分析データを TelemetryDeck に送信します。送信する範囲はご自身で選べます。ギャラリーのタイトル、リンク、検索した文字列が送信されることはありません。 | EhPanda 会向 TelemetryDeck 发送匿名分析数据，帮助维护者了解哪些功能真正有用。发送多少由你决定。画廊标题、链接和你搜索的文字永远不会发送。 | EhPanda 會將匿名的分析資料傳送給 TelemetryDeck，讓維護者了解大家實際在用哪些功能。傳送多少由你決定。畫廊標題、連結和你搜尋的文字永遠不會傳送。 |

Retired: `consent.level.none` ("None"), `consent.level.none.description` ("Nothing is sent.").

Unchanged and still correct: `consent.title` ("Choose what EhPanda shares"), the Basic and Full names and descriptions (Basic's description later superseded by Revision 3, msg 1839, then Basic's and Full's by Revision 6, msg 1880), `consent.footer` ("You can change this anytime in Settings."), `consent.privacy_link`, `shareAnalyticsData`.

## Notes

- "Minimal", not "Install only": it keeps the three names as one set of plain words and doesn't put a technical idea on a button. The description says exactly what it sends.
- zh uses 最少 (least) beside 基本 / 完整; ja 最小限 and ko 최소 are the usual words for a minimal setting.
- The description starts with "Sends", like Basic's, so the three read as one ladder.

## Knock-on for the website (Leto, at 3.0 ship, not before)

The privacy page rewrite for the three levels now uses Minimal / Basic / Full and these descriptions. There is no level that sends nothing, so the page must not say sharing can be turned off completely.
Since Revision 5 (msg 1864) the in-app intro no longer names TelemetryDeck or says why analytics are collected; the privacy page, linked from the same screen, must carry both (D-06e).

## Revision 2 (owner msg 1812; APPROVED owner msg 1818)

Only `consent.level.minimal.description` changes. The name "Minimal", `consent.body` and everything else stay as approved in msg 1805.

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.level.minimal.description | Sends only a signal that EhPanda is installed, and where you installed the app from. | Sendet nur, dass EhPanda installiert ist, und woher du die App installiert hast. | EhPanda가 설치되어 있다는 사실과 앱을 설치한 곳만 보냅니다. | EhPanda がインストールされていることと、アプリの入手元だけを送信します。 | 仅发送 EhPanda 已安装的信息，以及应用的安装来源。 | 僅傳送 EhPanda 已安裝的資訊，以及 App 的安裝來源。 |

Notes:
- "Where you installed the app from" is word for word the phrase already approved in Basic's description, in every language, so the two levels name the install channel the same way. No new term ("marketplace", "channel", "install source") reaches the user.
- Still true only if the signal carries nothing beyond the install and its source, once per install (D-06b/D-06c).

## Revision 3 (owner msg 1830: Basic's description repeats Minimal's; APPROVED owner msg 1839)

Only `consent.level.basic.description` changes. Basic now builds on Minimal the same way Full builds on Basic ("Everything in X, plus ..."), so the three read as one ladder and the install line appears once. Content is unchanged: Basic still sends the install signal and where it came from (via "Everything in Minimal"), usage frequency, device model and app version, and error kinds.

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.level.basic.description | Everything in Minimal, plus how often the app is used, technical details such as device model and app version, and which kinds of errors occur. | Alles aus „Minimal“, dazu wie oft die App genutzt wird, technische Angaben wie Gerätemodell und App-Version und welche Arten von Fehlern auftreten. | 최소 항목에 더해 앱 사용 빈도, 기기 모델과 앱 버전 같은 기술 정보, 발생한 오류의 종류를 보냅니다. | 「最小限」の内容に加え、アプリの利用頻度、デバイスのモデルやアプリのバージョンなどの技術情報、発生したエラーの種類を送信します。 | 在“最少”的基础上，还会发送应用的使用频率、设备型号和应用版本等技术信息，以及出现的错误类型。 | 在「最少」之外，還會傳送 App 的使用頻率、裝置型號和 App 版本等技術資訊，以及發生的錯誤類型。 |

Unchanged: Minimal (Revision 2, msg 1818), Full, the title and the intro.
Side effect: in Settings the footer for Basic now starts "Everything in Minimal", which reads fine beside the picker that lists Minimal.

## Revision 5 (owner msg 1854: "too much details. can we go with something like, what you have searched or viewed are never sent"; version B APPROVED owner msg 1864)

Only `consent.body` changes. Revision 4 (msg 1847) was not approved. The owner chose version B over A ("Anonymous analytics. What you search for or view is never sent.") because Full sends the category of a gallery that is opened, but never which gallery; B promises exactly that.

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.body | Anonymous analytics. Your searches and the galleries you view are never sent. | Anonyme Analysedaten. Deine Suchen und die Galerien, die du ansiehst, werden nie gesendet. | 익명 분석 데이터입니다. 검색어와 본 갤러리는 절대 보내지 않습니다. | 匿名の分析データです。検索語や閲覧したギャラリーは送信されません。 | 匿名分析数据。你的搜索内容和浏览的画廊永远不会发送。 | 匿名分析資料。你的搜尋內容和瀏覽的畫廊永遠不會傳送。 |

Notes:
- Developer check (msg 1858): at no level does any gallery ID, title, link, tag name or search text go out. Full sends a gallery's category and per-namespace tag counts on open; a search sends only word count, length, tag-syntax flag and a result-count bucket.
- 77 characters in English, two lines on iPhone at default size (designer msg 1846/1850).
- The purpose ("which features matter") and TelemetryDeck's name move to the Privacy Policy, linked on the same screen (website, Phase 20).

## Revision 6 (owner msg 1869: screens and features move from Full to Basic; Basic is the default)

Only the Basic and Full descriptions change. The ladder stays.

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.level.basic.description | Everything in Minimal, plus how often the app is used, which screens and features you use, technical details such as device model and app version, and which kinds of errors occur. | Alles aus „Minimal“, dazu wie oft die App genutzt wird, welche Bildschirme und Funktionen du nutzt, technische Angaben wie Gerätemodell und App-Version und welche Arten von Fehlern auftreten. | 최소 항목에 더해 앱 사용 빈도, 사용하는 화면과 기능, 기기 모델과 앱 버전 같은 기술 정보, 발생한 오류의 종류를 보냅니다. | 「最小限」の内容に加え、アプリの利用頻度、使用している画面や機能、デバイスのモデルやアプリのバージョンなどの技術情報、発生したエラーの種類を送信します。 | 在“最少”的基础上，还会发送应用的使用频率、你使用的页面和功能、设备型号和应用版本等技术信息，以及出现的错误类型。 | 在「最少」之外，還會傳送 App 的使用頻率、你使用的頁面和功能、裝置型號和 App 版本等技術資訊，以及發生的錯誤類型。 |
| consent.level.full.description | Everything in Basic, plus your reading and download activity and your main settings. | Alles aus „Basis“, dazu deine Lese- und Downloadaktivität und deine wichtigsten Einstellungen. | 기본 항목에 더해 읽기 및 다운로드 활동과 주요 설정을 보냅니다. | 「基本」の内容に加え、閲覧とダウンロードの状況、主な設定を送信します。 | 在“基本”的基础上，还会发送你的阅读和下载情况，以及主要设置。 | 在「基本」之外，還會傳送你的閱讀和下載情況，以及主要設定。 |

The screens-and-features phrase is the one already approved in Full, moved word for word in every language.

Only if the owner takes the "Recommended" label option (msg 1872):

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.level.recommended | Recommended | Empfohlen | 권장 | おすすめ | 推荐 | 推薦 |

## Revision 7 (owner msg 2552: report the distribution channel only; copywriter msg 2559)

Only `consent.level.minimal.description` changes.

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.level.minimal.description | Sends only a signal that EhPanda is installed, and where you got the app from. | Sendet nur, dass EhPanda installiert ist, und woher du die App hast. | EhPanda가 설치되어 있다는 사실과 앱을 받은 곳만 보냅니다. | EhPanda がインストールされていることと、アプリの入手元だけを送信します。 | 仅发送 EhPanda 已安装的信息，以及应用的获取来源。 | 僅傳送 EhPanda 已安裝的資訊，以及 App 的取得來源。 |

Notes:
- The signal carries only the channel the download was published for (GitHub, AltStore, SideStore, AltStore PAL, EhPanda Beta, or `source`), so "got the app from" is what the app knows; "installed from" claimed more.
- The READMEs' Analytics sections use the same line (copywriter msg 2586).
