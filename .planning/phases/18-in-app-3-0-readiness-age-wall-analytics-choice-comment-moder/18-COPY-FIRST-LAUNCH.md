> **Superseded in part:** None strings and consent.body superseded by [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md)
> (owner msgs 1795, 1805).
> `consent.level.basic.description` is superseded by Revision 3 in [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md)
> (owner msgs 1830, 1839; CONTEXT D-06d). The Basic description in the table below is the retired text.

# EhPanda 3.0: first-launch copy (age wall + analytics choice)

APPROVED by the owner, msg 1767 (2026-11-05), all six languages. Author: Camo. Delivered in msg 1761.
Decisions this is written for (owner card answers, msg 1753): two screens, everyone sees both once on the first 3.0 launch; analytics levels None / Basic / Full; agents draft, owner approves.
Tone per locale, as in the rest of the app and site: de "du", ko -습니다, ja です/ます, zh plain 你.

## One term per concept

| Concept | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| analytics | analytics | Analysedaten | 분석 데이터 | 分析データ | 分析数据 | 分析資料 |
| sexually explicit content | sexually explicit content | sexuell explizite Inhalte | 성적으로 노골적인 콘텐츠 | 性的に露骨なコンテンツ | 色情内容 | 色情內容 |
| Settings (the app's screen) | Settings | Einstellungen | 설정 | 設定 | 设置 | 設定 |
| Privacy Policy | Privacy Policy | Datenschutzerklärung | 개인정보 처리방침 | プライバシーポリシー | 隐私政策 | 隱私權政策 |
| the app | EhPanda / the app | EhPanda / die App | EhPanda / 앱 | EhPanda / アプリ | EhPanda / 应用 | EhPanda / App |

All of these match existing app or website strings. Don't introduce synonyms ("telemetry", "statistics", "tracking", "18+").

---

## Screen 1: age wall

No skip and no "No" button. The Continue button stays dimmed until the checkbox is ticked, the same pattern as the website's adult-mode box. Nothing on this screen may say or suggest that the age was checked.

The checkbox sentence is the owner-approved text (msg 1454, 1457), word for word. Don't edit it.

| Key (suggested) | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| age_wall.title | EhPanda is for adults | EhPanda ist nur für Erwachsene | EhPanda는 성인용 앱입니다 | EhPanda は成人向けのアプリです | EhPanda 仅限成年人使用 | EhPanda 僅限成年人使用 |
| age_wall.body | This app shows sexually explicit content. | Diese App zeigt sexuell explizite Inhalte. | 이 앱은 성적으로 노골적인 콘텐츠를 표시합니다. | このアプリでは、性的に露骨なコンテンツが表示されます。 | 本应用会显示色情内容。 | 本 App 會顯示色情內容。 |
| age_wall.declaration (APPROVED) | Under every law that applies to me, I'm an adult and may view sexually explicit content. | Nach jedem für mich geltenden Recht bin ich volljährig und darf sexuell explizite Inhalte ansehen. | 저에게 적용되는 모든 법률에 따라 저는 성인이며 성적으로 노골적인 콘텐츠를 볼 수 있습니다. | 私に適用されるすべての法律のもとで、私は成人であり、性的に露骨なコンテンツを閲覧できます。 | 依据适用于我的所有法律，我已成年，且可浏览色情内容。 | 依適用於我的所有法律，我已成年，且可瀏覽色情內容。 |
| age_wall.continue | Continue | Weiter | 계속 | 続ける | 继续 | 繼續 |
| age_wall.footnote | If this isn't true for you, please close EhPanda. | Wenn das nicht auf dich zutrifft, schließe EhPanda bitte. | 해당하지 않는다면 EhPanda를 닫아 주세요. | 当てはまらない場合は、EhPanda を閉じてください。 | 如果以上不符合你的情况，请关闭 EhPanda。 | 如果以上不符合你的情況，請關閉 EhPanda。 |
| age_wall.continue_hint (VoiceOver hint while dimmed) | Tick the statement above to continue. | Hake die Aussage oben an, um fortzufahren. | 위 문장을 선택하면 계속할 수 있습니다. | 上の文にチェックを入れると続けられます。 | 勾选上方的声明后即可继续。 | 勾選上方的聲明後即可繼續。 |

Notes:
- Title says what the app is, not what the user is. That keeps the screen a statement by the user, never a check by us.
- "Continue", not "Enter" or "I agree": the agreement is the checkbox, the button just moves on.
- The footnote is always visible; it's the whole answer for someone who can't tick the box.

---

## Screen 2: analytics choice

Three options, all equally prominent, none pre-selected (Pluso's recommendation in the prep file; Colo decides the layout). If the design uses a separate Continue button, it stays dimmed until an option is picked and reuses `age_wall.continue`. If tapping an option saves and continues directly, no button is needed.

Note (owner msg 1839): the `consent.level.basic.description` row below is retired; use Revision 3 in [18-COPY-MINIMAL.md](18-COPY-MINIMAL.md) (D-06d).

The SDK doesn't start before this choice (L14), so "None" really means nothing is sent. The level descriptions follow Pluso's GA-2 option A; if the developer changes what a level sends, the description has to change with it.

| Key (suggested) | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| consent.title | Choose what EhPanda shares | Wähle, was EhPanda teilt | EhPanda가 공유할 정보를 선택하세요 | EhPanda が共有する情報を選んでください | 选择 EhPanda 要分享的内容 | 選擇 EhPanda 要分享的內容 |
| consent.body | EhPanda can send anonymous analytics to TelemetryDeck so its maintainers can see which features matter. Gallery titles, links and the text of your searches are never sent. | EhPanda kann anonyme Analysedaten an TelemetryDeck senden, damit das Entwicklerteam sieht, welche Funktionen wirklich genutzt werden. Galerietitel, Links und der Text deiner Suchanfragen werden nie gesendet. | EhPanda는 개발팀이 어떤 기능이 실제로 쓰이는지 파악할 수 있도록 익명 분석 데이터를 TelemetryDeck으로 보낼 수 있습니다. 갤러리 제목, 링크, 검색한 내용은 절대 보내지 않습니다. | EhPanda は、どの機能がよく使われているかを開発チームが把握できるよう、匿名の分析データを TelemetryDeck に送信できます。ギャラリーのタイトル、リンク、検索した文字列が送信されることはありません。 | EhPanda 可以向 TelemetryDeck 发送匿名分析数据，帮助维护者了解哪些功能真正有用。画廊标题、链接和你搜索的文字永远不会发送。 | EhPanda 可以將匿名的分析資料傳送給 TelemetryDeck，讓維護者了解大家實際在用哪些功能。畫廊標題、連結和你搜尋的文字永遠不會傳送。 |
| consent.level.none | None | Keine | 공유 안 함 | 共有しない | 不分享 | 不分享 |
| consent.level.none.description | Nothing is sent. | Es wird nichts gesendet. | 아무것도 보내지 않습니다. | 何も送信しません。 | 不会发送任何数据。 | 不會傳送任何資料。 |
| consent.level.basic | Basic | Basis | 기본 | 基本 | 基本 | 基本 |
| consent.level.basic.description | Sends how often the app is used, technical details such as device model and app version, where you installed the app from, and which kinds of errors occur. | Sendet, wie oft die App genutzt wird, technische Angaben wie Gerätemodell und App-Version, woher du die App installiert hast und welche Arten von Fehlern auftreten. | 앱 사용 빈도, 기기 모델과 앱 버전 같은 기술 정보, 앱을 설치한 곳, 발생한 오류의 종류를 보냅니다. | アプリの利用頻度、デバイスのモデルやアプリのバージョンなどの技術情報、アプリの入手元、発生したエラーの種類を送信します。 | 发送应用的使用频率、设备型号和应用版本等技术信息、应用的安装来源，以及出现的错误类型。 | 傳送 App 的使用頻率、裝置型號和 App 版本等技術資訊、App 的安裝來源，以及發生的錯誤類型。 |
| consent.level.full | Full | Vollständig | 전체 | すべて | 完整 | 完整 |
| consent.level.full.description | Everything in Basic, plus which screens and features you use, your reading and download activity, and your main settings. | Alles aus „Basis“, dazu welche Bildschirme und Funktionen du nutzt, deine Lese- und Downloadaktivität und deine wichtigsten Einstellungen. | 기본 항목에 더해 사용하는 화면과 기능, 읽기 및 다운로드 활동, 주요 설정을 보냅니다. | 「基本」の内容に加え、使用している画面や機能、閲覧とダウンロードの状況、主な設定を送信します。 | 在“基本”的基础上，还会发送你使用的页面和功能、阅读和下载情况，以及主要设置。 | 在「基本」之外，還會傳送你使用的頁面和功能、閱讀和下載情況，以及主要設定。 |
| consent.footer | You can change this anytime in Settings. | Du kannst das jederzeit in den Einstellungen ändern. | 설정에서 언제든지 바꿀 수 있습니다. | この選択は「設定」でいつでも変更できます。 | 你可以随时在设置中更改。 | 你可以隨時在設定中更改。 |
| consent.privacy_link | Privacy Policy | Datenschutzerklärung | 개인정보 처리방침 | プライバシーポリシー | 隐私政策 | 隱私權政策 |

Notes:
- The title is neutral on purpose. "Help improve EhPanda?" would nudge toward sharing, which a choice with no default shouldn't do.
- Level names are the owner's (None / Basic / Full). In ko, ja and zh, "None" reads as "Don't share", because a bare 없음 / なし / 无 is unclear as a button.
- "Anonymous" matches the website's privacy page, which the owner already approved.

---

## Settings (replaces today's toggle)

Today: a "Share Analytics Data" toggle with a footer saying "your installation is still counted". That footer becomes untrue once "None" means the SDK never starts, so it has to go.

- Row label: keep the existing `shareAnalyticsData` ("Share Analytics Data" / Analysedaten teilen / 분석 데이터 공유 / 分析データを共有 / 分享分析数据 / 分享分析資料), now as a picker.
- Picker values: the three `consent.level.*` labels.
- Footer: the selected level's `consent.level.*.description`, so Settings and the first-launch screen always say the same thing.
- A "Privacy Policy" row (`consent.privacy_link`), opening the website's privacy page.
- Retire `shareAnalyticsDataFooter`.

---

## Knock-on for the website (@website, when 3.0 ships, not before)

The privacy page says "Sharing is on by default", that turning it off still counts your installation, and that you turn it off with a switch. All three stop being true in 3.0. Its "Turning it off" section needs rewriting for the three levels, using the level descriptions above. Not to be changed before 3.0 is out, since 2.x users still have today's behaviour.
