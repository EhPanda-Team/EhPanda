# Library header stability — D74

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Status: unresolved and explicitly deferred by the owner (D75), 2026-10-16. D76 restores the native sidebar toggle; it is not a header-stability fix.

## Owner requirement

D74 originally requested stable Library headers across tab entry, rotation and sidebar transitions;
D75 now defers the unresolved defect while retaining native sidebar behavior.
The owner also saw the problem after closing and reopening the sidebar while its native toggle
was still available. Hiding the toggle is therefore not the sole trigger. D76 restores the working
toggle, superseding fixed-open D69. Keep native compact navigation, inlineLarge titles, native
search, section actions and the continuous top scroll effect required by D68–D73.

## Reproduction and evidence

On the dedicated iPadOS 27.0 simulator, built with Xcode 27.1:

- Normal logged-out Library: both titles at y=152 pt, search at y=204 pt after entering from Home.
- Native navigation bars themselves are displaced; this is not List row padding.
- The split view spans the window; both child navigation controllers receive the extra top space.
- A standalone SwiftUI app containing only TabView, NavigationStack and NavigationSplitView
  reproduces the defect. Starting directly in Library places its title at y=88 pt; starting in
  Home and then selecting Library places it at y=152 pt. Empty and scrolling detail views agree.
- This excludes TCA, account/network data and the app privacy layer as necessary causes. It does
  not prove a specific internal framework defect or that all app-side remedies are exhausted.
- A diagnostic fixed HStack of two native navigation stacks remains at y=98 pt across tab entry
  and rotation. Its sidebar styling/navigation differ, so it is not an accepted replacement.

Source, raw captures, accessibility geometry, build logs and minimal reproduction are kept locally
in `.build/library/header-stability/`. Nothing from the diagnostic app is a production dependency.

## Controlled experiments rejected

Removing balanced split style, moving/omitting top safe-area extension, relocating toggle removal,
explicit sidebar NavigationStack, explicit toolbar visibility/title role/minimization behavior,
static Tab declarations, tabBarOnly style, column-level top safe-area extension, and removing the
outer privacy layer did not resolve the transitions. Temporary production edits were restored.

The existing sidebar-local toolbar removal is Apple's documented placement. Restoring its toggle
changed the cold-entry geometry but does not address the owner's observed close/reopen failure.
No offsets, delayed remounts, identity resets, hard-coded safe-area values or private production
APIs were added.

The prior D68 acceptance of cold/live title differences is superseded by D74. Existing suite
results belong to earlier revisions; they do not verify a fix for this issue. A diagnostic LLDB
recursive expression failed with EXC_BAD_ACCESS and the debugger restored the app state; this is
not counted as an app crash or as a successful diagnostic. Flat public-property reads succeeded.

## Additional isolation and limits

- A persistent UIHostingController boundary around the completed native split still yields y=152.
- A UIKit UITabBarController with one hosting controller per tab still yields y=152.
- Removing native searchable does not remove the displacement.
- Hiding the root navigation bar or setting the outer split title mode to inline does not fix it.
- Moving NavigationSplitView outside TabView changes the sidebar title to y=34, places tabs at y=90,
  and loses the detail title in the prototype. Rejected as a preservation failure.
- The available iOS 27.1 runtime rejects the iPad M5 device type as incompatible. No simulator was
  created; this run cannot establish whether a later iPadOS runtime fixes the issue.
- With the native toggle retained and Library selected at cold launch, one close/reopen followed
  by three Home/Library/close/reopen cycles retained title/search y=88/140. The owner's rarer toggle
  sequence is recorded, but these particular runs did not reproduce it.

The evidence narrows the problem to native tab/split containment and transition layout. It does
not identify a confirmed Apple internal root cause. Comparable reports exist in
[Apple Developer Forums](https://developer.apple.com/forums/thread/759875), but they are developer
reports, not an Apple diagnosis of this app. The independent reproduction is preserved in
[HEADER-REPRODUCTION.md](HEADER-REPRODUCTION.md).

## Reviewable alternative, not an approved fix

A fixed side-by-side arrangement of two native NavigationStacks retained y=98 across Home→Library
and rotation. However, List(.sidebar) outside NavigationSplitView renders a grouped list. The
prototype's category links also need deliberate selection routing instead of navigation pushes.
It is **not** a drop-in replacement and has not passed query/focus, compact navigation, section
actions, Dynamic Type or Duo acceptance. No production code from this prototype was retained.

The owner was shown the actual native prototype and asked whether to accept a fixed category
panel and proceed with implementation/verification, or retain the native sidebar with the issue
recorded. D75 selected the latter; D76 then restored the toggle. The reason for asking was the
visible change to an already chosen navigation design, not an additional permission requirement
for ordinary code edits.

- Current app with displaced headers (image removed from repository history)
- Fixed-pane diagnostic prototype — not EhPanda's final UI (image removed from repository history)

Before the D76 toggle change, all failed production experiments were restored byte-for-byte to
HEAD. That restored application
built successfully (`restored-production.xcresult`, zero compiler warnings/errors); that is a
restoration check, **not** verification of a header fix. No new unit/UI suite pass is claimed.

At the intermediate pre-D76 restoration, the diagnostic app was terminated and the production
app relaunched with no EHPANDA_ environment keys. That landscape Library/Favorites screen in
normal logged-out state still showed title/search y=152/204;
the defect remains open. No unrelated simulator was operated or modified.

## Owner resolution — D75–D76

The owner selected **retain native sidebar and preserve the issue/reproduction**, then requested
keeping the toggle. The fixed-pane proposal is rejected for this follow-up. Restore native
hide/show behavior with @State columnVisibility initialized to .all, removing toolbar item
suppression. This supersedes D69's fixed-open constraint. D68's top-only safe-area extension,
native inlineLarge/search behavior and all section operations remain. Header displacement remains
a known issue; restoring the control does not claim to fix the owner's rare sequence.

## Final toggle validation

Implemented in `25848cc4dc`. Only LibraryView.swift changes: two added and two removed lines.

- Xcode 27.1 build succeeds with zero compiler warnings/errors (`toggle-restored-final.xcresult`).
- Strict no-cache SwiftLint reports zero violations. The first standalone lint invocation inherited
  a stale default Xcode/SourceKit path and failed to load SourceKit; rerunning with explicit
  DEVELOPER_DIR pointing to Xcode 27.1 succeeds. No rule was suppressed.
- iPad: hide/show works; hiding the sidebar, visiting Home, then returning to Library preserves
  the hidden state. Reopening restores categories. Downloads→Favorites selection still works.
- iPad and compact iPhone: standard, AX1, AX3 and AX5 cold/live title/search captures completed.
  The iPhone returned to categories and reopened Favorites at each size. Large labels wrap
  natively; there are no new font clamps or title/search replacements.
- iPad live Dynamic Type stepping retains the previous native search field height until cold
  entry; stable repeated accessibility snapshots confirm this difference. Cold entries show the
  corresponding larger search fields. This is recorded rather than claiming identical live/cold
  geometry or adding a native-search workaround. Controls remain visible.
- The first size-capture script could sample transitions early. A second pass waits for repeated
  matching accessibility outlines; final evidence uses the `toggle-settled-` captures.
- Source review found no actionable issue. Full XCTest suites, Duo, physical devices, VoiceOver
  and RTL were not rerun for this bounded restoration; older passes remain revision-specific.

Final iPad standard-size title/search positions are y=98/150, with the native toggle available.
This is **not** proof of resolving intermittent header displacement. The owner-deferred issue
and reproduction remain open. The iPad is left at normal Library/Favorites in landscape-right,
light appearance, standard text, and no EHPANDA_ launch environment keys. The compact iPhone is
restored to standard text and Shutdown. The independent diagnostic app is terminated.

Final running iPad with restored toggle (image removed from repository history).
