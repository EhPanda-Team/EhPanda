# Live Text screenshot review

Owner request: proceed to Live Text review after accepting and committing Home (`20940e628`).
The owner authorizes choosing a text-rich page for the second selected book, 4223235.

1. Inspect the selected pages and run the app's real recognizer in local review fixtures.
2. Capture both editions through the native screenshot test in English UI/light appearance on iPhone Air.
3. Present screenshots and recognition findings for owner review. Do not start final generation or change the rendering pin.

Review uses the available Xcode/iOS 27.2 environment and current build. Keep real content and capture
artifacts outside Git; preserve the accepted Home fixture. Delete only this task's simulators afterward.

## Corrected owner requirement

The owner rejected recognition-only highlights: the review must show translations replacing original
lettering. This authorizes completing the Debug capture replay path described in the translation
handoff. Record genuine Apple Translation responses for Japanese → English and English → Japanese,
bind them to normalized recognition text/group IDs, and reuse the production layout and renderer.
Keep recognition-only recording available. Capture readiness must wait for translated layout.
The earlier highlight images are superseded; final generation and the rendering-pin decision remain pending.
