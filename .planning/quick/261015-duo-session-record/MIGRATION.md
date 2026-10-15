---
type: integration-record
status: validating
recorded: 2026-10-15
---

# Worktree and commit migration

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Owner authorized local replay onto `feature/gsd-phase-17`, SHA correction, a new worktree/branch,
and removal of the old checkout/branch. No push or PR.

- Integration base: `d9e79691b7aa053945474062ab2d852b6e659de9` (Phase 17).
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
| `fee44887785a37ceb019daed1cbf4ef7c324e35f` | `7cf9ff16ef31d181dac3f495e2057074c5b66e25` |
| `04e61ee4ec08ca5d836c4d800440755d94762c64` | `605b4e4749121d55db940c9900bb7b71d4c20017` |
| `bcdb00220d410425d0d64e0e4006e2a66dde744d` | `e03456839ae9022b5e1610e27b4edb75ec0c2b07` |
| `9f572d03d516de59e5cc759764751438faf871a1` | `1c79f363682d048678f9ecf98bc6ddfa43ba5fdf` |
| `3b8ad8cec2d682a8e3bf5dd293de861aba8a3397` | `4191a6bb09f1574c83efd53d05b2f705912b92f3` |
| `ab671eb4afa3b5a77b7ee32728a9481dfd9ad449` | `8c332e2a211036fa539c275117d98a1bbbadbd30` |
| `899bd820a3e7767762fd64607ecd9d94330fd97d` | `7319a710b4e8b4767fd5bbddf738f73cc8c00044` |
| `29971da6e8053e890d9dcb00397a34e6cb7a0202` | `2d298eeba691fdbb0e1022a7112faf815acc29c2` |
| `433aa031f9272f34dca18ab872f0c1a22b5afc0a` | `5365df2f7d20464d2a2577790fa6c2fe2d7e3b69` |
| `9d0fa8e7e9426934294c868267e6979f0d2ec307` | `c1a0139b1cf2069fc46f72c9f590ca1acb1a23f5` |
| `d6f5fa54cc6f063527c4c69ea4b396a42b4ec2a5` | `f0f2b435f23539c9ff11e89dd4d6b1b7450602c1` |
| `5973b8013f041b7b745d44ffa63f50dc0b4eaaa0` | `67f5829629233db7178b57ba7fab09ba3f73e72c` |
| `a6210b8280106ac82738a2c2bab7a4c304256358` | `30ef583d2191b6c7961dd41ac9724f71910f1bde` |
| `8fb9490fb13dc89aa6de6dac1534366e513c7aee` | `0b72a1db9d3ea3aaa2bc08da897c575c43216ce3` |
| `4ae474d93b73d327e5cd91825db42ed895caa33d` | `49b70a328ee5942c3f2e91f2cd86db0795cebedb` |
| `8de27c700ed48d52be7e289b9ba6d18e439ee903` | `f23bf58d1c819d0949a2ad7a38da4cd6106d7dcd` |
| `f221c6e6a09a8484aa7aebba69df4e3489225763` | `5ab03faff3cd923640d3cec942aed7addfe1c39b` |
| `c58ddb0f55ee4ffa2525e7c427b06904e1700e47` | `24ede29e5fb4b382d59db34dedd5c00ea1951056` |
| `647c5d7ba120e1b203bce4e44b5e30f40c1e4bad` | `1eb8bdcdfeafd8d82d01df5b39d2be99262decf2` |
| `7f14dd15462b08d108c2d1853ef8ac36eb2c84ea` | `52e2547c11713f89d20b02b82f0c5783df2649d8` |
| `5c9ecc8e7b314621ee5833c45bd38efe7c0b2530` | `37461f3980a0a057078b5539c54efea285ebf43e` |

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
passed all 79 changed Swift files. The compatibility edits after replay are import-only in 17 files,
required by Phase 17 InternalImportsByDefault/MemberImportVisibility. Earlier compiler failures
are retained in the numbered build logs; no rule or diagnostic was suppressed.

The preserved original history bundle `source-history.bundle` passed `git bundle verify`.
A checksum-based dry-run comparison found no missing/changed archived evidence (excluding
rebuildable caches and the intentionally relocated preview server PID/log).

## Remaining steps

Execute simulator regressions when the existing test slot is free or parallel execution is approved;
then record results, fast-forward the target while preserving
its unrelated staged/unstaged work, and remove the old worktree/branch only after preservation.
The primary checkout is concurrently active; its branch must never move behind its index.
