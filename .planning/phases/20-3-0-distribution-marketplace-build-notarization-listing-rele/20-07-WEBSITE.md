# 20-07 Website URLs (DRAFT; live check pending)

*Amended 2026-11-11 (owner msg 3501; product lead msg 3502):* the website gets no GitHub Issues link, so there is no
contact URL to check, and the support URL is no longer the home page: it is the GitHub repository page,
https://github.com/EhPanda-Team/EhPanda (its Issues tab is the contact route), which returns 200 and needs no website
change. The rows and checks below for the contact link and the home-page support URL are history. The live check
records `- privacy: <url> 200` lines for the privacy pages, `- support: https://github.com/EhPanda-Team/EhPanda 200`
and the PAL source redirect.

**Status: DRAFT.** Leto's answer (msg 2795) and the orchestrator's (msg 2797) give the four URLs; owner msg 2809
makes the home page the support URL. The live check waits for the site, which is offline on purpose (no DNS) until it
goes live with the 3.0 release (D-26, owner msg 2802). 20-07 Task 2 stays open until then. The privacy link now goes
to each language's own page, because there is no page at `/privacy` (Leto msg 2812; owner msg 2818; see below). The
agent does not edit the website; Leto owns it (D-05).

## The four URLs (Leto msgs 2795, 2812; orchestrator msg 2797; owner msgs 2809, 2818; website msg 2819)

| Purpose | URL | Where it stands |
|---------|-----|-----------------|
| Privacy policy | https://ehpanda.app/en/privacy/, and `/de/`, `/ja/`, `/ko/`, `/zh-Hans/`, `/zh-Hant/` | There is no page at `/privacy`; it returns 404 (Leto msg 2812). The owner chose to have the app link the per-language pages (owner msg 2818, addresses in website msg 2819). `contact.privacy_policy` (`Constant.xcstrings`) now gives each language its own page, with English as the fallback (`fee87bae6`, checked by `PrivacyPolicyLinkTests`). The rewrite for the three analytics levels stays for the 3.0 release (D-10). |
| Support | https://ehpanda.app | The home page; there is no separate support page (owner msg 2809) |
| Contact (published contact link) | https://github.com/EhPanda-Team/EhPanda/issues | GitHub Issues; linked from the website (D-05) |
| PAL source | https://ehpanda.app/AltStorePAL.json | Being added on the website's `develop` branch. Expected to redirect to `https://raw.githubusercontent.com/EhPanda-Team/EhPanda/main/AltStorePAL.json`, as `AltStore.json`'s does. Confirm the redirect target at the live check. |

App Store Connect takes one privacy policy URL per listing language. The proposal is the English page
(`https://ehpanda.app/en/privacy/`), with a localized listing's own page where one exists. The collaborator enters
it at 20-08 Task 3, and the owner may choose otherwise.

## Checks so far (2026-11-09T01:35Z, this Mac)

```
000 https://ehpanda.app/privacy   curl: (6) Could not resolve host: ehpanda.app   (the app now links /<language>/privacy/, owner msg 2818)
000 https://ehpanda.app/support   curl: (6) Could not resolve host: ehpanda.app   (support is now the home page, owner msg 2809)
200 https://github.com/EhPanda-Team/EhPanda/issues
    https://ehpanda.app/AltStorePAL.json   curl: (6) Could not resolve host: ehpanda.app
```

The site has no DNS on purpose, so the three `ehpanda.app` URLs cannot be checked yet. GitHub Issues returns 200.

Wording guard: no tracked file outside `.planning/` uses the Apple-approval wording (`test_no_apple_approved.py`,
`49dd2b8be`). The website pages are grepped for it at the live check.

## Still to do at the live check (Task 2, steps 2 to 4)

1. Run `curl -sSfL -o /dev/null -w "%{http_code} %{url_effective}\n"` on the six privacy pages
   (`https://ehpanda.app/<language>/privacy/` for en, de, ja, ko, zh-Hans, zh-Hant), the support URL (the home page)
   and the contact URL. Each must return 200.
2. Run `curl -sSI` on the PAL source URL and read its `Location`. It must point at `AltStorePAL.json` on `main`.
   The target may return 404 until the first PAL publish (20-08), so only the redirect is checked.
3. Fetch the six privacy pages and the home page, plus the website's contact entry, and grep them for the wording.
4. Replace this draft's table with lines like `- privacy: <url> 200`, the redirect line and the wording result.

Under D-26 the site goes live with the 3.0 GitHub and AltStore Classic release, and the PAL submission (20-08)
comes after it. So this check runs when the site goes live. That is still before the build goes to Apple, as D-05
requires.
