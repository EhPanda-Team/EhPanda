#!/usr/bin/env python3
"""A small App Store Connect API client for the AltStore PAL upload (the `AltStorePAL` job of `deploy.yml`).

It makes the one call that job needs and nothing else (Phase 20 D-07, D-21; App Store Connect OpenAPI 4.6): before
the archive, it checks that the build number is still unused. The job uploads the build with xcodebuild and stops;
the collaborator creates the version, attaches the build and submits it in App Store Connect (owner decision,
2026-11-21). The standard library and `openssl` are all it uses, so a release job holding signing secrets installs
nothing.

Usage:
  asc.py check-build --app <id> --version <x.y.z> --build <n>
      fails if build <n> of version <x.y.z> was uploaded before (build numbers are single-use)

The `--app` ID is the app's Apple ID in App Store Connect, the same number as the PAL source's `marketplaceID`.

Environment:
  APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID   the API key's ID and issuer
  ASC_KEY_PATH                the key's `.p8` file
  ASC_CALL_RECORD             optional: a file each call is appended to as one JSON line
  ASC_BASE_URL                optional: the API's base URL (tests point it at a local fake)

Each call is logged on stderr as `ASC <method> <path> <status> key=<id>` and, with ASC_CALL_RECORD, recorded as
{"method", "path", "status", "keyID"}: the run's record of which key made each call (D-21).
No token, key, query or body is ever logged or recorded. Results (IDs) go to stdout, one per line.

The client refuses every endpoint outside `ALLOWED`, which holds only that build read. In particular it can never
create an app, bundle ID, certificate, profile, user or key: those are account actions for the collaborator (D-07).
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
TOKEN_REFRESH = 900    # A token is replaced well before it expires.

# The only endpoint this client may call, as (method, path pattern): the build list check-build reads.
ALLOWED = [
    ("GET", r"^/v1/builds$"),
]


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
    def __init__(self, base_url, token, key_id, record, log):
        parsed = urllib.parse.urlsplit(base_url)
        local = parsed.scheme == "http" and parsed.hostname in ("127.0.0.1", "localhost", "::1")
        if parsed.scheme != "https" and not local:
            raise AscError(f"The API base URL must use https (got {parsed.scheme}://{parsed.hostname}).")
        self.base_url = base_url.rstrip("/")
        self.token, self.key_id, self.record, self.log = token, key_id, record, log

    def note(self, method, path, status):
        self.log(f"ASC {method} {path} {status} key={self.key_id}")
        if self.record:
            with open(self.record, "a", encoding="utf-8") as handle:
                handle.write(json.dumps({"method": method, "path": path, "status": status,
                                         "keyID": self.key_id}) + "\n")

    def request(self, method, path, query=None, attempts=3):
        if not allowed(method, path):
            raise AscError(f"{method} {path} is not on the client's allow-list.")
        url = self.base_url + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        for attempt in range(1, attempts + 1):
            request = urllib.request.Request(url, method=method)
            request.add_header("Authorization", "Bearer " + self.token())
            request.add_header("Accept", "application/json")
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

def check_build(client, args):
    query = {"filter[app]": args.app, "filter[preReleaseVersion.version]": args.version, "limit": "200"}
    builds = (client.request("GET", "/v1/builds", query) or {}).get("data") or []
    numbers = [item["attributes"].get("version") for item in builds]
    if args.build in numbers:
        raise AscError(f"Build {args.build} of version {args.version} was already uploaded to App Store Connect; "
                       f"build numbers are single-use. Bump the build number and release again.")
    listed = ", ".join(sorted(numbers, key=lambda n: int(n) if n and n.isdigit() else 0)) or "none"
    print(f"Build {args.build} of version {args.version} is new to App Store Connect (listed: {listed}).",
          file=sys.stderr)


def parse(argv):
    parser = argparse.ArgumentParser(description="App Store Connect's build check for the AltStore PAL upload.")
    commands = parser.add_subparsers(dest="command", required=True)

    def number(text):
        if not re.fullmatch(r"[0-9]+", text):
            raise argparse.ArgumentTypeError(f"{text!r} is not a whole number")
        return text

    def version(text):
        if not re.fullmatch(r"[0-9]+(\.[0-9]+){1,2}", text):
            raise argparse.ArgumentTypeError(f"{text!r} is not a version like 3.0.0")
        return text

    command = commands.add_parser("check-build")
    command.add_argument("--app", required=True, type=number)
    command.add_argument("--version", required=True, type=version)
    command.add_argument("--build", required=True, type=number)
    return parser.parse_args(argv)


COMMANDS = {"check-build": check_build}


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
