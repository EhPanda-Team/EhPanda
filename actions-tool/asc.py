#!/usr/bin/env python3
"""A small App Store Connect API client for the AltStore PAL notarization workflow (`deploy-pal.yml`).

It does the few calls a notarization submission needs and nothing else (Phase 20 D-07, D-21; App Store Connect
OpenAPI 4.6). The standard library and `openssl` are all it uses, so a release job holding signing secrets
installs nothing.

Usage:
  asc.py check-build --app <id> --version <x.y.z> --build <n>
      fails if build <n> of version <x.y.z> was uploaded before (build numbers are single-use)
  asc.py wait-build --app <id> --version <x.y.z> --build <n> [--timeout <s>] [--interval <s>]
      waits until the uploaded build is VALID and prints its ID; fails on INVALID, FAILED or timeout
  asc.py ensure-version --app <id> --version <x.y.z>
      prints the ID of the editable iOS version <x.y.z>, creating it with review type NOTARIZATION and manual
      release if there is none
  asc.py attach-build --version-id <id> --build-id <id>
      sets the version's build
  asc.py submit --app <id> --version-id <id>
      adds the version to the app's open review submission (creating one if needed), submits it and prints the
      submission's ID
  asc.py adp-id (--version-id <id> | --app <id> --version <x.y.z>)
      prints the ID of the version's alternative distribution package

The `--app` ID is the app's Apple ID in App Store Connect, the same number as the PAL source's `marketplaceID`.

Environment:
  APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID   the API key's ID and issuer
  ASC_KEY_PATH                the key's `.p8` file
  APP_STORE_CONNECT_KEY_ROLE  the key's role as recorded when it was made (informational, for the call record)
  ASC_CALL_RECORD             optional: a file each call is appended to as one JSON line
  ASC_BASE_URL                optional: the API's base URL (tests point it at a local fake)

Each call is logged on stderr as `ASC <method> <path> <status> key=<id> role=<role>` and, with ASC_CALL_RECORD,
recorded as {"method", "path", "status", "keyID", "keyRole"}: D-21 asks which key type and role made each call.
No token, key, query or body is ever logged or recorded. Results (IDs) go to stdout, one per line.

The client refuses every endpoint outside `ALLOWED`. In particular it can never create an app, bundle ID,
certificate, profile, user or key: those are account actions for the collaborator (D-07).
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_BASE_URL = "https://api.appstoreconnect.apple.com"
TOKEN_LIFETIME = 1200  # Apple's maximum: 20 minutes.
TOKEN_REFRESH = 900    # A long wait gets a new token well before the old one expires.

# The only endpoints this client may call, as (method, path pattern). Reading an app's versions is the one
# `apps` path, and it is read-only; there is no list endpoint for appStoreVersions at the top level.
ALLOWED = [
    ("GET", r"^/v1/builds$"),
    ("GET", r"^/v1/builds/[^/]+$"),
    ("GET", r"^/v1/preReleaseVersions$"),
    ("GET", r"^/v1/apps/[^/]+/appStoreVersions$"),
    ("GET", r"^/v1/appStoreVersions/[^/]+$"),
    ("POST", r"^/v1/appStoreVersions$"),
    ("PATCH", r"^/v1/appStoreVersions/[^/]+/relationships/build$"),
    ("GET", r"^/v1/appStoreVersions/[^/]+/alternativeDistributionPackage$"),
    ("GET", r"^/v1/reviewSubmissions$"),
    ("POST", r"^/v1/reviewSubmissions$"),
    ("PATCH", r"^/v1/reviewSubmissions/[^/]+$"),
    ("GET", r"^/v1/reviewSubmissions/[^/]+/items$"),
    ("POST", r"^/v1/reviewSubmissionItems$"),
]

# Version states in which a version can still take a build and be submitted.
EDITABLE_VERSION_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
                           "INVALID_BINARY"}
# Review submission states: the open one that can still take items, and those that block a new submission.
OPEN_SUBMISSION_STATE = "READY_FOR_REVIEW"
BUSY_SUBMISSION_STATES = ["WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"]


class AscError(Exception):
    pass


def allowed(method, path):
    return any(method == allowed_method and re.match(pattern, path) for allowed_method, pattern in ALLOWED)


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


def make_token(key_id, issuer_id, key_path, now=None):
    """An ES256 token for the App Store Connect API, signed by `openssl` with the `.p8` key."""
    now = int(time.time()) if now is None else int(now)
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer_id, "iat": now, "exp": now + TOKEN_LIFETIME, "aud": "appstoreconnect-v1"}
    signing_input = (b64url(json.dumps(header, separators=(",", ":")).encode()) + "." +
                     b64url(json.dumps(claims, separators=(",", ":")).encode()))
    result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input.encode(),
                            capture_output=True)
    if result.returncode != 0 or not result.stdout:
        # openssl's message names the file at most; it never prints the key.
        raise AscError("openssl could not sign the token with the key at ASC_KEY_PATH.")
    return signing_input + "." + b64url(der_to_raw(result.stdout))


class TokenSource:
    def __init__(self, key_id, issuer_id, key_path):
        self.key_id, self.issuer_id, self.key_path = key_id, issuer_id, key_path
        self.token, self.made = None, 0.0

    def __call__(self):
        if self.token is None or time.time() - self.made > TOKEN_REFRESH:
            self.token, self.made = make_token(self.key_id, self.issuer_id, self.key_path), time.time()
        return self.token


# HTTP

class Client:
    def __init__(self, base_url, token, key_id, key_role, record, log):
        parsed = urllib.parse.urlsplit(base_url)
        local = parsed.scheme == "http" and parsed.hostname in ("127.0.0.1", "localhost", "::1")
        if parsed.scheme != "https" and not local:
            raise AscError(f"The API base URL must use https (got {parsed.scheme}://{parsed.hostname}).")
        self.base_url = base_url.rstrip("/")
        self.token, self.key_id, self.key_role, self.record, self.log = token, key_id, key_role, record, log

    def note(self, method, path, status):
        self.log(f"ASC {method} {path} {status} key={self.key_id} role={self.key_role}")
        if self.record:
            with open(self.record, "a", encoding="utf-8") as handle:
                handle.write(json.dumps({"method": method, "path": path, "status": status,
                                         "keyID": self.key_id, "keyRole": self.key_role}) + "\n")

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


def describe_errors(payload):
    if not isinstance(payload, dict) or not payload.get("errors"):
        return "no details"
    return "; ".join(" ".join(str(error.get(key)) for key in ("code", "title", "detail") if error.get(key))
                     for error in payload["errors"])


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


def adp_id(client, args):
    version_id = args.version_id
    if not version_id:
        if not (args.app and args.version):
            raise AscError("adp-id needs --version-id, or --app and --version.")
        versions = [item for item in find_versions(client, args.app, args.version)
                    if item.get("attributes", {}).get("versionString") == args.version]
        if not versions:
            raise AscError(f"Version {args.version} does not exist in App Store Connect.")
        version_id = versions[0]["id"]
    package = client.request("GET", f"/v1/appStoreVersions/{version_id}/alternativeDistributionPackage")
    package_id = ((package or {}).get("data") or {}).get("id")
    if not package_id:
        raise AscError(f"Version {version_id} has no alternative distribution package yet.")
    print(package_id)


def parse(argv):
    parser = argparse.ArgumentParser(description="App Store Connect calls for the PAL notarization workflow.")
    commands = parser.add_subparsers(dest="command", required=True)

    def number(text):
        if not re.fullmatch(r"[0-9]+", text):
            raise argparse.ArgumentTypeError(f"{text!r} is not a whole number")
        return text

    def version(text):
        if not re.fullmatch(r"[0-9]+(\.[0-9]+){1,2}", text):
            raise argparse.ArgumentTypeError(f"{text!r} is not a version like 3.0.0")
        return text

    for name in ("check-build", "wait-build"):
        command = commands.add_parser(name)
        command.add_argument("--app", required=True, type=number)
        command.add_argument("--version", required=True, type=version)
        command.add_argument("--build", required=True, type=number)
        if name == "wait-build":
            command.add_argument("--timeout", type=float, default=3600.0)
            command.add_argument("--interval", type=float, default=30.0)
    command = commands.add_parser("ensure-version")
    command.add_argument("--app", required=True, type=number)
    command.add_argument("--version", required=True, type=version)
    command = commands.add_parser("attach-build")
    command.add_argument("--version-id", required=True)
    command.add_argument("--build-id", required=True)
    command = commands.add_parser("submit")
    command.add_argument("--app", required=True, type=number)
    command.add_argument("--version-id", required=True)
    command = commands.add_parser("adp-id")
    command.add_argument("--version-id")
    command.add_argument("--app", type=number)
    command.add_argument("--version", type=version)
    return parser.parse_args(argv)


COMMANDS = {"check-build": check_build, "wait-build": wait_build, "ensure-version": ensure_version,
            "attach-build": attach_build, "submit": submit, "adp-id": adp_id}


def main(argv=None):
    args = parse(sys.argv[1:] if argv is None else argv)
    try:
        missing = [name for name in ("APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID", "ASC_KEY_PATH") if not os.environ.get(name)]
        if missing:
            raise AscError(f"Missing environment: {', '.join(missing)}.")
        if not os.path.isfile(os.environ["ASC_KEY_PATH"]):
            raise AscError("ASC_KEY_PATH does not name a file.")
        key_id = os.environ["APP_STORE_CONNECT_KEY_ID"]
        client = Client(os.environ.get("ASC_BASE_URL") or DEFAULT_BASE_URL,
                        token=TokenSource(key_id, os.environ["APP_STORE_CONNECT_ISSUER_ID"], os.environ["ASC_KEY_PATH"]),
                        key_id=key_id, key_role=os.environ.get("APP_STORE_CONNECT_KEY_ROLE") or "unrecorded",
                        record=os.environ.get("ASC_CALL_RECORD") or None,
                        log=lambda line: print(line, file=sys.stderr, flush=True))
        COMMANDS[args.command](client, args)
    except AscError as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
