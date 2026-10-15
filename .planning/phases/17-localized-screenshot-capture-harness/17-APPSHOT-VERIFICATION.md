# Standalone appshot consumer verification

Date: 2026-10-15. This records repository extraction and a bounded, actual-app integration check.
It does not close Phase 17, establish full matrix parity, or accept appshot v1.

## Source and tool identities

- Tool repository: `$HOME/Fork/appshot-cli`, `main`, standalone setup commit
  `ec89ab6ed8af3f261f09cb67415c1ded32bc6875`, tree
  `547e6937d2b8bffa684fa9793b1b3514550fd475`.
- Its history contains 136 extracted implementation/design/debug commits plus one standalone setup
  commit. Every extracted revision preserves its selected file contents, modes, messages and author
  and committer identities/dates. Rewritten commits have verified signatures. A subsequent SDK correction
  excludes the protocol and XCTest helper from iOS Release, commit
  `2664848084c91ebab15d86f8a56e5d29b2491b97`; its tree is
  `b22d6f583a9ad0ffd4160471ce32efcd2a810d89`. The SHA correspondence
  lives in that repository's `.planning/migrations/standalone/COMMIT-MAP.json`.
- Initial consumer source exported from this branch: tree
  `b686bee97bee53728dd9d092af2f4db9137c56c7`. The export excludes the unrelated staged project changes,
  dispatch sentinel, milestone lock and window-probe note, and the unrelated unstaged ignore change.
- Final capture used consumer tree `d647c8a66862c8c1a4d41af69497ca0b5d07a94f` and SDK commit `2664848`.
  Relative to the initial source, the only code change guards the capture UI test with `#if DEBUG`.
  The final consumer commit adds the resulting verification notes; its capture inputs remain identical.
- Xcode 27.1 RC, build `27A9275`; Swift 6.4; iOS SDK 27.1; simulator runtime iOS 27.0, build `24A434`.
  The explicit `DEVELOPER_DIR` was used without changing the system selection.

Evidence below is relative to `$HOME/Library/Caches/Appshot/handoff/extraction-20261015`.
Original/frozen runs remain recovery evidence. The obsolete source worktrees are being retired only
after complete history/document verification and a checked recovery backup; see the integration record.
No remote was created, nothing was pushed, and compiler reports remain local.

## Executed checks

| Check | Observed result | Evidence |
|---|---|---|
| Standalone exact-tree gate | All seven checks passed; 469 Debug and 469 optimized tests, zero build warnings/errors and zero strict lint violations | `../extraction-final-gate-20261015-2/results.json` |
| SDK Release correction gate | All seven checks passed on the committed correction tree; 469 Debug and 469 optimized tests, zero build warnings/errors and zero strict lint violations | `../sdk-release-isolation-gate-20261015/results.json` |
| Consumer Debug build-for-testing | Passed after resolving typed-throws adaptation and test compilation issues; final build has no warnings | `consumer-unit-build-3.log` |
| Consumer adapter unit tests | Seven selected tests passed, including parameterized screen/conflict/malformed-scene cases; zero skips or repetitions | `consumer-units-2/verification.json` |
| Existing Python runner tests | 196 passed | `consumer-python-tests.log` |
| Changed Swift files | Strict SwiftLint passed with zero violations | `consumer-swiftlint.log` |
| Actual-app pin measurement/review | Candidate geometry and existing reference font metrics agree for both devices and all six locales | `pin-review.json` |
| Final-source pin check | 12 probes passed: two devices by six locales, portrait, large text | `consumer-pin-check.log` |
| Final actual-app capture | Two requested coordinates captured on their first attempt; each passed content checks and two exactly equal cold-launch frames | `consumer-final-smoke/run.json` |
| Final integrity verification | Passed for both accepted frames and all four launches | `consumer-final-verify.log` |
| Final export | Two PNGs exported; bytes and SHA-256 match the accepted frames and both launches | `consumer-final-export-verification.json` |
| Consumer Release build | Corrected SDK passed with zero warnings/errors for both simulator architectures | `consumer-release-2-build-results.json` |
| Release binary inspection | No capture/protocol symbols or channel strings in arm64 or x86_64; no capture resources | `consumer-release-2-inspection.json` |

The capture command selected `screen=home,set=nonexplicit,locale=en,appearance=light`. The other axes
were portrait and large text. It used the existing private fixture version through the app's isolated
fixture/replay path and the shared content verifier. No fixture data or screenshots are committed.

| Device | Pixels | Cold launches | Accepted frame SHA-256 |
|---|---|---|---|
| iPad Pro 11-inch (M5) | 1668 x 2420 | 2 of 2, equal | `7c99c5469f92e2e0da85f0785124a62e5524382089fc70fd9bc3c1a5f5f0b295` |
| iPhone Air | 1260 x 2736 | 2 of 2, equal | `a48ea8dc1600f6ba30293149a29f04a056634fe499aa070aaedcc6da432f03d0` |

Both exported images were inspected and show the app's populated Home screen. The run explicitly
reports `requested: 2`, `possible: 384`, `complete: false`; no other coordinates are claimed.
The final two exported frames also match the initial two-device smoke run byte-for-byte.
Both dedicated simulators returned to Shutdown, and the CLI checked restored UI settings after reboot.
No foreign test process was signaled and no second capture driver ran concurrently.

The local verification driver mistakenly created its first export directory before invoking the CLI.
The CLI correctly rejected that existing destination. Export to a fresh destination then passed;
the capture and verify steps were not repeated. The failed command and its output remain in
`consumer-export.log`; the successful result is in `consumer-export-1.log`. This was a driver error,
not a waived tool failure.

The initial Release build succeeded but retained 9,874 arm64 `AppshotProtocol` symbols and protocol
channel strings despite using dead stripping. That result exposed a false SDK assumption. The
standalone SDK now compiles its protocol and helper only for Debug or macOS, and the capture UI test
also guards its use with `#if DEBUG`. The corrected Release binary contains none of the checked
capture entry points, protocol names or channel strings. The original binary and inspection remain
in the evidence directory. No runtime activation check is claimed by this static inspection.

## Remaining acceptance work

- Run the remaining app coordinates and compare the complete marketing output against the reference
  workflow before retiring the Python consumer/export adapter or its Live Text recording entry point.
  Existing sheet-only comparison and appshot's whole-frame strict comparison are different contracts.
- The original three tool soak matrices were not identical: 47/48, 44/48 and 45/48 pairwise matches.
  Their original equality acceptance criterion remains unmet. Do not infer cross-run equality from
  the two equal cold launches reported here.
- Native simulator setting persistence remains unresolved. Reboot verification now detects a lost
  restore and preserves the recovery journal; that detection is not a fix for native persistence.
- Full Phase 17 Release isolation, clean-checkout CI and workflow replacement remain separate
  acceptance work. A bounded consumer check does not mark the overall phase complete.

Prior selections of agent-recommended engineering options are revisable on evidence. They must not
be presented as permanent owner positions. Keeping compiler reports local is an explicit user
constraint.
