# Quick task 261123-355: deferred items

Out of scope for this task. Found at the P3 strict lint of plan 01 and logged, not fixed.

## Pre-existing strict-lint errors (7)

`swiftlint lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension` reports exactly
these 7 errors. They reproduce on the base commit 36d01f26c (pre-change tree) and lie in files no plan of this task
touches. The sorted, repo-relative output of the base tree is saved as `.capture/261123-355/logs/lint-baseline.txt`
(gitignored); each plan's P3 compares the current sorted output against it.

| File:line | Rule |
|---|---|
| `AppPackage/Tests/AppFeatureTests/UITestStubTests.swift:412:20` | `optional_data_string_conversion` |
| `AppPackage/Tests/AppFeatureTests/UITestStubTests.swift:482:17` | `optional_data_string_conversion` |
| `AppPackage/Tests/DetailFeatureTests/HeaderSectionActionSpacingTests.swift:51:38` | `large_tuple` |
| `EhPandaUITests/DetailRowSnapUITests.swift:61:9` | `control_statement` |
| `EhPandaUITests/DetailRowSnapUITests.swift:136:13` | `identifier_name` (variable `to`) |
| `EhPandaUITests/RecentlyViewedAnchorUITests.swift:141:17` | `identifier_name` (variable `to`) |
| `EhPandaUITests/RecentlyViewedAnchorUITests.swift:177:13` | `identifier_name` (variable `to`) |

Likely cause (unverified): the SwiftLint binary in this DerivedData enforces rules these test files predate, and the
app-scheme build gate does not lint `Tests/` or `EhPandaUITests`.
