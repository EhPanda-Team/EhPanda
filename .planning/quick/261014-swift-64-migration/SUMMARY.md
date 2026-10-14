# Swift 6.4 migration

Completed: 2026-10-14

## Implementation

- `432022db7d78ae0857034a5cef8209a51c2dc53f` — migrate all app-owned targets to Swift 6.4's six upcoming language features,
  adopt modern and non-deprecated APIs, update all direct and resolved dependencies, and split
  functional and configured visual test execution.
- Keep the haptics architecture unchanged at the owner's request.
- Preserve the domain-fronting transport's documented compatibility boundary.

The implementation, dependency versions, regression coverage and evidence are recorded in
[the migration report](../../../docs/swift-6.4-migration.md).

## Verification

- Device Release and UI test target builds passed without compiler warnings.
- Functional suite: 1,356 passed, 10 existing expected failures, zero unexpected failures.
- Native fixture export: 2 passed; all 47 fixture images checked.
- Python visual-runner contracts: 185 passed.
- Strict SwiftLint: zero violations. Both dependency lockfiles match.
- The complete visual matrix remains a separate gate requiring pinned Xcode 27.0.

## Integration

Integrated with the newer Live Text translation work on `feature/gsd-phase-17`; the implementation
reference above names the final cherry-picked commit, including its verified integration fixes.
All 73 app-owned modules compile with Swift 6 mode and the six upcoming features. The target
checkout's pre-existing staged and unstaged changes are excluded from these commits.

The 127 existing commit references in Phase 17 and the latest translation task resolve to the
unchanged ancestor history. Fixture hashes, SDK diagnostic codes and upstream dependency revisions
are not repository commit references and remain unchanged.

Final integration evidence:

- `/tmp/ehpanda-swift64-integration-feature2.xcresult`: 1,356 passed, 10 existing expected failures,
  zero unexpected failures and zero skipped tests.
- `/tmp/ehpanda-swift64-integration-release-final.log`: Release build passed without warnings.
- `/tmp/ehpanda-swift64-integration-ui-build.log`: UI test build passed without warnings.
- `/tmp/ehpanda-swift64-integration-lint-final.json`: zero violations.
- `/tmp/ehpanda-swift64-integration-flag-audit.json`: all 73 owned modules verified.
