"""The App Store Connect client (`asc.py`) against a local fake server (Phase 20 plan 20-04; D-07, D-21).

Nothing here reaches Apple: the client runs with its base URL pointed at an `http.server` on 127.0.0.1 and a
P-256 key made for the test. The tests check the token, the build check's request (App Store Connect
OpenAPI 4.6), the endpoint allow-list, and that neither the key nor a token ever reaches the logs or the call
record. Since 2026-11-21 (owner decision) the client makes only that check; the submission is the collaborator's,
by hand.
"""

import base64
import http.server
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.parse

TOOLS = pathlib.Path(__file__).resolve().parents[1]
ASC = TOOLS / "asc.py"
sys.path.insert(0, str(TOOLS))

import asc  # noqa: E402

OPENSSL = shutil.which("openssl")
KEY_ID = "FAKEKEY123"
ISSUER_ID = "00000000-0000-4000-8000-000000000000"
ROLE = "APP_MANAGER"
APP_ID = "1234567890"


def b64url_decode(text):
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def der_from_raw(raw):
    """The DER `ECDSA-Sig-Value` for a JWT's raw `r || s`, which is what `openssl dgst -verify` reads."""
    def integer(value):
        value = value.lstrip(b"\x00") or b"\x00"
        if value[0] & 0x80:
            value = b"\x00" + value
        return b"\x02" + bytes([len(value)]) + value
    body = integer(raw[:32]) + integer(raw[32:])
    return b"\x30" + bytes([len(body)]) + body


def make_key(directory):
    key = pathlib.Path(directory) / f"AuthKey_{KEY_ID}.p8"
    pem = subprocess.run([OPENSSL, "ecparam", "-name", "prime256v1", "-genkey", "-noout"], capture_output=True,
                         check=True).stdout
    pkcs8 = subprocess.run([OPENSSL, "pkcs8", "-topk8", "-nocrypt"], input=pem, capture_output=True,
                           check=True).stdout
    key.write_bytes(pkcs8)
    return key


class FakeASC:
    """A local App Store Connect stand-in. `routes` maps (method, path) to a list of (status, body) replies;
    each call takes the first reply and the last one repeats. Every request is kept in `requests`."""

    def __init__(self):
        self.routes = {}
        self.requests = []
        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def handle_any(self):
                parsed = urllib.parse.urlsplit(self.path)
                length = int(self.headers.get("Content-Length") or 0)
                raw = self.rfile.read(length) if length else b""
                fake.requests.append({
                    "method": self.command,
                    "path": parsed.path,
                    "query": urllib.parse.parse_qs(parsed.query),
                    "authorization": self.headers.get("Authorization", ""),
                    "body": json.loads(raw) if raw else None,
                })
                replies = fake.routes.get((self.command, parsed.path))
                if not replies:
                    status, body = 404, {"errors": [{"status": "404", "title": "Not found", "detail": parsed.path}]}
                else:
                    status, body = replies[0] if len(replies) == 1 else replies.pop(0)
                payload = json.dumps(body).encode() if body is not None else b""
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.server.server_address[1]}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


def build(build_id, number, state):
    return {"type": "builds", "id": build_id, "attributes": {"version": number, "processingState": state}}


@unittest.skipUnless(OPENSSL, "openssl is not installed")
class TokenTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.key = make_key(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_the_token_verifies_with_openssl(self):
        token = asc.make_token(KEY_ID, ISSUER_ID, str(self.key), now=1_800_000_000)
        header_b64, claims_b64, signature_b64 = token.split(".")
        header = json.loads(b64url_decode(header_b64))
        claims = json.loads(b64url_decode(claims_b64))
        self.assertEqual(header, {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"})
        self.assertEqual(claims["iss"], ISSUER_ID)
        self.assertEqual(claims["aud"], "appstoreconnect-v1")
        self.assertEqual(claims["iat"], 1_800_000_000)
        self.assertEqual(claims["exp"] - claims["iat"], 1200)

        raw = b64url_decode(signature_b64)
        self.assertEqual(len(raw), 64)
        directory = pathlib.Path(self.tmp.name)
        (directory / "signature.der").write_bytes(der_from_raw(raw))
        (directory / "input").write_bytes(f"{header_b64}.{claims_b64}".encode())
        public = subprocess.run([OPENSSL, "ec", "-pubout", "-in", str(self.key)], capture_output=True,
                                check=True).stdout
        (directory / "public.pem").write_bytes(public)
        result = subprocess.run([OPENSSL, "dgst", "-sha256", "-verify", str(directory / "public.pem"),
                                 "-signature", str(directory / "signature.der"), str(directory / "input")],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Verified OK", result.stdout)

    def test_a_tampered_token_does_not_verify(self):
        token = asc.make_token(KEY_ID, ISSUER_ID, str(self.key), now=1_800_000_000)
        header_b64, _, signature_b64 = token.split(".")
        other = base64.urlsafe_b64encode(json.dumps({"iss": "someone-else"}).encode()).rstrip(b"=").decode()
        directory = pathlib.Path(self.tmp.name)
        (directory / "signature.der").write_bytes(der_from_raw(b64url_decode(signature_b64)))
        (directory / "input").write_bytes(f"{header_b64}.{other}".encode())
        public = subprocess.run([OPENSSL, "ec", "-pubout", "-in", str(self.key)], capture_output=True,
                                check=True).stdout
        (directory / "public.pem").write_bytes(public)
        result = subprocess.run([OPENSSL, "dgst", "-sha256", "-verify", str(directory / "public.pem"),
                                 "-signature", str(directory / "signature.der"), str(directory / "input")],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)

    def test_der_signatures_become_raw_r_and_s(self):
        # r with a sign-padding zero byte, s shorter than 32 bytes.
        r = b"\x80" + b"\x11" * 31
        s = b"\x22" * 30
        der = b"\x30\x43" + b"\x02\x21\x00" + r + b"\x02\x1e" + s
        self.assertEqual(asc.der_to_raw(der), r + b"\x00\x00" + s)

    def test_a_malformed_signature_is_refused(self):
        for der in (b"", b"\x31\x02\x02\x00", b"\x30\x06\x02\x01\x01\x03\x01\x01"):
            with self.subTest(der=der), self.assertRaises(asc.AscError):
                asc.der_to_raw(der)


class AllowListTests(unittest.TestCase):
    def test_the_allow_list_is_the_build_read_only(self):
        self.assertEqual(asc.ALLOWED, [("GET", r"^/v1/builds$")])

    def test_the_allow_list_has_no_record_making_endpoint(self):
        # D-07: no app, bundle ID, certificate, profile, user or key is ever created by this client.
        for method, pattern in asc.ALLOWED:
            with self.subTest(method=method, pattern=pattern):
                for word in ("bundleIds", "certificates", "profiles", "users", "apiKeys", "devices",
                             "userInvitations", "alternativeDistributionKeys", "alternativeDistributionDomains"):
                    self.assertNotIn(word, pattern)
                if method != "GET":
                    self.assertFalse(re.match(pattern, "/v1/apps"), pattern)
                    self.assertNotIn("/apps", pattern)
                    self.assertNotIn("alternativeDistribution", pattern)
        self.assertFalse(asc.allowed("POST", "/v1/apps"))
        self.assertFalse(asc.allowed("PATCH", "/v1/apps/1"))
        self.assertFalse(asc.allowed("POST", "/v1/bundleIds"))
        self.assertFalse(asc.allowed("POST", "/v1/certificates"))
        self.assertFalse(asc.allowed("POST", "/v1/profiles"))
        self.assertFalse(asc.allowed("GET", "/v1/users"))
        self.assertFalse(asc.allowed("POST", "/v1/alternativeDistributionPackages"))
        self.assertFalse(asc.allowed("DELETE", "/v1/appStoreVersions/1"))

    def test_the_paths_the_client_uses_are_allowed(self):
        self.assertTrue(asc.allowed("GET", "/v1/builds"))

    def test_the_submission_steps_are_refused(self):
        for method, path in (("POST", "/v1/appStoreVersions"), ("PATCH", "/v1/appStoreVersions/1/relationships/build"),
                             ("GET", "/v1/apps/1/appStoreVersions"), ("GET", "/v1/appStoreVersions/1"),
                             ("GET", "/v1/reviewSubmissions"), ("POST", "/v1/reviewSubmissions"),
                             ("PATCH", "/v1/reviewSubmissions/1"), ("GET", "/v1/reviewSubmissions/1/items"),
                             ("POST", "/v1/reviewSubmissionItems"),
                             ("GET", "/v1/appStoreVersions/1/alternativeDistributionPackage"),
                             ("GET", "/v1/builds/1"), ("GET", "/v1/preReleaseVersions")):
            with self.subTest(method=method, path=path):
                self.assertFalse(asc.allowed(method, path))

    def test_only_the_build_check_is_a_command(self):
        self.assertEqual(set(asc.COMMANDS), {"check-build"})
        for name in ("wait-build", "ensure-version", "attach-build", "submit", "adp-id"):
            with self.subTest(command=name):
                result = subprocess.run([sys.executable, str(ASC), name], capture_output=True, text=True, timeout=60)
                self.assertEqual(result.returncode, 2)
                self.assertIn("invalid choice", result.stderr)

    def test_a_path_off_the_list_is_refused_before_any_request(self):
        fake = FakeASC()
        self.addCleanup(fake.close)
        client = asc.Client(fake.base_url, token=lambda: "unused", key_id=KEY_ID, key_role=ROLE, record=None,
                            log=lambda line: None)
        for method, path in (("POST", "/v1/apps"), ("POST", "/v1/bundleIds"), ("POST", "/v1/certificates"),
                             ("POST", "/v1/profiles"), ("GET", "/v1/users")):
            with self.subTest(method=method, path=path), self.assertRaises(asc.AscError):
                client.request(method, path)
        self.assertEqual(fake.requests, [])

    def test_the_base_url_must_be_https_unless_it_is_local(self):
        for url in ("http://api.appstoreconnect.apple.com", "ftp://127.0.0.1", "http://example.com"):
            with self.subTest(url=url), self.assertRaises(asc.AscError):
                asc.Client(url, token=lambda: "", key_id="", key_role="", record=None, log=lambda line: None)
        asc.Client("https://api.appstoreconnect.apple.com", token=lambda: "", key_id="", key_role="", record=None,
                   log=lambda line: None)
        asc.Client("http://127.0.0.1:8080", token=lambda: "", key_id="", key_role="", record=None,
                   log=lambda line: None)


@unittest.skipUnless(OPENSSL, "openssl is not installed")
class CommandTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = make_key(self.tmp.name)
        self.record = pathlib.Path(self.tmp.name) / "calls.jsonl"
        self.fake = FakeASC()
        self.addCleanup(self.fake.close)
        self.addCleanup(self.check_requests_were_allowed)

    def check_requests_were_allowed(self):
        for request in self.fake.requests:
            self.assertTrue(asc.allowed(request["method"], request["path"]), request)
            self.assertRegex(request["authorization"], r"^Bearer [\w-]+\.[\w-]+\.[\w-]+$")

    def run_asc(self, *args):
        env = {key: value for key, value in os.environ.items() if not key.startswith("ASC_")}
        env.update({"ASC_BASE_URL": self.fake.base_url, "APP_STORE_CONNECT_KEY_ID": KEY_ID, "APP_STORE_CONNECT_ISSUER_ID": ISSUER_ID,
                    "ASC_KEY_PATH": str(self.key), "APP_STORE_CONNECT_KEY_ROLE": ROLE, "ASC_CALL_RECORD": str(self.record)})
        result = subprocess.run([sys.executable, str(ASC), *args], capture_output=True, text=True, env=env,
                                timeout=60)
        self.outputs = getattr(self, "outputs", "") + result.stdout + result.stderr
        return result

    def calls(self, method=None):
        return [r for r in self.fake.requests if method is None or r["method"] == method]

    # check-build

    def test_check_build_fails_when_the_number_was_uploaded_before(self):
        self.fake.routes[("GET", "/v1/builds")] = [(200, {"data": [build("b-1", "158", "VALID"),
                                                                   build("b-2", "159", "INVALID")]})]
        result = self.run_asc("check-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159")
        self.assertEqual(result.returncode, 1)
        self.assertIn("159", result.stderr)
        self.assertEqual(self.calls()[0]["query"]["filter[preReleaseVersion.version]"], ["3.0.0"])

    def test_check_build_passes_for_a_new_number(self):
        self.fake.routes[("GET", "/v1/builds")] = [(200, {"data": [build("b-1", "158", "VALID")]})]
        result = self.run_asc("check-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159")
        self.assertEqual(result.returncode, 0, result.stderr)
        query = self.calls()[0]["query"]
        self.assertEqual(query["filter[app]"], [APP_ID])
        self.assertEqual(query["limit"], ["200"])

    def test_an_api_error_fails_with_apples_message(self):
        self.fake.routes[("GET", "/v1/builds")] = [
            (403, {"errors": [{"status": "403", "code": "FORBIDDEN_ERROR", "title": "Forbidden",
                               "detail": "The API key in use does not allow this request."}]})]
        result = self.run_asc("check-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159")
        self.assertEqual(result.returncode, 1)
        self.assertIn("403", result.stderr)
        self.assertIn("The API key in use does not allow this request.", result.stderr)

    # the call record (D-21) and the logs

    def run_build_checks(self):
        self.fake.routes[("GET", "/v1/builds")] = [(200, {"data": [build("b-1", "158", "VALID")]})]
        for number in ("159", "160"):
            result = self.run_asc("check-build", "--app", APP_ID, "--version", "3.0.0", "--build", number)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_the_call_record_has_one_line_per_call_and_only_the_allowed_fields(self):
        self.run_build_checks()
        lines = [json.loads(line) for line in self.record.read_text(encoding="utf-8").splitlines()]
        self.assertEqual(len(lines), len(self.fake.requests))
        for line, request in zip(lines, self.fake.requests):
            with self.subTest(line=line):
                self.assertEqual(set(line), {"method", "path", "status", "keyID", "keyRole"})
                self.assertEqual((line["method"], line["path"]), (request["method"], request["path"]))
                self.assertEqual(line["keyID"], KEY_ID)
                self.assertEqual(line["keyRole"], ROLE)
        self.assertEqual([line["status"] for line in lines], [200, 200])

    def test_every_call_is_logged_with_method_path_status_and_key(self):
        self.run_build_checks()
        for request in self.fake.requests:
            with self.subTest(request=request["path"]):
                self.assertRegex(self.outputs, rf"ASC {request['method']} {re.escape(request['path'])} \d{{3}} "
                                               rf"key={KEY_ID} role={ROLE}")

    def test_neither_the_key_nor_a_token_reaches_the_logs_or_the_record(self):
        self.run_build_checks()
        record = self.record.read_text(encoding="utf-8")
        tokens = {request["authorization"].removeprefix("Bearer ") for request in self.fake.requests}
        self.assertTrue(tokens)
        key_lines = [line for line in self.key.read_text().splitlines() if line and not line.startswith("-----")]
        self.assertTrue(key_lines)
        for haystack_name, haystack in (("record", record), ("stdout and stderr", self.outputs)):
            for token in tokens:
                with self.subTest(haystack=haystack_name, part="token"):
                    self.assertNotIn(token, haystack)
                    for part in token.split("."):
                        self.assertNotIn(part, haystack)
            for line in key_lines:
                with self.subTest(haystack=haystack_name, part="key"):
                    self.assertNotIn(line, haystack)
            self.assertNotIn("Bearer", haystack)
            self.assertNotIn("PRIVATE KEY", haystack)

    def test_missing_credentials_fail_before_any_request(self):
        env = {key: value for key, value in os.environ.items() if not key.startswith("ASC_")}
        env["ASC_BASE_URL"] = self.fake.base_url
        result = subprocess.run([sys.executable, str(ASC), "check-build", "--app", APP_ID, "--version", "3.0.0",
                                 "--build", "159"], capture_output=True, text=True, env=env, timeout=60)
        self.assertEqual(result.returncode, 1)
        self.assertIn("APP_STORE_CONNECT_KEY_ID", result.stderr)
        self.assertEqual(self.fake.requests, [])


if __name__ == "__main__":
    unittest.main()
