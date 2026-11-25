# 19-25 C15 proposal: insufficient funds on Archives

Status: decided 2026-11-25: C15 is accepted, nothing lands in source (see "Owner decision"). Before that it was
proposed, waiting for the owner's answer (Task 2). Nothing in this file has landed in source. No key, string or
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
| Unaffordable card (Button) | unchanged, VoiceOver reads the card text: resolution, size, price | `accessibility.archive_unaffordable` | still activatable |
| Other cards | unchanged | none | unchanged |
| Download button | `download_to_hath_client`, unchanged | none | `.disabled`, so VoiceOver reports it as dimmed |
| The line | its own text, static, read directly after the button | none | not hidden, not repeated as a hint |

Keys (module-local, `DetailFeature/Resources/Localizable.xcstrings`, `extractionState` manual, `state` translated in
every locale):

- `archives_insufficient_funds`, generated as `func archivesInsufficientFunds(cost: Int, balance: Int)`.
- `accessibility.archive_unaffordable`, generated as `accessibilityArchiveUnaffordable`, no arguments. It is a
  spoken value, so it takes the `accessibility.` prefix and the spelled-out currency of the existing spoken balance
  label (`accessibility.gallery_points_balance`).

Format variables:

| Key | Variable | argNum | Specifier | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|---|---|---|
| `archives_insufficient_funds` | `cost` | 1 | lld | other | other | other | other | other | other |
| `archives_insufficient_funds` | `balance` | 2 | lld | other | other | other | other | other | other |
| `accessibility.archive_unaffordable` | none | none | none | none | none | none | none | none | none |

Each variable's `other` value is `%arg`. GP is the unit abbreviation and does not change with the count, so `other`-only
is coherent for en and de, as it is in the existing balance keys.

#### `archives_insufficient_funds`

| Locale | Text |
|---|---|
| en | The selected archive costs %#@cost@ GP, but you only have %#@balance@ GP, so you can't download it to your H@H client. |
| de | Das ausgewählte Archiv kostet %#@cost@ GP, du hast aber nur %#@balance@ GP. Deshalb kannst du es nicht auf deinen H@H-Client laden. |
| ja | 選択したアーカイブには%#@cost@ GPが必要ですが、残高が%#@balance@ GPのため、H@Hクライアントにダウンロードできません。 |
| ko | 선택한 아카이브는 %#@cost@ GP가 필요하지만 잔액이 %#@balance@ GP뿐이어서 H@H 클라이언트로 저장할 수 없습니다. |
| zh-Hans | 所选归档需要 %#@cost@ GP，但你目前只有 %#@balance@ GP，无法下载到 H@H 客户端。 |
| zh-Hant | 所選壓縮檔需要 %#@cost@ GP，但你目前只有 %#@balance@ GP，無法下載至 H@H 用戶端。 |

#### `accessibility.archive_unaffordable`

| Locale | Text |
|---|---|
| en | Not enough Gallery points |
| de | Nicht genug Galeriepunkte |
| ja | ギャラリーポイントが足りません |
| ko | 갤러리 포인트 부족 |
| zh-Hans | 画廊点数不足 |
| zh-Hant | 畫廊點數不足 |

Word choice per locale (U1), after the blind review (see "Blind locale review"):

- Every locale names the selected archive ("The selected archive", "Das ausgewählte Archiv", 選択した, 선택한, 所选,
  所選), because the line sits under the button and the sheet lists several cards.
- en: active "you can't download it to your H@H client", which repeats the button's verb and noun.
- de: two sentences instead of one chained clause, informal "du" as in "Dein H@H-Client ist offline"; "laden" as in the
  button.
- ja: 「残高が…GPのため」 makes the second half the result of the first, polite です/ます as the neighbouring keys,
  「H@Hクライアント」 with no space, a space between the number and GP.
- ko: 「뿐이어서」 fits the app's 합니다 register better than 「뿐이라」; 「잔액」 and 「저장」 as in the existing keys.
- zh-Hans and zh-Hant: 「目前只有」 for the balance, the everyday way Taiwan copy states a balance and natural in
  mainland copy too, so both carry it; 归档 / 壓縮檔, 客户端 / 用戶端 and 下载到 / 下載至 as in the existing keys.
- Spoken value: five of the six reviewers preferred the spelled-out currency, because VoiceOver reads "GP" letter by
  letter and the spoken balance on the same sheet already says Gallery points. The ja reviewer preferred 「GP」 only on
  the condition that the card's spoken price says "GP"; the card speaks its price as the bare site text (for example
  "380") with no unit, so that condition does not hold and every locale spells the currency out.

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
| Unaffordable card (Button) | unchanged, VoiceOver reads the card text | `accessibility.archive_unaffordable` | `.disabled`, tap ignored |
| Other cards | unchanged | none | unchanged |
| Download button | `download_to_hath_client`, unchanged | none | `.disabled` only without a selection |
| The note under the funds | its own text, static, read after the funds | none | not hidden |

Keys:

- `archives_unaffordable_list`, generated as `func archivesUnaffordableList(_ arg1: String)`, one positional `%@`.
- `accessibility.archive_unaffordable`, the same key and text as in U1.

Format variables:

| Key | Variable | Kind | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|---|---|
| `archives_unaffordable_list` | `%@` list of resolutions | positional string | none | none | none | none | none | none |
| `accessibility.archive_unaffordable` | none | none | none | none | none | none | none | none |

Neither key has a numeric argument, so neither has a plural variation. The list is one string, so the wording does not
depend on how many archives are named (every locale's line holds for one archive or for three).

#### `archives_unaffordable_list`

| Locale | Text |
|---|---|
| en | You don't have enough GP for %@. |
| de | Dein GP-Guthaben reicht nicht für %@. |
| ja | GPが足りずダウンロードできないアーカイブ：%@ |
| ko | GP가 부족해 저장할 수 없는 아카이브: %@ |
| zh-Hans | GP 不足，无法下载：%@ |
| zh-Hant | GP 不足，無法下載：%@ |

#### `accessibility.archive_unaffordable`

| Locale | Text |
|---|---|
| en | Not enough Gallery points |
| de | Nicht genug Galeriepunkte |
| ja | ギャラリーポイントが足りません |
| ko | 갤러리 포인트 부족 |
| zh-Hans | 画廊点数不足 |
| zh-Hant | 畫廊點數不足 |

Word choice per locale (U2), after the blind review:

- Every reviewer found the first draft read as if the archives were short of GP. Each line now says the account is
  short and, where the language puts the list after a label, what it prevents.
- en and de name the shortfall with the list as its object ("You don't have enough GP for %@.", "Dein GP-Guthaben
  reicht nicht für %@."), which reads for one archive or several without a plural noun.
- ja and ko keep a label before the list and state the result (ダウンロードできない, 저장할 수 없는).
- zh-Hans and zh-Hant state cause then result (「GP 不足，无法下载：」), the full-width colon as in the existing labels.

## Pair check: zh-Hans against zh-Hant

The check reads this file, takes every zh-Hans and zh-Hant row under the same key, converts the zh-Hans text with the
regional-word table first and the script table second, and requires the result to equal the zh-Hant text. Anything
the two tables do not explain fails. The regional words are the ones the existing catalog already pairs
(归档 and 壓縮檔, 客户端 and 用戶端, and the button's 下载到 and 下載至); every other difference must be a
character of the script table.

```python
import re
import sys

REGIONAL_WORDS = {"归档": "壓縮檔", "客户端": "用戶端", "下载到": "下載至"}
SCRIPT_CHARS = {"无": "無", "选": "選", "载": "載", "画": "畫", "点": "點", "数": "數"}

key = None
rows = {}
for line in open(sys.argv[1], encoding="utf-8"):
    heading = re.match(r"#### `([a-z_.]+)`", line)
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
archives_insufficient_funds: OK; applied: 归档->壓縮檔, 客户端->用戶端, 下载到->下載至, 无->無, 选->選
accessibility.archive_unaffordable: OK; applied: 画->畫, 点->點, 数->數
accessibility.archive_unaffordable: OK; applied: 画->畫, 点->點, 数->數
archives_unaffordable_list: OK; applied: 无->無, 载->載
pairs-with-differences 0
```

## Open points for the owner

- Price format. The card price text is shown as the site wrote it, and the rule accepts "Free", plain digits, comma
  grouping and a trailing " GP". Whether the site writes archive prices in one of those forms is not provable from the
  repository (see Evidence). The H@H cost is assumed to be paid in GP; the screen shows the account's GP and Credits.
- Spoken currency. Settled by the blind review: the spoken value spells the currency out, as the spoken balance does
  (see "Word choice per locale (U1)"). The visible lines keep "GP", as the site and the funds row write it.
- Number grouping. The numbers in the line are grouped by the locale, as the funds row's are: a labeled numeric
  argument of a generated `LocalizedStringResource` is formatted with the resource's locale (checked with the 27.2 SDK:
  24680 reads "24,680" in en and ja and "24.680" in de). Task 3 checks it in a picture with a balance of four digits
  or more.
- Selection state. The cards show their selection by border colour only and carry no selected trait today. This plan
  does not change that.

## Question for Task 2

Show the owner this file (both options with their copy) and ask in Taiwanese Mandarin, verbatim:

「C15（GP 不夠時的壓縮檔畫面）的提案在這裡：兩種顯示方式各附六種語言的文案。想請你決定：一、用 U1 還是 U2（我建議 U1：卡片還能選，但選了買不起的就停用下載鈕，下面一行說明差多少 GP）；二、文案可以照這樣用，還是要改哪裡；三、網站上壓縮檔的價格實際是怎麼寫的（例如「180」、「180 GP」還是「1,234 GP」），H@H 下載扣的是 GP 對嗎？」

## Blind locale review

Done by the orchestrator on 2026-11-25 before Task 2, under the project's rule that each locale is read by a reviewer
who has not seen the English. Six reviewers, one per locale; each saw only its own locale's draft, that locale's
neighbouring strings on this sheet and the facts each line must express. What they found and what changed:

- U1 line: every non-English reviewer asked that the line name the selected archive, since it sits under the button
  among several cards; adopted in every locale. en: passive "it can't be downloaded" made active. de: the chained
  sentence split in two. ja: 「のため」 added so the second half reads as the result. ko: 「뿐이라」 to 「뿐이어서」 for
  the 합니다 register. zh-Hant: 「目前只有」 for the balance, carried into zh-Hans to keep the pair aligned (the zh-Hans
  reviewer found the draft natural and offered 所选 as an improvement).
- Spoken value: spelled-out currency in every locale (five of six; the sixth's condition does not hold, see above);
  the key is renamed to `accessibility.archive_unaffordable` to match the other spoken keys.
- U2 line: every reviewer found the draft described the archives as short of GP; each locale rewritten as recorded
  above.

## Owner answers, first round (2026-11-25)

Asked by the orchestrator in Taiwanese Mandarin, four questions. Answers, verbatim:

- Display: 「維持現狀，卡片 disabled 不能選，不用加一列」 (an unaffordable card is disabled and cannot be selected; no
  line is added).
- Copy: 「你有按 global agents.md 的指示來寫嗎」. Answered honestly: not fully. One writer drafted all six locales
  with the English and the other locales in view, the blind reviewers corrected those drafts instead of writing from
  the facts, and one zh-Hant change was carried into zh-Hans. The copy that the owner's display choice still needs is
  rewritten under the rule: one writer per locale from the facts alone, then a different blind reviewer per locale,
  then the side-by-side and pair checks.
- Price format: 「你去網站看」. Done, see "Site evidence".
- Currency: 「不確定」. Settled by the site, see "Site evidence".

## Site evidence (2026-11-25)

Read by the orchestrator on e-hentai.org with a signed-in account, read only (no download, no purchase, no form
submitted), from one gallery's archiver page (`archiver.php?gid=…&token=…`) and the site's wiki.

- The H@H table, the part the app parses: each cell is `<p><a onclick="return do_hathdl('1280')">1280x</a></p>`,
  `<p>64.01 MiB</p>`, `<p>1343 GP</p>`. So the H@H price is digits with no grouping and a trailing " GP", even above
  999 ("14441 GP"). The direct-download section above it writes the same costs grouped ("Download Cost: 14,441 GP");
  the app does not parse that section. The proposal's cost rule (digits, optional "," grouping, optional " GP")
  already covers both. Note that the fixtures' bare "180" is not what the site writes; the card shows the stored text,
  so a real card reads "1343 GP".
- The funds line (the account's amounts replaced): `<p>1,234 GP [<a href="…/wiki/Gallery_Points">?</a>] &nbsp; 5,678 Credits [<a href="…/wiki/Credits">?</a>]</p>`,
  as `parseCurrentFunds` expects.
- The page does not mark or disable an H@H size the account's GP cannot pay: on an account whose GP was below every
  H@H price, all five sizes were the same plain links.
- What pays for an archive, from the wiki page "Gallery Points", section Uses: "Purchasing archives of galleries. …
  Credits can be used in place of GP for the above if not enough GP are available. In these cases, the system
  auto-converts credits to GP using the "High" rate from the last 24 hours in the GP Exchange."

Consequence for the rule: a price above the GP balance does not mean the archive cannot be downloaded. The site
covers the shortfall from Credits at an exchange rate the app does not know. A gate on GP alone would block downloads
the site would fulfil, which is exactly T-19-54. Only a price above the GP balance with no Credits at all (a known
zero) is certainly unaffordable. When the site does refuse, the app already shows the site's own response text
(`parseDownloadCommandResponse`) in a toast.

## Owner decision

Asked of the owner by the orchestrator on 2026-11-25, second round, in Taiwanese Mandarin, after the site evidence:
the H@H price reads "1343 GP" and is paid in GP, but the site covers a GP shortfall from Credits at the GP Exchange's
24-hour "High" rate, which the app does not know, and the site itself does not grey out a size the GP cannot pay. The
question was when a card should be disabled, with three options: only when it is certainly unaffordable (a price above
the GP balance and no Credits; recommended), never (C15 accepted), or on GP alone (blocks downloads the site would
fulfil, T-19-54). Answer, verbatim: 「不停用，C15 改為接受」.

- Option: **accepted**, neither `U1` nor `U2`. No card is disabled and the download button keeps its current gate (a
  selection). The app does not judge affordability; the site decides, and its response is shown in the toast as
  today. Decided by: the owner.
- Copy: none. No key is added, so no copy table is final and the six-locale drafts above are not used. The copy
  rewrite promised in the first round's answer is therefore not needed.
- Price format: the site writes the H@H price as digits with " GP" and no grouping ("1343 GP"), see "Site evidence".
  No parser change follows from it, because nothing reads the price as a number.
- Task 3 is not run: there is no approved design or copy to implement. `HathArchive.gpCost`, the affordability gate
  and the three planned test files are not written.
- C15 in `19-13-PRECHECK.md` is now accepted, with this reason. The `detail-pages-archives-insufficient-funds` picture
  stays as it is in the next recording.
