---
quick_id: 261123-1dk
date: "2026-11-23"
source: owner answers, 2026-11-23 (two AskUserQuestion rounds)
---

# Quick task 261123-1dk: owner decisions (locked)

Scope: the two deferred download-queue notes, now authorized:

- `.planning/notes/2026-11-17-download-list-order-vs-queue-order.md` (Part A, investigation first).
- `.planning/notes/2026-11-16-reported-download-library-issues.md`, item 1 only (Part B, queue
  operations). Items 2 and 3 of that note were fixed by 261117-tyj and stay untouched.

The decisions below are the owner's. Downstream agents must not revisit them. Anything a decision
does not settle goes back to the orchestrator; it is not the agent's to choose.

## Part A: list order vs queue order

### Orchestrator investigation (verified in source, 2026-11-23)

- **What the queue runs in.** `DownloadQueueStore` (`AppPackage/Sources/DownloadClient/DownloadQueueStore.swift`)
  is a persisted `[String]` of gids. `enqueue` appends to the end (`:23`). The scheduler walks that
  array in order and starts the first schedulable gid (`nextQueuedDownload`,
  `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:84`). The active gallery stays
  in the array while it runs and leaves it on completion (`settleCompletedDownload`,
  `DownloadClient+Execution.swift:249`). Pause removes the gid (`writeInitialPauseRecord`,
  `DownloadClient+Scheduling.swift:294`); Resume appends it again at the end (`resume`, `:372`).
  So the queue is FIFO by the time each gallery was last enqueued.
- **What the list shows.** The list is the coordinator's snapshot, which `downloads(from:)` sorts with
  `sortDownloadsByDisplayStatus` (`DownloadClient+Persistence.swift:117`): first by
  `DownloadDisplayStatus.sortPriority` (`AppPackage/Sources/AppModels/Download/DownloadDisplayStatus.swift:11`:
  active, queued, update available, error, inactive, completed), then by `lastDownloadedDate`
  descending. `lastDownloadedDate` is the gallery folder's `contentModificationDate`
  (`DownloadStore.swift:685`). The sort never reads the queue. `DownloadsReducer.State.downloads`
  keeps the snapshot's order (`AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift:98`).
- **Whether they were meant to match.** No `.planning/` record decides the list order. The sort came
  with the original downloads feature (`d92a0690a`, 2026-03-24); the persisted queue was added later
  (`b2b240b98`, 2026-06-09) and the list sort was never updated to follow it. The existing test
  `DownloadCoordinatorSchedulesManifestQueueOrder` pins the run order (queue order beats the newer
  folder date), so the two orders are known to differ by construction.
- **Effect.** Within the queued group the list usually shows the newest folder first, roughly the
  reverse of the run order. Pause then Resume moves a gallery to the end of the queue without moving
  it in the list, which is the owner's observation ("pause/resume repeatedly to adjust queue order").

### Decision A-1 (owner): the waiting group follows queue order

- Within the `.queued` display group, list galleries in queue (run) order: the next one to start
  first. The active gallery stays at the top (its own group, as today).
- Every other group keeps today's order (status priority, then newest folder first).
- The order comes from the persisted queue, the one record the scheduler reads. It must hold in the
  list, the grid, and every other consumer of the coordinator snapshot.

## Part B: queue operations

Terminology: a **waiting item** is a gallery whose display status is `.queued` (in the queue, not
the active one). A **paused item** is one whose display status is `.inactive` (incomplete, not in
the queue, no error), the state the existing Resume applies to (`canPauseOrResume`). "Front of the
waiting items" means directly after the active gallery, i.e. the next one the scheduler starts.

### Decision B-1 (owner): Download Now cuts in line; the interrupted gallery becomes next

- **Download Now** on a waiting or paused item that is not the active one: interrupt the active
  gallery and start the selected one now.
- The interrupted gallery is **not** paused and does **not** leave the queue: it goes to the front
  of the waiting items, directly after the selected gallery, so it continues as soon as the selected
  one finishes. Its saved pages stay; the manifest remains the record of what is done.
- With no active gallery, Download Now puts the selected item at the front and starts it.

### Decision B-2 (owner): operations in scope

- **Download Now** (B-1).
- **Download Next**: move the selected item to the front of the waiting items. The active gallery
  keeps running.
- **Move Up / Move Down**: move a waiting item one place earlier or later among the waiting items.
- **Download Last**: move a waiting item to the end of the waiting items.
- **Paused items too**: Download Now and Download Next also apply to a paused item directly (no
  Resume first). For a paused item they mobilize it the way Resume does, then place it as above.
  Move Up, Move Down and Download Last apply to waiting items only (a paused item is not in the
  queue; Resume already puts it last).
- Out of scope (not approved): "pause without losing its place". Pause and Resume keep today's
  behavior.

### Decision B-3 (owner): context menu only

- The operations go in the context menu of both presentations (list row and grid cell, the shared
  `managementMenu` in `AppPackage/Sources/DownloadsFeature/DownloadGalleryItem.swift`).
- No new swipe actions, no toolbar, no inspector buttons.
- VoiceOver gets every applicable operation as a custom accessibility action on both presentations,
  named exactly as in the menu.

### Decision B-4 (owner): labels, Download-based naming

zh-Hant and English as chosen by the owner:

| Operation | zh-Hant | en |
|---|---|---|
| Download Now | 立即下載 | Download Now |
| Download Next | 接著下載 | Download Next |
| Move Up | 往前移 | Move Up |
| Move Down | 往後移 | Move Down |
| Download Last | 最後下載 | Download Last |

The other four locales are written natively for the same meaning, not translated word for word, and
reviewed side by side with all six (zh-Hans mirrors zh-Hant's structure in Simplified vocabulary).
Orchestrator-proposed values, to be checked against each catalog's existing download wording
(German already uses "laden", e.g. `redownload` = "Erneut laden"):

| Operation | de | ja | ko | zh-Hans |
|---|---|---|---|---|
| Download Now | Jetzt laden | 今すぐダウンロード | 지금 다운로드 | 立即下载 |
| Download Next | Als Nächstes laden | 次にダウンロード | 다음에 다운로드 | 接着下载 |
| Move Up | Nach oben | 上へ移動 | 위로 이동 | 往前移 |
| Move Down | Nach unten | 下へ移動 | 아래로 이동 | 往后移 |
| Download Last | Als Letztes laden | 最後にダウンロード | 마지막에 다운로드 | 最后下载 |
| Submenu (B-5) | Reihenfolge ändern | 順番を変更 | 순서 변경 | 调整顺序 |

### Decision B-5 (owner): menu structure

- Download Now and Download Next appear directly in the menu.
- Move Up, Move Down and Download Last sit in a submenu: zh-Hant 調整順序, en "Reorder".
- Inapplicable items are hidden, not dimmed, as the existing Move to Folder already is: no Move Up
  on the first waiting item, no Move Down or Download Last on the last, no Download Next on the item
  that is already next, nothing on the active gallery, and the submenu is hidden when it would be
  empty. VoiceOver actions follow the same applicability.
- Placement inside the existing menu is an implementation call (orchestrator): the queue items sit
  together next to Pause/Resume.

### Decision B-6 (owner): VoiceOver reads the queue position

- A waiting item's VoiceOver description includes its place among the waiting items, e.g.
  zh-Hant 「等待中，第 2 個」, so a move is audible. Position 1 is the next to start.
- Nothing visible changes on screen for this.
- The position number is a numeric localized-format argument: a labeled `%#@variable@`
  substitution per `CLAUDE.md`, with plural categories coherent across locales (`en` set == `de`
  set; `ja`/`ko`/`zh-Hans`/`zh-Hant` `other` only). The status word matches the existing
  `download_badge.queued` value in each locale (en Queued, de In der Warteschlange, ja 待機中,
  ko 대기 중, zh-Hans/zh-Hant 等待中).

## Invariants that bind this task (CLAUDE.md)

- The persisted manifest stays the single source of truth for completeness. Interrupting a run
  (B-1) must leave the interrupted gallery's manifest exactly as the run left it, and must not
  record a failure, blank hashes or drop it from the queue.
- The client never deletes a gallery folder it did not create in the same run. No queue operation
  deletes anything.
- The queue mutations go through the coordinator's existing convergence point
  (`scheduleNextIfNeeded`) so the continued-processing session stays matched to queue state.
- Every `blockScheduling(gid:)` call site is pinned by `DownloadSourceInventoryTests`, together
  with the documented rule that no queue-mobilizing entry point takes a block. If the interrupt in
  B-1 needs a block on the interrupted gallery, that is a deliberate change to that census and its
  rule, and the plan must say so, justify it and update the test with the reason; it may not be
  slipped in.
- No `.serialized` tests, no lint suppression, Swift Testing in parallel, reducers named with the
  `Feature` suffix for any new reducer.

## Orchestrator decisions on the planner's open questions (2026-11-23)

Implementation-level calls inside the owner's decisions above, made by the orchestrator per the
standing rule that it decides such questions and reports them:

- OQ-1 (B-6 wording): accepted as planned: the position joins the badge's existing progress
  reading, e.g. zh-Hant 「等待中，第 2 個，共 20 頁，已完成 3 頁」, en "Queued, position 2, 3 of 20".
- OQ-2 (B-6 reach): accepted: every surface that draws `DownloadBadgeLabel` reads the position;
  the Detail header's download button keeps its own label (not in the owner's scope).
- OQ-3 (interrupted mode): accepted: an interrupted `.redownload`/`.update` run that had already
  replaced its folder continues as `.repair`, so its saved pages are never wiped by a later run
  (the folder-deletion invariant); one interrupted before preparing keeps its mode.
- OQ-4 (symbols): accepted as listed in the plan.
- OQ-5 (analytics): no analytics event; the signal vocabulary is owner-signed and unchanged.
- OQ-6 (unqueued active run): accepted: Download Now does not interrupt a run the persisted queue
  does not hold and acts as Download Next.
- OQ-7 (placement): accepted; the row's VoiceOver action order (queue actions after the
  swipe-derived ones) is flagged for the owner's on-device check.
