# Setting tab transient selection — root cause

Date: 2026-09-09. Diagnosis only; no production fix applied.

## Confirmed cause

On iPad, `TabBarView` includes Setting as an ordinary selectable tab with its own `SettingView` content and `.tag(.setting)`, while `TabBarReducer` treats the corresponding selection request as an instruction to open a sheet and deliberately keeps its old selection. The native controller can commit its selection independently of whether the binding setter accepts the value. The setter is being used as a selection veto, but it does not provide that behavior.

This temporarily creates two different selections: UIKit has Setting selected, while the store retains Downloads. Presenting the sheet updates the view hierarchy and reconciles the native selection back to the store. Without the sheet/presentation effect, the native Setting selection persists in the observed control run. No reducer transition to Setting and back occurred.

## Experiments

Device: iPad mini review simulator, iOS 26.5, portrait, Large, dark appearance, app `app.ehpanda.personal`. Start on Downloads. The tab bar's Next Page control must first expose Setting; tapping its offscreen AX entry does not send an action and was excluded.

A temporary passive `UIViewRepresentable` used `CADisplayLink` to sample the live `UITabBarController.selectedIndex`, selected item's title, presentation presence, and the store selection. It did not set selection or replace delegates. Reducer action logs used the same unified-log timeline. The probe and experimental branches were removed after diagnosis.

| Mode | Observed outcome |
| --- | --- |
| Original asynchronous device resolution | Native Setting selection lasted approximately 196 ms between sampled state changes; store stayed Downloads throughout. |
| Ignore Setting request entirely (`return .none`) | Native Setting became selected and its inline content remained visible, with no sheet and no store selection change. |
| Directly send the presentation delegate, bypassing device resolution | Native Setting still appeared for approximately 133 ms between sampled state changes; store remained Downloads. |

The durations are individual simulator samples, not performance guarantees or precise event-boundary measurements. The synchronous control proves that removing the actor/effect hop alone does not remove the underlying selection mismatch.

### Original timeline

| Time | Event |
| --- | --- |
| 18:51:55.010 | Reducer receives Setting selection request; stored selection is Downloads. |
| 18:51:55.011 | Display sample: store Downloads, UIKit index 4 / Setting, no presentation. |
| 18:51:55.083 | Presentation delegate action arrives; stored selection is still Downloads. |
| 18:51:55.207 | Display sample: store Downloads, UIKit index 3 / Downloads, presentation present. |

### Controls

Ignore run at 18:52:56.627–.628: Setting selection action arrives, followed by store Downloads / native Setting / no presentation. The subsequent screenshot and AX tree show Setting selected with its full inline settings content.

Direct-delegate run: request at 18:53:58.144, delegate at .146, native Setting/store Downloads at .157, native Downloads with presentation at .290.

## Source correspondence and implication

- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift`: Setting is a real tab, alongside the independent settings sheet; selection uses `.sending(\.setTabBarItemType)`.
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarReducer.swift`: iPad Setting requests emit a presentation delegate without setting `tabBarItemType`; only `selectSettingInline` selects Setting.
- Installed TCA `Observation/Binding+Observation.swift`: the `.sending` setter sends the action, without assigning the proposed value into state.
- Existing six Setting routing tests verify the model invariant; they cannot detect the native UI/model divergence demonstrated here.

A fix must prevent native selection before it commits or represent Settings as a presentation action instead of a selectable destination. Repeating the same setter guard or merely making device resolution synchronous does not address the confirmed cause. Replacing or intercepting SwiftUI-owned UIKit delegates was not attempted in this diagnosis.

## Evidence and cleanup

External artifacts: `$HOME/.codex/visualizations/2026/09/09/01a08497-6c61-7343-82a3-f277e0964e23/tab-selection-root-cause/` contains `all-modes.log`, `tab-probe-normal-ignore.log`, `tab-selection-ignore.png`, `tab-selection-normal.mp4`, and the passive probe source. The recording is supplemental; the conclusions above use the instrumented timeline and the observed control screen.

The original tab reducer and view were restored byte-for-byte from their pre-diagnosis copies, and the temporary probe file was removed. The normal app was rebuilt for reinstallation. Earlier login/cover edits remain intact. No phase-wide acceptance or fix is inferred.
