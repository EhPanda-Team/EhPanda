---
phase: 261126-dkv-use-an-individual-app-store-connect-api-
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - actions-tool/asc.py
  - actions-tool/tests/test_asc.py
  - actions-tool/ExportOptions-marketplace.plist
  - actions-tool/marketplace-signing.sh
  - .github/workflows/marketplace-upload.yml
  - actions-tool/tests/test_workflows.py
  - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-06-ACCOUNT.md
autonomous: true
requirements: [DIST-18-03]
user_setup:
  - service: github-environment-app-marketplace
    why: "The next marketplace-upload.yml run signs its App Store Connect tokens with the owner's individual API key"
    env_vars:
      - name: APP_STORE_CONNECT_KEY_ID
        source: "The owner's individual App Store Connect API key; the owner adds it to the app-marketplace environment after this change"
      - name: APP_STORE_CONNECT_PRIVATE_KEY
        source: "The same key's .p8 file, as text; the owner adds it to the app-marketplace environment after this change"

estimate:
  tokens: 140000
  raw_tokens: 140000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "asc.py signs every token for an individual key: header {alg ES256, kid <key id>, typ JWT}, claims exactly {sub: user, iat, exp = iat + 1200, aud: appstoreconnect-v1}; its environment is only APP_STORE_CONNECT_KEY_ID and ASC_KEY_PATH, and no issuer remains in asc.py, its tests, the workflow, its tests, the signing script or the export options (owner decision 1)."
    - "The job exports the .ipa with xcodebuild -exportArchive and destination export, with no authentication flags and no step env, tears down signing right after, and then uploads it with `asc.py upload`, whose only secret is APP_STORE_CONNECT_KEY_ID (owner decision 2)."
    - "asc.py upload creates the build upload (version, build, IOS, the app), the .ipa's file (ASSET, its name and size, com.apple.ipa), PUTs each upload operation's byte range to that operation's URL, PATCHes the file uploaded with its file and composite MD5 checksums, then polls the build upload until COMPLETE (prints its ID) or FAILED (exit 1 with every error and warning Apple lists) (owner decision 2)."
    - "A part goes only over https (http only on loopback while the API itself is the local fake), carries only the headers its operation lists plus Host and Content-Length, never the API token, and is logged and recorded without the URL's query (D-21)."
    - "A malformed operation list, or a part the storage refuses, stops the run before the file is marked uploaded; a part answered 429, 5xx or with a lost connection is sent again, at most three times (owner decision 2)."
    - "Everything from quick 261126-0b9 stays: the release path submits, wait-build, ensure-version, whats-new, attach-build and submit, the exact allow-list (now 15 entries), the call record, Tear down signing then Remove the API key (owner decision 3; D-07, D-21)."
    - "20-06-ACCOUNT.md carries dated 2026-11-26 owner-decision amendments for the individual key and the environment's secrets."
  artifacts:
    - path: "actions-tool/asc.py"
      provides: "The App Store Connect client with the individual-key token and the Build Upload API upload"
      contains: "\"upload\": upload"
    - path: ".github/workflows/marketplace-upload.yml"
      provides: "Export, signing teardown, then the Build Upload API upload, then the submission"
      contains: "name: Upload to App Store Connect"
    - path: "actions-tool/ExportOptions-marketplace.plist"
      provides: "Export options that only sign and write the .ipa"
      contains: "<string>export</string>"
    - path: "actions-tool/tests/test_asc.py"
      provides: "Fake App Store Connect plus a fake storage server for the upload's parts"
      contains: "class FakeStorage"
    - path: "actions-tool/tests/test_workflows.py"
      provides: "Shape tests of the export and upload steps and the export options"
      contains: "def test_the_export_only_signs_and_writes_the_ipa"
    - path: ".planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-06-ACCOUNT.md"
      provides: "The dated record of the individual key and the environment's secrets"
      contains: "*Amended 2026-11-26 (owner decisions):* the"
  key_links:
    - from: ".github/workflows/marketplace-upload.yml"
      to: "actions-tool/asc.py"
      via: "the Upload to App Store Connect step runs `asc.py upload` on the exported .ipa"
      pattern: "\"$ASC_TOOL_PATH\" upload --app"
    - from: ".github/workflows/marketplace-upload.yml"
      to: "actions-tool/ExportOptions-marketplace.plist"
      via: "marketplace-signing.sh setup copies the template to MARKETPLACE_EXPORT_OPTIONS, which Export .ipa file passes to xcodebuild"
      pattern: "-exportOptionsPlist \"$MARKETPLACE_EXPORT_OPTIONS\""
    - from: ".github/workflows/marketplace-upload.yml"
      to: "actions-tool/marketplace-signing.sh"
      via: "Tear down signing runs teardown-signing right after Export .ipa file; Remove the API key runs teardown last"
      pattern: "teardown-signing"
    - from: "actions-tool/tests/test_asc.py"
      to: "actions-tool/asc.py"
      via: "FakeStorage receives the PUTs that Client.send_part sends, and the record's UPLOAD PUT lines are checked against them"
      pattern: "UPLOAD PUT"
---

<objective>
Switch the AltStore PAL CI to the owner's individual App Store Connect API key and upload the build through the
App Store Connect Build Upload API in `actions-tool/asc.py`, exactly as the owner decided on 2026-11-26 (locked; cited
below as "owner decision N"):

1. Individual key only; no team-key path remains. The issuer secret and every use of an issuer disappear (workflow
   env, asc.py, tests, docs). The token has no `iss` and carries `"sub": "user"` (Apple, "Generating tokens for API
   requests"); the header stays `alg ES256, kid <key id>, typ JWT`; the claims are `sub, iat, exp, aud:
   appstoreconnect-v1`. The key has the role and app access of the owner's own user.
2. The upload goes through the Build Upload API in a new `asc.py upload` command, not altool and not xcodebuild's
   upload (both need an issuer for an API key). The job exports the `.ipa` with `xcodebuild -exportArchive` and export
   options `destination: export` (no authentication flags at all), then `asc.py upload` uploads it.
3. Everything from quick task 261126-0b9 stays: submit only on the release path, wait-build, ensure-version, whats-new,
   attach-build, submit, the allow-list, the call record (D-21), teardown-signing then teardown.

Purpose: the owner's individual key replaces the removed team key, and the run no longer depends on a tool that
needs an issuer.

Output: three tasks, three signed commits.
1. `ci: upload the PAL build with an individual key` (Task 1, the tracer: the token, the upload command end to end
   against a fake App Store Connect and a fake storage server, the export options, the workflow and its shape tests).
2. `ci: check the PAL upload plan and resend parts` (Task 2, the expansion: the full check of App Store Connect's
   upload operations before any byte is sent, and the resend of a part after a transient failure).
3. `docs(quick-261126-dkv): record the individual key` (Task 3).

Why Task 1 spans six files: each layer's source and its test change in the same commit so every commit leaves the
tests green. The workflow calls the new command and drops the key flags in the same commit as `asc.py` (the old
xcodebuild upload cannot run without the removed secret), the export options must say `export` in that commit, the
signing script's usage text describes the new step order, and `test_workflows.py` holds the workflow's shape.

Out of scope, untouched: `.github/workflows/deploy.yml` (its header and caller stay accurate), `publish-pal.yml`,
`actions-tool/pal_publish.py`, `Scripts/visual/README.md` (it names no issuer; "its AltStore PAL upload" stays true),
`20-08-SUBMISSION.md` (it names no issuer; its First CI upload records a past xcodebuild run, which stays true),
`.planning/REQUIREMENTS.md` (DIST-18-03's wording and Complete state do not depend on the key type or the upload
tool), `.planning/STATE.md` and `.planning/ROADMAP.md` (the quick workflow updates STATE.md), and
`marketplace-signing.sh api-key` (its `^[A-Z0-9]+$` check and `AuthKey_<id>.p8` name fit the 12-character individual
key ID; asc.py signs with openssl, so nothing reads the file name).

Execution rule: follow this plan exactly. If any step cannot be done as written (ambiguity, a contradiction with the
source, a test outcome the plan does not foresee, missing information, unexpected repository state, a needed
deviation), stop and ask the orchestrator. Do not choose or invent a workaround. Do not dispatch any workflow, do not
push, and do not call App Store Connect, Apple's storage hosts, AltStore or the GitHub API: every check is offline
(a local fake App Store Connect, a local fake storage server, workflow shape tests, actionlint). The first live upload
is the owner's next run, after the owner adds the two secrets (user_setup).

Open risks (recorded, not solved here; the first live run shows each one with Apple's own answer):
- Apple's reference does not say whether the asset description and SPI files that Xcode's upload also sent are
  required. Only the `.ipa` is sent (`ASSET`, `com.apple.ipa`). If Apple requires them, the run fails at the upload's
  poll with FAILED and Apple's errors in the log. Do not generate those files.
- The composite checksum's inner form is inferred, not documented: the MD5 of the concatenated raw 16-byte MD5 digests
  of the parts (the S3 multipart convention), then `-<part count>-<part size>`, all hex in lowercase. Orchestrator
  pre-check before dispatch (optional, read-only): for the single-part file of the 3.1.0 (164) upload
  ("...-1-3339239"), the composite's first field should equal the MD5 of the raw digest that its `file` hash spells
  (`hashlib.md5(bytes.fromhex(file_hash)).hexdigest()`), and both hashes should be lowercase. If either is not so,
  revise Task 1's checksum rule before execution.
- An upload operation's method is taken to be PUT (WWDC25 session 324); any other method is refused before any byte
  is sent (Task 2), so a different design fails visibly.
- What COMPLETE means is not documented: it may come before or after the build's processing. The upload's poll
  (`--timeout 3600`) and wait-build (`--timeout 5400`) fit the 240-minute job either way.
- Whether a build upload that fails or is left unfinished uses up its build number is unknown.
- `uploadSymbols` stays true in the export options, so the `.ipa` carries its symbols; whether the Build Upload API
  processes them as Xcode's upload did is unknown. The app's dSYMs still go to Sentry in Upload dSYMs.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@AGENTS.md
@.github/workflows/marketplace-upload.yml
@actions-tool/asc.py
@actions-tool/marketplace-signing.sh
@actions-tool/ExportOptions-marketplace.plist
@.planning/quick/261126-0b9-automate-the-altstore-pal-notarization-s/261126-0b9-PLAN.md

- Locked phase decisions cited here (`.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md`):
  D-07 (Apple-account actions only with the owner's OK at the time; the `app-marketplace` environment's required
  reviewer gives it per run), D-21 (the call record `asc-calls.jsonl`, uploaded as the `asc-call-record-*` artifact),
  D-26 (the PAL build carries the release's version and build number).
- Facts the orchestrator observed read-only with the owner's individual key (2026-11-26), not to be re-checked:
  a `sub: "user"` token signed by asc.py's `openssl` path got 200 on the app, its builds, its versions, its
  `buildUploads` and one build upload with its files. Xcode's own upload of 3.1.0 (164) was a build upload (state
  `{state: COMPLETE, errors: [], warnings: [], infos: []}`, platform `IOS`, its `build` relationship ID equal to its
  own ID) with three files; the `.ipa` was `fileName` `EhPanda.ipa`, `assetType` `ASSET`, `uti` `com.apple.ipa`. Each
  file had `sourceFileChecksums: {file: {algorithm: MD5, hash}, composite: {algorithm: MD5, hash:
  "<md5 of the part md5s>-<part count>-<part size>"}}`, the part size 5242880 for the 31,456,182-byte `.ipa`
  ("...-6-5242880") and the whole size for a one-part file ("...-1-3339239"); `uploadOperations` was null once done.
- Apple's reference (read by the orchestrator 2026-11-26): `POST /v1/buildUploads` with `{data: {type: "buildUploads",
  attributes: {cfBundleShortVersionString, cfBundleVersion, platform}, relationships: {app: {data: {type: "apps",
  id}}}}}` (201); `POST /v1/buildUploadFiles` with `{data: {type: "buildUploadFiles", attributes: {assetType, fileName,
  fileSize, uti}, relationships: {buildUpload: {data: {type: "buildUploads", id}}}}}` (201), whose `uploadOperations`
  are `{method, url, offset, length, partNumber, requestHeaders: [{name, value}], entityTag, expiration}`, each done
  with its method and its listed headers, one call per operation; `PATCH /v1/buildUploadFiles/{id}` with
  `{data: {type: "buildUploadFiles", id, attributes: {uploaded: true, sourceFileChecksums}}}` (200);
  `GET /v1/buildUploads/{id}` gives `attributes.state.state` in `AWAITING_UPLOAD | PROCESSING | FAILED | COMPLETE` with
  `errors`, `warnings` and `infos` arrays of `{code, description}`.
- Facts checked while planning (2026-11-26, HEAD `0d80493c8` on develop):
  - `python3 -m unittest discover -s actions-tool/tests` runs 350 tests, all OK; `test_asc.py` has 39 and
    `test_workflows.py` 100. The Lint loop (every `test_*.py` directory under Scripts and actions-tool) is green in
    about three minutes. `actionlint` 1.7.12 exits 0 on marketplace-upload.yml and deploy.yml.
  - `/usr/bin/python3` here is Xcode 27.2's Python 3.9.6 with LibreSSL 2.8.3 and passes `test_asc.py` and
    `test_workflows.py`. The runner's `python3` may be that same Python, so asc.py and its tests must stay valid
    Python 3.9: no `match`, no `X | Y` annotations evaluated at run time; `dataclasses`, `hashlib.md5(...,
    usedforsecurity=False)` and `str.removeprefix` are fine.
  - `http.client`'s `putrequest(method, target, skip_host=True, skip_accept_encoding=True)`, then `putheader` per
    header and `endheaders(message_body=data)`, sends exactly the headers given, in order (probed on 3.9 and 3.10
    against a local `http.server`).
  - A local HTTPS fake with a self-signed certificate is not portable: Xcode's LibreSSL Python ignores
    `SSL_CERT_FILE` and failed the handshake with an EC certificate. So the fake storage server is plain http on
    127.0.0.1, which the client allows only while its own API base URL is a loopback http fake, exactly as it already
    allows that base URL. Production never sets ASC_BASE_URL, so every part URL must be https there.
  - Case-insensitive "issuer" lines: asc.py 8, marketplace-upload.yml 9, test_asc.py 5, test_workflows.py 3,
    marketplace-signing.sh 0, ExportOptions-marketplace.plist 0. Lines over 120 columns: asc.py 2 and test_asc.py 1,
    all three issuer lines. The export options' `destination` is `upload`. `asc.COMMANDS` has 6 entries and
    `asc.ALLOWED` 11.
  - The job's secrets today: APPLE_TEAM_ID, the three APP_STORE_CONNECT_* (key ID, issuer, private key),
    DISTRIBUTION_CERTIFICATE(_PASSWORD), PROVISIONING_PROFILE_APP, PROVISIONING_PROFILE_SHARE_EXTENSION, and the
    repository's SENTRY_AUTH_TOKEN, SENTRY_DSN, TELEMETRYDECK_APP_ID, TELEMETRYDECK_SALT.
- Writing rules: comments and docstrings in plain, short sentences like the surrounding ones, wrapped at 120 columns
  like the rest of each file; no em dashes in any file outside `.planning/`; no absolute home path in any file. No
  file, comment or docstring outside `.planning/` may mention an issuer (owner decision 1).
- Commits (one per task): the configured git identity and its signing key, made with `TZ=Asia/Shanghai git commit`
  (never bypass signing or hooks), subject of 50 characters or fewer, no attribution or Co-Authored-By lines. Verify
  each with `git log -1 --format='%G? %aI %cI'`: `G`, and both dates end in `+08:00`. Stage files by explicit path
  only; never stage anything this plan does not list.
</context>

<tasks>

<!-- planner-discipline-allow: issuer -->
<!-- planner-discipline-allow: ISSUER -->
<!-- planner-discipline-allow: -authentication -->

<task type="tracer">
  <name>Task 1: Upload the PAL build through the Build Upload API with the individual key, end to end (owner decisions 1-3; D-07, D-21, D-26)</name>
  <files>actions-tool/asc.py, actions-tool/tests/test_asc.py, actions-tool/ExportOptions-marketplace.plist, actions-tool/marketplace-signing.sh, .github/workflows/marketplace-upload.yml, actions-tool/tests/test_workflows.py</files>
  <read_first>
    - actions-tool/asc.py (whole)
    - actions-tool/tests/test_asc.py (whole)
    - actions-tool/ExportOptions-marketplace.plist (whole)
    - actions-tool/marketplace-signing.sh lines 1-30 and 244-251
    - .github/workflows/marketplace-upload.yml (whole)
    - actions-tool/tests/test_workflows.py lines 1-90 (helpers) and 436-760 (`PAL_*` constants and `PalUploadJobTests`), and 1000-1010 (`CrashReportingWorkflowTests.RELEASES`)
  </read_first>
  <behavior>
    - The token's claims are exactly {"sub": "user", "iat": t, "exp": t + 1200, "aud": "appstoreconnect-v1"} and it still verifies with openssl; every request the fake App Store Connect receives carries such a token.
    - upload of a 2,563-byte file whose operations are three parts of 1,024, 1,024 and 515 bytes: POST /v1/buildUploads and POST /v1/buildUploadFiles with the bodies below, three PUTs whose bodies are the three byte ranges and whose headers are exactly the operation's two plus Host and Content-Length, then PATCH /v1/buildUploadFiles/f-1 with uploaded true, the file MD5 and the composite "<md5 of the raw part digests>-3-1024", then GET /v1/buildUploads/u-1 until COMPLETE; exit 0 and "u-1" on stdout.
    - One part of 1,100 bytes gives the composite "<md5 of its raw digest>-1-1100".
    - FAILED exits 1 with every error's and warning's code and description in stderr; PROCESSING past the timeout exits 1 with "timed out" and "PROCESSING".
    - An http operation URL off loopback exits 1 with "https" in stderr and sends no byte and no PATCH; a part answered 403 exits 1 with "403", sends no later part and no PATCH; a missing .ipa exits 1 before any request. No message, log line or record line ever holds the URL's query.
    - The whole sequence check-build, upload, wait-build, ensure-version, whats-new, attach-build, submit records statuses [200, 201, 201, 200, 200, 200, 200, 200, 200, 201, 200, 200, 204, 200, 201, 201, 200]; App Store Connect lines have exactly method, path, status and keyID, part lines exactly method, url, status and part; no PUT carries an Authorization header.
    - The workflow runs Export .ipa file (no env, no key flags), Tear down signing, then Upload to App Store Connect with only APP_STORE_CONNECT_KEY_ID as a secret; the job's secrets are exactly the seven environment and four repository secrets; the export options' destination is export.
  </behavior>
  <action>
Work in this order: (a) asc.py, (b) its tests, (c) the export options, (d) the signing script, (e) the workflow,
(f) test_workflows.py. Then run the verify and commit.

(a) actions-tool/asc.py (owner decisions 1, 2; D-07, D-21)
1. Docstring.
   - Second paragraph: replace "Before the archive it checks that the build number is still unused. After the upload,
     when the run submits" with "Before the archive it checks that the build number is still unused. After the export
     it uploads the `.ipa` through the Build Upload API and waits until App Store Connect has taken it (owner
     decisions, 2026-11-26). When the run submits"; the rest of the paragraph stays. Rewrap at 120 columns.
   - Usage: after the check-build entry add the entry
     `  asc.py upload --app <id> --version <x.y.z> --build <n> --ipa <file> [--timeout <s>] [--interval <s>]`
     with the description lines "uploads the .ipa as build <n> of version <x.y.z> through the Build Upload API, each
     part to the storage URL App Store Connect gives for it, then waits until the upload is COMPLETE and prints its ID;
     fails on FAILED, listing every error and warning Apple gives, or on timeout", indented and wrapped like the other
     entries' descriptions.
   - Environment: replace the line naming the key ID together with the removed secret by
     `  APP_STORE_CONNECT_KEY_ID    the ID of an individual API key (owner decision, 2026-11-26)`, its description
     starting in the same column as the `ASC_KEY_PATH` line's.
   - Call-record paragraph: after its first sentence (the one ending "which key made each call (D-21).") insert "Each
     part of an upload goes to the storage URL App Store Connect gave for it, with only the headers it listed and
     never the API token; it is logged as `UPLOAD PUT <url> <status> part=<n>` and recorded as {"method", "url",
     "status", "part"}, the URL without its query, which holds the URL's signature." Rewrap.
   - Last paragraph: append "An upload's parts go only to the URLs App Store Connect returned for that upload in the
     same run, and only over https." Rewrap.
2. Imports: add `dataclasses`, `hashlib`, `http.client` and `ssl` to the standard-library block, keeping it
   alphabetical.
3. After TOKEN_REFRESH add: the comment "# The only hosts a local fake may use: an http API base URL, and then http
   upload URLs, are allowed only on these (the tests)." and `LOCAL_HOSTS = ("127.0.0.1", "localhost", "::1")`; the
   comment "# How long one part of an upload may take." and `PART_TIMEOUT = 300`.
4. `ALLOWED`: after ("GET", r"^/v1/builds$") insert, in this order, ("POST", r"^/v1/buildUploads$"),
   ("POST", r"^/v1/buildUploadFiles$"), ("PATCH", r"^/v1/buildUploadFiles/[A-Za-z0-9-]+$") and
   ("GET", r"^/v1/buildUploads/[A-Za-z0-9-]+$"). Nothing else in the list changes: 15 entries.
5. After WHATS_NEW_LIMIT add the comment "# What the Build Upload API is told about the .ipa, as Xcode's own upload of
   3.1.0 (164) told it." and `IPA_ASSET_TYPE = "ASSET"`, `IPA_UTI = "com.apple.ipa"`.
6. Token (owner decision 1): `make_token(key_id, key_path, now=None)`; docstring "An ES256 token for an individual
   App Store Connect API key, signed by `openssl` with the `.p8` key. An individual key's token has no `iss` and
   carries `"sub": "user"` (Apple, "Generating tokens for API requests"; owner decision, 2026-11-26)."; the header
   stays; the claims are, in this order, {"sub": "user", "iat": now, "exp": now + TOKEN_LIFETIME, "aud":
   "appstoreconnect-v1"}. `TokenSource.__init__(self, key_id, key_path)` keeps only those two, and `__call__` calls
   `make_token(self.key_id, self.key_path)`.
7. `Client.__init__`: the local check uses `LOCAL_HOSTS`; keep the result as `self.local`. Add the method
   `note_part(self, part, status)`: logs f"UPLOAD PUT {part.public} {status} part={part.number}" and, with a record,
   appends the JSON line {"method": "PUT", "url": part.public, "status": status, "part": part.number}. `note` and
   `request` stay as they are.
8. After `describe_errors`, under a new "# Upload" heading comment like "# Token" and "# HTTP":
   - `@dataclasses.dataclass(frozen=True) class Part` with fields `number: int`, `offset: int`, `length: int`,
     `url: str`, `public: str`, `headers: tuple`, and the docstring "One upload operation, checked: the byte range it
     takes, where it goes and the headers App Store Connect listed for it. `public` is the URL without its query, for
     the log, the record and errors."
   - `check_part_url(url, local)`, docstring "The URL of an upload operation without its query (the query holds the
     signature), or AscError. It must use https; http is allowed only on a loopback host, and only while the API
     itself is a local fake (`local`)." It raises AscError, each message ending "Nothing was uploaded." and none
     holding the URL: when `url` is not a str ("An upload operation has no URL."); when `urllib.parse.urlsplit(url)`
     has a username or password ("An upload operation's URL carries a user name or password."); when it has no
     hostname ("An upload operation's URL has no host."); when reading its `port` raises ValueError ("An upload
     operation's URL has a bad port."); when the scheme is neither "https" nor, with `local` and the hostname in
     LOCAL_HOSTS, "http" (f"An upload operation's URL must use https, not {scheme or 'no scheme'} on {hostname}.").
     It returns f"{scheme}://{netloc}{path}".
   - `upload_parts(operations, size, local)`, docstring "The upload operations App Store Connect gave for a file of
     `size` bytes, checked before any byte is sent, in file order." When `operations` is not a non-empty list, raise
     AscError("App Store Connect gave no upload operations for the file. Nothing was uploaded."). Check every URL with
     `check_part_url(op.get("url"), local)` before returning anything; sort the operations by `offset`; return one
     `Part` per operation with `number` its 1-based place in file order, `offset` and `length` as given, `url` as
     given, `public` from check_part_url and `headers` the tuple of (name, value) of its `requestHeaders` (none when
     that is null). Task 2 adds the remaining checks; `size` is used there.
   - `Client.send_part(self, part, data)` (a Client method, so every part goes through the Client and its record),
     docstring "PUTs one part to the storage URL App Store Connect gave for it: only the headers it listed, plus Host
     and Content-Length when it did not list them, and never the API token. No redirect is followed, and the reply's
     body is never shown: a storage error can echo the signature." It splits `part.url`; uses
     `http.client.HTTPSConnection(hostname, port, timeout=PART_TIMEOUT, context=ssl.create_default_context())` for
     https and `http.client.HTTPConnection(hostname, port, timeout=PART_TIMEOUT)` for http; the request target is the
     path (or "/") plus "?" and the query when there is one; `putrequest("PUT", target, skip_host=True,
     skip_accept_encoding=True)`; `putheader("Host", netloc)` unless the part lists a Host header (names compared
     without case); each of the part's headers in order; `putheader("Content-Length", str(len(data)))` unless the part
     lists one; `endheaders(message_body=data)`; reads and discards the response, keeps its status, and always closes
     the connection. It never reads `self.token`. On OSError or `http.client.HTTPException`: `note_part(part, 0)`,
     then AscError(f"PUT {part.public} failed: {type(error).__name__}; the file was not marked uploaded.") from None.
     Otherwise `note_part(part, status)`, and a status outside 200-299 raises AscError(f"PUT {part.public} returned
     {status}; the file was not marked uploaded."). (Task 2 adds the resend.)
   - `describe_upload_issues(details)`: for "errors" then "warnings" of the build upload's `state` object, the
     entries as f"{code}: {description}" joined by "; ", each kind prefixed "errors: " or "warnings: ", the kinds
     joined by " "; "Apple gave no errors or warnings." when both are empty or missing.
9. Command `upload(client, args, sleep=time.sleep)`, placed after `check_build`, docstring "Owner decision 2
   (2026-11-26): the build goes up through the Build Upload API, not xcodebuild or altool. Only the .ipa is sent
   (ASSET, com.apple.ipa), part by part as App Store Connect's upload operations say, with the MD5 checksums of the
   file and of its parts; then the build upload is polled until App Store Connect reports it COMPLETE or FAILED." It:
   - before any request, raises AscError(f"{args.ipa} is not a file with content.") unless `os.path.isfile` and the
     size from `os.path.getsize` is above 0;
   - POSTs /v1/buildUploads with body {"data": {"type": "buildUploads", "attributes": {"cfBundleShortVersionString":
     args.version, "cfBundleVersion": args.build, "platform": "IOS"}, "relationships": {"app": {"data": {"type":
     "apps", "id": args.app}}}}} and takes `upload_id` from `data.id`; prints f"Created build upload {upload_id} for
     {args.version} ({args.build})." to stderr;
   - POSTs /v1/buildUploadFiles with body {"data": {"type": "buildUploadFiles", "attributes": {"assetType":
     IPA_ASSET_TYPE, "fileName": os.path.basename(args.ipa), "fileSize": size, "uti": IPA_UTI}, "relationships":
     {"buildUpload": {"data": {"type": "buildUploads", "id": upload_id}}}}} and takes `file_id` from `data.id`;
   - `parts = upload_parts(data.attributes.uploadOperations, size, client.local)`;
   - opens the file once and, for each part in order: `seek(part.offset)`, reads `part.length` bytes (fewer raises
     AscError(f"{args.ipa} changed while it was uploaded; the file was not marked uploaded.")), feeds them to the
     file's MD5 (`hashlib.md5(usedforsecurity=False)`), keeps the part's raw digest
     (`hashlib.md5(data, usedforsecurity=False).digest()`) and calls `client.send_part(part, data)`. Only one part is
     in memory at a time;
   - PATCHes /v1/buildUploadFiles/{file_id} with body {"data": {"type": "buildUploadFiles", "id": file_id,
     "attributes": {"uploaded": True, "sourceFileChecksums": {"file": {"algorithm": "MD5", "hash": <the file MD5's
     hexdigest>}, "composite": {"algorithm": "MD5", "hash": f"{<MD5 hexdigest of the parts' raw digests joined in
     file order>}-{len(parts)}-{parts[0].length}"}}}}}, with the comment "# As Xcode's own upload reported them: the
     composite is the MD5 of the parts' raw MD5 digests, the part count and the part size (the whole size for one
     part).";
   - polls GET /v1/buildUploads/{upload_id} like `wait_build` polls (deadline from `args.timeout`, `sleep(
     args.interval)` between reads), reading `state = data.attributes.state` (an object) and its `state` string:
     COMPLETE prints each warning and info as f"Apple: {code}: {description}" and f"Build upload {upload_id} is
     COMPLETE." to stderr, then `upload_id` to stdout, and returns; FAILED raises AscError(f"Build upload {upload_id}
     FAILED in App Store Connect. {describe_upload_issues(state)}"); any other state keeps polling; past the deadline
     it raises AscError(f"Waiting for build upload {upload_id} timed out after {args.timeout:g}s; its last state was
     {last}.").
10. `parse`: the loop becomes `for name in ("check-build", "upload", "wait-build")`; for "upload" add `--ipa`
    (required), `--timeout` (float, default 3600.0) and `--interval` (float, default 15.0); wait-build keeps its own.
11. `COMMANDS = {"check-build": check_build, "upload": upload, "wait-build": wait_build, "ensure-version":
    ensure_version, "whats-new": whats_new, "attach-build": attach_build, "submit": submit}`, wrapped like now.
12. `main`: the missing-environment check covers ("APP_STORE_CONNECT_KEY_ID", "ASC_KEY_PATH"); the token is
    `TokenSource(key_id, os.environ["ASC_KEY_PATH"])`. No line of asc.py may pass 120 columns.

(b) actions-tool/tests/test_asc.py
1. Docstring: the second sentence becomes "Nothing here reaches Apple: the client runs with its base URL pointed at an
   `http.server` on 127.0.0.1, the upload's parts go to a second one standing in for Apple's storage URLs, and a P-256
   key made for the test signs individual-key tokens." The third sentence gains "the upload's parts and checksums,"
   after "the requests and bodies of each command (App Store Connect OpenAPI 4.6),". Append "Since 2026-11-26 the
   build goes up through the Build Upload API with an individual key (owner decisions)." Rewrap.
2. Imports: add `hashlib`. Remove the module's issuer constant.
3. After `localization(...)` add two helpers:
   - `operation(storage, number, offset, length)` returning {"method": "PUT", "url":
     f"{storage.base_url}/upload/part-{number}?X-Signature=secret-sig-{number}&X-Expires=600", "offset": offset,
     "length": length, "partNumber": number, "requestHeaders": [{"name": "Content-Type", "value":
     "application/octet-stream"}, {"name": "x-apple-part", "value": str(number)}], "entityTag": None, "expiration":
     "2026-11-27T00:00:00Z"};
   - `upload_state(state, errors=(), warnings=())` returning {"data": {"type": "buildUploads", "id": "u-1",
     "attributes": {"state": {"state": state, "errors": list(errors), "warnings": list(warnings), "infos": []}}}}.
4. After `FakeASC` add `class FakeStorage` with the docstring "A local stand-in for the storage URLs App Store Connect
   hands out for an upload. `replies` maps a path to a list of statuses; each call takes the first and the last one
   repeats (200 when none). Every request is kept in `requests` with its method, path, query, headers (as received,
   in order) and body." Built like FakeASC: a silenced `http.server.BaseHTTPRequestHandler` whose `handle_any` reads
   the body by Content-Length, appends {"method", "path", "query" (`parse_qs`), "headers": list(self.headers.items()),
   "body": raw}, answers the status with `ETag: "<hashlib.md5(raw).hexdigest()>"` and `Content-Length: 0`, and is
   bound to do_PUT, do_GET, do_POST, do_PATCH and do_DELETE; a `ThreadingHTTPServer` on ("127.0.0.1", 0) in a daemon
   thread; `base_url`; `close()`.
5. `TokenTests`: `make_token(KEY_ID, str(self.key), now=1_800_000_000)` in both token tests. In the first, replace
   the separate claim assertions with `assertEqual(claims, {"sub": "user", "iat": 1_800_000_000, "exp":
   1_800_001_200, "aud": "appstoreconnect-v1"})`; the header assertion and the openssl verification stay. In the
   tampered-token test the substituted claims are `{"sub": "someone-else"}`.
6. `AllowListTests`:
   - The exact list gains the four entries of (a)4 in the same places (15 entries).
   - The allowed paths gain ("POST", "/v1/buildUploads"), ("POST", "/v1/buildUploadFiles"),
     ("PATCH", "/v1/buildUploadFiles/f-1") and ("GET", "/v1/buildUploads/u-1").
   - The refused paths gain ("GET", "/v1/buildUploads"), ("PATCH", "/v1/buildUploads/u-1"),
     ("DELETE", "/v1/buildUploads/u-1"), ("GET", "/v1/buildUploadFiles/f-1"), ("DELETE", "/v1/buildUploadFiles/f-1"),
     ("GET", "/v1/apps/1/buildUploads"), ("POST", "/v1/buildUploads/u-1/buildUploadFiles"),
     ("PATCH", "/v1/buildUploadFiles/f-1?x=1") and ("GET", "/v1/buildUploads/u/1").
   - The command set gains "upload".
7. New `class UploadUrlTests(unittest.TestCase)` (no network, no skip) with
   `test_parts_go_over_https_and_http_only_to_a_local_fake`: `asc.check_part_url(url, local)` returns
   "https://storage.example.com/a/b" for ("https://storage.example.com/a/b?X-Signature=secret-sig#f", False) and
   "http://127.0.0.1:9/p" for ("http://127.0.0.1:9/p?X-Signature=secret-sig", True); each of
   ("http://127.0.0.1:9/p?X-Signature=secret-sig", False), ("http://storage.example.com/p?X-Signature=secret-sig",
   True), ("ftp://storage.example.com/p?X-Signature=secret-sig", True),
   ("https://user:pw@storage.example.com/p?X-Signature=secret-sig", False), ("https:///p?X-Signature=secret-sig",
   False), ("//storage.example.com/p?X-Signature=secret-sig", False),
   ("https://storage.example.com:99999/p?X-Signature=secret-sig", False) and (None, False) raises AscError whose
   message ends "Nothing was uploaded." and holds neither "secret-sig" nor "pw" (one subTest each).
8. `CommandTests`:
   - `setUp`: after the fake, `self.storage = FakeStorage()` with `self.addCleanup(self.storage.close)` and
     `self.ipa = pathlib.Path(self.tmp.name) / "EhPanda.ipa"`, before the two existing check cleanups.
   - `reset_calls` also clears `self.storage.requests`.
   - `check_every_call_was_recorded`: the record's lines that have "path", as (method, path), equal the fake's
     requests as (method, path); the lines that have "url", as (method, url), equal the storage's requests as
     (method, `self.storage.base_url + path`); both in order.
   - `check_requests_were_allowed`: for each fake request also decode the token's claims (the middle segment, with
     `b64url_decode`) and assert their keys are exactly {"sub", "iat", "exp", "aud"} and `sub` is "user"; for each
     storage request assert no header name is "authorization" (compared lowercased).
   - `run_asc`: the copied environment drops every name starting with "ASC_" or "APP_STORE_CONNECT_"; it sets
     ASC_BASE_URL, APP_STORE_CONNECT_KEY_ID, ASC_KEY_PATH and ASC_CALL_RECORD only.
   - Helpers: `upload_routes(self, content, part_size, ops=None)` writes `content` to `self.ipa`, builds `ops` (when
     not given) with `operation(self.storage, n, offset, min(part_size, len(content) - offset))` for offsets
     `range(0, len(content), part_size)` numbered from 1, and sets the routes ("POST", "/v1/buildUploads") →
     [(201, {"data": {"type": "buildUploads", "id": "u-1"}})], ("POST", "/v1/buildUploadFiles") → [(201, {"data":
     {"type": "buildUploadFiles", "id": "f-1", "attributes": {"uploadOperations": ops}}})],
     ("PATCH", "/v1/buildUploadFiles/f-1") → [(200, {"data": {"type": "buildUploadFiles", "id": "f-1"}})] and
     ("GET", "/v1/buildUploads/u-1") → [(200, upload_state("COMPLETE"))]; it returns `ops`. `run_upload(self,
     *extra)` runs ("upload", "--app", APP_ID, "--version", "3.0.0", "--build", "159", "--ipa", str(self.ipa),
     *extra).
   - A "# upload" section after check-build's, with:
     - `test_upload_sends_each_part_to_its_url_and_reports_the_checksums`: content `bytes(range(256)) * 10 +
       b"end"` (2,563 bytes), part size 1024, GET answering [(200, upload_state("PROCESSING")), (200,
       upload_state("COMPLETE"))]; `run_upload("--interval", "0")` returns 0 and stdout is "u-1". The fake's calls
       as (method, path) are POST /v1/buildUploads, POST /v1/buildUploadFiles, PATCH /v1/buildUploadFiles/f-1, GET
       /v1/buildUploads/u-1 twice. The first POST's body is the body of (a)9 with "3.0.0", "159" and APP_ID; the
       second's is {"data": {"type": "buildUploadFiles", "attributes": {"assetType": "ASSET", "fileName":
       "EhPanda.ipa", "fileSize": 2563, "uti": "com.apple.ipa"}, "relationships": {"buildUpload": {"data": {"type":
       "buildUploads", "id": "u-1"}}}}}. The storage got three PUTs to /upload/part-1, -2 and -3, with
       `query["X-Signature"] == [f"secret-sig-{n}"]` and bodies content[0:1024], content[1024:2048], content[2048:];
       each PUT's header names, lowercased, are exactly {"host", "content-length", "content-type", "x-apple-part"},
       with Content-Type "application/octet-stream", x-apple-part str(n) and Content-Length the body's length. The
       PATCH body is {"data": {"type": "buildUploadFiles", "id": "f-1", "attributes": {"uploaded": True,
       "sourceFileChecksums": {"file": {"algorithm": "MD5", "hash": hashlib.md5(content).hexdigest()},
       "composite": {"algorithm": "MD5", "hash": f"{hashlib.md5(<the three parts' raw md5 digests joined>)
       .hexdigest()}-3-1024"}}}}}. The record's methods in order are ["POST", "POST", "PUT", "PUT", "PUT", "PATCH",
       "GET", "GET"].
     - `test_a_file_in_one_part_has_its_whole_size_in_the_composite`: content `b"single part" * 100` (1,100 bytes),
       part size 4096; return code 0; the PATCH's composite hash is f"{hashlib.md5(hashlib.md5(content).digest())
       .hexdigest()}-1-1100" and its file hash `hashlib.md5(content).hexdigest()`.
     - `test_a_failed_upload_lists_every_error_and_warning_apple_gives`: content 2,563 bytes as above; the GET answers
       [(200, upload_state("FAILED", errors=[{"code": "ASSET_DESCRIPTION_MISSING", "description": "The asset
       description is missing."}], warnings=[{"code": "SYMBOLS_MISSING", "description": "Some symbols are
       missing."}]))]; return code 1, stdout empty, and both codes and both descriptions in stderr.
     - `test_upload_times_out_with_the_last_state`: the GET answers [(200, upload_state("PROCESSING"))];
       `run_upload("--interval", "0.05", "--timeout", "0.3")` returns 1 with "timed out" and "PROCESSING" in stderr.
     - `test_an_upload_url_without_https_is_refused_before_any_byte`: the 2,563-byte content with `ops` =
       [`operation(self.storage, 1, 0, 2563)` with its "url" set to
       "http://storage.example.com/upload/part-1?X-Signature=secret-sig-1"]; `run_upload("--interval", "0")`
       returns 1; "https" in stderr and "secret-sig" not; `self.storage.requests` is empty; no PATCH call.
     - `test_a_part_the_storage_refuses_stops_the_upload_before_it_is_marked_uploaded`: content 2,563 bytes,
       `self.storage.replies["/upload/part-2"] = [403]`; return code 1; "403" in stderr and "secret-sig" not; the
       storage's paths are ["/upload/part-1", "/upload/part-2"]; no PATCH and no GET /v1/buildUploads/u-1.
     - `test_a_missing_ipa_fails_before_any_request`: no file written; return code 1; `self.fake.requests` is empty.
   - `run_whole_sequence`: first `self.upload_routes(bytes(range(256)) * 6, 1024)` (two parts), then the existing
     `routes.update(...)`; the command list gains ("upload", "--app", APP_ID, "--version", "3.0.0", "--build", "159",
     "--ipa", str(self.ipa), "--interval", "0") right after check-build.
   - The record test: the line count equals `len(self.fake.requests) + len(self.storage.requests)`; ASC lines (with
     "path") have exactly {"method", "path", "status", "keyID"} and keyID KEY_ID, and the existing pairing loop runs
     over them and the fake's requests; part lines (with "url") have exactly {"method", "url", "status", "part"} and
     method "PUT"; no line's JSON holds "?"; the statuses, in record order, are [200, 201, 201, 200, 200, 200, 200,
     200, 200, 201, 200, 200, 204, 200, 201, 201, 200].
   - The log test also checks, for each storage request, the line `UPLOAD PUT <storage.base_url + path> 200
     part=<n>` (regex, multiline, `\d+` for n).
   - The no-leak test also asserts that neither "secret-sig" nor "X-Signature" is in the record or the output.
   - `test_missing_credentials_fail_before_any_request`: the copied environment drops the "ASC_" and
     "APP_STORE_CONNECT_" names, and stderr contains "Missing environment: APP_STORE_CONNECT_KEY_ID, ASC_KEY_PATH.".
   - No test line may pass 120 columns.

(c) actions-tool/ExportOptions-marketplace.plist (owner decision 2)
1. `destination` becomes `<string>export</string>`. Nothing else in the dict changes (uploadSymbols stays true).
2. The comment's first line becomes "Export options for the AltStore PAL .ipa (the AltStorePAL job of
   marketplace-upload.yml, Phase 20 plan 20-04)."; after the template sentence add the lines "destination export:
   xcodebuild only signs and writes the .ipa, with no API key; actions-tool/asc.py uploads it through the Build Upload
   API (owner decisions, 2026-11-26)." The D-26 lines stay.

(d) actions-tool/marketplace-signing.sh (the step order changes: the signing teardown now comes before the upload)
1. Usage, teardown-signing entry: "keeps the API key for the App Store Connect calls after the upload" becomes "keeps
   the API key for the upload and the App Store Connect calls after it"; rewrap the two description lines.
2. `teardown_signing`'s echo becomes "Signing material removed; the App Store Connect API key stays for the upload and
   the calls after it." Nothing else changes.

(e) .github/workflows/marketplace-upload.yml (owner decisions 1-3)
1. Header, first paragraph: "uploads it to App Store Connect. With `submit` on" becomes "uploads it to App Store
   Connect through the Build Upload API, with the owner's individual API key (owner decisions, 2026-11-26). With
   `submit` on"; the rest of the paragraph stays; rewrap.
2. "Its own archive" paragraph: replace "The signing material is removed right after the upload; only the API key
   stays, until the last step." with "xcodebuild only signs and exports the .ipa, with no API key; the signing
   material is removed right after the export, and only the API key stays, for the upload and the calls after it,
   until the last step."
3. Secret list: delete the line of the removed secret; the APP_STORE_CONNECT_KEY_ID line's text becomes "the ID of the
   owner's individual App Store Connect API key". The other lines stay.
4. Last paragraph: replace "Its calls are recorded with the key's ID and uploaded as an artifact (D-21); the upload
   uses the same key." with "The .ipa's parts go only to the storage URLs App Store Connect gives for that upload, over
   https and without the API token. The call record (D-21) holds each App Store Connect call with the key's ID and
   each part of the upload with its storage URL, never the URL's signature, and is uploaded as an artifact." Rewrap
   the whole header at 120 columns.
5. The job's timeout comment becomes "# The build, the export and the upload (about 16 minutes for 3.1.0 (164)), the
   wait for App Store Connect to take the upload (up to 60 minutes here), its processing of the build (up to 90
   minutes here) and the submission." `timeout-minutes` stays 240.
6. Delete the issuer line from the env of Check build number, Wait for the build, Ensure the notarization version,
   Fill What's New, Attach the build and Submit for notarization. Nothing else in those steps changes.
7. Replace the step "Export and upload" with two steps, keeping Tear down signing between them:
   - "Export .ipa file": no `env`; `run`: `set -euo pipefail`; the comment "# destination export (owner decisions,
     2026-11-26): xcodebuild signs the .ipa with the profiles named in the export options and writes it to
     PAL_EXPORT_PATH, with no API key; asc.py uploads it after the signing teardown."; `xcodebuild -exportArchive \`
     with the three lines `-archivePath "$PAL_ARCHIVE_PATH" \`, `-exportOptionsPlist "$MARKETPLACE_EXPORT_OPTIONS" \`
     and `-exportPath "$PAL_EXPORT_PATH"` (no key flags); then
     `[[ -f "$PAL_EXPORT_PATH/$SCHEME_NAME.ipa" ]] || { echo "::error::The export wrote no $SCHEME_NAME.ipa."; exit 1; }`.
   - "Tear down signing" stays where it is, now right after "Export .ipa file"; its comment becomes "# The signing
     material goes as soon as the .ipa is signed (owner decisions, 2026-11-26): the upload, the wait and the
     submission need only the API key, which the last step removes."
   - "Upload to App Store Connect", right after "Tear down signing", no `if`; `env`, in this order:
     `APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}`, `VERSION: ${{ steps.version.outputs.version
     }}`, `BUILD_NUMBER: ${{ steps.build-number.outputs.build }}`, `SUBMIT: ${{ inputs.submit }}`; `run`:
     `set -euo pipefail`; the comment "# The Build Upload API with the individual key (owner decisions, 2026-11-26):
     each part of the .ipa goes to the storage URL App Store Connect gives for it, and the step waits until App Store
     Connect has the upload."; then
     `upload_id="$(python3 "$ASC_TOOL_PATH" upload --app "$ASC_APP_ID" --version "$VERSION" --build "$BUILD_NUMBER" --ipa "$PAL_EXPORT_PATH/$SCHEME_NAME.ipa" --timeout 3600)"`;
     then the existing two-line "# With submit on ..." comment and summary block moved from the old step, where after
     the heading's `echo ""` come two new lines, `echo "Build upload \`$upload_id\`."` and `echo ""`, and then the
     existing if/else; each message stays a single `echo` line.
   No other step changes. No comment line may pass 120 columns.

(f) actions-tool/tests/test_workflows.py
1. Imports: add `plistlib`.
2. `PAL_SECRETS` = ["APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_PRIVATE_KEY", "DISTRIBUTION_CERTIFICATE",
   "DISTRIBUTION_CERTIFICATE_PASSWORD", "PROVISIONING_PROFILE_APP", "PROVISIONING_PROFILE_SHARE_EXTENSION",
   "APPLE_TEAM_ID"], wrapped at 120 columns. Add after PAL_VARIABLES the comment "# The repository secrets the archive
   and the dSYM upload read (deploy.yml passes them with `secrets: inherit`)." and `PAL_REPOSITORY_SECRETS =
   ["TELEMETRYDECK_APP_ID", "TELEMETRYDECK_SALT", "SENTRY_DSN", "SENTRY_AUTH_TOKEN"]`.
3. `PAL_UPLOAD_STEPS`: "Export and upload" becomes "Export .ipa file", and "Upload to App Store Connect" follows
   "Tear down signing".
4. `PalUploadJobTests` docstring: "it archives the marketplace build on its own, verifies and uploads it" becomes "it
   archives the marketplace build on its own, verifies it, exports the .ipa and uploads it through the Build Upload API
   with the owner's individual key".
5. `test_the_version_is_the_projects`: "Export and upload" in the VERSION loop becomes "Upload to App Store Connect".
6. `test_the_marketplace_build_is_verified_before_upload`: compare with "Export .ipa file".
7. Replace `test_the_upload_uses_the_export_options_and_the_api_key` with two tests:
   - `test_the_export_only_signs_and_writes_the_ipa`: "Export .ipa file" has no "env"; its `run_text` contains
     "xcodebuild -exportArchive", '-archivePath "/tmp/action-builds/EhPanda-AltStorePAL.xcarchive"',
     '-exportOptionsPlist "$MARKETPLACE_EXPORT_OPTIONS"', '-exportPath "/tmp/action-builds/EhPanda-AltStorePAL-export"'
     and '[[ -f "/tmp/action-builds/EhPanda-AltStorePAL-export/EhPanda.ipa" ]]', and neither "-authentication" nor
     "altool"; `plistlib.load` of actions-tool/ExportOptions-marketplace.plist equals {"destination": "export",
     "manageAppVersionAndBuildNumber": False, "method": "app-store-connect", "provisioningProfiles": {},
     "signingCertificate": "Apple Distribution", "signingStyle": "manual", "teamID": "", "uploadSymbols": True}.
   - `test_the_upload_goes_through_the_build_upload_api_with_the_key`: "Upload to App Store Connect" has no "if" and
     its env equals the four entries of (e)7; its unexpanded `code(run)` contains the `upload_id=` command line of
     (e)7 from its start up to and including "--timeout " (one line in the workflow; the test may write the needle as
     adjacent string literals); `expand("$PAL_EXPORT_PATH/$SCHEME_NAME.ipa",
     {**self.env, **self.job["env"]})` is "/tmp/action-builds/EhPanda-AltStorePAL-export/EhPanda.ipa"; it is the step
     right after "Tear down signing"; its `run_text` contains none of "xcodebuild", "altool" and "-authentication".
8. Rename `test_the_signing_material_is_gone_before_the_wait` to `test_the_signing_material_is_gone_before_the_upload`:
   "Tear down signing" is right after "Export .ipa file" and before "Upload to App Store Connect" and every step of
   PAL_SUBMIT_STEPS; the per-step loop after it stays and also asserts that the env names whose value holds "secrets."
   are a subset of {"APP_STORE_CONNECT_KEY_ID"}.
9. `test_the_client_calls_are_the_build_check_then_the_submission` becomes
   `test_the_client_calls_are_the_check_the_upload_then_the_submission`, expecting ["check-build", "upload",
   "wait-build", "ensure-version", "whats-new", "attach-build", "submit"].
10. `test_the_submission_waits_for_the_build_and_chains_its_ids`: delete the assertion on the removed secret; after
    the existing timeout assertion add the comment "# The upload's wait and the build's wait together leave an hour for
    the build and the export." and assert the `--timeout` of "Upload to App Store Connect" plus the wait's is at most
    `(self.job["timeout-minutes"] - 60) * 60`.
11. `test_the_summary_says_whether_the_run_submits`: it reads "Upload to App Store Connect" instead of the old step;
    the needles also include "Build upload"; 'asc.py" upload' comes before "GITHUB_STEP_SUMMARY" in its `run_text`.
12. Add `test_the_job_uses_exactly_the_documented_secrets`, with the comment "# An individual key (owner decision,
    2026-11-26): its ID and its .p8 are the only App Store Connect secrets.": the set of `secrets.(\w+)` names in
    `json.dumps(self.job)` equals set(PAL_SECRETS) | set(PAL_REPOSITORY_SECRETS).
13. `test_the_header_lists_every_secret_and_variable`: the needles also include "individual" and "Build Upload API".
14. `CrashReportingWorkflowTests.RELEASES`: the marketplace entry's step becomes "Export .ipa file".

Commit (signed, +0800, the six paths staged explicitly): `ci: upload the PAL build with an individual key`.
  </action>
  <verify>
    <automated>python3 -m unittest discover -s actions-tool/tests -p 'test_asc.py' && /usr/bin/python3 -m unittest discover -s actions-tool/tests -p 'test_asc.py' && python3 -m unittest discover -s actions-tool/tests -p 'test_workflows.py' && python3 -m unittest discover -s actions-tool/tests && python3 -m unittest discover -s Scripts/visual -p 'test_snapshot_gate.py' && actionlint .github/workflows/marketplace-upload.yml .github/workflows/deploy.yml && [ "$(cat actions-tool/asc.py actions-tool/tests/test_asc.py .github/workflows/marketplace-upload.yml actions-tool/tests/test_workflows.py actions-tool/marketplace-signing.sh actions-tool/ExportOptions-marketplace.plist | grep -ci 'issuer')" -eq 0 ] && [ "$(grep -v '^[[:space:]]*#' .github/workflows/marketplace-upload.yml | grep -c -- '-authentication')" -eq 0 ] && [ "$(plutil -extract destination raw -o - actions-tool/ExportOptions-marketplace.plist)" = export ] && [ "$(grep -v '^[[:space:]]*#' .github/workflows/marketplace-upload.yml | grep -c '"$ASC_TOOL_PATH" upload --app')" -ge 1 ] && [ "$(awk 'length > 120' actions-tool/asc.py actions-tool/tests/test_asc.py | wc -l)" -eq 0 ] && [ "$(grep '^[[:space:]]*#' .github/workflows/marketplace-upload.yml | awk 'length > 120' | wc -l)" -eq 0 ] && python3 -c 'import sys; sys.path.insert(0, "actions-tool"); import asc; sys.exit(sorted(asc.COMMANDS) != ["attach-build", "check-build", "ensure-version", "submit", "upload", "wait-build", "whats-new"] or len(asc.ALLOWED) != 15)'</automated>
    Baselines (HEAD = `0d80493c8`): actions-tool/tests tests run, all OK [HEAD=350 EXPECT>350]; case-insensitive issuer lines across the six files [HEAD=25 EXPECT==0] (unfiltered on purpose: owner decision 1 removes every mention, comments included); uncommented `-authentication` lines in marketplace-upload.yml [HEAD=3 EXPECT==0]; the export options' destination reading `export` (it reads `upload` at HEAD) [HEAD=absent EXPECT==present]; uncommented `"$ASC_TOOL_PATH" upload --app` lines [HEAD=0 EXPECT>=1]; lines over 120 columns in asc.py and test_asc.py [HEAD=3 EXPECT==0]; comment lines over 120 columns in marketplace-upload.yml [HEAD=0 EXPECT==0 GUARD MUTATION: a header or step comment rewrapped past 120 columns]; asc commands [HEAD=6 EXPECT==7]; allow-list entries [HEAD=11 EXPECT==15]. Then `git log -1 --format='%G? %aI %cI'` shows `G` and two `+08:00` dates.
  </verify>
  <done>asc.py signs individual-key tokens (sub user, no iss) and needs only the key ID and the key file; `asc.py upload` creates the build upload and its .ipa file, PUTs each part to its https URL with only the listed headers, marks the file uploaded with its MD5 checksums and polls to COMPLETE or FAILED; the allow-list has exactly 15 entries; the workflow exports with destination export and no key flags, tears down signing, then uploads with only the key ID secret; no issuer remains in the six files; every named test run passes under both Pythons and actionlint is clean; one signed +0800 commit.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Check App Store Connect's upload plan before any byte, and resend a part after a transient failure (owner decision 2; D-07, D-21)</name>
  <files>actions-tool/asc.py, actions-tool/tests/test_asc.py</files>
  <read_first>
    - actions-tool/asc.py and actions-tool/tests/test_asc.py as committed by Task 1 (the "# Upload" section, `Client.send_part`, `upload_parts`, `operation`, `FakeStorage`, `upload_routes`)
  </read_first>
  <behavior>
    - upload_parts returns the parts in file order whatever order App Store Connect lists them in, and takes a null requestHeaders as no headers.
    - It refuses, before any byte, with a message ending "Nothing was uploaded." and never holding the URL's query: no operations, an operation that is not an object, a method other than PUT, an offset or length that is not a whole number (text or a boolean), a negative offset, a zero length, headers that are not a list, a header without a string name or value, a name that is not an HTTP token, a value with a line break or NUL, a Content-Length header other than the part's length, and ranges that do not start at 0, leave a gap, overlap, or end before or after the file's size.
    - A part answered 500 and then 200 is sent twice with the same bytes and succeeds; the record shows 500 then 200 and the client sleeps 5 s once.
    - A part answered 429 every time fails after three attempts naming 429; a part answered 403 is sent once; a lost connection is tried three times, recorded with status 0 each time, sleeping 5 s then 10 s.
    - Sending a part never reads the API token.
    - A subprocess upload whose operations overlap sends nothing to the storage and no PATCH.
  </behavior>
  <action>
Write the tests of (b) first and run `python3 -m unittest discover -s actions-tool/tests -p 'test_asc.py'` to see
them fail (RED); then make the changes of (a) until they pass (GREEN). One commit at the end of the task.

(a) actions-tool/asc.py (owner decision 2)
1. After PART_TIMEOUT add the comment "# A header App Store Connect lists for a part: an HTTP token as its name and a
   value on one line." and `HEADER_NAME = re.compile(r"[!#$%&'*+.^_`|~0-9A-Za-z-]+")`; then the comment "# A part is
   the same bytes to the same URL, so it is sent again as a read is." and `PART_ATTEMPTS = 3`.
2. `upload_parts`: keep its docstring and the empty-list refusal; before sorting, check each operation in the order
   given (its number `n` is its 1-based place in that order), raising AscError with a message that names the
   operation by number, never by URL, and ends "Nothing was uploaded.":
   - it is a dict (f"Upload operation {n} is not an object.");
   - `method` is "PUT" (f"Upload operation {n} asks for {method!r}; only PUT is sent.");
   - `offset` is an int and not a bool (`type(offset) is int`) and at least 0, and `length` an int, not a bool, above 0
     (f"Upload operation {n} has no usable byte range.");
   - its URL passes `check_part_url` (as in Task 1);
   - `requestHeaders` is null or a list (f"Upload operation {n} lists its headers in an unknown form."); each entry is
     a dict whose `name` is a str matching HEADER_NAME with `fullmatch` and whose `value` is a str with no "\r", "\n"
     or "\0" (f"Upload operation {n} lists a header that cannot be sent."); a Content-Length header (name compared
     without case) must have the value `str(length)` (f"Upload operation {n} gives a Content-Length other than its
     length.").
   After sorting by offset: the first offset is 0 and each next offset equals the previous offset plus its length
   (else f"The upload operations do not meet: one ends at byte {end}, the next starts at {offset}."), and the last
   end equals `size` (else f"The upload operations cover {end} of the file's {size} bytes."), each message ending
   " Nothing was uploaded.". Then build the parts as in Task 1.
3. `Client.send_part(self, part, data)`: wrap the send in a loop of PART_ATTEMPTS attempts, with the comment "# A part
   is sent again on 429, a server error or a lost connection, like a read; any other refusal is final." On OSError or
   `http.client.HTTPException`: `note_part(part, 0)`; with attempts left, `time.sleep(attempt * 5)` and send again;
   after the last, AscError(f"PUT {part.public} failed {PART_ATTEMPTS} times ({type(error).__name__}); the file was
   not marked uploaded.") from None. On status 429 or at least 500: `note_part(part, status)`; with attempts left,
   sleep and send again; after the last, AscError(f"PUT {part.public} returned {status} {PART_ATTEMPTS} times; the file
   was not marked uploaded."). Any other status outside 200-299: `note_part` and the Task 1 AscError at once. A status
   in 200-299: `note_part` and return. Every attempt sends the same `data` and opens its own connection, closed after
   it. Extend the docstring with "429, a server error or a lost connection get the part sent again, at most
   PART_ATTEMPTS times."

(b) actions-tool/tests/test_asc.py
1. Imports: add `socket` and `from unittest import mock`.
2. New `class UploadPlanTests(unittest.TestCase)` (no network, no skip), after UploadUrlTests, with the class
   attributes `SIZE = 2563`, `RANGES = ((0, 1024), (1024, 1024), (2048, 515))`, `STORAGE =
   types.SimpleNamespace(base_url="https://storage.example.com")` (add `import types`) and `REMOVE = object()`:
   - helper `plan(self, ranges=RANGES, **second)`: the operations `operation(self.STORAGE, n, offset, length)` for
     each (offset, length) of `ranges`, numbered from 1 in the order given; then each keyword sets that key of the
     second operation's dict, or deletes it when the value is `self.REMOVE`. Its URLs are
     "https://storage.example.com/upload/part-<n>?X-Signature=secret-sig-<n>&X-Expires=600".
   - `test_the_parts_come_back_in_file_order`: `asc.upload_parts(self.plan(((2048, 515), (0, 1024), (1024, 1024))),
     self.SIZE, False)` returns three parts numbered 1, 2, 3 with offsets 0, 1024, 2048, public URLs
     "https://storage.example.com/upload/part-2", "-3" and "-1" (no query), and the headers of their operations as
     (("Content-Type", "application/octet-stream"), ("x-apple-part", "<operation number>")).
   - `test_no_headers_is_allowed`: `self.plan(requestHeaders=None)` gives the second part headers ().
   - `test_a_malformed_plan_is_refused_before_any_byte`: one subTest per case below, each
     `asc.upload_parts(<operations>, self.SIZE, False)` raising AscError whose message ends "Nothing was uploaded."
     and holds no "secret-sig":
     - None; []; ["PUT"];
     - `self.plan(method="POST")`; `self.plan(method=self.REMOVE)`; `self.plan(offset="1024")`;
       `self.plan(offset=True)`; `self.plan(length=0)`;
     - `self.plan(requestHeaders="Content-Type: application/octet-stream")`; `self.plan(requestHeaders=[{"value":
       "x"}])`; `self.plan(requestHeaders=[{"name": "Content Type", "value": "x"}])`;
       `self.plan(requestHeaders=[{"name": "X-A", "value": "a\r\nAuthorization: Bearer t"}])`;
       `self.plan(requestHeaders=[{"name": "X-A", "value": "a\0"}])`;
       `self.plan(requestHeaders=[{"name": "content-length", "value": "1"}])`;
     - ranges that start at 1: `self.plan(((1, 1023), (1024, 1024), (2048, 515)))`; a negative offset:
       `self.plan(((-1, 1025), (1024, 1024), (2048, 515)))`; a gap: `self.plan(((0, 1000), (1024, 1024), (2048,
       515)))`; an overlap: `self.plan(((0, 1100), (1024, 1024), (2048, 515)))`; short of the file:
       `self.plan(((0, 1024), (1024, 1024), (2048, 514)))`; past the file: `self.plan(((0, 1024), (1024, 1024),
       (2048, 516)))`.
3. New `class PartRetryTests(unittest.TestCase)` (in process, no openssl needed): `setUp` makes a temporary folder
   (cleaned up), `self.storage = FakeStorage()` (closed in cleanup), `self.record` a file in the folder, `self.lines`
   a list, and `self.client = asc.Client("http://127.0.0.1:1", token=self.no_token, key_id=KEY_ID,
   record=str(self.record), log=self.lines.append)` (a loopback base URL that is never contacted, so loopback http
   parts are allowed); `no_token(self)` calls `self.fail("sending a part read the API token")`. Helpers:
   `part(self, url=None)` = `asc.upload_parts([operation(self.storage, 1, 0, 9)], 9, True)[0]`, with the operation's
   url replaced when `url` is given; `statuses(self)` = the record lines' statuses. Tests, each with
   `mock.patch.object(asc.time, "sleep")` as `slept` around the send and DATA = b"part-data":
   - `test_a_part_is_sent_again_after_a_server_error`: replies [500, 200] for "/upload/part-1";
     `send_part(self.part(), DATA)` returns; the storage got two requests whose bodies are both DATA; statuses
     [500, 200]; `slept.assert_called_once_with(5)`.
   - `test_a_part_that_keeps_failing_stops_after_three_attempts`: replies [429]; AscError with "429" and "3 times" in
     its message and no "secret-sig"; three requests; statuses [429, 429, 429].
   - `test_a_refused_part_is_not_sent_again`: replies [403]; AscError with "403"; one request; statuses [403];
     `slept.assert_not_called()`.
   - `test_a_lost_connection_is_tried_again_then_fails`: bind a socket to ("127.0.0.1", 0), take its port and close
     it; the part's url is f"http://127.0.0.1:{port}/upload/part-1?X-Signature=secret-sig-1"; AscError with "3 times";
     statuses [0, 0, 0]; the sleep calls are [mock.call(5), mock.call(10)].
4. `CommandTests`: add `test_an_overlapping_plan_uploads_nothing` in the "# upload" section: `upload_routes` with the
   2,563-byte content and `ops` = [operation(self.storage, 1, 0, 1100), operation(self.storage, 2, 1024, 1024),
   operation(self.storage, 3, 2048, 515)]; return code 1; "Nothing was uploaded." in stderr; the storage got no
   request; no PATCH call.
5. No line of either file may pass 120 columns.

Commit (signed, +0800, the two paths staged explicitly): `ci: check the PAL upload plan and resend parts`.
  </action>
  <verify>
    <automated>python3 -m unittest discover -s actions-tool/tests -p 'test_asc.py' && /usr/bin/python3 -m unittest discover -s actions-tool/tests -p 'test_asc.py' && python3 -m unittest discover -s actions-tool/tests && grep -qE '^class UploadPlanTests\(' actions-tool/tests/test_asc.py && grep -qE '^class PartRetryTests\(' actions-tool/tests/test_asc.py && [ "$(awk 'length > 120' actions-tool/asc.py actions-tool/tests/test_asc.py | wc -l)" -eq 0 ] && python3 -c 'import sys; sys.path.insert(0, "actions-tool"); import asc; sys.exit(asc.PART_ATTEMPTS != 3 or len(asc.ALLOWED) != 15)'</automated>
    Baselines (HEAD = Task 1's commit): each of the two new test classes [HEAD=absent EXPECT==present]; `asc.PART_ATTEMPTS` [HEAD=absent EXPECT==3]; allow-list entries [HEAD=15 EXPECT==15 GUARD MUTATION: any added endpoint]; lines over 120 columns in asc.py and test_asc.py [HEAD=0 EXPECT==0 GUARD MUTATION: a new check or test line past 120 columns]. Then `git log -1 --format='%G? %aI %cI'` shows `G` and two `+08:00` dates.
  </verify>
  <done>A malformed upload plan is refused before any byte with a message naming no URL query; a part answered 429, 5xx or with a lost connection is sent again at most three times and a refusal is final; sending a part never reads the token; the asc tests pass under both Pythons and the whole actions-tool suite passes; one signed +0800 commit.</done>
</task>

<task type="auto">
  <name>Task 3: Record the individual key and the environment's secrets in the 20-06 account record (owner decisions 1, 2)</name>
  <files>.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-06-ACCOUNT.md</files>
  <read_first>
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-06-ACCOUNT.md lines 61-69 (the API key) and 130-159 (Task 3's live check)
  </read_first>
  <action>
Add dated amendments only; change no existing sentence or table row. Do not touch any other file.

1. After the paragraph that starts "Open: the key's ID, its type (team or individual) and its role" (it ends "is
   therefore not yet in this file."), add a blank line and the paragraph: "*Amended 2026-11-26 (owner decisions):* the
   CI uses the owner's own individual App Store Connect API key, not a team key: its type is individual, and it acts
   with the owner's own role and app access. The three secrets above were removed from `app-marketplace`; the owner
   adds `APP_STORE_CONNECT_KEY_ID` and `APP_STORE_CONNECT_PRIVATE_KEY` for the individual key after quick 261126-dkv.
   `APP_STORE_CONNECT_ISSUER_ID` is gone for good: an individual key's token has no `iss` and carries `"sub":
   "user"`. The build goes up through the App Store Connect Build Upload API (`asc.py upload`), not through
   `xcodebuild` or `altool`, which both ask for an issuer ID with an API key; `xcodebuild` only exports the signed
   `.ipa`. The key's ID and when it was made are not recorded here." Wrap at 120 columns like the lines around it.
2. After the last paragraph of the file (it ends "`required_reviewers` and the eight names above."), add a blank line
   and the paragraph: "*Amended 2026-11-26 (owner decisions):* after this check the environment changed.
   `APPLE_TEAM_ID`, `DISTRIBUTION_CERTIFICATE` and `DISTRIBUTION_CERTIFICATE_PASSWORD` stay, and the owner renewed
   `PROVISIONING_PROFILE_APP` and `PROVISIONING_PROFILE_SHARE_EXTENSION` on 2026-11-26. The three
   `APP_STORE_CONNECT_*` secrets were removed; the owner adds `APP_STORE_CONNECT_KEY_ID` and
   `APP_STORE_CONNECT_PRIVATE_KEY` for the individual key after quick 261126-dkv. So the `AltStorePAL` job, now in
   `marketplace-upload.yml`, and that workflow's header name seven environment secrets, and
   `APP_STORE_CONNECT_ISSUER_ID` is not among them. This change did not check the environment live." Wrap at 120
   columns.

Commit (signed, +0800, the one path staged explicitly): `docs(quick-261126-dkv): record the individual key`.
  </action>
  <verify>
    <automated>P=.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele; tr '\n' ' ' < $P/20-06-ACCOUNT.md | grep -qF "*Amended 2026-11-26 (owner decisions):* the CI uses the owner's own individual App Store Connect API key, not a team key" && tr '\n' ' ' < $P/20-06-ACCOUNT.md | grep -qF "*Amended 2026-11-26 (owner decisions):* after this check the environment changed." && [ "$(grep -c '^\*Amended 2026-11-26 (owner decisions):\*' $P/20-06-ACCOUNT.md)" -ge 2 ] && grep -qF '| `APP_STORE_CONNECT_ISSUER_ID` | 2026-11-25T08:00:46Z | yes |' $P/20-06-ACCOUNT.md && grep -qF 'is therefore not yet in this file.' $P/20-06-ACCOUNT.md && git diff --quiet 0d80493c8 -- $P/20-08-SUBMISSION.md .planning/REQUIREMENTS.md</automated>
    Baselines (HEAD = `0d80493c8`): the two amendments, each starting a line [HEAD=0 EXPECT>=2]; the 2026-11-25 table row and the "Open:" paragraph are guards [HEAD=present EXPECT==present GUARD MUTATION: deleting or rewriting an existing line]; 20-08-SUBMISSION.md and REQUIREMENTS.md unchanged since `0d80493c8` [EXPECT==unchanged]. Then `git log -1 --format='%G? %aI %cI'` shows `G` and two `+08:00` dates.
  </verify>
  <done>20-06-ACCOUNT.md carries both dated 2026-11-26 amendments, every existing line is intact, 20-08-SUBMISSION.md and REQUIREMENTS.md are unchanged; one signed +0800 commit.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| GitHub Actions job → App Store Connect API | The job holds the individual API key and creates a build upload, its file, and (with submit) the version and submission |
| Job → Apple's storage hosts | The .ipa's parts go to pre-signed storage URLs on hosts other than the API's |
| App Store Connect response → client | The upload operations (URLs, methods, ranges, headers) arrive from the API and steer the PUTs |
| Runner disk after the export | The signed .ipa and the API key sit in the runner's temp folders until the last step |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261126-dkv-01 | Information disclosure | `Client.send_part` | high | mitigate | It never reads the token and sends only the operation's headers plus Host and Content-Length through `http.client` (no default headers, no proxy, no redirect); every test's cleanup asserts no PUT carried Authorization, and PartRetryTests fail if the token is read (Tasks 1, 2) |
| T-261126-dkv-02 | Information disclosure | Logs, call record, errors | high | mitigate | Part URLs appear only as scheme, host and path (`check_part_url`'s public form); storage reply bodies are never shown; tests look for the fake signature text in the record, the output and every refusal message (Tasks 1, 2) |
| T-261126-dkv-03 | Spoofing / Tampering | Part destination | high | mitigate | https only, with `ssl.create_default_context()`; http only on loopback while the API base URL itself is a loopback fake (the workflow never sets ASC_BASE_URL); no user info, no bad port; URLs come only from the same run's POST response (Tasks 1, 2) |
| T-261126-dkv-04 | Tampering | Upload integrity | medium | mitigate | Ranges must start at 0, meet exactly and end at the file size; each part's bytes are read at its range and length-checked; the file and composite MD5s go with `uploaded: true`; a refused part stops the run before the PATCH (Tasks 1, 2) |
| T-261126-dkv-05 | Elevation of privilege | `asc.py` `ALLOWED` | high | mitigate | Exactly 15 (method, path) entries matched with `re.fullmatch`, IDs letters, digits and hyphens; tests pin the list and refuse the unused build-upload paths (Task 1) |
| T-261126-dkv-06 | Elevation of privilege | Individual key's role | medium | mitigate | The key acts with the owner's own role (owner decision 1), so the allow-list, not the key's role, bounds what the client can do; every run still waits for the `app-marketplace` reviewer (D-07) |
| T-261126-dkv-07 | Repudiation | D-21 call record | medium | mitigate | Every ASC call and every part attempt is a record line; `check_every_call_was_recorded` pairs both kinds with the fakes after every command test (Task 1) |
| T-261126-dkv-08 | Information disclosure | Signing material during the upload and waits | medium | mitigate | Tear down signing runs right after the export, before the upload; no later step names a signing secret, and only APP_STORE_CONNECT_KEY_ID is a secret after it (Task 1) |
| T-261126-dkv-09 | Denial of service | Runner held by the two waits | low | accept | `upload --timeout 3600` and `wait-build --timeout 5400` within the 240-minute job; a test keeps an hour for the build and export (Task 1) |
| T-261126-dkv-SC | Tampering | npm/pip/cargo installs | low | accept | Nothing is installed: asc.py uses the standard library and `openssl`; the tests use `ruby`, `openssl` and `bash` already on the machine |
</threat_model>

<verification>
- After each task: its `<automated>` command passes and `git log -1 --format='%G? %aI %cI'` shows `G` and two
  `+08:00` dates.
- After Task 3: the Lint loop passes:
  `failed=0; while IFS= read -r directory; do python3 -m unittest discover -s "$directory" -p 'test_*.py' || failed=1; done < <(find Scripts actions-tool -name 'test_*.py' -exec dirname {} \; | sort -u); [ "$failed" -eq 0 ]`
  (about three minutes; green at `0d80493c8`); `actionlint .github/workflows/marketplace-upload.yml
  .github/workflows/deploy.yml` exits 0; `git status --short` lists nothing this plan touched.
- `git diff 0d80493c8 --stat -- .github/workflows/deploy.yml .github/workflows/publish-pal.yml actions-tool/pal_publish.py Scripts/visual/README.md .planning/REQUIREMENTS.md`
  prints nothing.
</verification>

<success_criteria>
- The PAL job exports with destination export and uploads through the Build Upload API with the owner's individual
  key; no issuer remains anywhere outside `.planning/`.
- Parts go only over https, with only the listed headers, never the token, and appear in the call record without
  their signatures; a bad plan or a refused part stops before the file is marked uploaded.
- Everything quick 261126-0b9 built still runs as before.
- Three signed +0800 commits with subjects of 50 characters or fewer.
</success_criteria>

<output>
Create `.planning/quick/261126-dkv-use-an-individual-app-store-connect-api-/261126-dkv-SUMMARY.md` when done
</output>
