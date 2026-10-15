---
type: integration-record
status: complete
recorded: 2026-10-15
---

# Worktree and commit migration

Owner authorized local replay onto `feature/gsd-phase-17`, SHA correction, a new worktree/branch,
and removal of the old checkout/branch. No push or PR.

- Integration base: `4b94f62438b1483f653d0635f55faf958e399861` (Phase 17).
- New branch: `agent/iphone-duo-support`.
- New worktree: `$HOME/.codex/worktrees/iphone-duo-support/EhPanda`.
- Old branch: `claude/iphone-duo-support-c0b23d`.
- Old worktree: `$HOME/Fork/EhPanda/.claude/worktrees/iphone-duo-support-c0b23d`.
- Original implementation tip: `5c9ecc8e7b314621ee5833c45bd38efe7c0b2530`.
- Original documentation recovery: `a76fa2867`.

## Rewritten implementation commits

Operational references in this session record point to the new IDs. Historical test claims
remain evidence from the original trees; the mapping preserves that distinction.

| Original tested source | Replayed implementation |
|---|---|
| `fee44887785a37ceb019daed1cbf4ef7c324e35f` | `c4e9347f18024533fd1147dfbb49e68b00c03ab1` |
| `04e61ee4ec08ca5d836c4d800440755d94762c64` | `69f23462ee1064ee0d8e4da2fc44973f07aa9914` |
| `bcdb00220d410425d0d64e0e4006e2a66dde744d` | `ff58682f9c5b09319688ebe0cce8211cfd60ea72` |
| `9f572d03d516de59e5cc759764751438faf871a1` | `7fb7fd1a6d984970b09b66494449a05b5853e005` |
| `3b8ad8cec2d682a8e3bf5dd293de861aba8a3397` | `b564f590a37e6da118e5daa65f5693092b3195eb` |
| `ab671eb4afa3b5a77b7ee32728a9481dfd9ad449` | `fbfc01d1fc72bd56a8eb0fe4ae73e316042cc304` |
| `899bd820a3e7767762fd64607ecd9d94330fd97d` | `c005393aadfe9b0f2769f1759197a5b3975cb3fd` |
| `29971da6e8053e890d9dcb00397a34e6cb7a0202` | `2a2aef98abbf113e274a9e3394ace96431f1d6ac` |
| `433aa031f9272f34dca18ab872f0c1a22b5afc0a` | `506d15d14698b58f65a4aab9b89729404b36ea6c` |
| `9d0fa8e7e9426934294c868267e6979f0d2ec307` | `d7d1de88ca4f24b22e0b0dc20249e239ae074c96` |
| `d6f5fa54cc6f063527c4c69ea4b396a42b4ec2a5` | `334a9876dc3a71ebf623c4afe5c5998cabea2bdc` |
| `5973b8013f041b7b745d44ffa63f50dc0b4eaaa0` | `c8a4294f9b95ff23bbb02e010187a8ad309e962d` |
| `a6210b8280106ac82738a2c2bab7a4c304256358` | `19a557ec5d39cfdff22ee0cb19ec95cfe54ed4dc` |
| `8fb9490fb13dc89aa6de6dac1534366e513c7aee` | `1bc34288924f2b929c36dd15dd80a3fd4f0b826e` |
| `4ae474d93b73d327e5cd91825db42ed895caa33d` | `b22b0cd54640718710bd65e1329769153d983736` |
| `8de27c700ed48d52be7e289b9ba6d18e439ee903` | `2224ba1d9deaaaa52c9ed16f43a7a605ab686889` |
| `f221c6e6a09a8484aa7aebba69df4e3489225763` | `7527c96bbd742dd5653b245d0d56a897ee4bb2a8` |
| `c58ddb0f55ee4ffa2525e7c427b06904e1700e47` | `52c66849739dbc19475829cc43a190a9613d0517` |
| `647c5d7ba120e1b203bce4e44b5e30f40c1e4bad` | `5859cf619548fe2cc7e0093152c4b9a5d9d661c5` |
| `7f14dd15462b08d108c2d1853ef8ac36eb2c84ea` | `8ca48f567755bfb0f07794b6093f1b5e49dcd782` |
| `5c9ecc8e7b314621ee5833c45bd38efe7c0b2530` | `79a59892e0648457ae88710a552448ffa6a45aa8` |

## Integration handling

Import conflicts retained Phase 17 Swift 6.4 explicit/public module imports while removing obsolete
DeviceClient dependencies. Home extraction retained the split-aware hierarchy and the modern
scroll-indicator modifier. Newer Phase 17 Live Text and capture integration remain present.

## Evidence and preview preservation

Useful ignored `.build` evidence was copied to `$HOME/Fork/EhPanda/.build/duo-session-20261014-15/`.
Derived build/index/module/dependency caches were excluded; diagnostic logs/results and review
artifacts were retained. The preview now serves the preserved `wide-screen-proposals` directory
at the unchanged `http://127.0.0.1:55920/index.html`; page and screenshot HTTP 200 checks passed.

## Integrated build review

The FeatureTests and UITests generic arm64 simulator builds passed without compiler/lint warnings
(`.build/integration/build-feature-10.log`, 16.006 s; `build-ui.log`, 10.265 s). Strict SwiftLint
passed all 80 changed Swift files after the inventory correction below. Compatibility edits are import-only in 17 files,
required by Phase 17 InternalImportsByDefault/MemberImportVisibility. Earlier compiler failures
are retained in the numbered build logs; no rule or diagnostic was suppressed.

The preserved original history bundle `source-history.bundle` passed `git bundle verify`.
A checksum-based dry-run comparison found no missing/changed archived evidence (excluding
rebuildable caches and the intentionally relocated preview server PID/log).

## Migration completion

Validation and local migration are complete. `feature/gsd-phase-17` was fast-forwarded normally
from the integration base to `agent/iphone-duo-support`; both branches include the recovered
session docs and validation corrections. The old worktree and `claude/iphone-duo-support-c0b23d`
branch were removed after a fresh clean-status, history-bundle and checksum comparison. The new
managed worktree remains attached to this chat. No push or PR was performed.

The primary checkout’s five unrelated staged/unstaged entries were preserved byte-for-byte across
the fast-forward. SHA-256 of the saved Git output remained:

- `status --short`: `49617f01a18f4461c901385b4a32fc6ed45e1c9046fac7be9e60f91dae16be2e`
- `diff --binary`: `49d81ae1fc9cc828038b147eb90e93a74521f5e67e6ae92a65417848d51fa425`
- `diff --cached --binary`: `64ac509d0d6b822779294e9922193b5e21c3be28f73f42cea877932948137051`

The archived `source-history.bundle` retains the original source tip and requires the shared
ancestor `7aba2cdbd6ef29b2d2dcebdfdd6c3d2df634887b`, still present in this repository. Useful ignored
evidence is retained separately from rebuildable caches. The stable preview returns HTTP 200 for
its index and all nine proposal screenshots. Its document root is outside the removed worktree.

## Owner-approved validation scheduling

After the clean builds, the owner explicitly permitted parallel validation on independent dedicated
simulators (D55). This session runs its own test commands sequentially. The idle single-slot waiter
was stopped before launching any test, and FeatureTests then started on the dedicated probe iPhone.
No other session’s device or process was changed.

## Reduce Motion inventory correction

The first full integrated FeatureTests execution exposed three failures in the source inventory,
not a new animation defect: Home’s existing gate moved from HomeView to HomeNavigationView, and
the approved slider-side transition adds a position-animation gate to ControlPanel. Under Phase 16
D-29 this motion must honor Reduce Motion. The pinned test inventory now retains 17 environment
reads, records 25 ternary predicates and 56 mentions, and keeps 2 withAnimation gates and all 11
ungated numericText sites unchanged. Exact two-way equality assertions remain intact. No production
behavior or assertion strength was changed to address the inventory drift.

## Fresh integrated validation (2026-10-15)

Validated implementation: `0af542eabff355bb611e6aedd8cd0a23691790dd`, including the import and
source-inventory corrections. Documentation-only changes after this commit do not change the build.
All paths below are relative to the new worktree. Tests use Xcode 27.1 Release Candidate, explicit
EhPanda simulator IDs, `-parallel-testing-enabled NO` and `-collect-test-diagnostics never`.

| Check | Result | Local evidence |
|---|---|---|
| FeatureTests build-for-testing | Passed, no compiler/lint warnings; final inventory rebuild 7.593 s | `.build/integration/build-feature-10.log`, `build-inventory-final.log` |
| UITests build-for-testing | Passed, no compiler/lint warnings, 10.265 s | `.build/integration/build-ui.log` |
| Strict SwiftLint, all 80 integrated Swift files | Passed, exit 0; no diagnostics | `.build/integration/swiftlint-final.log` |
| Full FeatureTests excluding VisualSnapshotTests | 1,328 tests: 1,315 passed, 3 inventory failures, 10 expected failures, 0 skipped | `.build/integration/feature-tests.xcresult`, `feature-tests-summary.json` |
| Entire AppToolsTests target after inventory correction | 15/15 passed; 0 failures, expected failures or skips | `.build/integration/inventory-final.xcresult`, `inventory-final-summary.json` |
| iPad LandscapePaneUITests, iOS 27.0 | 2/2 passed, 0 failures/skips, 63.847 s command duration | `.build/integration/ipad-ui.xcresult`, `ipad-ui-summary.json` |
| Duo LandscapePaneUITests, iOS 27.1 | 2/2 passed, 0 failures/skips, 67.432 s command duration | `.build/integration/duo-ui.xcresult`, `duo-ui-summary.json` |
| Diff whitespace check | Passed | `git diff --check` |

Both UI runs execute `testHomeAndNestedSheetsUseOppositeHalves` and
`testReaderControlsMoveAndKeepTheirSideAfterRotation`. The latter checks the opposite move button,
slider geometry, side retention after rotation and device-specific lower Close placement/count.
These focused integration checks do not replace the broader historical matrices in VERIFICATION.md.

The first full FeatureTests run failed only the three inventory checks described above. After their
correction the complete affected target passed. The other targets were not unnecessarily rerun;
this record does **not** claim a second all-green full-plan execution. The 10 expected failures are
pre-existing test diagnostics and are not presented as ordinary passes. VisualSnapshotTests were
excluded deliberately; no baseline was promoted. SDK runtime-build parsing messages appeared in
Xcode's test logs; they did not produce compiler warnings or test failures.

The repository's `Gate.single_pass_run` helper created local copies of the FeatureTests/UITests
manifests with repetition policy removed. The original manifests were not changed. All four
result trees have zero `Repetition` nodes. Manifest preparation evidence is under
`.build/integration/single-pass/`. An initial unsupported `-maximum-test-iterations 1` invocation
exited 64 before tests ran; `feature-tests.log` retains that preflight error. Successful commands
use the single-pass manifest copies instead.

Representative execution commands (the local manifests and bundles are retained):

```sh
xcodebuild test-without-building \
  -xctestrun .build/integration-dd/Build/Products/phase17-FeatureTests.xctestrun \
  -destination 'platform=iOS Simulator,id=6CE1E40A-7090-484E-8C49-B7BCBDC5E684' \
  -derivedDataPath .build/integration-dd -skip-testing:VisualSnapshotTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .build/integration/feature-tests.xcresult
# AppTools rerun uses -only-testing:AppToolsTests and inventory-final.xcresult.

xcodebuild test-without-building \
  -xctestrun .build/integration-dd/Build/Products/phase17-ipad-ui.xctestrun \
  -destination 'platform=iOS Simulator,id=114E0258-098C-4C26-B2FF-0B5CECEA4810' \
  -derivedDataPath .build/integration-dd \
  -only-testing:EhPandaUITests/LandscapePaneUITests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .build/integration/ipad-ui.xcresult

python3 Scripts/run-duo-ui-tests.py \
  --device 05422A43-8575-4BA6-A791-FAC2D5D3BA19 \
  --xctestrun .build/integration-dd/Build/Products/phase17-UITests.xctestrun -- \
  -derivedDataPath .build/integration-dd -collect-test-diagnostics never \
  -only-testing:EhPandaUITests/LandscapePaneUITests \
  -resultBundlePath .build/integration/duo-ui.xcresult
```

After testing, each of the three dedicated simulators received a normal app launch. Process
inspection found no `EHPANDA_` fixture flags. Duo was restored to hinge 0° / portrait and all three
simulators returned to their recorded entry `Shutdown` state. No Reduce Motion setting was changed
by this integration validation. See `.build/integration/simulator-cleanup.json`. No other session's
simulator or process was operated.
