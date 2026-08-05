---
phase: 15-continued-background-downloads
plan: 33
subsystem: downloads
tags: [gap-closure, download-client, working-seed, reconciliation, filesystem-probe, tdd]
status: complete
requires:
  - "15-30 — the directory-level positive signal (`PageFileScan.scanSucceeded`) this plan extends one level down"
  - "15-29 — D-G7-01's delta-keyed withdrawal bracket, which the per-file refusal relies on without touching"
provides:
  - "PageFileScan.unprobedPages — the per-file positive signal (claimed pages whose listed file the probe could not classify)"
  - "AssetFileProbeOutcome + probeAssetFile(at:) — the exhaustive per-file probe classification in DownloadStore"
  - "reconcileWorkingManifestAgainstPageFiles refusing to blank any unprobed page (D-G13-01)"
affects:
  - "AppPackage/Sources/DownloadClient/DownloadStore.swift"
  - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
tech-stack:
  added: []
  patterns:
    - "Exhaustive enum classification replacing a Bool decision tree, with the Bool kept as a one-line forward so existing callers stay byte-identical"
    - "Injected FileManager subclass throwing from ONE named call (attributesOfItem) while the real filesystem denies the fallback — contract-faithful staging of a narrowed reachability class"
key-files:
  created: []
  modified:
    - "AppPackage/Sources/DownloadClient/DownloadStore.swift"
    - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
    - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"
    - "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift"
decisions:
  - "D-G13-01 — destroying a recorded content hash requires a positive PER-FILE signal on top of the positive directory-level one; a listed-but-unanswerable file is never blanked"
  - "unprobedPages is added ALONGSIDE scanSucceeded rather than replacing it: the two answer different questions at different granularities and the reconciliation consumes them independently"
  - "The probe's content-read fallback keeps its no-discard behavior on an immediate end-of-file (a positive empty-content determination that metadata never corroborated)"
metrics:
  duration: 50min
  completed: 2026-08-05
  tasks: 1
  commits: 2
---

# Phase 15 Plan 33: Per-File Positive Signal Before Blanking Summary

Blanking a recorded content hash now requires a positive per-file determination, not just a positive directory-level one: `PageFileScan` carries `unprobedPages`, every per-file probe exit is classified by an exhaustive `AssetFileProbeOutcome`, and the working-seed reconciliation refuses to blank any page the probe could not answer for.

## What Was Built

**The per-file signal.** `PageFileScan` gained a third member, `unprobedPages: Set<Int>` — claimed pages whose file a SUCCESSFUL enumeration did list but whose probe could not classify. `pageFileScan` now routes each candidate file through the classification instead of a Bool, recording a path on `.usable`, recording nothing on `.rejected` (blankable), and inserting the page number on `.unprobeable`. A `.usable` file settles a page outright even when an earlier candidate for the same page was the unanswerable one.

**The exhaustive classification.** `sanitizeAssetFileIfNeeded`'s decision tree moved into `probeAssetFile(at:) -> AssetFileProbeOutcome`, with every exit named:

| Exit | Outcome | Discards |
|------|---------|----------|
| Stat-backed existence check denies a file the listing just produced | `unprobeable` | no |
| Attributes read succeeds, item is not a regular file | `rejected` | yes |
| Attributes read succeeds, size key missing | `unprobeable` | no |
| Attributes read succeeds, size zero | `rejected` | yes |
| Attributes read succeeds, size positive | `usable` | no |
| Attributes read throws, content read yields a byte | `usable` | no |
| Attributes read throws, content read hits end-of-file | `rejected` | no |
| Attributes read throws, open or read throws | `unprobeable` | no |

The classification invariant is written on the enum itself:

> The distinction exists because ONE consumer acts irreversibly on the answer: the working-seed reconciliation destroys a recorded content hash for a claimed page the probe did not account for. Only a POSITIVE determination may ever authorize that. `unprobeable` is the answer that says the question went unanswered, and a non-answer is never authority to destroy state (G-15-13, fixed as D-G13-01).
>
> It is an exhaustively switched enum rather than a second `Bool` for SCOPE, and the scope is the point. This is the fifth consecutive round in which a fix scoped to the exact branch its regression staged left a sibling branch open — here the sibling is any probe exit nobody has enumerated yet. Classifying the whole function instead means a new exit cannot default into "positively absent": it has to be named, and every reader switches over the full set.

**The refusal.** The blank loop skips unprobed pages ahead of any mutation:

```swift
        guard pageFileScan.scanSucceeded else { return manifest }

        var pages = manifest.pages
        var blankedPageCount = 0
        for page in manifest.pages.keys.sorted() {
            guard pages[page]?.isEmpty == false,
                  pageFileScan.pages[page] == nil,
                  !pageFileScan.unprobedPages.contains(page)
            else { continue }
            pages[page] = ""
            blankedPageCount += 1
        }
```

The signature takes the whole `PageFileScan` (replacing the separate `existingPages:`/`scanSucceeded:` parameters), which is the option the plan preferred; `prepareWorkingSeed` still surfaces `.pages` for the seed.

**The corrected doc.** The two paragraphs at the refusal site were rewritten as a numbered three-line defence, and the false premise is gone (`grep -c 'per-file probe failure en masse'` → `0`). Quoted:

> 1. **The directory-level positive signal (G-15-9).** `scanSucceeded` false means the enumeration itself failed, so the whole answer is a non-answer and nothing is blanked. […]
> 2. **The per-file positive signal (G-15-13, fixed as D-G13-01).** `unprobedPages` carries the claimed pages whose file the successful listing DID yield but whose probe could not classify, and no page in that set is blanked. The trigger is narrow and real: the metadata read itself throwing for many-but-not-all files — an I/O error, a permission change, a volume going away mid-scan. It is not descriptor exhaustion and not a locked device, since a metadata read needs no descriptor and still answers under data protection. Line 1 cannot reach this population, because the listing succeeded, and line 3 cannot either, because it disables itself as soon as one claimed page survives: a gallery with 100 claimed pages and 99 failed probes passed `99 < 100` and lost 99 recorded hashes irreversibly.
> 3. **The all-or-nothing guard, as the residual second line.** A refusal is still taken when a nominally successful listing that answered for every file it did probe would nonetheless blank every claimed page. […]
>
> A refusal at any of the three moves no index record, so D-G7-01's delta-keyed bracket withdraws exactly zero from the floor by construction, without coordination here.
>
> **What the defence deliberately costs.** […] Genuine absence is untouched and stays fully blankable: a claimed page whose file a SUCCESSFUL listing simply did not yield is a positive absence, and a scan that finds K of them blanks exactly those K.

**The staging.** `PartialProbeFailureFileManager` throws a configured error from `attributesOfItem(atPath:)` for configured path fragments and forwards every other operation to `FileManager`. It stages the reachability class the verification narrowed G-15-13 to — the attributes read itself throwing for many-but-not-all files — while the directory enumeration, the existence check and the content-read denial all stay real (`0o000` modes on the same three files make the `FileHandle` open throw `EACCES` for real). The double's fragments and the real page-file names are built by different routes, so the case pins them against each other rather than assuming they match.

## Falsifiability: the RED run

Both cases were written first and the targeted run was taken BEFORE the classification landed (test commit `c1134925`, run at that tree). The mass-partial case failed with exactly the derived pre-fix readings:

```
testAMassPartialProbeFailureBlanksNothingWritesNothingAndWithdrawsNothing() Failed
  :766: Expectation failed: await manager.fetchDownload(gid: partial.gid)?.completedPageCount == 4
  :774: Expectation failed: (refusalPair.completedUnitCount → 1) == 4
  :776: Expectation failed: (refusalPair.subtitle → "1 / 6 pages · 1 gallery") == "4 / 6 pages · 1 gallery"
  :781: Expectation failed: (onDiskManifest.pages → [4: "", 6: "", 3: "", 2: "", 1: "sha256:done", 5: ""])
        == (manifest(for: partial).pages → [1: "sha256:done", 6: "", 4: "sha256:done", 3: "sha256:done", 2: "sha256:done", 5: ""])
  :782: Expectation failed: (onDiskManifest.completedPageCount → 1) == 4
```

That is the defect end to end: three of four recorded hashes destroyed (`3 < 4` passed the all-or-nothing guard), the manifest rewritten on disk, the record republished at 1-of-6, and the D-G7-01 bracket withdrawing 3 from the floor so the announcement read `1 / 6 pages · 1 gallery` where `4 / 6 pages · 1 gallery` was derived. Nothing physically moved: all four page files were still on disk, and all six manifest entries were still what the fixture wrote.

`testAGenuinePartialLossBlanksExactlyTheMissingPages` was **green in the same pre-fix run**, and that is correct rather than a manufactured RED. It stages a positive absence — two page files really deleted, so the successful listing simply does not yield them — which is behaviour the old code and the fixed code share and which the fix must NOT move. Its job is to pin the other side: a fix that bought the mass-partial case by disabling partial blanking, raising the all-or-nothing threshold or special-casing the staged names fails there in the same run. Manufacturing a false RED for it would have meant staging a behaviour change nobody asked for.

Post-fix the same targeted invocation is green: 22 tests in 2 suites, `** TEST SUCCEEDED **`.

## Bool callers untouched

`sanitizeAssetFileIfNeeded` is now the one-line forward:

```swift
    @discardableResult
    public func sanitizeAssetFileIfNeeded(at url: URL) -> Bool {
        probeAssetFile(at: url) == .usable
    }
```

Both non-usable outcomes were `false` before and are `false` now, so no caller's behavior moves. From diff inspection: `git diff -U0` over `DownloadStore.swift` shows exactly one `sanitizeAssetFileIfNeeded` line touched — the call removed from `pageFileScan`'s guard chain, which is the site that gained the classification. `existingAssetFileURL(in:prefix:)` (`DownloadStore.swift`) is not in the diff at all, so its `first(where:)` predicate and therefore its behavior are unchanged, and `DownloadStore+Operations.swift`, which holds seven more Bool callers, is not in the diff either.

## Prior literals unchanged

From diff inspection, `DownloadContinuedSessionBasisTests.swift`'s pre-existing cases are untouched apart from two call sites renamed by the helper generalisation (`restoreFolderPermissions(at:to:)` → `restorePermissions(at:to:)`, so the same helper can restore a mode-`0o000` page file as well as an execute-only folder). No assertion, literal or expected subtitle in any pre-existing case changed. The 15-30 wholesale case still passes — its staging defeats the enumeration, which the first line of defence still refuses at — and Tests G/H (the repair-seed partial-blanking cases) and Test E (ledger) pass in both runs. The D-G7-01 bracket, the trust set, the floor arithmetic and `reconcileRetiredSessionPages` are not in the diff.

## Verification

| Check | Result |
|-------|--------|
| Targeted run (basis + ledger), pre-fix | RED, mass-partial case only, readings quoted above |
| Targeted run (basis + ledger), post-fix | `** TEST SUCCEEDED **`, 22 tests / 2 suites |
| Full `FeatureTests` run (one invocation) | exit `0`, `** TEST SUCCEEDED ** [90.224 sec]`, zero `✘` lines, includes `DownloadLogPrivacyInvariantTests` |
| SwiftLint (`--strict`, four edited files) | exit `0`, zero violations |
| `grep -c 'unprobedPages'` DownloadStore / ExecutionSupport | `11` / `2` (≥3 and ≥1 required) |
| `grep -c 'enum AssetFileProbeOutcome'` | `1` |
| `grep -c 'func probeAssetFile('` | `1` |
| `grep -c 'per-file probe failure en masse'` | `0` |
| `wc -l` (four edited files) | 758 / 705 / 906 / 627 — all below 1000 |
| Post-commit deletion check | no files deleted |

No new production log line was added, so `DownloadLogPrivacyInvariantTests`' named per-file masked-count inventory is untouched (it passes in the full run).

## Deviations from Plan

**1. [Clarification, not a behaviour change] The manifest re-read is not preceded by an explicit permission restore**

- **Found during:** Task 1, writing the mass-partial case
- **Issue:** The plan's behavior block says "the on-disk manifest re-read after restoring permissions". The three files staged at mode `0o000` are page files; the manifest re-read opens `manifest.json`, whose mode was never touched, so an extra restore before the re-read would be a no-op that reads as load-bearing.
- **Resolution:** The restore runs once, in the case's cleanup path (a `defer` declared after the tree removal so it runs before it), which is what the acceptance criterion requires. A comment at the `defer` states why no earlier restore is needed. The assertion the plan asked for — the re-read manifest still carrying its four non-empty hashes — is present and unchanged.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift`
- **Commit:** `c1134925`

**2. [Rule 3 - Blocking] The permission-restore helper was generalized rather than duplicated**

- **Found during:** Task 1
- **Issue:** `restoreFolderPermissions(at:to:)` is path-based and works for any item, but its name and doc claimed folders only; the new case needs it for three page files. Copying it would have duplicated a helper for no reason (project rule: no thin wrappers, fix at the root).
- **Fix:** Renamed to `restorePermissions(at:to:)` with a doc naming both stagings; both pre-existing call sites updated. No literal or assertion changed.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift`
- **Commit:** `c1134925`

**3. [Naming] `canReadNonEmptyFile` became `probeAssetFileContent`**

- **Found during:** Task 1, Step 2
- **Issue:** The content fallback had to return the tri-state so an open/read throw could be distinguished from a positive empty-content determination — a Bool cannot carry that.
- **Fix:** The private helper returns `AssetFileProbeOutcome` and is named for what it now does. It had exactly one caller (the probe), which is why no call site outside the file exists. Its no-discard behavior on an immediate end-of-file is preserved and the reason is now documented.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore.swift`
- **Commit:** `fffea740`

No architectural changes were needed; no authentication gates were hit.

## Threat Flags

None. The plan's `T-15-33-01` (tampering via conflated per-file probe answers) is mitigated as designed; `T-15-33-03` (identity leakage) needed nothing, since no production log line was added. No new network endpoint, auth path, file-access pattern or schema change was introduced.

## Known Stubs

None.

## TDD Gate Compliance

RED gate: `c1134925` (`test(15-33): stage the mass-partial probe failure`), taken with the mass-partial case failing at the readings quoted above. GREEN gate: `fffea740` (`fix(15-33): refuse to blank unprobed page files`). No REFACTOR commit was needed — the classification landed in its final shape and the full suite was green on the first post-fix run.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` — FOUND
- `.planning/phases/15-continued-background-downloads/15-33-SUMMARY.md` — FOUND
- Commit `c1134925` — FOUND
- Commit `fffea740` — FOUND
