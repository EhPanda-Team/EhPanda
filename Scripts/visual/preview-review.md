# Preview review (agent aid)

Agents can look at an existing SwiftUI `#Preview` through Xcode's own preview tools. This is a review aid for
work in progress. **A preview render never counts as snapshot acceptance**: it is not a coordinate of the snapshot
matrix, is not compared with the approved baseline, and approves nothing. Acceptance is the snapshot gate
(`README.md`, "Snapshot gate") and the owner's one approval.

## What it is for, and what it is not

- For: a quick look at a view in a given locale and variant while editing, with the source line and any error the
  tool reports kept as evidence.
- Not for: regression evidence, marketing pictures or "the screen looks right at AX5". A preview is not the app:
  it has no real reducer state, window, status bar or settled layout, and its determinism is **unproven**.
- Never evidence: a render that shows a live date, a spinner or progress ring, a loading placeholder, or any other
  value that changes between renders. Note it and do not keep the render.

## Prerequisites

- The installed Xcode (the pin's Xcode is in `regression-environment.json`; a newer one on a developer's Mac is fine
  for a look) with its agent tools enabled in the user's own settings, and the project open in Xcode. Opening Xcode,
  granting the tools access and editing any MCP configuration are the user's own steps. An agent does not edit the
  user's MCP configuration silently, and does not open Xcode on a Mac another job is using.
- When the tools are not injected into the session, `xcrun mcpbridge` is the alternative route to the same tools. It
  also needs a running Xcode with the project open, so without one the procedure stops at step 1: record that
  prerequisite and ask, do not work around it.

## Procedure

Run every step in the same session, one call after another.

1. **Query the tool list each session.** Ask for the tools afresh (`tools/list` or the host's tool search) and use
   only the tools, arguments and values it returns. Tool names, arguments and the supported localization and
   variant values change with Xcode. Do not invent a width, height or any argument the schema lacks.
2. **Open the workspace by its returned identifier.** List the open workspaces or windows and take the identifier
   the tool returns for the project; pass that identifier to every later call. Do not guess it from the path.
3. **List the run destinations and switch by the returned title.** Read the list, pick the destination by the
   title it returns (for example `iPhone Air`, the pinned phone, or `iPad Pro 11-inch (M5)`), and switch with
   that title. Do not assume a device by name from the pin.
4. **Render an existing preview.** Name the source file and the preview's index in it (for example the first
   preview in `DownloadsView+Subviews.swift`) and render it. Do not add or edit a preview to get a picture.
   Take the supported localization and variant values from the render tool's own schema.
5. **One call per locale, sequentially.** Render in one locale, keep the result, then the next locale. Never two
   renders at once: the tool shares one preview session.
6. **Keep what the tool returns:** the snapshot path (`previewSnapshotPath`), the destination it actually rendered
   on (`renderedDestination`), the preview's display name (`displayName`), the source line (`sourceLineNumber`)
   and the errors list (`errors`). Look at the picture and add one note on live content (`review`).
7. **Check the destination.** A mismatch between the destination you asked for and the one the tool returns (a
   requested iPhone Air that comes back as another phone) is a failed render. Switch again or stop; do not keep
   that picture.
8. **Validate before attaching it to anything** with `validate-preview.py` below.

## Validate

Store the render's result as `response.json` (the object the tool returned, plus `review`), and what was asked
for as `expected.json`:

```json
{
  "previewSnapshotPath": "preview.png",
  "renderedDestination": "iPhone Air",
  "displayName": "Downloading",
  "sourceLineNumber": 343,
  "errors": [],
  "locale": "ja",
  "variant": "dark",
  "review": {"liveContent": false, "note": "No date, spinner or progress ring is drawn."}
}
```

```json
{
  "schemaVersion": 1,
  "kind": "preview-expectation",
  "destination": "iPhone Air",
  "locale": "ja",
  "variant": "dark",
  "supportedLocales": ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant"],
  "supportedVariants": ["light", "dark"],
  "source": {"file": "AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift", "previewIndex": 0}
}
```

`supportedLocales` and `supportedVariants` are the values the render tool's schema lists, copied from step 1, not
the app's six languages by assumption. A relative `previewSnapshotPath` is read next to `response.json`.

```sh
python3 -B Scripts/visual/validate-preview.py --response response.json \
  --expected-environment expected.json --output DIR
```

`DIR` must not exist. The command rejects, writes nothing and exits 1 on:

- a returned destination that differs from the requested one;
- a non-empty `errors` list;
- a missing snapshot: no path, or no non-empty file at it;
- a requested locale or variant the tool does not list, or a render in another locale or variant than requested;
- a `review` that records live content.

An accepted response writes `preview-metadata.json` (requested and returned values, the snapshot's SHA-256 and
size, and `countsAsSnapshotAcceptance: false`) and a copy of the snapshot. Keep these under `.capture/`; a preview
picture is not a baseline and is never committed as one. Tests: `python3 -B -m unittest discover -s Scripts/visual
-p test_preview.py`.

## Evidence status

The procedure has been validated against the validator's tests only. The first real render (the first preview of
`DownloadsView+Subviews.swift`, sequentially in two locales) needs a running Xcode with the project open and its
agent tools enabled; it has not been taken (19-17-SUMMARY.md, "Open evidence step"). It will be recorded there
when taken, with the validator's `preview-metadata.json`.
