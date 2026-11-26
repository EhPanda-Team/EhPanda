# Quick 261126-wzg: My Tags editor suggestions, colour feedback and weight field

Owner request (2026-11-26): the native My Tags page should replace the site's /mytags page; the owner approved the
gap designs. This task covers the Add Tag / Edit Tag editor's gaps. Branch `develop`; it touches the `MyTagEditor`
module, `TagSuggestionView` and a new suggestion request, and runs after quick 261126-udx lands.

## The design (owner-approved 2026-11-26)

EhPanda App Design canvas, page "Screens v1.1.0", section 21, canvas version 1795703968-3cc3, and its behaviour file
`app/behavior/21-my-tags.md` in the local `ehpanda-design` repository (sections named below). The boards and the
behaviour file are the spec for layout, states and interaction; where they and this file differ on copy, this file
wins (the design's English is placeholder). Owner decisions that stay (2026-11-26): a swipe removes one tag at once
(D-05), a tag without a colour shows "No Color" (D-06), Enabled and Default Color save at once (no Save button), New
Tag Set starts empty. D-09 (My Tags hidden under Bypass SNI Filtering) is unchanged and out of scope.

Boards: `MyTags-Editor-States` (Add Tag, Alias Suggestion, Edit Tag, Invalid Color, Weight Typed, Saving, Save
Failed), `MyTagEditorView` (component), `TagSuggestionView` (component: the alias line), `MyTags-iPad-States`. The tag
preview was removed by the owner: no Preview section. Behaviour file section: "Add Tag and Edit Tag".

## Site contract (the site's live `ehg_mytags.c.js` and its API, read and probed 2026-11-26)

- Suggestions: the site's `tagcompleter` POSTs JSON `{"method":"tagsuggest","text":<text>}` to its API (the
  `api.php` the app already calls for `setusertag`), 200 ms after typing stops, only when the text after the
  namespace has at least 2 characters. Before sending it rewrites loose namespace prefixes: `x…:`/`mix…:` → `mixed:`,
  `mis…:` → `temp:`, `co…:` → `cosplayer:`, `lo…:` → `location:`, then `t…:` temp, `f…:` female, `m…:` male, `r…:`
  reclass, `l…:` language, `p…:` parody, `c…:` character, `g…:` group, `a…:` artist, `o…:` other; quotes are removed.
- The answer (probed anonymously 2026-11-26): `{"tags":{"<id>":{"ns":"female","tn":"glasses"},"<id>":{"ns":"female",
  "tn":"sun glasses","mid":37587,"mns":"female","mtn":"sunglasses"}}}`; with no match `{"tags":[]}` (an empty JSON
  array, not an object: the decoder must accept both). `mid`/`mns`/`mtn` mark an alias: the entry's own `ns:tn` is
  the alias, `mns:mtn` the master tag that is inserted. The site shows the entries whose `ns:tn` matches the typed
  text at a word start (`(^| |:)<text>`, case-insensitive). An answer with `error` carries a message; with `login`
  the session expired.

## Decisions (orchestrator, 2026-11-26; locked for planning)

- **G-1 Suggestions.** In Add Tag, from the 2nd character after the namespace, the site's suggestions show under the
  field as rows (`TagSuggestionView`, form placement), whatever "Show Tag Suggestions" says; debounced (the site's
  200 ms) and cancelled when the text changes; a failed request shows no rows and no alert. With "Translate Tags" on,
  the local translation matches are added and translated names shown, as today; the planner states how the two lists
  merge without duplicates. An alias suggestion's row shows the master tag and a third line `my_tags.alias` with the
  alias; a tap inserts the master tag. A chosen suggestion fills the field. The request is its own type in its own
  file (not `Request+MyTags.swift`), with a parser test against the probed shapes (both the object and the empty
  array), synthetic ids only.
- **G-2 Invalid colour.** While the hex field's text is neither empty nor a valid code, the Color section's footer is
  `my_tags.hex_invalid` in red, the well keeps the last valid colour, and confirm is disabled; submitting an invalid
  code still restores the last valid one (today's behaviour). Valid or empty text shows the existing footers.
- **G-3 Weight field.** A number field (trailing, prompt "0", `.numbersAndPunctuation`, up to three characters,
  accessibility label the existing weight label) beside the existing Stepper, −99…99. Submit or leaving the field
  clamps into range; empty or unreadable text returns to the last value; the field and the Stepper follow each other;
  the Stepper's end halves disable at the range ends.
- **G-4 Tests.** Feature tests for suggestion debounce, cancel, the alias insert, the 2-character threshold, the
  prefix rewrite, failure showing nothing; the invalid-colour footer and confirm gating; weight parsing, clamping and
  sync. Request and parser tests for the suggestion API.

## Copy

Each locale was written by its own writer from the facts, then read by its own blind reviewer, then checked side
by side (2026-11-26). The executor copies the values verbatim and does not write or change copy. `{count}` marks the
number: a COUNT key becomes a labeled `%#@count@` substitution with an integer plural variable (CLAUDE.md "Labeled
localized-format arguments"; en/de `one` + `other`, ja/ko/zh-Hans/zh-Hant `other` only), so the generated symbol takes
`count:`. `%@` stays positional (a String). Zero tags never reaches `my_tags.tag_count`: the app shows
`my_tags.no_tags` for a set without tags. `…` is U+2026, zh-Hant `⋯` is U+22EF, German keeps the space before `…`,
apostrophes and quotes are the curly forms shown. If a key cannot be added exactly as specified, the executor stops
and reports. `my_tags.alias` takes the alias as `%@`; `my_tags.hex_invalid` is the red footer.

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `my_tags.hex_invalid` | Enter a color code with six hexadecimal digits, such as #1F3A93. | Ein gültiger Farbcode besteht aus sechs Hexadezimalziffern, z. B. #1F3A93. | カラーコードは #1F3A93 のように16進数6桁で入力してください。 | 색상 코드는 #1F3A93처럼 16진수 6자리로 입력하십시오. | 颜色代码应为六位十六进制数字，例如 #1F3A93。 | 請輸入 6 位數的十六進位色碼，例如 #1F3A93。 |
| `my_tags.alias` | Also known as %@ | Alias %@ | 別名 %@ | 별칭 %@ | 别名 %@ | 別名 %@ |

## Rules

As for quick 261126-udx: CLAUDE.md / AGENTS.md, the root `.swiftlint.yml` first, no suppressions; `Feature` suffix;
dialog placement on the action source; scroll-edge policy unchanged; parallel tests; document the WHY; remove
emptied actions. One atomic signed commit per task, `TZ=Asia/Shanghai`, author and committer dates +08:00, subject
<= 50 characters, no attribution lines, nothing pushed. One `xcodebuild test` at a time (check `pgrep -x xcodebuild`
/ `pgrep -x xctest` first; another project's or session's run may be going, wait for it). Simulator "EhPanda iPhone
Air (phase19)", id `19DB23C0-8C35-49C7-9A7D-5D99566BF092`. 0 warnings, lint `--strict` clean, test files included.
The live site cannot be exercised without the owner's account: the SUMMARY lists the owner's device checks.
