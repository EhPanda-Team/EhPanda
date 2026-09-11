# Phase 16 — deferred items

Out-of-scope discoveries logged by executors (deviation-rule scope boundary). Not fixed by the plan that found them.

## Found during 16-16

- `AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings` is not strict JSON: the last string entry is followed by a trailing comma before `"version"` (`json.load` fails at line 932). Xcode's catalog compiler tolerates it and the build is green, but any script that reads the catalogs (the six-locale check, the D-30 structural guard) must skip or repair this file first. Plan 16-19 lists this catalog among its files and is the natural place to normalise it while adding keys.
- `AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings`: the existing `vote_up` / `vote_down` keys carry English (`Vote up` / `Vote down`) in `zh-Hant` while every other locale is translated. Pre-existing; not touched by 16-16 (which only added keys). A translation pass over the DetailFeature catalog should fix both.
