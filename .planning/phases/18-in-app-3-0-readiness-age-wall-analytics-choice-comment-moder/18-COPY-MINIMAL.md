# EhPanda 3.0: analytics wording change for "Minimal"

APPROVED by the owner, msg 1805 (2026-11-05), all six languages. Author: Camo. Delivered in msg 1797. Written for owner msg 1795: "None" becomes "Minimal", which sends only the installation.
Everything not listed here in 18-COPY-FIRST-LAUNCH.md stays as approved (msg 1767).
Developer confirmation (msg 1798): under Minimal the analytics SDK never starts; the app sends one signal, once per install (D-06b).

**Revision 2 APPROVED by the owner, msg 1818 (2026-11-05):** owner msg 1812 adds the install channel to the Minimal signal (D-06c, developer msg 1814). The Minimal description in the table below is SUPERSEDED by Revision 2 at the end of this file; everything else stays as approved in msg 1805.

## What changes

1. The level name and its description (key renamed `consent.level.none` -> `consent.level.minimal`).
2. `consent.body`: "can send" becomes "sends", plus a short line saying the user picks how much. "Can send" implied a level that sends nothing, which no longer exists.
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

Unchanged and still correct: `consent.title` ("Choose what EhPanda shares"), the Basic and Full names and descriptions, `consent.footer` ("You can change this anytime in Settings."), `consent.privacy_link`, `shareAnalyticsData`.

## Notes

- "Minimal", not "Install only": it keeps the three names as one set of plain words and doesn't put a technical idea on a button. The description says exactly what it sends.
- zh uses 最少 (least) beside 基本 / 完整; ja 最小限 and ko 최소 are the usual words for a minimal setting.
- The description starts with "Sends", like Basic's, so the three read as one ladder.

## Knock-on for the website (Leto, at 3.0 ship, not before)

The privacy page rewrite for the three levels now uses Minimal / Basic / Full and these descriptions. There is no level that sends nothing, so the page must not say sharing can be turned off completely.

## Revision 2 (owner msg 1812; APPROVED owner msg 1818)

Only `consent.level.minimal.description` changes. The name "Minimal", `consent.body` and everything else stay as approved in msg 1805.

| Key | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.level.minimal.description | Sends only a signal that EhPanda is installed, and where you installed the app from. | Sendet nur, dass EhPanda installiert ist, und woher du die App installiert hast. | EhPanda가 설치되어 있다는 사실과 앱을 설치한 곳만 보냅니다. | EhPanda がインストールされていることと、アプリの入手元だけを送信します。 | 仅发送 EhPanda 已安装的信息，以及应用的安装来源。 | 僅傳送 EhPanda 已安裝的資訊，以及 App 的安裝來源。 |

Notes:
- "Where you installed the app from" is word for word the phrase already approved in Basic's description, in every language, so the two levels name the install channel the same way. No new term ("marketplace", "channel", "install source") reaches the user.
- Still true only if the signal carries nothing beyond the install and its source, once per install (D-06b/D-06c).
