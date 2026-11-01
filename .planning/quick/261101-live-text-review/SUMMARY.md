# Live Text review evidence — 2026-11-01

**The highlight-only screenshots below were rejected by the owner and are superseded by translation review.**

Prepared both owner-selected books at page 12: Japanese 4217037 and English 4223235.
The owner authorized choosing a text-rich page for the second book. The previously configured
Japanese page 11 is an illustration without text; its recording test correctly failed with no
recognized groups. Page 12 provides corresponding dialogue in both editions.

The editions share a cover replay URL, which the fixture validator rejects in one combined selection.
Separate local review fixtures preserve the accepted Home fixture and its current pointer:

- Japanese: `/tmp/ehpanda-live-text-japanese-fixtures/versions/marketing-40c3df4808a5bea2`.
- English: `/tmp/ehpanda-live-text-english-fixtures/versions/marketing-051b990406eeb60a`.

Both real-recognition tests and both native screenshot tests passed once, with zero runtime warnings.
Each final test reports one executed test; no retries or serialization overrides were added.
Evidence: `/tmp/ehpanda-livetext-4217037-page12-record.xcresult`,
`/tmp/ehpanda-livetext-4223235-record.xcresult`, `/tmp/ehpanda-livetext-en-capture.xcresult`,
`/tmp/ehpanda-livetext-ja-capture.xcresult` and corresponding logs/attachment directories.

Screenshots and recognition JSON are saved under
`$HOME/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/live-text-review/`:
`japanese-4217037-page12.png` and `english-4223235-page12.png`.
Both are unmodified native 1260×2736 screenshots, English UI/light appearance, on iPhone Air,
iOS 27.2 build 24B8117, using the accepted Home build. Reader chrome is hidden in this scenario;
there is no visible Dynamic Island capsule or charging status. The next page is visible below in
the continuous reader, without selected-page highlights.

Recognition findings: Japanese has seven groups/14 lines; its stylized heading misreads 写真 as 高真
and adds a leading 一. English has seven groups/24 lines; the main dialogue and heading are captured,
while small “Aww” and sound effects are omitted. Highlights are visually aligned with the detected text.
These screenshots show original image text within highlights, not substituted OCR strings.

The task simulator and its clones have been removed. No app source changes, fixture-repository changes,
final generation, baseline approval or rendering-pin edits were made. Owner review is pending.

## Translation replacement implementation

The owner clarified that original lettering must be replaced by translated text, then requested the
correct screenshots. The Debug capture path now accepts optional recorded translation responses,
validates complete unique group coverage and exact normalized source text, and feeds them through
`LiveTextTranslatedPage.layOut` and the normal Canvas renderer. Capture readiness is reported only
after layout is installed. Existing recognition-only records and recording scenarios remain supported.
No live translation or model download occurs during screenshot replay.

Responses were recorded from Apple's installed local Translation models with their default strategy.
No OCR or translated strings were hand-corrected. Both source/response JSON and the Swift recorder
are retained with the local images, along with `translation-provenance.json`.

- Japanese → English fixture: `marketing-132203fe1ee96165`.
- English → Japanese fixture: `marketing-7e3dac62d0a9092e`.
- Both retain page 12 and the original recognized group IDs and image checksums.
- The Japanese heading's OCR mistake propagates into its English translation; do not characterize
  these captures as proof of perfect OCR or translation.

Validation: 20 focused Swift tests passed with zero runtime warnings in
`/tmp/ehpanda-translated-replay-tests-r2.xcresult`; 52 Python fixture tests passed; strict lint passed
for all eight changed Swift files. UITests and FeatureTests builds passed without compiler warnings
or errors. An initial test invocation used the wrong architecture filename and ran no tests; it is
not credited. The corrected invocation used the generated universal-architecture FeatureTests bundle.

The final generation runner still needs locale-specific translation recording/fixture selection;
this work completes the replay/rendering path for the requested review. No generation or pin update
is authorized by this review alone. Changes are uncommitted pending owner review.

## Corrected screenshots delivered

Both translated native captures passed 1/1 with zero runtime warnings:
`/tmp/ehpanda-translated-ja-en.xcresult` and `/tmp/ehpanda-translated-en-ja.xcresult`.
The local review directory now contains `translated-japanese-to-english.png` and
`translated-english-to-japanese.png`, unmodified native 1260×2736 frames in light mode.
The selected page's lettering is replaced; following pages below remain original under the existing
selected-page capture contract. No Dynamic Island capsule or charging indicator is visible.

Visual findings: dialogue is painted into its speech bubbles; the Japanese-to-English heading
uses a conspicuously large white fallback plate over artwork. The heading OCR error propagates
into English, and some model translations are awkward. These are review findings, not approved
marketing output. Both task simulator and test clones are removed. Await owner review.

## Owner approval — 2026-11-01

The owner approved both corrected translation screenshots and requested Home screenshot sets next.
This accepts the reviewed translation presentation; it does not approve final generation or change
the Phase 17 rendering pin. Translation implementation changes remain uncommitted.

## Owner-requested commit — 2026-11-01

The owner requested committing the outstanding work. Implementation committed as `252b3a8d5`;
this supersedes the earlier uncommitted-status notes. Signature verified and both timestamps use
the repository convention. Local review evidence remains outside Git.
