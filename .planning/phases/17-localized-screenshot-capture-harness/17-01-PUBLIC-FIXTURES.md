---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: exporter-passed-matrix-pending
---

# Deterministic public fixture export

Committed generator: `AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift`.
Schema 1; fixture version `phase17-finite-v1`. The native export test independently
materializes two fresh directories and verifies identical aggregate digests and manifest
bytes. It also checks every exported file's length and SHA-256. Unknown fixture, requested
asset and replay-route inputs are rejected before creating output.

The catalog contains six Home covers, sixteen download covers, twelve comment records,
eight reader pages and previews, fixed recognition groups, metadata and four named JSON
replay responses. These are public synthetic inputs for hosted tests. Live network responses
and marketing content are outside this catalog. Later scenario producers must extend the
source catalog rather than relying on a previous local export.

GREEN: 2 actual tests passed, 0 failed/skipped/Repetition nodes, exit 0, no runtime warnings.
Clean build has no compiler/deprecation/lint diagnostics. RED is independently verified
in `17-01-PUBLIC-EXPORT-RED.json`; commit `1902bfd987`.

- Build: `/tmp/ehpanda-phase17-public-export-green-clean-2.log`.
- Result: `/tmp/ehpanda-phase17-public-export-green.xcresult`.
- Summary/tests: `/tmp/ehpanda-phase17-public-export-green-summary.json` and
  `/tmp/ehpanda-phase17-public-export-green-tests.json`.
- Native directory attachment manifest:
  `/tmp/ehpanda-phase17-public-export-green-attachments/manifest.json`.
- Attachment: `EC757F0E-35AD-4089-AF50-7AE1F59712E8.zip`.
- 45 checked entries; aggregate digest:
  `fea2e358249a04ed6eab8ee553640d264ce41cb374cf636b36f117601f8c8a59`.
- Generator source SHA-256:
  `2996f17c8bbb1284b199ae19491ef70c828028e528cfafc1f215a16039bbcefd`.

The attachment was extracted and independently checked, then copied to disposable
`.capture/regression`. No previous export was required. Task 2's actual screen matrix
and both package lockfile validation remain pending; this is not plan completion.
