#!/usr/bin/env python3
"""A small App Store Connect API client for the AltStore PAL build (the `AltStorePAL` job of `marketplace-upload.yml`).

It makes the calls that job needs and nothing else (Phase 20 D-07, D-21; App Store Connect OpenAPI 4.6). Before the
archive it checks that the build number is still unused. After the export it uploads the `.ipa` through the Build
Upload API and waits until App Store Connect has taken it (owner decisions, 2026-11-26). When the run submits (the
release path; owner decisions, 2026-11-26), it then waits until App Store Connect has processed the build, creates or
reuses the version with review type Notarization, fills What's New for each of its localizations from that language's
section of the release notes, attaches the build and submits it for notarization. The standard library and `openssl`
are all it uses, so a release job holding signing secrets installs nothing.

Usage:
  asc.py check-build --app <id> --version <x.y.z> --build <n>
      fails if build <n> of version <x.y.z> was uploaded before (build numbers are single-use)
  asc.py upload --app <id> --version <x.y.z> --build <n> --ipa <file> [--timeout <s>] [--interval <s>]
      uploads the .ipa as build <n> of version <x.y.z> through the Build Upload API, each part to the storage URL
      App Store Connect gives for it, then waits until the upload is COMPLETE and prints its ID; fails on FAILED,
      listing every error and warning Apple gives, or on timeout
  asc.py wait-build --app <id> --version <x.y.z> --build <n> [--timeout <s>] [--interval <s>]
      waits until the uploaded build is VALID and prints its ID; fails on INVALID, FAILED or timeout
  asc.py ensure-version --app <id> --version <x.y.z>
      prints the ID of the editable iOS version <x.y.z>, creating it with review type NOTARIZATION and manual
      release if there is none; refuses an existing version with another review type
  asc.py whats-new --version-id <id> --notes <file>
      writes each of the version's localizations' What's New from that language's section of the notes file
      (ReleaseNotes/<version>.md); refuses, before writing anything, a localization whose language has no section
  asc.py attach-build --version-id <id> --build-id <id>
      sets the version's build
  asc.py submit --app <id> --version-id <id>
      adds the version to the app's open review submission (creating one if needed), submits it and prints the
      submission's ID

The `--app` ID is the app's Apple ID in App Store Connect, the same number as the PAL source's `marketplaceID`.

Environment:
  APP_STORE_CONNECT_KEY_ID    the ID of an individual API key (owner decision, 2026-11-26)
  ASC_KEY_PATH                the key's `.p8` file
  ASC_CALL_RECORD             optional: a file each call is appended to as one JSON line
  ASC_BASE_URL                optional: the API's base URL (tests point it at a local fake)

Each call is logged on stderr as `ASC <method> <path> <status> key=<id>` and, with ASC_CALL_RECORD, recorded as
{"method", "path", "status", "keyID"}: the run's record of which key made each call (D-21). Each part of an upload goes
to the storage URL App Store Connect gave for it, with only the headers it listed and never the API token; it is
logged as `UPLOAD PUT <url> <status> part=<n>` and recorded as {"method", "url", "status", "part"}, the URL without
its query, which holds the URL's signature. No token, key, query or body is ever logged or recorded. Results (IDs) go
to stdout, one per line.

The client refuses every endpoint outside `ALLOWED`, which holds exactly the calls these commands make. In particular
it can never create an app, bundle ID, certificate, profile, user or key: those are account actions for the
collaborator (D-07). An upload's parts go only to the URLs App Store Connect returned for that upload in the same run,
and only over https.
"""

import argparse
import base64
import dataclasses
import hashlib
import http.client
import json
import os
import re
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import altstore_languages
import release_notes

DEFAULT_BASE_URL = "https://api.appstoreconnect.apple.com"
TOKEN_LIFETIME = 1200  # Apple's maximum: 20 minutes.
TOKEN_REFRESH = 900    # A long wait gets a new token well before the old one expires.
# The only hosts a local fake may use: an http API base URL, and then http upload URLs, are allowed only on these (the
# tests).
LOCAL_HOSTS = ("127.0.0.1", "localhost", "::1")
# How long one part of an upload may take.
PART_TIMEOUT = 300

# The only endpoints this client may call, as (method, path pattern): exactly what the commands below call. An ID in a
# path is letters, digits and hyphens, so it can never add a segment or a query.
ALLOWED = [
    ("GET", r"^/v1/builds$"),
    ("POST", r"^/v1/buildUploads$"),
    ("POST", r"^/v1/buildUploadFiles$"),
    ("PATCH", r"^/v1/buildUploadFiles/[A-Za-z0-9-]+$"),
    ("GET", r"^/v1/buildUploads/[A-Za-z0-9-]+$"),
    ("GET", r"^/v1/apps/[0-9]+/appStoreVersions$"),
    ("POST", r"^/v1/appStoreVersions$"),
    ("GET", r"^/v1/appStoreVersions/[A-Za-z0-9-]+/appStoreVersionLocalizations$"),
    ("PATCH", r"^/v1/appStoreVersionLocalizations/[A-Za-z0-9-]+$"),
    ("PATCH", r"^/v1/appStoreVersions/[A-Za-z0-9-]+/relationships/build$"),
    ("GET", r"^/v1/reviewSubmissions$"),
    ("POST", r"^/v1/reviewSubmissions$"),
    ("GET", r"^/v1/reviewSubmissions/[A-Za-z0-9-]+/items$"),
    ("POST", r"^/v1/reviewSubmissionItems$"),
    ("PATCH", r"^/v1/reviewSubmissions/[A-Za-z0-9-]+$"),
]

# Version states in which a version can still take a build and be submitted.
EDITABLE_VERSION_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
                           "INVALID_BINARY"}
# Review submission states: the open one that can still take items, and those that block a new submission.
OPEN_SUBMISSION_STATE = "READY_FOR_REVIEW"
BUSY_SUBMISSION_STATES = ["WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"]
# App Store Connect's limit for a version's What's New, checked before anything is written.
WHATS_NEW_LIMIT = 4000
# What the Build Upload API is told about the .ipa, as Xcode's own upload of 3.1.0 (164) told it.
IPA_ASSET_TYPE = "ASSET"
IPA_UTI = "com.apple.ipa"


class AscError(Exception):
    pass


def allowed(method, path):
    return any(method == allowed_method and re.fullmatch(pattern, path) for allowed_method, pattern in ALLOWED)


# Token

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_to_raw(der):
    """The JWT form (`r || s`, 32 bytes each) of an ECDSA P-256 signature in DER, as `openssl dgst` writes it."""
    def length_at(index):
        if index >= len(der):
            raise AscError("The signature is truncated.")
        first = der[index]
        if first < 0x80:
            return first, index + 1
        count = first & 0x7F
        if count == 0 or count > 2 or index + 1 + count > len(der):
            raise AscError("The signature has a bad length.")
        return int.from_bytes(der[index + 1:index + 1 + count], "big"), index + 1 + count

    if len(der) < 2 or der[0] != 0x30:
        raise AscError("The signature is not a DER sequence.")
    length, index = length_at(1)
    if index + length != len(der):
        raise AscError("The signature's length does not match its content.")
    parts = []
    for _ in range(2):
        if index >= len(der) or der[index] != 0x02:
            raise AscError("The signature does not hold two integers.")
        length, index = length_at(index + 1)
        value = der[index:index + length].lstrip(b"\x00")
        if index + length > len(der) or len(value) > 32:
            raise AscError("The signature's integers are out of range.")
        parts.append(value.rjust(32, b"\x00"))
        index += length
    if index != len(der):
        raise AscError("The signature has trailing bytes.")
    return parts[0] + parts[1]


def make_token(key_id, key_path, now=None):
    """An ES256 token for an individual App Store Connect API key, signed by `openssl` with the `.p8` key. An
    individual key's token has no `iss` and carries `"sub": "user"` (Apple, "Generating tokens for API requests";
    owner decision, 2026-11-26)."""
    now = int(time.time()) if now is None else int(now)
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"sub": "user", "iat": now, "exp": now + TOKEN_LIFETIME, "aud": "appstoreconnect-v1"}
    signing_input = (b64url(json.dumps(header, separators=(",", ":")).encode()) + "." +
                     b64url(json.dumps(claims, separators=(",", ":")).encode()))
    result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input.encode(),
                            capture_output=True)
    if result.returncode != 0 or not result.stdout:
        # openssl's message names the file at most; it never prints the key.
        raise AscError("openssl could not sign the token with the key at ASC_KEY_PATH.")
    return signing_input + "." + b64url(der_to_raw(result.stdout))


class TokenSource:
    def __init__(self, key_id, key_path):
        self.key_id, self.key_path = key_id, key_path
        self.token, self.made = None, 0.0

    def __call__(self):
        if self.token is None or time.time() - self.made > TOKEN_REFRESH:
            self.token, self.made = make_token(self.key_id, self.key_path), time.time()
        return self.token


# HTTP

class Client:
    def __init__(self, base_url, token, key_id, record, log):
        parsed = urllib.parse.urlsplit(base_url)
        local = parsed.scheme == "http" and parsed.hostname in LOCAL_HOSTS
        if parsed.scheme != "https" and not local:
            raise AscError(f"The API base URL must use https (got {parsed.scheme}://{parsed.hostname}).")
        self.base_url = base_url.rstrip("/")
        self.local = local
        self.token, self.key_id, self.record, self.log = token, key_id, record, log

    def note(self, method, path, status):
        self.log(f"ASC {method} {path} {status} key={self.key_id}")
        if self.record:
            with open(self.record, "a", encoding="utf-8") as handle:
                handle.write(json.dumps({"method": method, "path": path, "status": status,
                                         "keyID": self.key_id}) + "\n")

    def note_part(self, part, status):
        self.log(f"UPLOAD PUT {part.public} {status} part={part.number}")
        if self.record:
            with open(self.record, "a", encoding="utf-8") as handle:
                handle.write(json.dumps({"method": "PUT", "url": part.public, "status": status,
                                         "part": part.number}) + "\n")

    def request(self, method, path, query=None, body=None, attempts=3):
        if not allowed(method, path):
            raise AscError(f"{method} {path} is not on the client's allow-list.")
        url = self.base_url + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        data = json.dumps(body).encode() if body is not None else None
        for attempt in range(1, attempts + 1):
            request = urllib.request.Request(url, data=data, method=method)
            request.add_header("Authorization", "Bearer " + self.token())
            request.add_header("Accept", "application/json")
            if data is not None:
                request.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    status, raw = response.status, response.read()
            except urllib.error.HTTPError as error:
                status, raw = error.code, error.read()
            except urllib.error.URLError as error:
                self.note(method, path, 0)
                if method == "GET" and attempt < attempts:
                    time.sleep(attempt * 5)
                    continue
                raise AscError(f"{method} {path} failed: {error.reason}") from None
            self.note(method, path, status)
            # Only reads are retried; a create is never sent twice.
            if method == "GET" and (status == 429 or status >= 500) and attempt < attempts:
                time.sleep(attempt * 5)
                continue
            payload = json.loads(raw) if raw else None
            if status >= 400:
                raise AscError(f"{method} {path} returned {status}: {describe_errors(payload)}")
            return payload
        raise AscError(f"{method} {path} failed after {attempts} attempts.")

    def send_part(self, part, data):
        """PUTs one part to the storage URL App Store Connect gave for it: only the headers it listed, plus Host and
        Content-Length when it did not list them, and never the API token. No redirect is followed, and the reply's
        body is never shown: a storage error can echo the signature."""
        parsed = urllib.parse.urlsplit(part.url)
        if parsed.scheme == "https":
            connection = http.client.HTTPSConnection(parsed.hostname, parsed.port, timeout=PART_TIMEOUT,
                                                     context=ssl.create_default_context())
        else:
            connection = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=PART_TIMEOUT)
        target = (parsed.path or "/") + ("?" + parsed.query if parsed.query else "")
        listed = {name.lower() for name, _ in part.headers}
        try:
            connection.putrequest("PUT", target, skip_host=True, skip_accept_encoding=True)
            if "host" not in listed:
                connection.putheader("Host", parsed.netloc)
            for name, value in part.headers:
                connection.putheader(name, value)
            if "content-length" not in listed:
                connection.putheader("Content-Length", str(len(data)))
            connection.endheaders(message_body=data)
            response = connection.getresponse()
            response.read()
            status = response.status
        except (OSError, http.client.HTTPException) as error:
            self.note_part(part, 0)
            raise AscError(f"PUT {part.public} failed: {type(error).__name__}; the file was not marked "
                           f"uploaded.") from None
        finally:
            connection.close()
        self.note_part(part, status)
        if not 200 <= status < 300:
            raise AscError(f"PUT {part.public} returned {status}; the file was not marked uploaded.")


def describe_errors(payload):
    if not isinstance(payload, dict) or not payload.get("errors"):
        return "no details"
    return "; ".join(" ".join(str(error.get(key)) for key in ("code", "title", "detail") if error.get(key))
                     for error in payload["errors"])


# Upload

@dataclasses.dataclass(frozen=True)
class Part:
    """One upload operation, checked: the byte range it takes, where it goes and the headers App Store Connect listed
    for it. `public` is the URL without its query, for the log, the record and errors."""
    number: int
    offset: int
    length: int
    url: str
    public: str
    headers: tuple


def check_part_url(url, local):
    """The URL of an upload operation without its query (the query holds the signature), or AscError. It must use
    https; http is allowed only on a loopback host, and only while the API itself is a local fake (`local`)."""
    if not isinstance(url, str):
        raise AscError("An upload operation has no URL. Nothing was uploaded.")
    parsed = urllib.parse.urlsplit(url)
    if parsed.username or parsed.password:
        raise AscError("An upload operation's URL carries a user name or password. Nothing was uploaded.")
    if not parsed.hostname:
        raise AscError("An upload operation's URL has no host. Nothing was uploaded.")
    try:
        parsed.port
    except ValueError:
        raise AscError("An upload operation's URL has a bad port. Nothing was uploaded.") from None
    if parsed.scheme != "https" and not (local and parsed.scheme == "http" and parsed.hostname in LOCAL_HOSTS):
        raise AscError(f"An upload operation's URL must use https, not {parsed.scheme or 'no scheme'} on "
                       f"{parsed.hostname}. Nothing was uploaded.")
    return f"{parsed.scheme}://{parsed.netloc}{parsed.path}"


def upload_parts(operations, size, local):
    """The upload operations App Store Connect gave for a file of `size` bytes, checked before any byte is sent, in
    file order."""
    if not isinstance(operations, list) or not operations:
        raise AscError("App Store Connect gave no upload operations for the file. Nothing was uploaded.")
    publics = [check_part_url(operation.get("url"), local) for operation in operations]
    ordered = sorted(zip(operations, publics), key=lambda pair: pair[0]["offset"])
    return [Part(number=number, offset=operation["offset"], length=operation["length"], url=operation["url"],
                 public=public,
                 headers=tuple((header["name"], header["value"]) for header in operation.get("requestHeaders") or []))
            for number, (operation, public) in enumerate(ordered, start=1)]


def describe_upload_issues(details):
    kinds = []
    for kind in ("errors", "warnings"):
        entries = (details or {}).get(kind) or []
        if entries:
            kinds.append(f"{kind}: " + "; ".join(f"{entry.get('code')}: {entry.get('description')}"
                                                 for entry in entries))
    return " ".join(kinds) or "Apple gave no errors or warnings."


# Commands

def find_builds(client, app, version, build=None):
    query = {"filter[app]": app, "filter[preReleaseVersion.version]": version, "limit": "200"}
    if build is not None:
        query["filter[version]"] = build
    return (client.request("GET", "/v1/builds", query) or {}).get("data") or []


def check_build(client, args):
    builds = find_builds(client, args.app, args.version)
    numbers = [item["attributes"].get("version") for item in builds]
    if args.build in numbers:
        raise AscError(f"Build {args.build} of version {args.version} was already uploaded to App Store Connect; "
                       f"build numbers are single-use. Bump the build number and release again.")
    listed = ", ".join(sorted(numbers, key=lambda n: int(n) if n and n.isdigit() else 0)) or "none"
    print(f"Build {args.build} of version {args.version} is new to App Store Connect (listed: {listed}).",
          file=sys.stderr)


def upload(client, args, sleep=time.sleep):
    """Owner decision 2 (2026-11-26): the build goes up through the Build Upload API, not xcodebuild or altool. Only
    the .ipa is sent (ASSET, com.apple.ipa), part by part as App Store Connect's upload operations say, with the MD5
    checksums of the file and of its parts; then the build upload is polled until App Store Connect reports it
    COMPLETE or FAILED."""
    if not os.path.isfile(args.ipa) or os.path.getsize(args.ipa) <= 0:
        raise AscError(f"{args.ipa} is not a file with content.")
    size = os.path.getsize(args.ipa)
    body = {"data": {"type": "buildUploads",
                     "attributes": {"cfBundleShortVersionString": args.version, "cfBundleVersion": args.build,
                                    "platform": "IOS"},
                     "relationships": {"app": {"data": {"type": "apps", "id": args.app}}}}}
    upload_id = client.request("POST", "/v1/buildUploads", body=body)["data"]["id"]
    print(f"Created build upload {upload_id} for {args.version} ({args.build}).", file=sys.stderr)
    body = {"data": {"type": "buildUploadFiles",
                     "attributes": {"assetType": IPA_ASSET_TYPE, "fileName": os.path.basename(args.ipa),
                                    "fileSize": size, "uti": IPA_UTI},
                     "relationships": {"buildUpload": {"data": {"type": "buildUploads", "id": upload_id}}}}}
    created = client.request("POST", "/v1/buildUploadFiles", body=body)["data"]
    file_id = created["id"]
    parts = upload_parts((created.get("attributes") or {}).get("uploadOperations"), size, client.local)
    whole, digests = hashlib.md5(usedforsecurity=False), []
    with open(args.ipa, "rb") as handle:
        for part in parts:
            handle.seek(part.offset)
            data = handle.read(part.length)
            if len(data) < part.length:
                raise AscError(f"{args.ipa} changed while it was uploaded; the file was not marked uploaded.")
            whole.update(data)
            digests.append(hashlib.md5(data, usedforsecurity=False).digest())
            client.send_part(part, data)
    # As Xcode's own upload reported them: the composite is the MD5 of the parts' raw MD5 digests, the part count and
    # the part size (the whole size for one part).
    composite = hashlib.md5(b"".join(digests), usedforsecurity=False).hexdigest()
    body = {"data": {"type": "buildUploadFiles", "id": file_id, "attributes": {
        "uploaded": True,
        "sourceFileChecksums": {"file": {"algorithm": "MD5", "hash": whole.hexdigest()},
                                "composite": {"algorithm": "MD5",
                                              "hash": f"{composite}-{len(parts)}-{parts[0].length}"}}}}}
    client.request("PATCH", f"/v1/buildUploadFiles/{file_id}", body=body)
    deadline = time.monotonic() + args.timeout
    last = None
    while True:
        payload = client.request("GET", f"/v1/buildUploads/{upload_id}") or {}
        state = ((payload.get("data") or {}).get("attributes") or {}).get("state") or {}
        last = state.get("state") or last
        if last == "COMPLETE":
            for kind in ("warnings", "infos"):
                for entry in state.get(kind) or []:
                    print(f"Apple: {entry.get('code')}: {entry.get('description')}", file=sys.stderr)
            print(f"Build upload {upload_id} is COMPLETE.", file=sys.stderr)
            print(upload_id)
            return
        if last == "FAILED":
            raise AscError(f"Build upload {upload_id} FAILED in App Store Connect. {describe_upload_issues(state)}")
        if time.monotonic() + args.interval > deadline:
            raise AscError(f"Waiting for build upload {upload_id} timed out after {args.timeout:g}s; its last state "
                           f"was {last}.")
        sleep(args.interval)


def wait_build(client, args, sleep=time.sleep):
    deadline = time.monotonic() + args.timeout
    state = None
    while True:
        builds = find_builds(client, args.app, args.version, args.build)
        if builds:
            item = builds[0]
            state = item["attributes"].get("processingState")
            if state == "VALID":
                print(item["id"])
                return
            if state in ("INVALID", "FAILED"):
                raise AscError(f"Build {args.build} of version {args.version} is {state} in App Store Connect.")
        if time.monotonic() + args.interval > deadline:
            seen = f"its last state was {state}" if state else "it is not listed yet"
            raise AscError(f"Waiting for build {args.build} of version {args.version} timed out after "
                           f"{args.timeout:g}s; {seen}.")
        sleep(args.interval)


def find_versions(client, app, version):
    query = {"filter[platform]": "IOS", "filter[versionString]": version, "limit": "10"}
    return (client.request("GET", f"/v1/apps/{app}/appStoreVersions", query) or {}).get("data") or []


def ensure_version(client, args):
    for item in find_versions(client, args.app, args.version):
        attributes = item.get("attributes", {})
        if attributes.get("versionString") != args.version:
            continue
        state = attributes.get("appVersionState") or attributes.get("appStoreState")
        if state not in EDITABLE_VERSION_STATES:
            raise AscError(f"Version {args.version} is {state} in App Store Connect and cannot take a new build.")
        review_type = attributes.get("reviewType")
        if review_type != "NOTARIZATION":
            raise AscError(f"Version {args.version} exists with review type {review_type}, not NOTARIZATION. "
                           f"Change it in App Store Connect, or remove it, before submitting.")
        print(f"Reusing version {args.version} ({state}).", file=sys.stderr)
        print(item["id"])
        return
    body = {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": args.version, "reviewType": "NOTARIZATION",
                       "releaseType": "MANUAL"},
        "relationships": {"app": {"data": {"type": "apps", "id": args.app}}},
    }}
    created = client.request("POST", "/v1/appStoreVersions", body=body)
    print(f"Created version {args.version} for notarization.", file=sys.stderr)
    print(created["data"]["id"])


def whats_new(client, args):
    """Owner decision 3 (2026-11-26): each localization of the version gets its language's section of the release
    notes, matched as AltStore matches a language (`altstore_languages.localized_value`). A localization whose
    language has none stops the run before anything is written; there is no fallback."""
    try:
        notes = release_notes.read(args.notes)
    except release_notes.NotesError as error:
        raise AscError(str(error)) from None
    path = f"/v1/appStoreVersions/{args.version_id}/appStoreVersionLocalizations"
    localizations = (client.request("GET", path, {"limit": "200"}) or {}).get("data") or []
    if not localizations:
        raise AscError(f"Version {args.version_id} has no localizations in App Store Connect, so What's New has "
                       f"nowhere to go.")
    missing, writes = [], []
    for item in localizations:
        locale = item["attributes"]["locale"]
        text = altstore_languages.localized_value(notes, [locale])
        if text is None:
            missing.append(locale)
            continue
        if len(text) > WHATS_NEW_LIMIT:
            raise AscError(f"The {locale} section of {args.notes} has {len(text)} characters; What's New takes at "
                           f"most {WHATS_NEW_LIMIT}. Nothing was written.")
        writes.append((item["id"], locale, text))
    if missing:
        raise AscError(f"{args.notes} has no section for {', '.join(missing)}, and What's New has no fallback to "
                       f"another language. Add the section, or remove that localization in App Store Connect. "
                       f"Nothing was written.")
    for localization_id, locale, text in writes:
        body = {"data": {"type": "appStoreVersionLocalizations", "id": localization_id,
                         "attributes": {"whatsNew": text}}}
        client.request("PATCH", f"/v1/appStoreVersionLocalizations/{localization_id}", body=body)
        print(f"Wrote What's New for {locale}.", file=sys.stderr)


def attach_build(client, args):
    body = {"data": {"type": "builds", "id": args.build_id}}
    client.request("PATCH", f"/v1/appStoreVersions/{args.version_id}/relationships/build", body=body)
    print(f"Attached build {args.build_id} to version {args.version_id}.", file=sys.stderr)


def submit(client, args):
    query = {"filter[app]": args.app, "filter[platform]": "IOS",
             "filter[state]": ",".join([OPEN_SUBMISSION_STATE] + BUSY_SUBMISSION_STATES), "limit": "10"}
    submissions = (client.request("GET", "/v1/reviewSubmissions", query) or {}).get("data") or []
    busy = [item for item in submissions if item["attributes"].get("state") in BUSY_SUBMISSION_STATES]
    if busy:
        raise AscError(f"Review submission {busy[0]['id']} is {busy[0]['attributes']['state']}; "
                       f"resolve it in App Store Connect before submitting again.")
    open_submissions = [item for item in submissions if item["attributes"].get("state") == OPEN_SUBMISSION_STATE]
    holds_version = False
    if open_submissions:
        submission_id = open_submissions[0]["id"]
        items = (client.request("GET", f"/v1/reviewSubmissions/{submission_id}/items",
                                {"include": "appStoreVersion", "limit": "50"}) or {}).get("data") or []
        holds_version = any(((item.get("relationships") or {}).get("appStoreVersion") or {}).get("data", {})
                            .get("id") == args.version_id for item in items)
    else:
        body = {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                         "relationships": {"app": {"data": {"type": "apps", "id": args.app}}}}}
        submission_id = client.request("POST", "/v1/reviewSubmissions", body=body)["data"]["id"]
    if not holds_version:
        body = {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": args.version_id}},
        }}}
        client.request("POST", "/v1/reviewSubmissionItems", body=body)
    body = {"data": {"type": "reviewSubmissions", "id": submission_id, "attributes": {"submitted": True}}}
    client.request("PATCH", f"/v1/reviewSubmissions/{submission_id}", body=body)
    print(f"Submitted review submission {submission_id}.", file=sys.stderr)
    print(submission_id)


def parse(argv):
    parser = argparse.ArgumentParser(description="App Store Connect calls for the AltStore PAL upload and its "
                                                 "notarization submission.")
    commands = parser.add_subparsers(dest="command", required=True)

    def number(text):
        if not re.fullmatch(r"[0-9]+", text):
            raise argparse.ArgumentTypeError(f"{text!r} is not a whole number")
        return text

    def version(text):
        if not re.fullmatch(r"[0-9]+(\.[0-9]+){1,2}", text):
            raise argparse.ArgumentTypeError(f"{text!r} is not a version like 3.0.0")
        return text

    def identifier(text):
        if not re.fullmatch(r"[A-Za-z0-9-]+", text):
            raise argparse.ArgumentTypeError(f"{text!r} is not an App Store Connect ID")
        return text

    for name in ("check-build", "upload", "wait-build"):
        command = commands.add_parser(name)
        command.add_argument("--app", required=True, type=number)
        command.add_argument("--version", required=True, type=version)
        command.add_argument("--build", required=True, type=number)
        if name == "upload":
            command.add_argument("--ipa", required=True)
            command.add_argument("--timeout", type=float, default=3600.0)
            command.add_argument("--interval", type=float, default=15.0)
        if name == "wait-build":
            command.add_argument("--timeout", type=float, default=3600.0)
            command.add_argument("--interval", type=float, default=30.0)
    command = commands.add_parser("ensure-version")
    command.add_argument("--app", required=True, type=number)
    command.add_argument("--version", required=True, type=version)
    command = commands.add_parser("whats-new")
    command.add_argument("--version-id", required=True, type=identifier)
    command.add_argument("--notes", required=True)
    command = commands.add_parser("attach-build")
    command.add_argument("--version-id", required=True, type=identifier)
    command.add_argument("--build-id", required=True, type=identifier)
    command = commands.add_parser("submit")
    command.add_argument("--app", required=True, type=number)
    command.add_argument("--version-id", required=True, type=identifier)
    return parser.parse_args(argv)


COMMANDS = {"check-build": check_build, "upload": upload, "wait-build": wait_build,
            "ensure-version": ensure_version, "whats-new": whats_new, "attach-build": attach_build,
            "submit": submit}


def main(argv=None):
    args = parse(sys.argv[1:] if argv is None else argv)
    try:
        missing = [name for name in ("APP_STORE_CONNECT_KEY_ID", "ASC_KEY_PATH") if not os.environ.get(name)]
        if missing:
            raise AscError(f"Missing environment: {', '.join(missing)}.")
        if not os.path.isfile(os.environ["ASC_KEY_PATH"]):
            raise AscError("ASC_KEY_PATH does not name a file.")
        key_id = os.environ["APP_STORE_CONNECT_KEY_ID"]
        client = Client(os.environ.get("ASC_BASE_URL") or DEFAULT_BASE_URL,
                        token=TokenSource(key_id, os.environ["ASC_KEY_PATH"]),
                        key_id=key_id,
                        record=os.environ.get("ASC_CALL_RECORD") or None,
                        log=lambda line: print(line, file=sys.stderr, flush=True))
        COMMANDS[args.command](client, args)
    except AscError as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
