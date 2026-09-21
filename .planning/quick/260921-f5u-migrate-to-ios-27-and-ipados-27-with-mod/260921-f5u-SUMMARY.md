---
phase: quick-260921-f5u
plan: 01
status: complete
subsystem: ios-platform
requirements: [QUICK-27-01, QUICK-27-02, QUICK-27-03, QUICK-27-04, QUICK-27-05]
---

# iOS and iPadOS 27 migration

The app, extension, package and tests now require iOS/iPadOS 27 and Swift 6.4. Native overflow menus, tabs, title/search behavior, content builders, status-bar visibility and asynchronous continued-processing submission replace the applicable older APIs. All 46 inventoried pages carry the native soft top-edge policy, including independent presentations and owned web scroll hosts. AGENTS.md records the requirement for future pages.

## Implementation

- Seven `ToolbarOverflowMenu` sites preserve existing actions and individual enabled states. Reader Close and page indicator retain high visibility priority.
- Temporary accessibility title/search fallback modifiers are removed; designed inline-large titles remain.
- Detail header actions use one native Layout with persistent controls. The previous alternate view trees caused repeated fitting and cold-entry stalls. Intrinsic sizing, responsive reflow, action identity and native RTL mirroring are preserved.
- Home observes actual card-relative viewport geometry for highlighting. Native scrolling owns selection; removing obsolete geometry-driven scroll commands fixes rotation feedback and preserves the selected gallery. No replacement focus synchronizer remains.
- Continued-processing submission uses the native asynchronous scheduler API off the main actor. Session return stays immediate; identity-gated settlement and owned-task cleanup prevent late completion from corrupting a successor session.
- Login-observation and Settings import tests now control their asynchronous inputs. Search history delete controls meet the audited minimum touch target. Reader UI tests identify their native toolbar through its page indicator, preserving every assertion and timeout.
- CI selects the documented Xcode 27 runner and checks its SDK. Validation-bypass flags are removed. Six support READMEs reflect the new minimum.
- The package manifest removes redundant declarations and wrapper types. Its complete evaluated JSON is unchanged across all 66 targets; the helpers correctly isolate their shared plugin configuration to the main actor.

## Verification

The full FeatureTests plan passed on both devices: 1,391 passing cases and eleven pre-existing expected failures per device, zero unexpected failures or skips. Strict SwiftLint passes all 80 changed/new Swift files with zero violations. Manifest before/after JSON is completely equal.

The complete phone UI plan passed: 49 passing cases, two pre-existing iPad-only skips. All five new migration UI cases and all applicable accessibility audits passed first attempt on both devices. The complete iPad plan exposed an autoplay selector error and the existing W-38 scrolling discrepancy. After correcting the selector, the full reader class ran again: all five phone cases passed; four iPad cases passed and only W-38 failed its three configured attempts. The final reader invocation finalized normally with exit 65, preserving the W-38 failure; there were no skips or newly expected failures.

The clean-build native VoiceOver walkthrough passed on both devices: six carousel cards forward and backward, Frontpage exit and return, zero focus resets. Ordinary/rapid swipes, both loop directions, negative buffered IDs, rotation identity/centering and responsive Detail header sizes/RTL were also exercised. Both simulators have VoiceOver off again.

The full iPad UI plan is not claimed green. W-38 remains an explicitly carried Phase 16 issue: the owner withdrew its earlier fix because it caused last-page jitter. This migration neither reinstates that fix nor weakens its tests. Earlier failed or interrupted experiments remain documented in `260921-f5u-VERIFICATION.md`; `SCROLL-EDGE-INVENTORY.md` separates complete source coverage from sampled visual evidence.

## Commits

- `495732b5` — platform, toolchain, CI and support minimum.
- `d8cf4f9e` — controlled asynchronous feature-test inputs.
- `6fb4a735` — native asynchronous background submission and lifecycle/transfer coverage.
- `31f99f0c` — native iOS 27 UI APIs, page scroll edges and repository policy.
- `b2d1b4ae` — persistent Detail header controls and responsive layout tests.
- `d1b9ec1c` — native carousel selection and migration UI regressions.
- `255e8f09` — audited search target, snapshot isolation and reader toolbar selector.
- `d7f8b191` — graph-preserving package manifest simplification.

## Scope and limits

Hosted CI has not run locally. Actual system-granted continued-processing execution needs physical-device verification; deterministic lifecycle tests cover app-owned behavior. The pre-existing owner-approved private Share-extension handoff remains because the installed SDK provides no public replacement for that extension point. No new private API, suppression or validation bypass is introduced.

Phase 16 owner decisions, including W-38, VO-3/W-13, W-35 and W-8, remain separate. The quick task does not change roadmap or phase completion status.

## Dispatch

The planner was dispatched with the requested `gpt-6-astra` configuration and executor with `gpt-5.6-luna`, using resolved GSD effort values and exact-plan checkpoint instructions. Requested dispatch settings are recorded; independent runtime model metadata was unavailable.
