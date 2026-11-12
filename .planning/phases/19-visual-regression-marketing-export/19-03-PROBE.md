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

- **Authority:** owner msg 2397 (answer to card msg 2246): "Yes, run the test".
- **Branch:** `ci/runner-probe`, one empty signed commit `23ce9a0b9` (`[skip test]`) on `72c19c3d5`; test.yml was
  skipped. The remote branch was deleted after the record, under the same go-ahead.
- **Run:** 42433098473, job 128586078534, 2026-11-08 01:10:43 to 01:21:27 UTC (10 min 44 s, most of it the iOS
  platform install).
- **Runner:** `GitHub Actions 1000000629`, runner group `GitHub Actions` (GitHub-hosted), label `xcode-27`.
- **Image:** `xcode-27-arm64`, version `20261104.0337.1` (provisioner `20261103.629`).
- **Tests:** 5 executed, 0 failures (the probe plus the four offline `ProbeReportTests`). TEST SUCCEEDED.

`probe.json` (artifact `runner-probe`):

```json
{
  "date" : "2026-11-08T01:20:24Z",
  "mode" : "hosted",
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

Verdict: reachable

GitHub's hosted Mac reads all three guest pages without a Cloudflare challenge, and the app's parsers succeed. OQ-3
(daily-check fallback runner) does not need to be asked; 19-15 can choose the hosted runner on this evidence. One
run is one sample: 19-14's daily check keeps recording `cf-mitigated`, so a later block shows up there.
