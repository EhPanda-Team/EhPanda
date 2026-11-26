# Quick 261126-iq9: fix the findings, then release a new beta build

Owner request (2026-11-26): "fix the findings and release a new beta build". Branch `develop`; commits go on top,
nothing is rewritten. The release (build number, push, Deploy Beta dispatch) is done by the orchestrator after the
fixes land; the plan covers the three fixes only.

## The findings

1. **Webtoon detection misses galleries whose first page is a cover.** Recorded in
   `.planning/notes/2026-11-26-webtoon-detection-samples-middle-pages.md` (read it). Example: gallery 4354007
   (26 pages), cover 797 x 1895 (2.38), every other page 5 to 25 times as tall as wide.
2. **About page link rows end with a chevron.** Recorded in
   `.planning/notes/2026-11-26-about-links-use-the-external-arrow.md` (read it).
3. **The toast sits far too high.** Owner: "the add to my tags success toast in gallery page is way too high even
   for the tab bar avoid logics". `SystemNotification/View+Toast.swift` overlays at `.bottom` with a fixed
   `.padding(.bottom, 88)` (raised from 64 in `6270163b2` "Fix toast height", no reason recorded). The overlay is
   already inside the host's safe area, so on a page inside a tab (Detail) the tab bar is counted twice.

## Decisions (orchestrator, 2026-11-26; locked for planning)

### Webtoon (supersedes D-04, and D-06's "no extra fetching", of quick 261122-317)

- **W-1 Middle sample.** The three sampled pages are `m-1, m, m+1` with `m = (pageCount + 1) / 2` (1-based; for
  3 pages that is 1...3, for 26 pages 12...14). They no longer depend on the current page. D-05 (ratio >= 2.5, all
  three) and "fewer than three pages is never detected" stay.
- **W-2 Fetch the middle pages' addresses at open.** When the option is on and the gallery has no usable verdict,
  the reader asks for the three middle pages' image addresses when the gallery opens, through the reader's existing
  page-address fetch (the same request and storage it uses for any page, at that request's own granularity), so the
  sizes land in `State.pageSizes` through the existing served-URL file-identifier source. No new size source, no new
  request type. The fetched addresses are kept like any fetched page.
- **W-3 Failure.** A failed fetch records no verdict and starts no retry loop of its own; the verdict can still land
  later, when the normal reading path learns those pages' sizes.
- **W-4 Re-check old negative verdicts.** A "not a webtoon" verdict recorded under the old rule is dropped once so
  the gallery is checked again with the new rule; positive verdicts stay. Use the project's schema-migration engine
  (`AppModels/Persistence`: `SchemaVersioned`, `VersionedSchema`, `SchemaMigrator`): `GalleryHistoryEntry` gains a
  `SchemaV2` whose migration removes `isWebtoon: false` and keeps `true`. If the engine does not run for
  `[GalleryHistoryEntry]` as stored, stop and report instead of inventing another mechanism.
- D-06's switch-with-a-toast stays for a verdict that arrives while the gallery is showing. D-07 (one optional field,
  same upsert) stays.

### About arrow

- **A-1** The external-link arrow becomes one shared helper in `AppComponents` (beside `withArrow()`), drawn as the
  General privacy-policy row draws it today: `arrowUpRight`, `.imageScale(.small)`, `.foregroundStyle(.secondary)`,
  full opacity, hidden from accessibility. The About `LinkRow` and the General privacy-policy row both use it. Rows
  that push a page keep `withArrow()`.

### Toast

- **T-1** No fixed bottom constant. The toast sits on its host's bottom safe-area edge with a small gap, so a page
  inside a tab clears the tab bar exactly once. A host whose bottom chrome is not part of its safe area (for example
  the reader, which ignores the safe area and draws its controls as overlays, or a toast hosted at the tab-bar root)
  gets its clearance from its own layout, not from a shared constant. Every `.toast(` host is checked:
  AccountSettingView, MyTagsView, LoginView, ReadingView, TabBarView, DetailView, TorrentsView, ArchivesView.

## Rules

- Follow `CLAUDE.md` / `AGENTS.md`: SwiftLint (read the root `.swiftlint.yml` first, no suppressions), labeled
  numeric format arguments, scroll-edge policy, dialog placement, parallel tests (no `.serialized`), document the WHY
  of deliberate designs.
- One atomic commit per task, signed, `TZ=Asia/Shanghai`, author and committer dates +08:00, subject <= 50
  characters, no attribution lines. Nothing is pushed.
- One `xcodebuild test` at a time (check `pgrep -x xcodebuild` / `pgrep -x xctest` first). Simulator
  "EhPanda iPhone Air (phase19)", id `19DB23C0-8C35-49C7-9A7D-5D99566BF092`. Tests:
  `xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=…' -only-testing:<Target>`.
- 0 warnings, lint clean.
