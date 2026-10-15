# Library implementation decisions

Owner decisions D56–D64 remain in the session DISCUSSION-LOG. The following are engineering
choices made under D63 implementation authorization, not additional owner answers.

| ID | Decision | Reason / consequence |
|---|---|---|
| E01 | One native NavigationSplitView at every size; separate Favorites and Downloads feature stores | Shared categories, native collapse/expansion, retained source queries and paths; no size-class container replacement |
| E02 | Six requested layout scopes plus separate Watched and History; DetailSearch shares Search | Every existing full gallery list has an explicit owner, without retaining a global layout authority |
| E03 | Setting schema v2 migrates legacy detail to row and thumbnail to grid; Downloads and fresh installs start in row | Preserve existing online preferences and previous Downloads presentation; remove the old key after migration |
| E04 | Native Menu/Picker labeled Row and Grid in each list toolbar | Compact control that works with horizontal and vertical native bars; one persisted value per semantic list |
| E05 | Native lazy regular grid with aligned rows and aspect-fit 2:3 cover slots | Replace masonry, preserve metadata and text scaling, use actual container layout |
| E06 | Favorites and Downloads keep visible gallery IDs in feature state; a shared surviving-ID policy handles mutations | Retain position across renderer/source changes and choose a neighboring survivor after removal |
| E07 | Downloads row and grid use the same per-gallery feature and actions | Preserve manifest-derived status, read/inspect/move/update/pause/resume/delete semantics |
| E08 | Move confirmation joins delete confirmation in the existing per-gallery reducer | Stable gid ownership through observation reorder; row anchor for swipes, visible Actions anchor for grid |
| E09 | Logged-out category selection updates the canonical filter without requesting Favorites | Library navigation must remain available without authentication; existing login observation loads content later |
| E10 | Offline neutral HTML/images and a test-owned temporary download root | Exercise real parsing, image loading and file operations without contacting gallery servers or touching user downloads |
| E11 | Device-specific test locking, sequential runs on this task's devices | Implements owner D55 without blocking or operating other sessions' devices |
| E12 | Feature results match exact enumerated identities, with named existing expected diagnostic sites | Report intentional guard/unimplemented-client/TCA cancellation diagnostics separately from real failures; no skipped tests or repetition |
| E13 | Per-target Swift-linker SDK correction in the feature test command | Xcode 27.1 forwards `--sysroot` where Darwin clang needs `-isysroot` to read metadata; retain each target's actual SDK, including host macros |
| E14 | Diagnostic parsing recognizes compiler/tool diagnostic lines | Parameterized Swift Testing values named `error:` are test data, not compiler diagnostics; actual warnings/errors still fail the gate |
| E15 | Category rows use native NavigationLink values through the List selection binding | Manual iPhone verification found Button/tag selection did not advance after returning to the sidebar; native links preserve compact navigation semantics |
| E16 | Preserve native focused-search toolbar behavior | Row/grid anchor switching and searched-detail return are separate UI flows; no search presentation override is added |
| E17 | Grid trailing visibility uses the row threshold of 0.1 | Tall cards in short windows must still be able to paginate; real two-page UI fixture plus loading/append/error tests cover the path |
| E18 | Offline UI launches also use the inert bypass client | Settings initialization otherwise replaces the image protocol configuration, preventing neutral covers from loading; production networking is unchanged |
| E19 | Native UI tests reveal controls within the measured content viewport before tapping | XCTest can report an offscreen card as hittable; bounded, measured scrolling makes management checks exercise the visible action source without altering production layout |
| E20 | List restoration uses native minimal scrolling without a fixed top anchor | Manual iPad operation confirmed explicit top alignment hid the restored row behind the navigation bar; both online and Downloads rows reveal the complete target |
| E21 | Detail-return UI checks require the presentation to disappear | Native floating sheets dismiss through their measured outside margin; finding an underlying list after opening More was insufficient evidence of a return |
| E22 | Return and Close UI queries use semantic identifiers across accessibility element kinds | Duo vertical native controls can sit outside NavigationBar and expose BackButton as a generic element; preserve actual-dismissal assertions |

No new dependency, download filesystem resolution policy, analytics content dimension, Search A/B
redesign or Home preview redesign was added. The previous proposal preview remains at
`http://127.0.0.1:55920/index.html`; it is comparison material, not evidence of the current native app.

Validation is recorded separately. A compiled target or a historical tracer does not establish the
current full UI matrix. Unperformed checks must remain explicitly unverified.
