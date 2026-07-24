# Phase 14 — Owner Setup: the analytics credentials

**Applies to:** the release machine only. Nothing here is needed to build, test or contribute.

Plan 14-04 built the path that carries the TelemetryDeck credentials into the app bundle. The
credentials themselves are deliberately **not** in this repository, and they never will be: the
tracked `Config/Analytics.xcconfig` declares both values empty, `AppInfo.telemetryDeckAppID`
resolves to `nil`, and analytics no-ops. A clone, a fork and CI are structurally incapable of
sending anything to the owner's dataset (D-13).

Only the owner can complete the last step, because only the owner has the app ID.

## What to do, once, on the release machine

Create `Config/Analytics.local.xcconfig` — it is gitignored, so it can never be committed:

```
TELEMETRYDECK_APP_ID = <the app ID from the TelemetryDeck dashboard>
TELEMETRYDECK_SALT = <a random 64-character string of letters and digits>
```

Generate the salt locally rather than reusing one from anywhere:

```bash
LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 64; echo
```

## The salt is write-once

Per D-17, once a build carrying the salt has shipped, the value must never change. Changing it
re-derives every anonymized identifier, so every existing install looks new to the vendor —
permanently resetting retention and DAU/MAU, and severing each install's accumulated history from
its future. There is no migration and no way to reconcile the two sides afterwards. Back the value
up somewhere outside the repository before the first release build.

## Verifying it took effect

Build the app, then read the keys back out of the **built** bundle rather than the source plist —
a source plist containing `$(TELEMETRYDECK_APP_ID)` proves nothing about substitution:

```bash
APP="<DerivedData>/Build/Products/Debug-iphonesimulator/EhPanda.app"
/usr/libexec/PlistBuddy -c "Print :TelemetryDeckAppID" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Print :TelemetryDeckSalt" "$APP/Info.plist"
```

Both print empty on a machine with no local override, and print the configured values on a machine
that has one. Both states were executed and confirmed during plan 14-04.

## What must never happen

- The app ID or the salt appearing in any commit, in any file, including planning documents.
- `Config/Analytics.local.xcconfig` being force-added past its gitignore rule.
- The salt changing after a release.

---

*Phase: 14-analytics-instrumentation*
*Owned by: plan 14-04*
