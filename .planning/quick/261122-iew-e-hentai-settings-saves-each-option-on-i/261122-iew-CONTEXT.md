# Quick Task 261122-iew: E-Hentai Settings saves each option on its own - Context

**Gathered:** 2026-11-22
**Status:** Ready for planning

<domain>
## Task Boundary

The E-Hentai Settings page (`AppPackage/Sources/SettingFeature/EhSetting/`: `EhSettingReducer`, `EhSettingView`
and its `+Sections1/2/3.swift`). It follows the owner-approved Screens v1.1.0 design (design repository,
`app/behavior/19-settings-pages.md`, boards `SiteSettings-NoWebsite-iPhone` and `SiteSettings-Favorites-iPhone`):

1. Every option saves to the site as soon as the user changes it: toggles and pickers on change, sliders when the
   drag ends, text fields on submit. The toolbar's Save (`icloud.and.arrow.up`) and Website (`globe`) buttons are
   removed, so the page has no toolbar items.
2. A save shows no page-wide loading state: no `LoadingView` over the form, no spinner anywhere.
3. Only the changed option's control is disabled, from the action until the site's answer comes back. Every other
   control stays usable.
4. No error handling for saves: no alert, no toast, no rollback logic. When the site's answer comes back, the
   control and the whole form show the site's latest state.

The page's first load keeps its current loading and failed states (`loadingState`, `LoadingView`, `ErrorView` with
Retry). Out of scope: the design's "Open in Browser" fallback on the failed state (the repository does not have it
yet; another session ports it).

</domain>

<decisions>
## Implementation Decisions (orchestrator, locked)

### D-01 Option identity
- Add a nested `EhSettingReducer.Option` enum (`Hashable`, `Sendable`): one case per saved control of the form,
  and `disabledCategory(Int)`, `favoriteCategory(Int)` and `excludedLanguage(Int)` for the per-index controls (each
  category toggle, each favorites name field and each excluded-language toggle is its own control). The profile
  section's controls (Selected Profile picker, Set as Default, Delete Profile, Rename, Create New) share one case,
  `profile`.
- `Option` provides one function that lists the options whose values differ between two `EhSetting` values (field
  by field, index by index). It is the only place that maps options to `EhSetting` fields.

### D-02 How a save starts
- Controls keep writing the form through the existing projected bindings (`$store.ehSetting` → `BindingReducer`).
  `Binding(get:set:)` is banned by the lint (`binding_initializer`); do not add closure bindings.
- The reducer composes `BindingReducer().onChange(of: \.ehSetting) { old, new in ... }`. `onChange` on the
  `BindingReducer` sees only the changes the bindings made, never the ones a site answer applies, so a site answer
  can never trigger another save. For each option that changed it marks the option as updating and starts one save.
- Toggles, pickers (menu, inline and segmented), category toggles and excluded-language toggles write the binding
  directly, so they save on change.
- Sliders (`ValuePicker`) keep a view-local draft while dragging and write the binding once, when the drag ends
  (`Slider`'s `onEditingChanged` false). The value label follows the draft. While not dragging, the draft follows the
  model (so a site answer moves the slider).
- Single-line text fields (Ratings Color, each favorites name) keep a view-local draft and write the binding on
  submit (`.onSubmit`). When the field loses focus without a submit, the draft returns to the form's current value,
  so the field never shows text that was not saved. While not focused, the draft follows the model.
- The Excluded Uploaders `TextEditor` has no submit (return inserts a newline), so it writes the binding when its
  editing ends (focus leaves it). Its line-count footer follows the draft.
- The profile section keeps its existing actions (`performAction`, picker `onChange`, Rename, Create New, Set as
  Default, Delete confirmation). The profile name field is not saved on submit: it names the profile for Rename or
  Create New, as before.

### D-03 Disabling
- `State.updatingOptions: Set<Option>` replaces `submittingState`. Each control is `.disabled(...)` while its option
  is in the set; a `profile` update disables the profile section's controls. A save for an option already in the set
  is ignored (its control is disabled anyway). `LoadingView` shows only for `loadingState == .loading`.

### D-04 Which answer the form shows
- Every save posts the whole current form (`SubmitEhSettingChangesRequest`) and its response is the site's settings
  page parsed after the change, so the response is the refetch; no extra fetch. Profile actions
  (`EhProfileRequest`) likewise return the site's settings.
- Saves and profile actions run concurrently, are never cancelled by another save, and each carries a revision
  number from a monotonic `State` counter. When one returns, its option leaves `updatingOptions`. Its settings are
  applied to the form only if it is the most recently started request; an older answer is dropped, because the newer
  request posted the whole form including the older change and its answer shows the site's state after both.
- If the most recent request fails, the reducer quietly refetches the settings (`EhSettingRequest`) under the same
  revision, keeping that option disabled until the refetch returns, so a save that did not take shows the site's
  value. If the refetch also fails, the option is re-enabled and nothing else happens. No alert, toast or error state
  for saves; `signalsErrors` stays on `loadingState` only (update its comment).
- Applying site settings (`setEhSetting`) resets `editingProfileName` only on the first load and on profile-action
  answers, never on an option save's answer, so typing a profile name is not wiped by an unrelated save.

### D-05 Removed Website path
- With the globe button gone, `presentWebView`, `Destination.webView`, the web view `.sheet`, the destination
  `.haptics` and the then-empty `Destination` / `@Presents destination` are dead; remove them and all call sites
  (owner rule: remove emptied actions). Remove the `save` toolbar and `toolbar()` entirely. Leave `setKeyboardHidden`
  as it is (out of scope).

### D-06 Testability
- Follow the `GalleryClient` precedent (`AppPackage/Sources/GalleryClient/GalleryClient.swift`, commit
  `06b4747a3`): add an injected client module for this page's three requests (initial fetch, submit changes,
  profile action), with a `live` value that builds exactly today's requests and an unimplemented `testValue`. New
  module: `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml`, `Package.swift` registration like
  `galleryClient`, `///` doc comment stating why it exists.
- Swift Testing reducer tests (parallel-safe, no `.serialized`) under `AppPackage/Tests/SettingFeatureTests/`
  covering: a binding change saves only that option and disables only it; no `LoadingView` state change on save;
  the answer re-enables the option and applies the site's settings; an older answer is dropped while a newer request
  is in flight and the newer answer is applied; a failed latest save quietly refetches and applies the refetch; a
  site answer does not start a save; `Option`'s difference function over representative fields and indices; an
  option save's answer leaves `editingProfileName` alone. Update existing tests that use `submittingState` or the
  web view (`AnalyticsEmissionTests`, `SettingPresentationTests`, `ScenarioCatalog+Settings` if affected).

### D-07 Docs and comments
- `///` comments state the why of D-02 (onChange on BindingReducer only), D-04 (latest-wins revisions, quiet
  refetch) and the draft controls.

</decisions>

<specifics>
## Specific Ideas

- Possible collision: the `port/462` branch edits `EhSettingView+Sections2.swift` (the favorites dots in
  `FavoritesSection`). Keep edits to that section minimal and confined to the text-field draft and disabling.

</specifics>
