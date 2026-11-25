# 19-25 C15 proposal: insufficient funds on Archives

Status: proposed, waiting for the owner's answer (Task 2). Nothing in this file has landed in source. No key, string or
view change is made before the owner approves the exact text of every locale below.

Origin: C15 in `19-13-PRECHECK.md`, `detail-pages-archives-insufficient-funds`: insufficient funds are not indicated and
the H@H download button stays enabled. Owner verdict of 2026-11-22: fix and re-record.

## Evidence

What the repository shows about prices and balances:

- Archive card price. `Parser.parseGalleryArchive` (`ParserFeature/Parser+Archive.swift`) walks every `<p>` of the
  archiver table. A `<p>` containing "N/A" makes both size and price "N/A". A `<p>` containing "KiB", "MiB" or "GiB" is
  the size. Any other `<p>` text is stored unchanged as the price (`gpPrice`, a private `String`). The model compares it
  with the literal "Free" (shown as the localized `hath_archive_free`) and with "N/A" (`isValid` is false). No other
  price text is interpreted anywhere.
- Fixtures. `GalleryFixtures.archives` use bare digits, "180", "260", "380", "520", plus "Free" and "N/A". The preview
  data in `ArchivesView.swift` uses "20" to "50", "Free" and "N/A". The card shows the stored text as is, with no "GP".
- Saved pages. No saved archiver page exists in the repository (`TestingSupport/Resources/Parser` has no archiver
  HTML; the only archiver mention is the gallery detail page's "Archive Download" link). So the exact text the site
  writes for an archive price is unknown here, including any thousands separator and any "GP" suffix.
- Balance format, the one real evidence. `Parser.parseCurrentFunds` (`ParserFeature/Parser+User.swift`) reads a `<p>`
  that contains "GP", "[?]" and "Credits", takes the text before "GP", trims it and removes "," characters. So the
  site writes the GP balance with comma grouping and a "GP" suffix on the funds line, and the stored
  `user.galleryPoints` is a string of bare digits (`"24680"`). Credits are stored the same way.
- Fixture balances. `GalleryFixtures.funds` is 24680 GP and `lowFunds` is 120 GP, with credits 135790 and 90. Every
  priced fixture archive (180 to 520) costs more than 120 GP, and "Free" costs nothing.
- The C15 state. `detail-pages-archives-insufficient-funds` (`ArchivesViewSnapshot`, `GalleryScenarios.archives(lowFunds: true)`)
  builds the six archives, sets the low balances and pre-selects 1280x (380). Its own comment says the app has no state
  for a balance that cannot pay.
- Today's gate. `ArchivesView.downloadButton` is `DownloadButton(isDisabled: store.selectedArchive == nil)`, so
  nothing compares price and balance. `ArchivesReducer.fetchDownloadResponse` guards only on a selection and a toast.
- Existing copy to match. `download_to_hath_client` ("Download to H@H Client" in en and the localized forms below),
  `accessibility.credits_balance` and `accessibility.gallery_points_balance` (both use one labeled `%#@balance@`
  substitution, `other`-only in every locale, `%arg`), `archives` and `archives_action` (zh-Hans 归档, zh-Hant 壓縮檔),
  `hath_client_not_found` and `hath_client_not_online` (client is 客户端 in zh-Hans and 用戶端 in zh-Hant). The two-variable
  precedent is `accessibility.downloading` (`completed`, `total`).

| Term | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| H@H client (existing keys) | H@H client | H@H-Client | H@Hクライアント | H@H 클라이언트 | H@H 客户端 | H@H 用戶端 |
| Archive (existing keys) | Archive | Archiv | アーカイブ | 아카이브 | 归档 | 壓縮檔 |
| Balance (existing keys) | balance | Guthaben | 残高 | 잔액 | 余额 | 餘額 |
| GP in a spoken label (existing) | Gallery points | Galeriepunkte | ギャラリーポイント | 갤러리 포인트 | 画廊点数 | 畫廊點數 |

GP is written "GP" in every locale on screen, as the site writes it and as `greeting.reward_gp` does. The existing
VoiceOver label for the balance spells the term out; see "Open points" for the one decision this raises.

## Rule

Both options use the same rule, so the choice between them is only about how it is shown.

- Cost of an archive (`HathArchive.gpCost: Int?`): "Free" gives 0. Digits, optionally with "," grouping and optionally
  a trailing " GP" (for example "180", "1,234", "1,234 GP"), give that integer. Anything else, including "N/A" and
  any text the site might write that is not in these forms, gives unknown (`nil`).
- Balance: `Int(user.galleryPoints)` when the string is all digits (the parser has already removed commas), otherwise
  unknown.
- Unaffordable: only when both are known and cost is greater than balance. Equal is affordable. Unknown cost or
  unknown balance is never unaffordable, so a price or a balance the app cannot read never blocks a download.
- Download gate: `canDownload` is true only when an archive is selected and it is not unaffordable. The view's
  `DownloadButton(isDisabled:)` reads the negation. The reducer keeps the same gate in `fetchDownloadResponse`, so the
  action cannot start by another route when a funds refresh lowers the balance after a selection.
- The site stays the authority. If it refuses a purchase the app could not foresee, the existing error toast
  applies unchanged.

| Cost text | Balance | Result |
|---|---|---|
| "380" | "120" | unaffordable |
| "380" | "380" | affordable |
| "180" | "24680" | affordable |
| "Free" | "0" | affordable |
| "1,234 GP" | "1000" | unaffordable |
| "N/A" or unreadable | any | affordable (unknown) |
| any | nil or unreadable | affordable (unknown) |

## Comparison and recommendation

| | U1 | U2 |
|---|---|---|
| Unaffordable card | stays selectable, price in red | looks and behaves like N/A, cannot be selected |
| Download button | disabled while an unaffordable card is selected | disabled only when nothing is selected |
| Reason shown | one line under the button, with both numbers | one line under the funds, listing the archives |
| Stale selection after a funds refresh | handled by the same gate, nothing to clear | needs the reducer to clear an unaffordable selection |
| C15 state as recorded today | unchanged: 1280x pre-selected shows the disabled button and the line | the pre-selection in `GalleryScenarios.archives` (in `VisualSnapshotTests`, not in this plan's file list) must change, because a selection is no longer possible |

Recommendation: U1. The reason appears where the user acts, the size and the price stay readable on every card, and
the same gate covers a balance that changes after the choice.

## U1 Selectable cards, disabled download with a one-line reason

Behavior:

- A card whose archive is unaffordable keeps its look, with the price text in red (`.red`). Tapping it selects it, as
  today, with the same border and haptic.
- When the selected archive is unaffordable, the download button is disabled and one line sits directly under it
  (inside the pinned bar below the funds at standard sizes, and in the scrolling column after the button at
  accessibility sizes). The line states the selected archive's cost, the account's GP, and that the archive cannot be
  downloaded to the H@H client. With no selection, an affordable selection, or unknown values, no line is shown.
- Red is not the only signal: the card also carries a spoken value, and the line appears on selection.

Accessibility:

| Element | Label | Value | Other |
|---|---|---|---|
| Unaffordable card (Button) | unchanged, VoiceOver reads the card text: resolution, size, price | `archives_unaffordable` | still activatable |
| Other cards | unchanged | none | unchanged |
| Download button | `download_to_hath_client`, unchanged | none | `.disabled`, so VoiceOver reports it as dimmed |
| The line | its own text, static, read directly after the button | none | not hidden, not repeated as a hint |

Keys (module-local, `DetailFeature/Resources/Localizable.xcstrings`, `extractionState` manual, `state` translated in
every locale):

- `archives_insufficient_funds`, generated as `func archivesInsufficientFunds(cost: Int, balance: Int)`.
- `archives_unaffordable`, generated as `archivesUnaffordable`, no arguments.

Format variables:

| Key | Variable | argNum | Specifier | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|---|---|---|
| `archives_insufficient_funds` | `cost` | 1 | lld | other | other | other | other | other | other |
| `archives_insufficient_funds` | `balance` | 2 | lld | other | other | other | other | other | other |
| `archives_unaffordable` | none | none | none | none | none | none | none | none | none |

Each variable's `other` value is `%arg`. GP is the unit abbreviation and does not change with the count, so `other`-only
is coherent for en and de, as it is in the existing balance keys.

#### `archives_insufficient_funds`

| Locale | Text |
|---|---|
| en | This archive costs %#@cost@ GP, but you only have %#@balance@ GP, so it can't be downloaded to your H@H client. |
| de | Dieses Archiv kostet %#@cost@ GP, du hast aber nur %#@balance@ GP und kannst es deshalb nicht auf deinen H@H-Client laden. |
| ja | このアーカイブには%#@cost@ GPが必要ですが、残高は%#@balance@ GPです。H@Hクライアントにダウンロードできません。 |
| ko | 이 아카이브는 %#@cost@ GP가 필요하지만 잔액이 %#@balance@ GP뿐이라 H@H 클라이언트로 저장할 수 없습니다. |
| zh-Hans | 此归档需要 %#@cost@ GP，但你只有 %#@balance@ GP，无法下载到 H@H 客户端。 |
| zh-Hant | 此壓縮檔需要 %#@cost@ GP，但你只有 %#@balance@ GP，無法下載至 H@H 用戶端。 |

#### `archives_unaffordable`

| Locale | Text |
|---|---|
| en | Not enough GP |
| de | Zu wenig GP |
| ja | GPが足りません |
| ko | GP 부족 |
| zh-Hans | GP 不足 |
| zh-Hant | GP 不足 |

Word choice per locale (U1):

- en: "costs" for the price and "only have" for the balance, the plain way a store line reads; "download to your H@H
  client" repeats the button's own verb and noun.
- de: informal "du", as the existing H@H copy ("Dein H@H-Client ist offline"); "Archiv" and "H@H-Client" as in the
  existing keys; "laden" as in the button ("Auf H@H-Client laden").
- ja: polite です/ます like the neighbouring keys; "残高" as in the credits label; "H@Hクライアント" with no space,
  as the existing keys write it; a space between the number and GP, as `greeting.reward_gp` does.
- ko: "잔액" as in the existing labels; "저장" as in the button ("H@H 클라이언트로 저장"); "GP가" follows the vowel
  ending of "피"; "뿐이라" gives the natural single-sentence reason.
- zh-Hans: "归档" and "客户端" as in the existing keys, "你" as in the other detail copy, "下载到" as in the button.
- zh-Hant: Taiwan Mandarin, "壓縮檔", "用戶端", "下載至" as in the button; the sentence is the same as zh-Hans in
  everyday Taiwan usage, so only the regional words and the script differ.

## U2 Unaffordable cards disabled like unavailable ones, with a note under the funds

Behavior:

- A card whose archive is unaffordable is drawn like an N/A card: the disabled colours for the border and the text,
  no selection on tap, no haptic. It is `.disabled` so VoiceOver reports it as dimmed (the N/A cards are not marked
  that way today; this plan would not change them).
- One line sits under the funds row and names the unaffordable archives, for example "1280x, 1600x and 2400x", built
  from the resolutions with a locale-aware list format (`.formatted(.list(type: .and))`) and passed as a positional
  string argument. With no unaffordable archive, no line is shown.
- The download button is disabled only when nothing is selected. The reducer gate stays, and a selection that becomes
  unaffordable after a funds refresh must be cleared by the reducer.
- This option changes what the C15 snapshot state can show: no unaffordable archive can be pre-selected, so
  `GalleryScenarios.archives(lowFunds:)` (in `VisualSnapshotTests`, outside this plan's `files_modified`) would have to
  stop selecting 1280x, and the hosted test's "1280x selected" behavior would change. Choosing U2 therefore needs a
  plan amendment before Task 3.

Accessibility:

| Element | Label | Value | Other |
|---|---|---|---|
| Unaffordable card (Button) | unchanged, VoiceOver reads the card text | `archives_unaffordable` | `.disabled`, tap ignored |
| Other cards | unchanged | none | unchanged |
| Download button | `download_to_hath_client`, unchanged | none | `.disabled` only without a selection |
| The note under the funds | its own text, static, read after the funds | none | not hidden |

Keys:

- `archives_unaffordable_list`, generated as `func archivesUnaffordableList(_ arg1: String)`, one positional `%@`.
- `archives_unaffordable`, the same key and text as in U1.

Format variables:

| Key | Variable | Kind | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|---|---|
| `archives_unaffordable_list` | `%@` list of resolutions | positional string | none | none | none | none | none | none |
| `archives_unaffordable` | none | none | none | none | none | none | none | none |

Neither key has a numeric argument, so neither has a plural variation. The list is one string, so the wording does not
depend on how many archives are named ("Archives that cost more GP than you have" holds for one archive or for three).

#### `archives_unaffordable_list`

| Locale | Text |
|---|---|
| en | Archives that cost more GP than you have: %@ |
| de | Archive, die mehr GP kosten, als du hast: %@ |
| ja | GPが足りないアーカイブ：%@ |
| ko | GP가 부족한 아카이브: %@ |
| zh-Hans | GP 不足的归档：%@ |
| zh-Hant | GP 不足的壓縮檔：%@ |

#### `archives_unaffordable`

| Locale | Text |
|---|---|
| en | Not enough GP |
| de | Zu wenig GP |
| ja | GPが足りません |
| ko | GP 부족 |
| zh-Hans | GP 不足 |
| zh-Hant | GP 不足 |

Word choice per locale (U2):

- en: "Archives that cost more GP than you have" is a noun phrase, so it is true for one name or several, with no
  singular/plural agreement to get wrong.
- de: the same shape, with the comma German requires before "als"; "kosten" and "du" as in U1.
- ja: a noun phrase ending in the list, with the full-width colon the existing labels use ("残高：").
- ko: a relative clause ("GP가 부족한") before the noun, the natural order; ASCII colon and space as in the existing
  Korean labels.
- zh-Hans and zh-Hant: "GP 不足的" before the noun, the full-width colon as in the existing labels; only the term for
  archive differs by region.

## Pair check: zh-Hans against zh-Hant

The check reads this file, takes every zh-Hans and zh-Hant row under the same key, converts the zh-Hans text with the
regional-word table first and the script table second, and requires the result to equal the zh-Hant text. Anything
the two tables do not explain fails. The regional words are the ones the existing catalog already pairs
(归档 and 壓縮檔, 客户端 and 用戶端, and the button's 下载到 and 下載至).

```python
import re
import sys

REGIONAL_WORDS = {"归档": "壓縮檔", "客户端": "用戶端", "下载到": "下載至"}
SCRIPT_CHARS = {"无": "無"}

key = None
rows = {}
for line in open(sys.argv[1], encoding="utf-8"):
    heading = re.match(r"#### `([a-z_]+)`", line)
    if heading:
        key = heading.group(1)
        continue
    row = re.match(r"\| (zh-Hans|zh-Hant) \| (.*) \|$", line.rstrip("\n"))
    if row and key:
        rows.setdefault(key, {}).setdefault(row.group(1), []).append(row.group(2))

failures = 0
for name, pair in rows.items():
    for hans, hant in zip(pair["zh-Hans"], pair["zh-Hant"]):
        converted = hans
        used = []
        for source, target in REGIONAL_WORDS.items():
            if source in converted:
                converted = converted.replace(source, target)
                used.append(f"{source}->{target}")
        for source, target in SCRIPT_CHARS.items():
            if source in converted:
                converted = converted.replace(source, target)
                used.append(f"{source}->{target}")
        same = converted == hant
        failures += 0 if same else 1
        print(f"{name}: {'OK' if same else 'DIFF'}; applied: {', '.join(used) or 'none'}")
        if not same:
            print(f"  converted: {converted}\n  zh-Hant:   {hant}")
print("pairs-with-differences", failures)
sys.exit(1 if failures else 0)
```

Output of `python3 -I <script> 19-25-C15-PROPOSAL.md`:

```text
archives_insufficient_funds: OK; applied: 归档->壓縮檔, 客户端->用戶端, 下载到->下載至, 无->無
archives_unaffordable: OK; applied: none
archives_unaffordable: OK; applied: none
archives_unaffordable_list: OK; applied: 归档->壓縮檔
pairs-with-differences 0
```

## Open points for the owner

- Price format. The card price text is shown as the site wrote it, and the rule accepts "Free", plain digits, comma
  grouping and a trailing " GP". Whether the site writes archive prices in one of those forms is not provable from the
  repository (see Evidence). The H@H cost is assumed to be paid in GP; the screen shows the account's GP and Credits.
- Spoken GP. The visible copy and the new spoken value write "GP". The existing spoken balance label spells the term
  out (Gallery points, Galeriepunkte, ギャラリーポイント, 갤러리 포인트, 画廊点数, 畫廊點數). If the owner prefers the
  spelled-out form for the spoken value `archives_unaffordable`, the text changes and nothing else does.
- Number grouping. A numeric substitution prints the plain integer, like the existing balance labels, so the line
  reads "380 GP" and "24680 GP" while the funds row above prints "24,680". A grouped number in the line would need a
  string argument instead of the labeled numeric one, which the copy rules do not allow, so the proposal keeps the
  plain integer.
- Selection state. The cards show their selection by border colour only and carry no selected trait today. This plan
  does not change that.

## Question for Task 2

Show the owner this file (both options with their copy) and ask in Taiwanese Mandarin, verbatim:

「C15（GP 不夠時的壓縮檔畫面）的提案在這裡：兩種顯示方式各附六種語言的文案。想請你決定：一、用 U1 還是 U2（我建議 U1：卡片還能選，但選了買不起的就停用下載鈕，下面一行說明差多少 GP）；二、文案可以照這樣用，還是要改哪裡；三、網站上壓縮檔的價格實際是怎麼寫的（例如「180」、「180 GP」還是「1,234 GP」），H@H 下載扣的是 GP 對嗎？」
