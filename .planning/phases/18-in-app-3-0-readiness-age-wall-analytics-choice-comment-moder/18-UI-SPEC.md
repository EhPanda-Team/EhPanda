---
phase: 18
slug: in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
status: draft
shadcn_initialized: false
preset: none
created: 2026-11-05
author: Colo (design)
---

# Phase 18 — UI Design Contract

> Visual and interaction contract for the Phase 18 screens: the age wall, the analytics choice, the comment
> report and block UI (menu items, confirmations, posting warning, collapsed row) and the Settings changes
> (analytics picker and Privacy Policy row in General; Blocked Users row and list in Account). Written by Colo for
> D-17. Revised after owner msg 1795: None → Minimal, Blocked Users moved to Account.
>
> **Contract nature: new screens inside a shipped design language.** Nothing here restyles an existing screen.
> New screens reuse the app's system typography, its existing AccentColor, its 15pt card radius and its existing
> components. Every string comes verbatim from `18-COPY-FIRST-LAUNCH.md` / `18-COPY-COMMENTS.md`; this file never
> rewords one. Where a copy key is cited, the string is that key's approved text in all six languages.
>
> Sources: 18-CONTEXT.md D-03…D-17 and DD-06…DD-10, the two approved copy files, and the current code
> (`CommentsView.swift`, `DetailView+CommentCells.swift`, `DetailView+Subviews.swift` CommentsSection,
> `PostCommentView.swift`, `GeneralSettingView.swift`, `AccountSettingView.swift`, `AppearanceSettingView.swift`, `AppComponents/*`,
> `App/Assets.xcassets/AccentColor.colorset`). Deployment target iOS 27 (`Package.swift`).
>
> Mockups: 22 frames in `mockups/` beside this file (PNG, 2x), also published as an artifact. Frames are
> illustrations drawn in HTML; SF Symbols in them are stand-in drawings. **Where a frame and this text differ,
> this text wins.**

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (native SwiftUI; shadcn N/A — not a web stack) |
| Preset | not applicable |
| Component library | SwiftUI (iOS 27 SDK) + in-repo `AppPackage/Sources/AppComponents`; TCA for state, alerts via the existing `AppAlertState` / `appAlert` path or TCA `AlertState` (developer's choice, one per screen) |
| Icon library | SF Symbols via SFSafeSymbols — `Image(systemSymbol:)` / `Label(_:systemSymbol:)` only (`systemName:` is lint-banned) |
| Font | System font, Dynamic Type text styles only. No fixed sizes, no `dynamicTypeSize(...)` caps (Phase 10 D-02 still holds) |
| Accent | The existing `AccentColor` asset — #669D34 light / #96D35F dark. No new colour assets |
| New assets | None. The age wall uses the existing `AppIcon_Default` image already loaded by `AppIconView` (`UIImage(named: "AppIcon_Default", in: .main, with: nil)`) |

Mood: quiet, factual, system-native. These screens are a statement and a choice, not a welcome tour — no
illustrations, no gradients, no marketing tone. One accent, used only where listed under Color.

---

## Component Inventory

Enumerated by reading `AppPackage/Sources/AppComponents/` (37 files) and grepping the feature modules — 2026-11-05.
Non-exhaustive for SwiftUI itself; the executor may use any SwiftUI API that meets this contract.

### Reused

| Component | Import path | Use in this phase |
|-----------|-------------|-------------------|
| `View.withArrow()` | AppComponents/ViewModifiers.swift | Blocked Users row in Account settings (chevron, AX-hidden) |
| `AdaptiveStack` / explicit `ViewThatFits(in: .horizontal)` | AppComponents/AdaptiveStack.swift | Collapsed-row layout switch (explicit `ViewThatFits`, because the label has its own line limit — see that file's rule) |
| `SheetCloseToolbar` | AppComponents/SheetCloseToolbar.swift | Close button of the in-app report web sheet, if that route is used (see C-4) |
| `AppAlertState` / `.appAlert` or TCA `AlertState` | AppComponents/AppAlertState.swift | Report, Block and posting-warning alerts |
| `ContentUnavailableView` | SwiftUI | Blocked Users empty state (same as `LibraryView`, `StateViews`) |
| `Picker` `.pickerStyle(.menu)` | SwiftUI | Analytics level in Settings (same as Theme picker in `AppearanceSettingView`) |
| `Button` `.buttonStyle(.glassProminent)` | SwiftUI | Continue on both first-launch screens (same style as Detail's Read button) |
| `Menu`, `.contextMenu`, `.swipeActions`, `.accessibilityActions` | SwiftUI | Comment menu, Blocked Users unblock |
| `Link` | SwiftUI | Privacy Policy (first launch and Settings) |

### New (this phase creates them; names are suggestions)

| Component | Where | Purpose |
|-----------|-------|---------|
| `FirstLaunchGateView` | AppFeature | Hosts the age wall then the analytics choice; replaces `TabBarView` until both are answered (DD-06) |
| `AgeWallView` | AppFeature | Screen 1 |
| `AnalyticsChoiceView` | AppFeature (or SettingFeature, shared) | Screen 2 |
| `CheckboxToggleStyle` | AppComponents | The age-wall checkbox |
| `ChoiceCard` | AppComponents | One analytics level card (radio + name + description) |
| `FirstLaunchContinueButton` | AppComponents | The shared Continue button (C-1) |
| `CommentModerationMenu` | DetailFeature | Menu content shared by the `…` button, the context menu and the accessibility actions |
| `BlockedCommentRow` | DetailFeature/Comments | Collapsed row in the comments list |
| `BlockedCommentCard` | DetailFeature | Collapsed card in the Detail comment strip |
| `BlockedUsersView` | SettingFeature | The Blocked Users list |

---

## Spacing Scale

Points, multiples of 4. Values marked "existing" are the app's own and are not changed.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Level name → level description; text → inline symbol |
| sm | 8pt | Title → body; Continue bar top inset; between Show and Unblock; footnote → Privacy Policy link |
| md-12 | 12pt | Symbol → text inside cards; between level cards; Continue → footnote |
| md | 16pt | Card inner padding; bottom bar bottom inset (above the safe area); list row padding (system) |
| lg | 24pt | Screen side margins on the first-launch screens; icon → title; body → cards (analytics) |
| xl | 32pt | Body → checkbox card (age wall); top of the analytics symbol |
| 2xl | 48pt | Top of content on the age wall (compact width); end padding of AX-size scroll content |
| 3xl | 96pt | Top of content on regular width (iPad, wide windows) — replaces 48 (age wall) and 32→72 (analytics) |

Exceptions:
- **15pt** card corner radius (existing house radius: comment cards, Detail buttons). Used for checkbox and level cards.
- **Column width:** first-launch content is capped at **560pt** wide and centred whenever the window is wider.
- **Continue height:** min 50pt (`.controlSize(.large)` on `.glassProminent`); grows with text.
- **Hit targets:** every new tappable element ≥ 44×44pt (the `…` button gets a 44pt frame around a 17pt glyph).
- Comment cell paddings, Detail card sizes (300–380 × 120pt × scale) and Form metrics are existing and unchanged.

---

## Typography

Dynamic Type text styles only. Sizes listed at the default (Large) setting and at the largest (AX5) for reference;
the system scales between.

| Role | Text style | Default | AX5 | Weight | Where |
|------|-----------|---------|-----|--------|-------|
| Screen title | `.title` | 28pt | 58pt | `.bold()` | Age wall title, analytics title; centred; `.accessibilityAddTraits(.isHeader)` |
| Body | `.body` | 17pt | 53pt | regular | Age wall body + declaration, analytics body, Settings rows |
| Level name | `.headline` | 17pt | 53pt | semibold | Analytics card titles |
| Level description | `.subheadline` | 15pt | 49pt | regular, `.secondary` | Analytics card descriptions |
| Button | `.headline` | 17pt | 53pt | semibold | Continue |
| Collapsed-row label | `.subheadline` | 15pt | 49pt | regular, `.secondary` | "Comment from a user you've blocked" |
| Small pill buttons | `.subheadline` | 15pt | 49pt | semibold | Show, Unblock, Hide (`.controlSize(.small)` bordered) |
| Footnote | `.footnote` | 13pt | 44pt | regular, `.secondary` | Age-wall footnote, `consent.footer`, Settings footers |
| Link | `.footnote` | 13pt | 44pt | semibold, `.primary` | Privacy Policy on the analytics screen |
| Empty state title | `ContentUnavailableView` default | — | — | system | Blocked Users empty |

Rules: no `lineLimit` on any approved sentence except the collapsed label's *horizontal* candidate (C-8); every
text wraps; nothing truncates at any size. `.multilineTextAlignment(.center)` for centred headers and footnotes.

---

## Color

All values are semantic system colours unless they are the accent. Light / dark.

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `systemGroupedBackground` — #F2F2F7 / #000000 | First-launch screen background; Settings |
| Secondary (30%) | `secondarySystemGroupedBackground` — #FFFFFF / #1C1C1E | Checkbox card, level cards |
| Accent (10%) | `AccentColor` — #669D34 / #96D35F | Listed below only |
| On-accent label | `.white` light / `.black` dark | Continue label (contrast below) |
| Destructive | `.red` — #FF3B30 / #FF453A | Block menu item, Block alert button, Unblock swipe action |
| Muted | `.secondary` (secondaryLabel) | Unticked checkbox, unselected radio, collapsed label, descriptions, footnotes, `…` glyph, eye.slash glyph |
| Pill fill | `.bordered` + `.tint(.primary)` (gray fill) in the list; `secondarySystemGroupedBackground` capsule on the Detail strip card | Show / Unblock / Hide |
| Detail strip card | `systemGray5` (existing) | Collapsed card keeps the existing card colour |

**Accent reserved for:** (1) Continue fill when enabled; (2) the ticked checkbox glyph; (3) the selected level's
radio glyph and its 2pt card stroke. Nothing else — not the Privacy Policy link, not the pills. The Settings picker keeps the
system menu-picker look, exactly like the existing Theme picker.

**Contrast (WCAG 2.2):**
- Continue light: white on #669D34 = **3.3:1** — passes AA for large text; `.headline` is semibold ≥ 14pt at every
  Dynamic Type size, so it always counts as large. Dark: **black** on #96D35F = **11.8:1** (white would be 1.8:1 —
  forbidden). Implement as `Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })`.
- Checkbox / radio / card stroke (non-text, ≥ 3:1): #669D34 on #FFFFFF card = 3.3:1 ✓; #96D35F on #1C1C1E = 9.6:1 ✓.
  These glyphs always sit on the card colour, never directly on the grouped background (#669D34 on #F2F2F7 is 2.9:1).
- Disabled Continue: system dimming of `.glassProminent` with `.disabled(true)`; disabled controls are exempt, and
  the state is also announced ("dimmed") and hinted (`age_wall.continue_hint`).
- Increase Contrast: no custom handling needed; all colours are semantic or the asset (no high-contrast
  variants needed). Smart Invert: the app icon on the age wall gets `.accessibilityIgnoresInvertColors()`.

---

## Copywriting Contract

Every string is verbatim from the approved copy files (all six languages). Keys are the copy files' suggested keys;
the catalog may rename them, never the text. Nothing on any screen below may say or suggest the age was checked.

| Element | Copy (key) |
|---------|-----------|
| Age wall title | `age_wall.title` — "EhPanda is for adults" |
| Age wall body | `age_wall.body` |
| Age wall checkbox sentence | `age_wall.declaration` (owner-approved website sentence, unchanged) |
| Primary CTA (both first-launch screens) | `age_wall.continue` — "Continue" |
| Continue hint while dimmed (VoiceOver) | `age_wall.continue_hint` (age wall only — see C-2) |
| Age wall footnote (always visible) | `age_wall.footnote` |
| Analytics title / body | `consent.title` / `consent.body` |
| Level names / descriptions | `consent.level.{minimal,basic,full}` / `…description`. Minimal replaces None (owner msg 1795); its name and description and the new `consent.body` are Camo's wording: name and `consent.body` from msg 1797 (approved msg 1805), Minimal's description from Revision 2 in msg 1815 (**approved msg 1818**, replaces the 1805 line), as shown in the mockups |
| Analytics footer | `consent.footer` |
| Privacy link (both places) | `consent.privacy_link` |
| Settings analytics row | `shareAnalyticsData` (existing key, now a picker); section header `analytics` (existing) |
| Settings analytics footer | the selected level's `consent.level.*.description`; `shareAnalyticsDataFooter` retired |
| Comment menu | `comment.report` ("Report on {site}"), `comment.block` ("Block %@"), `comment.unblock` ("Unblock %@") |
| Report confirmation | `comment.report.confirm_title`, `comment.report.confirm_body`, buttons `comment.report.open` + existing `cancel` |
| Destructive confirmation | Block: `comment.block.confirm_title` / `comment.block.confirm_body`, buttons `comment.block.confirm` (destructive) + `cancel` |
| Posting warning | `comment.filter.title` / `comment.filter.body`, buttons `comment.filter.edit` (default) + `comment.filter.post_anyway` |
| Collapsed row | `comment.blocked_row`, buttons `comment.blocked_row.show`, `blocked_users.unblock` ("Unblock", no name — the row never shows the name) |
| Revealed comment | `comment.blocked_row` + button `comment.blocked_row.hide` |
| Blocked Users title / row in Settings | `blocked_users` |
| Blocked Users footer | `blocked_users.footer` |
| Empty state heading | `blocked_users.empty` — "You haven't blocked anyone." (no body line; none is approved) |
| Empty state body | none |
| Swipe action | `blocked_users.unblock` |
| Error state | none new. All actions are local or open a fixed URL; no new error copy exists or is needed (see UI Considerations) |

`{site}`: use the gallery's site name (E-Hentai / ExHentai) — it is already known per gallery and is what the user
sees elsewhere. `%@`: the commenter's name exactly as shown on the comment.

Note for the copy owner, not a change: the collapsed row's Unblock button reuses `blocked_users.unblock` because the
named `comment.unblock` would print the name the row must hide (D-13). Same word, approved.

---

## Screens

Numbers C-1…C-12 are referenced from UI Considerations. Mockup frame numbers in brackets.

### C-1 · First-launch container (DD-06)

- `FirstLaunchGateView` replaces the whole root content (tab bar or sidebar included) until both answers exist. It
  is not a sheet or a cover over the app: nothing of the app is rendered behind it.
- Background `systemGroupedBackground`, edge to edge. No navigation bar, no back, no close, no skip.
- Content: `ScrollView` → `VStack(spacing: 0)` capped at 560pt, centred, side margins 24pt.
- **Continue bar:** `.safeAreaBar(edge: .bottom)` (soft scroll-edge effect under it) holding `FirstLaunchContinueButton`
  full column width, 8pt top, 16pt bottom above the safe area. At accessibility sizes
  (`dynamicTypeSize.isAccessibilitySize`) the bar is removed and the same button (plus the age-wall footnote) is the
  last item of the scroll content, 24pt below the last card, with 48pt after it — a pinned bar would cover half the
  screen at AX5 [16, 17].
- `FirstLaunchContinueButton`: `Button { } label: { Text(age_wall.continue).frame(maxWidth: .infinity) }`,
  `.buttonStyle(.glassProminent)`, `.controlSize(.large)`, `.tint(.accentColor)`, label colour per Color (on-accent),
  `.keyboardShortcut(.defaultAction)`. `.disabled(...)` per screen.
- Transition age wall → analytics: `.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal:
  .move(edge: .leading).combined(with: .opacity))`, `.smooth(duration: 0.35)`; Reduce Motion → `.opacity`, 0.2s.
  Analytics → app: crossfade 0.3s (Reduce Motion: 0.2s). Right-to-left layouts mirror automatically with `.leading/.trailing`.
- Orientation, iPad multitasking, Stage Manager: layout reads only the offered width (560pt cap) and
  `horizontalSizeClass` for the top padding (compact 48/32, regular 96/72). Never branch on device idiom.
- An upgrader who already answered the age wall but quits before the analytics choice lands on the analytics choice
  next launch (the age answer is stored on Continue, D-04).

### C-2 · Age wall [01, 02, 16, 17, 20]

Top to bottom inside the column:

1. App icon `AppIcon_Default`, 80×80pt (120pt at AX sizes — it is decorative; it does not need to scale further),
   `.clipShape(.rect(cornerRadius: 18, style: .continuous))`, `.accessibilityHidden(true)`,
   `.accessibilityIgnoresInvertColors()`. 48pt from the top (96pt regular width).
2. 24pt · Title `age_wall.title`, `.title.bold()`, centred, `.isHeader`.
3. 8pt · Body `age_wall.body`, `.body`, `.secondary`, centred.
4. 32pt · **Checkbox card:** `Toggle(isOn:) { Text(age_wall.declaration) }.toggleStyle(CheckboxToggleStyle())`.
   - Card: `secondarySystemGroupedBackground`, radius 15, padding 16, full column width, whole card is the hit area
     (`.contentShape(.rect(cornerRadius: 15))`), `.hoverEffect(.highlight)` with
     `.contentShape(.hoverEffect, .rect(cornerRadius: 15))`.
   - Inside: `HStack(alignment: .firstTextBaseline, spacing: 12)` — glyph then sentence (`.body`, primary, leading).
     At accessibility sizes the glyph sits **above** the sentence (`VStack(alignment: .leading, spacing: 12)`) so the
     sentence keeps the full width.
   - Glyph: `square` (`.secondary`) → `checkmark.square.fill` (accent), `.font(.title2)` + `.imageScale(.large)`
     (≈ 28pt at default); `.contentTransition(.symbolEffect(.replace))`; Reduce Motion: no effect.
   - Haptic on tick and untick: `.sensoryFeedback(.selection, trigger: isOn)`.
5. Continue (in the bar) — `.disabled(!isOn)`. While disabled: `.accessibilityHint(age_wall.continue_hint)`.
6. 12pt under Continue · Footnote `age_wall.footnote`, `.footnote`, `.secondary`, centred. **Always rendered** (D-04)
   — in the bar under the button, or at AX sizes right under the in-content button.

Behaviour: unticking re-dims Continue. Continue stores the answer + wording version, then transitions to C-3. There is
no "No" button, no exit button, no "verify", no date picker, no age number, no "18+". Return key triggers Continue
only when enabled.

VoiceOver order: title (header) → body → checkbox ("[sentence], toggle, off/on" — `CheckboxToggleStyle` must add
`.accessibilityAddTraits(.isToggle)` and keep the sentence as the label) → Continue ("Continue, dimmed, button" +
hint) → footnote. Initial focus: the title.

### C-3 · Analytics choice [03, 04, 18, 21]

**Layout decision: separate Continue, not save-on-tap.** Reason: with no default and three long descriptions, people
read and compare before choosing; save-on-tap commits on a stray tap while scrolling and gives no chance to change
your mind, and a shared Continue keeps both first-launch screens one pattern.

1. Symbol `chart.bar.xaxis`, `.font(.largeTitle)` + `.imageScale(.large)` (≈ 48pt at default), `.secondary` (neutral — not accent, so nothing nudges), `.accessibilityHidden(true)`.
   32pt from top (72pt regular width).
2. 16pt · Title `consent.title`, `.title.bold()`, centred, `.isHeader`.
   **Line breaks (owner msg 1822):** the title must never end on a single word. At default size on iPhone, en
   reads "Choose what / EhPanda shares", not "Choose what EhPanda / shares". SwiftUI `Text` does this by default
   (it pulls the previous word down when the last line would hold one word), so: plain `Text`, no `\n` in any
   locale's string, no `.minimumScaleFactor`, no `.lineLimit`, no fixed width on the title. Acceptance: in every
   locale and every text size, the title's last line holds at least two words (zh/ja/ko: at least two characters).
   Same rule for the age wall title (C-2) and the Blocked Users empty-state title.
3. 8pt · Body `consent.body`, `.body`, `.secondary`, centred.
4. 24pt · **Three `ChoiceCard`s**, order Minimal, Basic, Full (owner's order; Minimal replaces None, owner msg 1795), 12pt apart, all identical in size rules,
   type and colour while unselected — no badge, no "recommended", no different weight.
   - Card: `secondarySystemGroupedBackground`, radius 15, padding 16, full width, whole card tappable,
     `.hoverEffect(.highlight)` as C-2.
   - `HStack(alignment: .firstTextBaseline, spacing: 12)`: radio glyph, then `VStack(alignment: .leading, spacing: 4)`
     { name `.headline`; description `.subheadline` `.secondary` }. At AX sizes the radio sits above the text (C-2 rule).
   - Radio: `circle` `.secondary` → `checkmark.circle.fill` accent, ≈ 28pt, `.symbolEffect(.replace)` (none with
     Reduce Motion).
   - Selected card: plus `.strokeBorder(Color.accentColor, lineWidth: 2)` on the card shape. Unselected: no stroke.
   - Initially **none selected**. Tapping a card selects it (and deselects the others); tapping the selected card
     keeps it. Haptic `.selection`.
5. 16pt · `consent.footer`, `.footnote`, `.secondary`, centred.
6. 8pt · `Link(consent.privacy_link, destination: privacyURL)` with a trailing `arrow.up.right` (`.imageScale(.small)`,
   AX-hidden) — `.footnote.weight(.semibold)`, `.primary`, centred, 44pt min hit height. Opens in the default browser
   (same as every other external link in the app). Allowed here: the age wall is already confirmed.
7. Continue in the bar (C-1) — `.disabled(selection == nil)`. No hint string is approved for this screen, so none.

On Continue: store the level, start the SDK only if Basic/Full (DD-09), crossfade to the app.

VoiceOver: each card is one element — `.accessibilityElement(children: .combine)`, `.isButton`, `.isSelected` when
selected, label = name + description. The three cards sit in a container labelled by the title
(`.accessibilityElement(children: .contain)`). Initial focus: the title.

### C-4 · Comment menu (comments list and Detail strip) [05, 09, 22]

Items, in this order:

| Comment state | Item 1 | Item 2 |
|---|---|---|
| Not blocked | `comment.report` — `exclamationmark.bubble` | `comment.block` — `hand.raised`, `role: .destructive` |
| Blocked, revealed (C-7) | `comment.report` — `exclamationmark.bubble` | `comment.unblock` — `hand.raised.slash`, no role |
| The signed-in user's own comment | no menu, no `…`, no actions (how "own" is detected is the developer's call; `editable` is a good proxy) |

Report and Block appear whether or not the user is signed in.

Entry points (all three show the same `CommentModerationMenu` content):
- **Comments list:** a `Menu` button at the trailing end of each comment's header row, after the score/date:
  glyph `ellipsis`, `.body` size, `.secondary`, inside a 44×44pt frame that overhangs the row padding (so the row
  doesn't grow), `.contentShape(.hoverEffect, .circle)` + system hover. `.accessibilityHidden(true)` — the same items
  are on the cell's accessibility actions (below). When the header falls back to its stacked layout, the `…` stays
  top-trailing on the author line.
- **Comments list and Detail strip:** `.contextMenu` with the same items on each cell/card (long press; secondary
  click or two-finger click with a pointer). The Detail strip gets no `…` button — its cards are fixed-size.
- **VoiceOver / Voice Control / Switch Control:** `.accessibilityActions` on the combined cell element, after the
  existing link actions: Report, then Block (or Unblock). Names = the visible menu strings.

Existing swipe actions (vote up/down, edit) are unchanged.

**Report confirmation** [06]: alert. Title `comment.report.confirm_title`, message `comment.report.confirm_body`
({site} + %@ filled). Buttons: `cancel` (role `.cancel`), `comment.report.open` (no role). On Open: open the
gallery's report page (`?report=select`). Route is the developer's call:
in-app sheet that carries the app's sign-in (large detent, `SheetCloseToolbar`, no title) is preferred because the
site's form needs the session — `AccountSettingView` already presents `WebView(url:)` in a sheet this way; the default browser is acceptable. The copy fits both.

**Block confirmation** [07]: alert. Title `comment.block.confirm_title`, message `comment.block.confirm_body`.
Buttons: `cancel` (`.cancel`), `comment.block.confirm` (`.destructive`). Alerts (not confirmation dialogs) for both
because both carry a full sentence that must be readable, and an alert renders the same on iPhone, iPad and with
large text (a confirmation dialog becomes a popover on iPad and hides its message unless forced).

After Block: every comment by that author on screen collapses at once (C-6/C-8), animation `.default`
(Reduce Motion: none). No toast — the collapse is the feedback. VoiceOver focus moves to the collapsed row of the
comment that was acted on (`AccessibilityFocusState`).

### C-5 · Posting warning [10]

- Trigger: the user taps Post (the sheet's confirm button) in `PostCommentView` — new comment or edit — and the
  filter matches. Shown **before** anything is sent, **over the sheet**; the sheet stays open underneath.
- Alert: title `comment.filter.title`, message `comment.filter.body`. Buttons:
  - `comment.filter.edit` — `role: .cancel` (the bold default; Esc and the hardware Return key's cancel map to it).
    Dismisses the alert only; the text stays exactly as typed and the editor regains focus.
  - `comment.filter.post_anyway` — no role. Posts, then the sheet dismisses as today.
- The matched word is never shown, highlighted or selected.
- If the filter doesn't match, Post behaves exactly as today.

### C-6 · Collapsed row — comments list [08, 19, 22]

Replaces the whole `CommentCell` content for a blocked author. Same `List` row, same insets.

- `ViewThatFits(in: .horizontal)`:
  - Horizontal candidate (fits on iPad and wide windows): `HStack(spacing: 8)` { label; `Spacer(minLength: 8)`;
    buttons } — label has `.lineLimit(1)` in this candidate only.
  - Stacked candidate (iPhone at default size and above): `VStack(alignment: .leading, spacing: 10)` { label; buttons }.
- Label: `HStack(alignment: .firstTextBaseline, spacing: 8)` { `eye.slash` `.secondary` AX-hidden;
  `Text(comment.blocked_row)` `.subheadline` `.secondary` }. **Never** the author's name, avatar, score, date or text.
- Buttons: `HStack(spacing: 8)` { Show (`comment.blocked_row.show`); Unblock (`blocked_users.unblock`) },
  `.buttonStyle(.bordered)`, `.buttonBorderShape(.capsule)`, `.controlSize(.small)`, `.tint(.primary)` (gray fill,
  primary text — never the accent),
  `.font(.subheadline.weight(.semibold))`. At AX sizes, if both don't fit one line they wrap to two lines
  (use the stacked candidate's buttons inside `ViewThatFits` { HStack; VStack(alignment: .leading) }).
- Show → C-7 for this one comment. Unblock → the author is unblocked immediately (no confirmation; blocking again is
  one menu away), every comment of theirs expands, animation `.default` (Reduce Motion: none).
- No swipe actions and no context menu on a collapsed row (nothing to vote on or report while hidden).
- Accessibility: the row is a container (`children: .contain`): the label is static text, Show and Unblock are
  ordinary buttons. Min row height 44pt.

### C-7 · Revealed comment (after Show) [09]

- The full `CommentCell` as normal (with name), with one line added above its header:
  `HStack(spacing: 8)` { `eye.slash` (`.footnote`, `.secondary`, AX-hidden); `Text(comment.blocked_row)` `.footnote`
  `.secondary`; `Spacer`; Hide button (`comment.blocked_row.hide`, same pill style as C-6) }, 4pt above the header.
- Hide → back to C-6. The reveal lasts until the comment leaves the screen (navigating away) — it is never stored.
  The author stays blocked; the menu shows Unblock instead of Block (C-4).
- Votes and swipe actions work as on any comment.

### C-8 · Collapsed card — Detail comment strip [11]

- Same card: same width/height steps, `systemGray5`, radius 15, padding 16 — the strip keeps equal card sizes.
- Content centred: `VStack(spacing: 10)` { label (as C-6, centred, up to 2 lines at default); HStack { Show; Unblock } }.
  Pills here can't use the gray bordered fill (it disappears on gray5): same size and type as C-6, but
  `.buttonStyle(.plain)`, `.padding(.horizontal, 14)`, `.frame(minHeight: 30)`,
  `.background(Color(.secondarySystemGroupedBackground), in: .capsule)`, primary text, `.hoverEffect(.highlight)`.
- Show reveals the comment in the card (normal card content). Hide is reachable from the card's context menu
  (`comment.blocked_row.hide` as a third item for a revealed card) — the card has no room for a Hide pill.
- **Developer check:** the strip is `.drawingGroup()`. Confirm buttons and `.contextMenu` work inside it; if they
  don't, removing `.drawingGroup()` from the strip is the expected fix (developer's call).

### C-9 · Settings → General: analytics [12, 13]

The existing Analytics section, rebuilt:

1. `Picker(shareAnalyticsData, selection: $level)` with three `Text(consent.level.*)` tags, `.pickerStyle(.menu)` —
   same as the Theme picker. At accessibility sizes use the Language-row pattern already in this file: label on its own
   line, picker (`.labelsHidden()`) trailing-aligned below it.
2. Privacy Policy row: `Link(destination: privacyURL) { HStack { Text(consent.privacy_link); Spacer; Image(arrow.up.right)
   .imageScale(.small) .foregroundStyle(.secondary) .accessibilityHidden(true) } }`, `.foregroundStyle(.primary)`.
3. Footer: `Text(selected level description)`; changes with the selection, `.animation(rowAnimation, value: level)`
   (`rowAnimation` already honours Reduce Motion).

Changing the level takes effect immediately (DD-09). No confirmation when lowering or raising.

### C-10 · Settings → Account: Blocked Users row [23, 24]

- Lives in **Account** settings (owner msg 1795), not General. New `Section` placed after the account section
  (website picker, log in/out, host settings…) and before the cookie section, no header, no footer. Shown
  **signed in and signed out** — blocking is local and works without an account.
- Push goes through `SettingPath` like the other Account pushes (a `.delegate(.pushBlockedUsers)` beside
  `.pushEhSetting`).
- `Button(blocked_users) { push }` `.foregroundStyle(.primary)` `.withArrow()` with a trailing count before the
  chevron: `Text(count, format: .number)` `.foregroundStyle(.secondary)` `.monospacedDigit()`. Count is shown at 0 too.
- Accessibility: one element, label `blocked_users`, value = the count.

### C-11 · Blocked Users list [14]

- Pushed screen, `.navigationTitle(blocked_users)`, large title like other Settings sub-screens.
- `List` (inset grouped, the Settings default) — one section of author names, `.body`, primary, sorted with
  `localizedStandardCompare`; long names wrap.
- Footer: `blocked_users.footer`.
- Unblock: `.swipeActions(edge: .trailing, allowsFullSwipe: true) { Button(role: .destructive) { … } label:
  { Text(blocked_users.unblock) } }` — text, not an icon, so the word is visible. Also a `.contextMenu` with
  `comment.unblock` ("Unblock %@", `hand.raised.slash`) for pointer and keyboard users. VoiceOver gets the swipe action
  automatically. No confirmation — the row removes with the standard delete animation.
- When the last name is removed, the screen switches to C-12 in place.

### C-12 · Blocked Users empty state [15]

- `ContentUnavailableView { Label(blocked_users.empty, systemSymbol: .handRaised) }` — no description, no action.
  The section footer is not shown when empty (it says "these users").

---

## UI Considerations

Applicable state considerations resolved: 21 covered, 3 backstop, 0 unresolved.

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| empty | Age wall, initial | ✅ covered | Checkbox unticked, Continue disabled and announced "dimmed" with `age_wall.continue_hint`; footnote visible |
| empty | Analytics choice, initial | ✅ covered | No card selected, no stroke, Continue disabled |
| empty | Blocked Users list | ✅ covered | `ContentUnavailableView` with `blocked_users.empty`, footer hidden |
| empty | Blocked Users row, nobody blocked | ✅ covered | Row shows count "0" and still pushes the list |
| loading | First-launch screens, Settings, Blocked Users | ✅ covered | No loading state: everything is local and instant |
| loading | Report page | ✅ covered | Handled by the web sheet / browser; the app shows no spinner of its own |
| error | Report page fails to load | ✅ covered | Shown by the web view / browser; no app error copy (none approved, none needed) |
| error | Privacy page offline | ✅ covered | Opens in the browser, which shows its own error |
| success | Block | ✅ covered | Comment collapses in place; no toast; VoiceOver focus moves to the collapsed row |
| success | Unblock (row, menu, list) | ✅ covered | Comments expand / row removes; no toast |
| success | Post Anyway | ✅ covered | Existing post flow and its existing feedback |
| partial | Posting warning → Edit | ✅ covered | Text kept exactly; editor refocused |
| partial | Upgrader quits between the two screens | ✅ covered | Next launch opens on the analytics choice (C-1) |
| zero-one-many | Blocked author with several comments on one page | ✅ covered | All collapse/expand together; Show reveals only the one tapped |
| zero-one-many | Blocked comment in the Detail strip | ✅ covered | Collapsed card at equal size (C-8) |
| own content | Signed-in user's own comments | ✅ covered | No menu, no `…`, no moderation actions |
| long-text | German / Korean / Japanese strings in alerts and menus | ✅ covered | System alerts stack buttons vertically when they don't fit; menus wrap |
| long-text | Long author names in "Block %@", list rows | ✅ covered | Menus and list rows wrap; nothing truncates |
| long-text | Collapsed label in other languages | ✅ covered | `ViewThatFits` falls back to stacked; buttons wrap at AX sizes |
| overflow | Age wall / analytics at AX5, landscape iPhone | ✅ covered | Everything scrolls; Continue + footnote move into the content at AX sizes |
| privacy | Collapsed row | ✅ covered | Never the name, avatar, score, date or text — also not in accessibility labels or values |
| input | Pointer / trackpad / keyboard | ✅ covered | System hover on buttons and menus, `.hoverEffect(.highlight)` on the cards, secondary click opens the context menu, Return = Continue when enabled, alerts take Return/Esc. Hover follows the input that is present, never the device type |
| visual | All new screens light/dark, iPhone/iPad, default and AX5 | 🧪 backstop | Phase 19 snapshots must include frames 01–22's states; compare against `mockups/` |
| behaviour | Buttons/context menu inside the `.drawingGroup()` strip | 🧪 backstop | Developer verifies in Simulator (C-8) |
| accessibility | VoiceOver order and focus on both first-launch screens and after Block | 🧪 backstop | Agent-run VoiceOver/accessibility-inspector pass (allowed by D-22) |

### Accessibility checklist

- All new text uses text styles; no caps; verified at AX5.
- Hit targets ≥ 44pt; whole cards tappable.
- Checkbox: `.isToggle`; radio cards: `.isButton` + `.isSelected`; titles `.isHeader`.
- Decorative glyphs (`eye.slash`, `arrow.up.right`, chevrons, the app icon, the analytics symbol, `…`) are
  accessibility-hidden; their meaning is in text or actions.
- Reduce Motion: every animation listed above has its no-motion form; symbol effects off.
- Voice Control: visible labels are the accessibility names (no custom labels that differ from the screen).
- Right-to-left: no RTL locale ships, but all layouts use leading/trailing so mirroring is free.

### SF Symbols used

`square`, `checkmark.square.fill`, `circle`, `checkmark.circle.fill`, `chart.bar.xaxis`, `arrow.up.right`,
`ellipsis`, `exclamationmark.bubble`, `hand.raised`, `hand.raised.slash`, `eye.slash`, `chevron.right` (existing via
`withArrow`). All available on iOS 27 through SFSafeSymbols.

### Mockup index (`mockups/`)

01 age wall light, unticked · 02 age wall dark, ticked · 03 analytics light, nothing picked · 04 analytics dark,
Basic · 05 comment menu · 06 report confirmation · 07 block confirmation dark · 08 collapsed row · 09 revealed row +
Unblock menu, dark · 10 posting warning · 11 Detail strip collapsed card · 12 General settings light (analytics) · 13 General settings dark,
Minimal · 14 Blocked Users with swipe · 15 Blocked Users empty, dark · 16/17 age wall AX5 top/bottom · 18 analytics
AX5 · 19 collapsed row AX5 · 20 iPad age wall landscape · 21 iPad analytics portrait dark · 22 iPad comments with a
pointer (hover on `…`, menu open, collapsed row on one line) · 23 Account settings light, signed in, Blocked
Users row · 24 Account settings dark, signed out, nobody blocked.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| none (native SwiftUI) | — | not applicable |

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS
- [ ] Dimension 7 Inventory Provenance: PASS

**Approval:** pending
