# Owner-directed follow-up — 2026-10-28

The owner authorizes implementing the recommended size reductions and requests a list of optional
approaches. The UI review must contain actual before/after screenshots, correcting the earlier
text-only deliverable. The three serialization exceptions remain undecided.

1. Archive current source with existing optimization, then compare a build-wide Release `-Osize`
   archive. Preserve Debug optimization and every shipping capability. Integrate the verified
   configuration into both release workflows and app-owned build settings. Verify actual compiler
   commands, payload sizes, unchanged resources and representative optimized tests/performance.
2. Trace the small retained preview fixture contribution. If references are exclusively preview-only,
   remove those references from Release compilation while preserving Debug previews and frozen IDs;
   measure its additional effect separately. Investigate device thinning without changing artwork,
   signing/account configuration or publishing. Record any concrete export prerequisite and keep
   installed-device size distinct from archive payload.
3. Make the B1–B6 UI proposal in a disposable source copy. Capture the baseline and proposal on the
   same iPhone/iPad simulators, fixtures, locale, appearance and content-size settings. Include loaded
   scroll positions that expose the bottom treatment and an Archives accessibility comparison.
   Keep UI production source unchanged until the owner reviews the images. Preserve the prototype
   patch and capture provenance, with images outside tracked repository history.
4. Review changes using the SwiftUI and package skills, run appropriate checks, commit size changes
   separately from review documentation, update the checkpoint, and present measured savings,
   optional choices and a linked screenshot list. Do not infer serialization approval.

Execution remains inline under the previously disclosed executor availability limitation. No
executor subagent may improvise a change to this plan. Reference-project identity and absolute home
paths remain excluded from repository artifacts.
