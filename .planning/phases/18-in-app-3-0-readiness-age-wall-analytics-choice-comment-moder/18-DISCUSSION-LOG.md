# Phase 18: In-App 3.0 Readiness: Age Wall, Analytics Choice, Comment Moderation & Reader Rework - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-05
**Phase:** 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
**Areas discussed:** Phase organisation, First-launch flow (GA-1), Analytics levels (GA-2), Report and contact (GA-3), Filter and blocking (GA-4), Reader behavior (GA-5), Marketplace build (GA-6), Release mechanics (GA-7), Listing content (GA-8)

The options come from [18-DISCUSSION-PREP.md](18-DISCUSSION-PREP.md) section 2. The owner answered on two cards: msg 1748 (answered in owner msg 1753) and msg 1759 (answered in owner msg 1765). Copy approvals are owner msgs 1767 and 1780.

---

## Phase organisation

| Option | Description | Selected |
|--------|-------------|----------|
| Three phases | In-app work, then visual regression and marketing export, then distribution (prep section 5) | ✓ |
| One phase, three waves | Same boundaries; one phase that stays open until the last outside party finishes | |

**User's choice:** three phases (owner msg 1753).
**Notes:** the final analytics revision goes wherever its inputs exist; the install source needs the marketplace build, so it is the last plan of Phase 20.

---

## First-launch flow (GA-1)

| Option | Description | Selected |
|--------|-------------|----------|
| Q1 A: two screens | Age wall, then the analytics choice | ✓ |
| Q1 B: one combined screen | Age confirmation plus consent on one screen | |
| Q1 C: consent later | Age wall first, consent on first use of Settings | |
| Q2 A: everyone once | Fresh installs and upgraders see both screens on the first 3.0 launch | ✓ |
| Q2 B: fresh installs only | Upgraders never asked | |
| Q3 A: agents draft, owner approves | Six languages drafted, one owner approval | ✓ |
| Q3 B: owner supplies the copy | | |

**User's choice:** two screens, everyone once; agents draft and the owner approves (owner msg 1753). First-launch copy approved in owner msg 1767.
**Notes:** the age-wall checkbox sentence is the owner-approved website sentence (msgs 1454, 1457), unchanged, with no list of examples. Prep L10 was updated.

---

## Analytics levels (GA-2)

| Option | Description | Selected |
|--------|-------------|----------|
| A: None / Basic / Full | SDK never started under None; Basic = session signal, install source, error kinds; Full = the complete vocabulary | ✓ |
| B: None / Full | | |
| C: three levels, Basic without error kinds | | |
| D: four levels | | |
| Default selection | Recommended: none pre-selected, all equally prominent | ✓ |

**User's choice:** None / Basic / Full, none pre-selected; the SDK does not start before the choice (owner msg 1753).

---

## Report and contact (GA-3)

| Option | Description | Selected |
|--------|-------------|----------|
| Q1 A: menu | "Report on E-Hentai" plus "Report to EhPanda" (email) | |
| Q1 B: email only | | |
| Q1 C: web form | | |
| Q1 D: GitHub issue link | | |
| E-Hentai report only | No email (owner's answer) | ✓ |
| Q2 A: support email plus support page | | |
| Q2 B: existing community channels only | | |

**User's choice:** "E-Hentai report only" (owner msg 1753). No contact option now: the owner asked Ampo (msg 1760), who answered "not now" (msg 1774).
**Notes:** a published contact link (GitHub Issues on the website, website owner Leto) is needed before the AltStore build goes to Apple. That is Phase 20.

---

## Filter and blocking (GA-4)

| Option | Description | Selected |
|--------|-------------|----------|
| Q1 A: block posting | Clear message, text kept | |
| Q1 B: warn, allow "Post anyway" | | ✓ |
| Q1 C: silently mask | | |
| Q2 A: slurs, hate, threats, harassment in six languages; sexual terms excluded | | developer default |
| Q2 B: English only | | |
| Q2 C: also links and contact info | | |
| Q3 A: hide fully, plus a Blocked Users list | | list only |
| Q3 B: collapse into "Comment from a blocked user" | | ✓ |

**User's choice:**
- Warn, allow posting anyway, edits included (owner msg 1765). Ampo flagged the Guideline 1.2 risk in msg 1751; the owner made the call.
- Blocked comments collapse into "Comment from a user you've blocked" (Show / Unblock), without the name (owner msg 1765).
- The Blocked Users list in Settings is included (owner msg 1780). Comment copy approved in owner msg 1780.

---

## Reader behavior (GA-5)

| Option | Description | Selected |
|--------|-------------|----------|
| Q1 A: slider scrub keeps the title preview | | developer default |
| Q2 A: follow-the-screen | | developer default |
| Q3 A: two-page spread stays a known limit | | developer default |

**User's choice:** not put to the owner; recorded as changeable developer defaults (DD-01 to DD-03).

---

## Marketplace build (GA-6)

| Option | Description | Selected |
|--------|-------------|----------|
| Q1 A: same features | Only bundle ID, signing, icon set and distribution differ | ✓ |
| Q1 B: hide some features | | |
| Q2: bundle suffix `.marketplace` | | developer default |
| Q3: in-app icon | | open (Phase 20) |
| Q4 A: PAL listing only | | ✓ |

**User's choice:** same features, PAL only; hide something only if Apple objects (owner msg 1753). Recorded in 20-CONTEXT.md.

---

## Release mechanics (GA-7)

| Option | Description | Selected |
|--------|-------------|----------|
| Q1: tag style | | dropped |
| Q2: the existing `3.0.0` tag | | dropped |
| Q3: Classic before PAL? | | dropped |

**User's choice:** "Tagging is not your business" (owner msg 1753). Tagging and release-order decisions are dropped from the plans, and no plan creates tags.

---

## Listing content (GA-8)

| Option | Description | Selected |
|--------|-------------|----------|
| Q1 A: designer images from the approved `nonexplicit` set | | close to the owner's answer |
| Q1 B: blur covers | | |
| Q1 C: raw captures for Classic | | |
| Q2 A: reuse the website selections for the iPhone half | | open (Phase 19) |
| Q2 B: fresh full selection | | |

**User's choice:** store screenshots are the website screenshots plus extra decorations by the designer Colo (owner msg 1753; Colo msg 1757). An AltStore listing can use only non-adult pictures (Ampo msg 1751, guideline 2.3.8). Q2 was not answered; it is open in 19-CONTEXT.md.

---

## Claude's Discretion

- The developer defaults DD-01 to DD-12 in 18-CONTEXT.md, all changeable by the owner.
- Placement: `MKSellsDigitalGoods` in Phase 18 (an app-code release fix); the final analytics revision at the end of Phase 20.

## Deferred Ideas

- The in-app contact option and support mailbox (not now).
- New analytics signals and the install source (Phase 20, ANALYTICS-02).
- An iPad two-page spread test (known limit).
