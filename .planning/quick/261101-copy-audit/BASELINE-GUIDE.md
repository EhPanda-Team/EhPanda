# Everyday-usage re-review

## Why this pass exists

The owner wants copy that reads naturally to a native speaker: quality localization rather than translation.
The first audit's brief also told reviewers to match Apple's own apps, and where Apple's wording differs from
what people in that language see every day, reviewers chose Apple. In Traditional Chinese that replaced natural
words with Apple-specific ones: 複製 became 拷貝, 剪貼簿 became 剪貼板, 篩選 became 過濾. The owner has now set the
baseline for every language:

**Use what a native speaker sees every day in mainstream apps and websites in that language. Apple's wording is
only a tie-breaker when everyday usage has no clear preference.**

Many Apple terms ARE the everyday term. Those stay. This pass is a narrow correction, not a redo: do not reopen
grammar, tone or length decisions unless the baseline forces it, do not change a string merely to differ from
Apple, and do not revert a proposal that fixed a real error.

This is still an audit. **Do not edit anything in the repository.** You write only your output file.

## Method

1. Read your input file in full. Section B lists proposals justified by Apple's wording, section C shows every
   final string, and section D lists names. `*` marks a string a first-pass proposal changed.
2. For each term where Apple's wording and everyday usage differ, decide which one a native reader expects on
   this surface. Check section C for every occurrence, including strings the first pass left alone, since an
   Apple-specific term may already be in the catalog.
3. Look for what the first pass could not see because of its brief: Apple-specific vocabulary, Apple's spelling
   or punctuation habits, and rules imposed to match Apple. Examples of the kind of thing to look for, which you must
   verify rather than assume:
   - Japanese: long-vowel marks (ユーザ vs ユーザー, フィルタ vs フィルター, カテゴリ vs カテゴリー), クッキー vs Cookie.
   - Simplified Chinese: 拷贝 vs 复制, 轻点 vs 点击, 储存 vs 保存, 蜂窝网络 vs 移动数据, 通用 vs 常规.
   - Korean: 보관함 vs 라이브러리, whether 합니다 style really is what Korean apps use for each kind of string.
   - German: Mediathek vs Bibliothek, Apple-only compounds.
4. Be honest about certainty. If everyday usage is genuinely split, keep the current choice and say so in `notes_zh`.
   A register change that would touch dozens of strings is an owner decision: record it under `owner_decisions`
   rather than changing the strings.

Domain vocabulary, length budgets and hard constraints from `GUIDE.md` in this folder still apply: placeholders,
plural categories, Markdown, the R/G/B/Y letters, runtime concatenation, and the owner's decided terms. Consult
`GUIDE.md` for these. The app's own Live Text feature keeps Apple's official name. `download_badge.*` status strings are
VoiceOver-only and have no width limit.

Width guide at the default text size on a 375 pt iPhone: toggle row 250 pt at 17 pt; picker row label about 190 pt at
17 pt; inline navigation title 220 pt at 17 pt semibold; category chip 84 pt at 12 pt bold and also 100 pt at 17 pt; info
strip 80 pt at 12 pt, with titles shown uppercase; detail action button 143 pt at 16 pt bold; segmented control of 3 is 98 pt at 13 pt.

## Output

Write one UTF-8 JSON file at the path your brief names and validate it with `python3 -I -m json.tool`.

```json
{
  "locale": "ja",
  "notes_zh": "2-5 句,台灣華語,說明這個語言 Apple 用語與日常用語的差距有多大,以及哪些維持不動",
  "glossary_updates": [
    {"concept": "User", "use": "ユーザー", "avoid": ["ユーザ"], "note_zh": "..."}
  ],
  "owner_decisions": [
    {"question_zh": "...", "detail_zh": "...", "options": ["建議選項", "另一個選項"]}
  ],
  "changes": [
    {
      "action": "rewrite",
      "catalog": "AppModels/Localizable",
      "key": "app_error.login_rejected_solution",
      "path": "",
      "current": "the catalog value before any proposal, copied from section B or the first-pass finding when you can",
      "proposed": "new final text",
      "severity": "P2",
      "type": "terminology",
      "reason_zh": "一句話,台灣華語,說明日常用語是什麼",
      "gloss_zh": "建議文案的意思,僅非中文語系需要;中文語系留空字串"
    }
  ]
}
```

`action` is one of:
- `withdraw`: drop the first-pass proposal so the string keeps its catalog value.
- `rewrite`: replace the first-pass proposal, or the current value if there was no proposal, with `proposed`.

Use the exact `catalog`, `key` and `path` from the input. Omit `current` if you do not have the raw catalog value;
a later script fills it in. List every affected key so a term change is complete.

Write `reason_zh`, `gloss_zh`, `note_zh`, `notes_zh`, and the decision text in Traditional Chinese as used in Taiwan, without
em dashes.

Your final chat message must be under 80 words: counts of withdraw and rewrite, plus the most important term changes.
