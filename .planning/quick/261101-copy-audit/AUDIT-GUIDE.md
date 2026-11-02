# EhPanda copywriting audit: shared guide

## The owner's goal, in their words (translated)

The app's copy probably contains a lot of literal translation and other unnatural wording. The owner
wants it to read smoothly for a native speaker. The goal is **quality localization, not translation**,
so there is no need for word-for-word correspondence. English is the base language, but the owner is
not confident about some English usages either (their example: "Give a Rating"). The audit must also
respect the text length the UI design prefers.

This is an AUDIT. **Do not edit anything in the repository.** You only write your findings file.

## The product

EhPanda is a native iOS / iPadOS client (SwiftUI, iOS 27) for the E-Hentai / ExHentai gallery site:
browsing, search, favorites, gallery detail, a reader, and offline downloads. Its users are fans who
already know the site. Tone: a well-made native Apple app. Plain, calm, compact, matter-of-fact; never
cute and never corporate. It must read like Apple's own apps in that language.

## Method

1. Read `~/.claude/skills/writing-for-interfaces/SKILL.md` and its `references/patterns.md` once.
2. Read your whole input file in pages (Read with offset/limit, about 800 lines at a time). Audit
   **every** entry. Do not sample. The file ends with the country and language name lists.
3. For anything ambiguous, read the Swift call site from `refs:` (paths are relative to
   `AppPackage/Sources/`). The string's real job on screen outranks its key name and its English.
   Judge meaning from behavior, then write what a native speaker would naturally say there.
4. Write your findings file (schema below). Only list entries worth changing. Silence means "fine".

## What to look for

- Errors: typos, grammar, wrong meaning, untranslated text, output that breaks for real values
  (for example "1 pages"), placeholders or plural forms that read wrong.
- Literal translation: structure or word choice calqued from English (or, in the source, from another
  language) that no native writer would produce. Rewrite freely; change the sentence structure.
- Register: must match how Apple's own iOS apps speak in this language (terms, sentence endings,
  button verb forms, capitalization, punctuation, ellipsis, spacing).
- Terminology: one concept gets one name across the whole app. Report the unified glossary.
- Length: a string longer than its surface wants is a defect even when the wording is good.
- Developer-speak: jargon the user does not need ("manifest", "parse error").
- Web-isms: many Settings footers were copied from the website's settings page and mention mice,
  browsers, clicking and "the front page". They still configure the website account, so keep the
  facts, but write them for someone reading on an iPhone, and much shorter when possible.
- Repetition: a footer that only restates its row title.

Do not change things merely to differ. Do not pad. Do not "improve" a string that is already what a
native writer would write. Prefer the shorter of two equally natural options.

## Surfaces and length budgets

Each entry carries a tier from automatic classification. It can be wrong; check the call site when it
matters, and say so in your reason if you overrule it.

| Tier | Meaning | Rule |
| --- | --- | --- |
| T1 | Hard width limit: tab bar, badge, category chip, compact button, segmented control, info strip | Must fit its stated budget at default text size on a 375 pt wide iPhone. |
| T2 | One line wanted: Form row, toggle, nav title, menu item, section header, picker | Should fit one line at 375 pt. Wrapping is possible but counts against it. |
| T3 | Supporting text: footer, alert body, description | May wrap. Shorter is still better. |
| A11Y | VoiceOver only, never visible | No width limit, must sound natural when spoken. |

Width estimates (default Dynamic Type). CJK glyph is about 1 em. Latin glyph averages 0.5 to 0.55 em.
Sizes: caption 12, footnote 13, subheadline 15, callout 16, body 17, title2 22, large title 34.

- Toggle row label: about 250 pt at 17 pt, so about 14 CJK glyphs or 28 Latin characters.
- Picker row: label and trailing value share about 300 pt.
- Inline navigation title: about 220 pt at 17 pt semibold, so about 12 CJK or 24 Latin characters.
- Alert buttons side by side: about 130 pt at 17 pt, so about 7 CJK or 14 Latin characters.
- Detail action buttons (rating, similar): two across, callout bold with an icon, about 150 pt of text.
- Download badge: caption bold, single line, about 90 pt. Segmented control of 3: about 110 pt each.

German runs long: compound nouns are welcome only if they fit. Prefer a shorter native word over
hyphen-wrapped compounds on T1 and T2.

## Domain concepts (semantics, not translations)

Use each locale's established fan and site vocabulary where one exists. Do not sanitize category names.

- **Gallery**: one uploaded work. **Uploader**: the account that posted it.
- **Frontpage**: the site's main listing. **Popular**: currently trending galleries site-wide.
  **Watched**: recent uploads matching tags the user subscribes to on the site.
  **Toplists**: the site's ranked lists (Yesterday / Past Month / Past Year / All Time).
  **History**: galleries the user opened in this app. **Library**: the tab that holds Favorites and Downloads.
- **Favorites**: the site's favorites, in up to 10 categories ("Favorites 0" is a default category name).
- **Archives**: a site-generated ZIP of a gallery that costs site currency. **Archiver**: the site's name
  for that feature. **Torrents**: BitTorrent downloads of a gallery. **Downloads**: this app's own offline
  copies. These three are different things and must stay distinct.
- **H@H** / **Hath**: Hentai@Home, the site's volunteer image network. Proper noun; keep "H@H". A user may
  have an H@H client. **GP** (gallery points), **Credits**: site currencies.
- **Expunged**: removed from normal listings by site moderation, still reachable with a filter.
- **Resampled image**: the site's downscaled copy. **Original**: the uploaded file.
- **Tag namespaces**: artist, character, cosplayer, female, male, group, language, mixed, other, parody,
  reclass, temp. **Tag power / low-power tag**: community vote weight. **Downvoted tag**: voted against.
  **My Tags**: the user's tag subscriptions on the site, with weights.
- **Profile** (Settings): a named preset of site settings on the user's account. **Host**: E-Hentai vs ExHentai.
- **Quick Search**: user-saved search phrases. The UI calls one a "word" today; the Search screen calls them
  "saved searches". **Recently Seen / Recently Viewed**: same browsing history.
- **Jump Page / Date Seek**: jump to a page of a list, or to galleries posted around a date.
- **Repair / Update / Redownload**: download actions. Repair fetches only damaged pages of an offline copy.
  Update re-downloads to the gallery's newest version. Redownload starts over.
- **Validate image data**: checks offline image files against their recorded hashes.
- **Manifest**: internal record of a download. Users should not need this word.
- **New Dawn greeting**: a daily site event. `first` ("It is the dawn of a new day!") and `second` are the
  site's RPG flavor text shown on a full-screen moment, and `greeting.*` assembles "You gain 30 EXP, 100
  Credits and 5 GP!" from pieces at runtime. Flavor is intentional and welcome here.
- **Laboratory**: Settings page for experimental features. **Bypass SNI Filtering**: a censorship workaround.
- **App Activity Logs**: diagnostic logs, reachable from Settings. Log levels are technical and may stay so.

## Hard constraints on proposals

- Keep every placeholder exactly: `%@`, `%1$@`, `%2$@`, `%lld`, `%arg`, `%#@name@`, Markdown `**`, and `\n`
  where line breaks are meaningful. You may reorder positional `%1$@`/`%2$@` when the language needs it.
- Plural categories per variable: `en` and `de` use the same set; `ja`, `ko`, `zh-Hans`, `zh-Hant` use `other` only.
  If a string needs a plural that it lacks (it would show "1 pages"), record it under `structural`, and
  also propose the wording.
- Numeric arguments stay in named substitutions; do not propose a bare `%lld` in a new form of a
  module-local key. `%@` stays positional.
- `ratings_color_prompt` and the R/G/B/Y letters in `ratings_color_description` are literal values the site
  accepts and must stay as those Latin letters.
- `greeting.*` and `ban_interval.and` are concatenated at runtime: spaces and punctuation in them matter.
  Check `Greeting.swift` and `AppError.swift` before touching them.
- `category.non_h` in zh-Hans/zh-Hant was just changed by the owner to 全年龄/全年齡. Treat as decided.
- Live Text uses Apple's official name for the feature in each language. Treat as decided.
- If a key appears to be unused (`refs: none found`), still review it, but mark `"unused": true`.
- Non-translated `Constant.xcstrings` entries are excluded from this audit.

## Output

Write one UTF-8 JSON file at the path your brief names. Validate it with `python3 -I -m json.tool`.

```json
{
  "locale": "de",
  "register_notes": "2-5 sentences in Traditional Chinese (Taiwan) on the current register and the target",
  "glossary": [
    {"concept": "Sign in", "use": "Anmelden", "avoid": ["Einloggen"], "note_zh": "..."}
  ],
  "structural": [
    {"catalog": "...", "key": "...", "issue_zh": "問題與建議的結構修改,例如缺少單複數、字串重複使用於不同情境"}
  ],
  "findings": [
    {
      "catalog": "HomeFeature/Localizable",
      "key": "toplists",
      "path": "",
      "current": "...",
      "proposed": "...",
      "severity": "P1",
      "type": "literal",
      "tier": "T2",
      "reason_zh": "一句話,台灣華語,說明哪裡不自然、為何這樣改",
      "gloss_zh": "建議文案的意思,僅非中文語系需要;中文語系留空字串",
      "unused": false
    }
  ]
}
```

- `path`: empty for the plain value. For a plural or substitution variant, copy the suffix exactly as the input
  shows it after the locale name, for example `{count}[plural:one]`.
- `type`: one of `error`, `literal`, `unnatural`, `terminology`, `length`, `register`, `jargon`, `webism`,
  `repetition`, `punctuation`, `capitalization`.
- `severity`:
  - **P0** visibly wrong: typo, grammar error, wrong meaning, untranslated, broken output.
  - **P1** a native speaker notices it reads translated or awkward, on a surface users see often, or it
    breaks platform convention on a primary surface, or it overflows a T1 budget.
  - **P2** understandable but clearly improvable, inconsistent term, or too long for a T2.
  - **P3** polish on low-visibility text.
- Group related entries: if one term changes across 20 keys, list all 20 findings so the change is complete.
- Write `reason_zh`, `gloss_zh`, `note_zh`, `issue_zh`, `register_notes` in Traditional Chinese as used in Taiwan.
  Avoid em dashes in them.

Your final chat message must be under 120 words: finding counts per severity plus the three most important
patterns you found. All detail belongs in the file.
