---
type: integration-record
status: validating
recorded: 2026-10-15
---

# Worktree and commit migration

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Owner authorized local replay onto `feature/gsd-phase-17`, SHA correction, a new worktree/branch,
and removal of the old checkout/branch. No push or PR.

- Integration base: `14ba361922aa597f3eb343bb2abcefabb5681681` (Phase 17).
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
| `fee44887785a37ceb019daed1cbf4ef7c324e35f` | `7015d62cd3b475f9043c9d4132ef170743906127` |
| `04e61ee4ec08ca5d836c4d800440755d94762c64` | `8fb237453684034d1a3957be2e6fee445c58e89d` |
| `bcdb00220d410425d0d64e0e4006e2a66dde744d` | `e89e89663487ed6245dc0e98d2997b5606dda110` |
| `9f572d03d516de59e5cc759764751438faf871a1` | `e8736e940c031f521cecf5cd969a311033ce69a7` |
| `3b8ad8cec2d682a8e3bf5dd293de861aba8a3397` | `0b0061bfe1b864143e1c8eb41b8ba5d3651a99ab` |
| `ab671eb4afa3b5a77b7ee32728a9481dfd9ad449` | `628b8b71522c38a9863c927d753ed94dfe7bfe99` |
| `899bd820a3e7767762fd64607ecd9d94330fd97d` | `97b2dbfc7fdc747f65a84e8e666fae8746e684fb` |
| `29971da6e8053e890d9dcb00397a34e6cb7a0202` | `3a6b817a99f9e49f7456f9c2324f7d7661f145ff` |
| `433aa031f9272f34dca18ab872f0c1a22b5afc0a` | `fd75e0746acf1766dae2211c5e0d64e6d53f249f` |
| `9d0fa8e7e9426934294c868267e6979f0d2ec307` | `a76548695909a525b8a2978791d6bd673b8b92ac` |
| `d6f5fa54cc6f063527c4c69ea4b396a42b4ec2a5` | `5c72028f6809ea995f7c9ce5491cf0f89ae24824` |
| `5973b8013f041b7b745d44ffa63f50dc0b4eaaa0` | `22423a32961acccb0fa6c9e4f7f608c78a9fb071` |
| `a6210b8280106ac82738a2c2bab7a4c304256358` | `0a42b7fbb41a29bd4f89fd6fcfbe505cc58272ea` |
| `8fb9490fb13dc89aa6de6dac1534366e513c7aee` | `9a5595c8edbfeb6156f494680a6245e1ed189d9c` |
| `4ae474d93b73d327e5cd91825db42ed895caa33d` | `d58ef18476eaaeb4e7c20ca86de8fb5f16deb924` |
| `8de27c700ed48d52be7e289b9ba6d18e439ee903` | `81f3b5cb588ff7d2acee389304e635fa1ed63df8` |
| `f221c6e6a09a8484aa7aebba69df4e3489225763` | `d25bd9113549221778fbb71636dafa981bbfd456` |
| `c58ddb0f55ee4ffa2525e7c427b06904e1700e47` | `b47eeac6edae1740fa736ae662bcc52a754ea9d4` |
| `647c5d7ba120e1b203bce4e44b5e30f40c1e4bad` | `412285ee9aa690a8621e629fa1956ea2c2fbf8d7` |
| `7f14dd15462b08d108c2d1853ef8ac36eb2c84ea` | `d7820e618e4ac09d259d6c180d3be6b978cd0378` |
| `5c9ecc8e7b314621ee5833c45bd38efe7c0b2530` | `c274f0eac7fa47566a61985bc8866ae70faf0ff9` |

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
