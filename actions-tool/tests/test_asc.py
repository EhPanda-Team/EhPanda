"""The App Store Connect client (`asc.py`) against a local fake server (Phase 20 plan 20-04; D-07, D-21).

Nothing here reaches Apple: the client runs with its base URL pointed at an `http.server` on 127.0.0.1 and a
P-256 key made for the test. The tests check the token, the request sequence and bodies (App Store Connect
OpenAPI 4.6), the endpoint allow-list, and that neither the key nor a token ever reaches the logs or the call
record.
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


def version(version_id, string, state, review_type="NOTARIZATION"):
    return {"type": "appStoreVersions", "id": version_id,
            "attributes": {"platform": "IOS", "versionString": string, "appVersionState": state,
                           "reviewType": review_type, "releaseType": "MANUAL"}}


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
    def test_the_allow_list_names_only_the_submit_and_read_endpoints(self):
        families = ("builds", "preReleaseVersions", "appStoreVersions", "reviewSubmissions",
                    "reviewSubmissionItems", "alternativeDistributionPackage")
        for method, pattern in asc.ALLOWED:
            with self.subTest(method=method, pattern=pattern):
                self.assertIn(method, ("GET", "POST", "PATCH"))
                self.assertTrue(pattern.startswith("^/v1/"))
                self.assertTrue(any(f"/{family}" in pattern for family in families), pattern)

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
        for method, path in (("GET", "/v1/builds"), ("GET", "/v1/apps/1/appStoreVersions"),
                             ("POST", "/v1/appStoreVersions"), ("PATCH", "/v1/appStoreVersions/1/relationships/build"),
                             ("GET", "/v1/reviewSubmissions"), ("POST", "/v1/reviewSubmissions"),
                             ("GET", "/v1/reviewSubmissions/1/items"), ("POST", "/v1/reviewSubmissionItems"),
                             ("PATCH", "/v1/reviewSubmissions/1"),
                             ("GET", "/v1/appStoreVersions/1/alternativeDistributionPackage")):
            with self.subTest(method=method, path=path):
                self.assertTrue(asc.allowed(method, path))

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

    # wait-build

    def test_wait_build_polls_until_the_build_is_valid(self):
        self.fake.routes[("GET", "/v1/builds")] = [
            (200, {"data": []}),
            (200, {"data": [build("b-1", "159", "PROCESSING")]}),
            (200, {"data": [build("b-1", "159", "VALID")]}),
        ]
        result = self.run_asc("wait-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159",
                              "--interval", "0", "--timeout", "30")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "b-1")
        self.assertEqual(len(self.calls()), 3)
        query = self.calls()[0]["query"]
        self.assertEqual(query["filter[app]"], [APP_ID])
        self.assertEqual(query["filter[version]"], ["159"])
        self.assertEqual(query["filter[preReleaseVersion.version]"], ["3.0.0"])

    def test_wait_build_fails_on_an_invalid_build(self):
        for state in ("INVALID", "FAILED"):
            with self.subTest(state=state):
                self.fake.routes[("GET", "/v1/builds")] = [(200, {"data": [build("b-1", "159", state)]})]
                result = self.run_asc("wait-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159",
                                      "--interval", "0", "--timeout", "30")
                self.assertEqual(result.returncode, 1)
                self.assertIn(state, result.stderr)
                self.assertEqual(result.stdout, "")

    def test_wait_build_times_out_with_the_last_state(self):
        self.fake.routes[("GET", "/v1/builds")] = [(200, {"data": [build("b-1", "159", "PROCESSING")]})]
        result = self.run_asc("wait-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159",
                              "--interval", "0.05", "--timeout", "0.3")
        self.assertEqual(result.returncode, 1)
        self.assertIn("PROCESSING", result.stderr)
        self.assertIn("timed out", result.stderr)

    def test_wait_build_times_out_when_the_build_never_appears(self):
        self.fake.routes[("GET", "/v1/builds")] = [(200, {"data": []})]
        result = self.run_asc("wait-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159",
                              "--interval", "0.05", "--timeout", "0.3")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not listed", result.stderr)

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

    # ensure-version

    def test_ensure_version_creates_a_notarization_version_with_manual_release(self):
        self.fake.routes[("GET", f"/v1/apps/{APP_ID}/appStoreVersions")] = [(200, {"data": []})]
        self.fake.routes[("POST", "/v1/appStoreVersions")] = [
            (201, {"data": version("v-1", "3.0.0", "PREPARE_FOR_SUBMISSION")})]
        result = self.run_asc("ensure-version", "--app", APP_ID, "--version", "3.0.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "v-1")
        query = self.calls("GET")[0]["query"]
        self.assertEqual(query["filter[platform]"], ["IOS"])
        self.assertEqual(query["filter[versionString]"], ["3.0.0"])
        self.assertEqual(self.calls("POST")[0]["body"], {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": "3.0.0", "reviewType": "NOTARIZATION",
                           "releaseType": "MANUAL"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }})

    def test_ensure_version_reuses_an_editable_version(self):
        for state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"):
            with self.subTest(state=state):
                self.fake.requests.clear()
                self.fake.routes[("GET", f"/v1/apps/{APP_ID}/appStoreVersions")] = [
                    (200, {"data": [version("v-7", "3.0.0", state)]})]
                result = self.run_asc("ensure-version", "--app", APP_ID, "--version", "3.0.0")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "v-7")
                self.assertEqual(self.calls("POST"), [])

    def test_ensure_version_refuses_a_version_in_review_or_done(self):
        for state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "ACCEPTED", "READY_FOR_DISTRIBUTION"):
            with self.subTest(state=state):
                self.fake.requests.clear()
                self.fake.routes[("GET", f"/v1/apps/{APP_ID}/appStoreVersions")] = [
                    (200, {"data": [version("v-7", "3.0.0", state)]})]
                result = self.run_asc("ensure-version", "--app", APP_ID, "--version", "3.0.0")
                self.assertEqual(result.returncode, 1)
                self.assertIn(state, result.stderr)
                self.assertEqual(self.calls("POST"), [])

    def test_ensure_version_refuses_an_app_store_review_version(self):
        self.fake.routes[("GET", f"/v1/apps/{APP_ID}/appStoreVersions")] = [
            (200, {"data": [version("v-7", "3.0.0", "PREPARE_FOR_SUBMISSION", review_type="APP_STORE")]})]
        result = self.run_asc("ensure-version", "--app", APP_ID, "--version", "3.0.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("APP_STORE", result.stderr)
        self.assertEqual(self.calls("POST"), [])

    def test_an_api_error_fails_with_apples_message(self):
        self.fake.routes[("GET", f"/v1/apps/{APP_ID}/appStoreVersions")] = [(200, {"data": []})]
        self.fake.routes[("POST", "/v1/appStoreVersions")] = [
            (409, {"errors": [{"status": "409", "code": "ENTITY_ERROR", "title": "Conflict",
                               "detail": "Another version is editable."}]})]
        result = self.run_asc("ensure-version", "--app", APP_ID, "--version", "3.0.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("409", result.stderr)
        self.assertIn("Another version is editable.", result.stderr)

    # attach-build

    def test_attach_build_links_the_build_to_the_version(self):
        self.fake.routes[("PATCH", "/v1/appStoreVersions/v-1/relationships/build")] = [(204, None)]
        result = self.run_asc("attach-build", "--version-id", "v-1", "--build-id", "b-1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[0]["body"], {"data": {"type": "builds", "id": "b-1"}})

    # submit

    def submission(self, submission_id, state):
        return {"type": "reviewSubmissions", "id": submission_id,
                "attributes": {"platform": "IOS", "state": state}}

    def test_submit_creates_a_submission_adds_the_version_and_submits(self):
        self.fake.routes[("GET", "/v1/reviewSubmissions")] = [(200, {"data": []})]
        self.fake.routes[("POST", "/v1/reviewSubmissions")] = [
            (201, {"data": self.submission("s-1", "READY_FOR_REVIEW")})]
        self.fake.routes[("POST", "/v1/reviewSubmissionItems")] = [
            (201, {"data": {"type": "reviewSubmissionItems", "id": "i-1"}})]
        self.fake.routes[("PATCH", "/v1/reviewSubmissions/s-1")] = [
            (200, {"data": self.submission("s-1", "WAITING_FOR_REVIEW")})]
        result = self.run_asc("submit", "--app", APP_ID, "--version-id", "v-1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "s-1")
        self.assertEqual([(r["method"], r["path"]) for r in self.calls()], [
            ("GET", "/v1/reviewSubmissions"), ("POST", "/v1/reviewSubmissions"),
            ("POST", "/v1/reviewSubmissionItems"), ("PATCH", "/v1/reviewSubmissions/s-1")])
        query = self.calls()[0]["query"]
        self.assertEqual(query["filter[app]"], [APP_ID])
        self.assertEqual(query["filter[platform]"], ["IOS"])
        posts = self.calls("POST")
        self.assertEqual(posts[0]["body"], {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
        self.assertEqual(posts[1]["body"], {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": "s-1"}},
                              "appStoreVersion": {"data": {"type": "appStoreVersions", "id": "v-1"}}}}})
        self.assertEqual(self.calls("PATCH")[0]["body"], {"data": {
            "type": "reviewSubmissions", "id": "s-1", "attributes": {"submitted": True}}})

    def test_submit_reuses_an_open_submission_that_holds_the_version(self):
        self.fake.routes[("GET", "/v1/reviewSubmissions")] = [
            (200, {"data": [self.submission("s-9", "READY_FOR_REVIEW")]})]
        self.fake.routes[("GET", "/v1/reviewSubmissions/s-9/items")] = [
            (200, {"data": [{"type": "reviewSubmissionItems", "id": "i-9", "relationships": {
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": "v-1"}}}}]})]
        self.fake.routes[("PATCH", "/v1/reviewSubmissions/s-9")] = [
            (200, {"data": self.submission("s-9", "WAITING_FOR_REVIEW")})]
        result = self.run_asc("submit", "--app", APP_ID, "--version-id", "v-1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "s-9")
        self.assertEqual(self.calls("POST"), [])
        self.assertEqual(self.calls()[1]["query"]["include"], ["appStoreVersion"])

    def test_submit_adds_the_version_to_an_open_submission_without_it(self):
        self.fake.routes[("GET", "/v1/reviewSubmissions")] = [
            (200, {"data": [self.submission("s-9", "READY_FOR_REVIEW")]})]
        self.fake.routes[("GET", "/v1/reviewSubmissions/s-9/items")] = [(200, {"data": []})]
        self.fake.routes[("POST", "/v1/reviewSubmissionItems")] = [
            (201, {"data": {"type": "reviewSubmissionItems", "id": "i-1"}})]
        self.fake.routes[("PATCH", "/v1/reviewSubmissions/s-9")] = [
            (200, {"data": self.submission("s-9", "WAITING_FOR_REVIEW")})]
        result = self.run_asc("submit", "--app", APP_ID, "--version-id", "v-1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([r["path"] for r in self.calls("POST")], ["/v1/reviewSubmissionItems"])

    def test_submit_refuses_while_another_submission_is_in_review(self):
        for state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"):
            with self.subTest(state=state):
                self.fake.requests.clear()
                self.fake.routes[("GET", "/v1/reviewSubmissions")] = [
                    (200, {"data": [self.submission("s-9", state)]})]
                result = self.run_asc("submit", "--app", APP_ID, "--version-id", "v-1")
                self.assertEqual(result.returncode, 1)
                self.assertIn(state, result.stderr)
                self.assertEqual([r for r in self.calls() if r["method"] != "GET"], [])

    # adp-id

    def test_adp_id_reads_the_versions_package(self):
        self.fake.routes[("GET", "/v1/appStoreVersions/v-1/alternativeDistributionPackage")] = [
            (200, {"data": {"type": "alternativeDistributionPackages", "id": "adp-1"}})]
        result = self.run_asc("adp-id", "--version-id", "v-1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "adp-1")

    def test_adp_id_finds_the_version_by_its_string(self):
        self.fake.routes[("GET", f"/v1/apps/{APP_ID}/appStoreVersions")] = [
            (200, {"data": [version("v-3", "3.0.0", "ACCEPTED")]})]
        self.fake.routes[("GET", "/v1/appStoreVersions/v-3/alternativeDistributionPackage")] = [
            (200, {"data": {"type": "alternativeDistributionPackages", "id": "adp-3"}})]
        result = self.run_asc("adp-id", "--app", APP_ID, "--version", "3.0.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "adp-3")
        self.assertEqual(self.calls("POST") + self.calls("PATCH"), [])

    def test_adp_id_fails_when_the_version_does_not_exist(self):
        self.fake.routes[("GET", f"/v1/apps/{APP_ID}/appStoreVersions")] = [(200, {"data": []})]
        result = self.run_asc("adp-id", "--app", APP_ID, "--version", "3.0.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("3.0.0", result.stderr)

    # the call record (D-21) and the logs

    def run_whole_sequence(self):
        self.fake.routes.update({
            ("GET", "/v1/builds"): [(200, {"data": [build("b-1", "159", "VALID")]})],
            ("GET", f"/v1/apps/{APP_ID}/appStoreVersions"): [(200, {"data": []})],
            ("POST", "/v1/appStoreVersions"): [(201, {"data": version("v-1", "3.0.0", "PREPARE_FOR_SUBMISSION")})],
            ("PATCH", "/v1/appStoreVersions/v-1/relationships/build"): [(204, None)],
            ("GET", "/v1/reviewSubmissions"): [(200, {"data": []})],
            ("POST", "/v1/reviewSubmissions"): [(201, {"data": self.submission("s-1", "READY_FOR_REVIEW")})],
            ("POST", "/v1/reviewSubmissionItems"): [(201, {"data": {"type": "reviewSubmissionItems", "id": "i-1"}})],
            ("PATCH", "/v1/reviewSubmissions/s-1"): [(200, {"data": self.submission("s-1", "WAITING_FOR_REVIEW")})],
        })
        for args in (("wait-build", "--app", APP_ID, "--version", "3.0.0", "--build", "159", "--interval", "0"),
                     ("ensure-version", "--app", APP_ID, "--version", "3.0.0"),
                     ("attach-build", "--version-id", "v-1", "--build-id", "b-1"),
                     ("submit", "--app", APP_ID, "--version-id", "v-1")):
            result = self.run_asc(*args)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_the_call_record_has_one_line_per_call_and_only_the_allowed_fields(self):
        self.run_whole_sequence()
        lines = [json.loads(line) for line in self.record.read_text(encoding="utf-8").splitlines()]
        self.assertEqual(len(lines), len(self.fake.requests))
        for line, request in zip(lines, self.fake.requests):
            with self.subTest(line=line):
                self.assertEqual(set(line), {"method", "path", "status", "keyID", "keyRole"})
                self.assertEqual((line["method"], line["path"]), (request["method"], request["path"]))
                self.assertEqual(line["keyID"], KEY_ID)
                self.assertEqual(line["keyRole"], ROLE)
        self.assertEqual([line["status"] for line in lines], [200, 200, 201, 204, 200, 201, 201, 200])

    def test_every_call_is_logged_with_method_path_status_and_key(self):
        self.run_whole_sequence()
        for request in self.fake.requests:
            with self.subTest(request=request["path"]):
                self.assertRegex(self.outputs, rf"ASC {request['method']} {re.escape(request['path'])} \d{{3}} "
                                               rf"key={KEY_ID} role={ROLE}")

    def test_neither_the_key_nor_a_token_reaches_the_logs_or_the_record(self):
        self.run_whole_sequence()
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
        result = subprocess.run([sys.executable, str(ASC), "adp-id", "--version-id", "v-1"], capture_output=True,
                                text=True, env=env, timeout=60)
        self.assertEqual(result.returncode, 1)
        self.assertIn("APP_STORE_CONNECT_KEY_ID", result.stderr)
        self.assertEqual(self.fake.requests, [])


if __name__ == "__main__":
    unittest.main()
