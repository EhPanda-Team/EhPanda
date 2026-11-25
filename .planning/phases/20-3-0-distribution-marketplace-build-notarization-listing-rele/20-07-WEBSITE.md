# 20-07 Website URLs

**Status: checked live, all pass.** Checked 2026-11-25T08:34Z (UTC) from this Mac, after the website went live with
the 3.0 release (D-26). The agent does not edit the website; the webmaster owns it (D-05).

## Live check

Each line is `curl -sSfL -o /dev/null -w "%{http_code} %{url_effective}\n"`.

- privacy: https://ehpanda.app/en/privacy/ 200
- privacy: https://ehpanda.app/de/privacy/ 200
- privacy: https://ehpanda.app/ja/privacy/ 200
- privacy: https://ehpanda.app/ko/privacy/ 200
- privacy: https://ehpanda.app/zh-Hans/privacy/ 200
- privacy: https://ehpanda.app/zh-Hant/privacy/ 200
- support: https://github.com/EhPanda-Team/EhPanda 200

PAL source (`curl -sSI https://ehpanda.app/AltStorePAL.json`; only the redirect is checked, the target may 404 until the
first PAL publish):

- pal: https://ehpanda.app/AltStorePAL.json HTTP/2 302, `location: https://github.com/EhPanda-Team/EhPanda/raw/main/AltStorePAL.json` (AltStorePAL.json on `main`)

Wording: the six privacy pages were fetched and grepped, case-insensitively, for `apple[- ]approved` and
`approved by apple`. No match in any of them (0 hits per page). No tracked file outside `.planning/` carries the wording
either (`actions-tool/tests/test_no_apple_approved.py`, `49dd2b8be`, passing).

## The four URLs (the webmaster's answers; owner decision)

| Purpose | URL | Answer |
|---------|-----|--------|
| Privacy policy | `https://ehpanda.app/<language>/privacy/` for en, de, ja, ko, zh-Hans, zh-Hant | Live. There is no page at `/privacy` (404); the owner chose to have the app link each language's own page. `contact.privacy_policy` (`Constant.xcstrings`) gives each language its page, with English as the fallback (`fee87bae6`, checked by `PrivacyPolicyLinkTests`). The rewrite for the three analytics levels stays for the 3.0 release (D-10). |
| Support | https://github.com/EhPanda-Team/EhPanda | The GitHub repository page; its Issues tab is the contact route. Needs no website change. |
| PAL source | https://ehpanda.app/AltStorePAL.json | Live, redirects to `AltStorePAL.json` on `main` as above. |

There is no published contact link: the website gets no GitHub Issues link (owner decision), so no contact URL is
checked.

App Store Connect takes one privacy policy URL per listing language. The proposal is the English page
(`https://ehpanda.app/en/privacy/`), with a localized listing's own page where one exists. The collaborator enters it
at 20-08 Task 3, and the owner may choose otherwise.

## Amendment history

- Earlier draft: the support URL was the website's home page and a GitHub Issues contact link was to be published on
  the website (D-05).
- 2026-11-11 (owner decision; product lead decision): the contact link and the home-page support URL were dropped. The
  support URL is the GitHub repository page, which returns 200. The privacy link goes to each language's own page.
- 2026-11-25: the website went live with the 3.0 release (D-26); the checks above replace the earlier pending checks
  (the site had no DNS before then).
