---
quick_id: 260923-nnu
mode: quick
description: Build and test; resolve all warnings, errors, and lint violations, including test targets
---

# Build, test, and lint every app-owned target

Run the quick workflow inline and sequentially on the current branch. Preserve the pre-existing
`EhPanda.xcodeproj/project.pbxproj` edit. The live baseline is commit `75dfb5a3`; edit scope below
is conditional on diagnostics collected from this checkout, including every test target.

## Task 1: Establish the baseline

- Read the root lint rules, package and scheme configuration, and test plans.
- Run a clean Xcode 27 build and the complete FeatureTests plan on iOS 27.
- Run strict, uncached SwiftLint across tracked Swift files, including package tests and UI tests.
- Record actual diagnostics and distinguish expected-failure tests from unexpected failures.
- Done when each reported issue has an identified source and fix scope.

## Task 2: Fix observed diagnostics

- Change only files implicated by current compiler, lint, or test diagnostics and necessary callers.
- Use modern APIs supported by the installed SDK. Consult relevant Swift skills and authoritative
  implementation/documentation where needed. Preserve behavior and existing owner decisions.
- Fix root causes without disabling rules, weakening assertions, adding warning suppression,
  or introducing unchecked concurrency annotations.
- Verify each change with the relevant focused check, then commit the code atomically.
- Done when observed app-owned diagnostics and unexpected test failures are resolved.

## Task 3: Verify and record

- Run the complete feature and UI test plans; use iPhone and iPad UI destinations where available.
- Inspect test result bundles for failures, skips, expected failures, and retries.
- Confirm strict uncached lint and clean app/test builds have no unresolved warnings or errors.
- Review the final diff, create the summary, and append the quick-task record to STATE.md.
- Commit only this task's artifacts and changes; preserve unrelated working-tree changes.

<threat_model>
ASVS level 1; high-severity findings block completion. This task introduces no new data boundary,
network integration, persistence schema, or authorization flow. Maintain test isolation and avoid
real credentials/network requests in tests. Do not weaken existing security or lint gates.
</threat_model>

## Evidence

Logs and result bundles use the temporary prefix `/tmp/ehpanda-260923-nnu-`.
No external API integration or identity-model transition is planned.
