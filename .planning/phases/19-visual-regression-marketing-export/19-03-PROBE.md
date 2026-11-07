# 19-03 Runner-IP probe

The probe asks whether GitHub's hosted Mac can read the site as a guest (19-CONTEXT D-25). It sends three guest
GETs, 5 s apart: the front page, Popular, then the first Popular gallery. Each GET uses its own session, with no
cookies and no cache. Per page, it records only:

- the HTTP status
- whether a `cf-mitigated` header was present
- whether the app's parser succeeded

It writes nothing else.

## Local run (development machine, residential address)

- **Date:** 2026-11-07, 13:52 UTC.
- **Simulator:** `$PHONE` (EhPanda iPhone Air, iOS 27.0), with Xcode 27.2.
- **Test plan:** `LiveCheck`, run with `TEST_RUNNER_EHPANDA_LIVE_CHECK=1` and
  `TEST_RUNNER_EHPANDA_LIVE_CHECK_OUTPUT=$TMPDIR/ehp19-probe`.
- **Tests:** 5 executed, 0 failures. That is the probe plus the four offline `ProbeReportTests`.
- **Log check:** the run's console log has no site URL and no gallery path.

`probe.json`:

```json
{
  "date" : "2026-11-07T13:52:01Z",
  "mode" : "local",
  "pages" : [
    { "cfMitigated" : false, "page" : "frontPage", "parsed" : true, "status" : 200 },
    { "cfMitigated" : false, "page" : "popular", "parsed" : true, "status" : 200 },
    { "cfMitigated" : false, "page" : "gallery", "parsed" : true, "status" : 200 }
  ],
  "schema" : 1
}
```

| Page | Status | `cf-mitigated` | Parsed |
|------|--------|----------------|--------|
| frontPage | 200 | no | yes |
| popular | 200 | no | yes |
| gallery | 200 | no | yes |

From a residential address, all three pages are reached and parse with the app's parsers. This matches the
2026-11-07 desk check (D-26).

## Hosted run (GitHub `xcode-27` runner)

Not run yet. The run needs the owner's go-ahead to push `ci/runner-probe` (OQ-6, owner card msg 2246, unanswered
when this file was written).

Fill in after the run:

- the owner message that allowed the push
- the run ID, runner name, image version and runner group (printed in the job summary)
- per page: status, `cf-mitigated` and parsed
- the verdict line: `Verdict: reachable`, `blocked` or `mixed`. A `blocked` or `mixed` verdict is marked "OQ-3 to
  ask at 19-15".
