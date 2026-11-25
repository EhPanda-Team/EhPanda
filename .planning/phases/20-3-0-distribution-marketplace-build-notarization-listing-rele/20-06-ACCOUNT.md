# 20-06 Record: the App Store Connect account and the GitHub environment

Recorded 2026-11-25 by the executing agent (as the owner's `chihchy` GitHub sign-in and the Helm CLI's read-only
commands), from what those showed and from the owner decisions in `.planning/STATE.md`. No secret value appears here
(D-07). Where who or when is not shown by a source, the line says "not recorded" and the question is open.

**Status (2026-11-25): Task 1 partly verified, Task 2 partly verified, Task 3 verified. Open items are listed under
each task and gathered at the end.** The plan's `pal-notarization` is `app-marketplace` everywhere below (owner
decision 2026-11-22), and its `KEY_ROLE` variable is gone (owner decision 2026-11-25).

## Task 1: App IDs, certificate, profiles and the API key

### Bundle IDs (the confirmation step)

| | Value | Source |
|---|---|---|
| App | `app.ehpanda.store` | owner decision 2026-11-13 (`BUNDLE_ID_SUFFIX = .store`); answers Task 1 step 1 |
| Share extension | `app.ehpanda.store.ShareExtension` | the same decision |

These replace the plan's `app.ehpanda.marketplace` and `app.ehpanda.marketplace.shareExtension`, which 20-01 and 20-03
used before the change. STATE.md dates the decision 2026-11-13, but the app record already carried
`app.ehpanda.store` with version 3.0.0 and build 158 on 2026-11-10 (below). Open: whether the owner approved the
identifier before the app record was created (T-20-19), or the decision was only written down on 2026-11-13.

### The app record (verified 2026-11-25 with `helm-asc apps 6832942312 --agent`, read only)

| | Value |
|---|---|
| Apple ID | 6832942312 (the repository variable `ALTSTORE_PAL_MARKETPLACE_ID` holds the same value, set 2026-11-22T07:25:51Z) |
| Name | EhPanda for Manga & Doujinshi |
| Bundle ID | `app.ehpanda.store` |
| SKU | `app.ehpanda.store` |
| Primary language | en-US (English) |
| Version | 3.0.0, created 2026-11-10T10:18Z; state `NOT_APPLICABLE` (a Notarization version; its active build is 163) |
| Builds | 163 (uploaded 2026-11-13T09:12Z, state `READY_FOR_BETA_SUBMISSION`, expires 2027-02-11) and 158 (uploaded 2026-11-10T10:23Z, expired) |

Who created the app record, the App IDs, the version and uploaded the builds: not recorded (Helm shows no actor).
The plan asked for the name "EhPanda"; the record's name is "EhPanda for Manga & Doujinshi". Open: whether that is
intended.

### Distribution certificate

An Apple Distribution certificate, expiry 2027-11-10 (STATE.md, 2026-11-22: set on the owner's instruction from
the owner's files). The `.p12` is the secret `DISTRIBUTION_CERTIFICATE` and its password
`DISTRIBUTION_CERTIFICATE_PASSWORD` (set 2026-11-22T07:27:37Z and 07:30:28Z). Who created the certificate: not
recorded.

### Provisioning profiles

Both secrets exist in the environment: `PROVISIONING_PROFILE_APP` (updated 2026-11-25T08:03:31Z) and
`PROVISIONING_PROFILE_SHARE_EXTENSION` (updated 2026-11-25T08:03:45Z). The owner said on 2026-11-25 that the
collaborator delivered the profiles.

History (STATE.md, 2026-11-22): the first profile supplied for `app.ehpanda.store`, named "EhPanda", was Ad Hoc
and could not sign an App Store Connect upload, so it was held; the extension's earlier profile was named "EhPanda
Shared Extension". Neither of those is the current secret.

Open: the two current profiles' names, and the confirmation that both are App Store profiles (not Ad Hoc) for
`app.ehpanda.store` and `app.ehpanda.store.ShareExtension`. The secret values were never read.

### The App Store Connect API key (CI)

The three secrets exist: `APP_STORE_CONNECT_KEY_ID` (2026-11-25T08:00:28Z), `APP_STORE_CONNECT_ISSUER_ID`
(2026-11-25T08:00:46Z) and `APP_STORE_CONNECT_PRIVATE_KEY` (2026-11-25T08:01:25Z). Their values were never read.

Open: the key's ID, its type (team or individual) and its role, and who created it and when. Helm signs in with its
own key, which is not necessarily this one, so nothing from Helm is recorded as the CI key. The plan's `role:` line
is therefore not yet in this file.

## Task 2: Agreements, marketplace, trader status, age rating, App Privacy answers and countries

What shows that the account steps happened, and what does not: Apple accepted build 163 for Notarization (owner's
report, 20-08-SUBMISSION.md), and AltStore processed the ADP `453ead28-2d2b-49d1-a398-5a06ca29186b` (created
2026-11-20T15:53:04Z). Both need the DPLA, the AltStore registration and the marketplace integration to exist.
Neither names who did them or when, so each item below says "not recorded" where that is so.

| Item | State (2026-11-25) | Who and when |
|---|---|---|
| DPLA acceptance (Account Holder) | implied by the accepted Notarization submission | not recorded |
| AltStore Developer ID registration (`POST https://api.altstore.io/register`) | implied by AltStore processing the ADP | not recorded |
| AltStore PAL under Users and Access, Integrations, Marketplace, with the app selected and notifications on | implied by the same | not recorded |
| Trader status | not readable through Helm | not recorded |
| Age rating | answered; see below | not recorded |
| App Privacy answers | not readable through Helm; see below | not recorded |
| Countries (EU, Japan, Brazil) | not readable through Helm | not recorded |
| `developerName` | "EhPanda Team", as D-24 decided; no question asked, template unchanged | verified in `actions-tool/altstore-pal.template.json` and `AltStorePAL.json` line 35 |

### Age rating (verified 2026-11-25 with `helm-asc apps 6832942312 age-rating --agent`, read only)

The declaration is answered, with no unanswered question; calculated rating 18+, rating 18+, app info state
`READY_FOR_DISTRIBUTION`, not editable. Answers: Parental Controls no; Age Assurance yes; Unrestricted Web Access no;
User-Generated Content yes; Messaging and Chat yes; Social Media yes (age restricted no); Advertising no; Profanity or
Crude Humor frequent; Horror or Fear Themes infrequent; Alcohol, Tobacco or Drug Use infrequent; Medical or Treatment
Information none; Health or Wellness Topics no; Mature or Suggestive Themes, Sexual Content or Nudity and Graphic
Sexual Content and Nudity frequent; Cartoon or Fantasy Violence frequent; Realistic Violence infrequent; Prolonged
Graphic or Sadistic Realistic Violence infrequent; Guns or Other Weapons none; Simulated Gambling, Contests, Gambling
and Loot Boxes none or no.

### App Privacy answers

Helm's CLI has no command that reads the App Privacy answers, so what App Store Connect holds is unknown. What it
needs, from `App/PrivacyInfo.xcprivacy` (the source the plan names, as changed by commit `4c661deef`, crash reporting,
2026-11-23):

| App Store Connect type | Manifest type | Purpose | Linked to the user | Tracking |
|---|---|---|---|---|
| Usage Data: Product Interaction | `ProductInteraction` | Analytics | no | no |
| Identifiers: Device ID | `DeviceID` | Analytics | no | no |
| Diagnostics: Other Diagnostic Data | `OtherDiagnosticData` | Analytics | no | no |
| Diagnostics: Crash Data | `CrashData` | App Functionality | no | no |

`NSPrivacyTracking` is false and `NSPrivacyTrackingDomains` is empty. The plan's must-have names only the first three
types, all with the Analytics purpose (D-18). The fourth, Crash Data with App Functionality, was added after the plan
was written. The README's Analytics section describes TelemetryDeck only and does not mention crash reports; the
manifest test's header explains that crash reports are declared separately because they are not analytics data.
Open: the answers the account holds today, and the owner's decision whether to enter four types (to match the
manifest) or three (to match the plan text).
