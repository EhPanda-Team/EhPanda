# Quick 261126-trf: add passive webtoon detection

Owner request (2026-11-26, after testing beta 166): "both worked. but the logics still need an improvement, sometimes
the middle pages can still contain short images and cause a miss. keep the aggressive middle pages fetch, add a
passive detection, we flip it to a webtoon when the loaded pages contain more than 2/3 tall pages."

Branch `develop`; commits go on top, nothing is pushed. Builds on quick 261122-317 (D-01 to D-07) and quick 261126-iq9
(W-1 to W-4). Implemented inline by the orchestrator (one reducer rule and its tests).

## Decisions (orchestrator, 2026-11-26)

- **P-1 The passive rule.** While "Always read webtoons vertically" is on and the open gallery is not a webtoon yet,
  the reader turns it into one as soon as more than two thirds of the pages whose size it knows are extremely tall
  (the D-05 ratio, 2.5), counted over at least three known pages. "Loaded pages" are read as every page whose size the
  reader knows (`pageSizes`), whatever told it: a thumbnail's original-file identifier, a served URL or a decoded
  image. All three are the page's real size, and the vertical strip already trusts them.
- **P-2 One way only.** The passive rule only turns a gallery into a webtoon; it never turns a webtoon back.
- **P-3 "Not a webtoon" is no longer final.** A recorded webtoon verdict stays final (D-07). A recorded "not a webtoon"
  now only spares later opens the middle-page fetch (W-2): the passive rule still applies in every session, so a miss
  recovers while the user reads. No schema change: the stored field and its meaning per value are unchanged.
- **P-4 The middle sample stays.** The open-time fetch of the middle three pages and their all-three rule (W-1, D-05)
  are unchanged and decide first when the passive rule does not.
- **P-5 Same effect as a sample verdict.** A passive flip mid-session reads the gallery vertically with the existing
  toast (D-06), updates open reading settings, and records the verdict in the history (D-07).

## Rules

As for quick 261126-pfh: CLAUDE.md / AGENTS.md, root `.swiftlint.yml`, no suppressions, parallel tests, document the
WHY, one atomic signed commit with +08:00 dates, subject <= 50 characters, one `xcodebuild test` at a time, 0 warnings,
lint `--strict` clean including tests.
