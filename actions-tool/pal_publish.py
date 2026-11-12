#!/usr/bin/env python3
"""Publishes a notarized AltStore PAL build: the ADP, unchanged, as assets of the version's GitHub release, and the
version in `AltStorePAL.json` on `main` (Phase 20 plan 20-05; DIST-18-02, DIST-18-03; D-19; Research §4, §5).

Usage:
  pal_publish.py process --adp-id <id>
      asks AltStore to process the ADP (`POST /adps`). Harmless when AltStore already processes it on its own
      (marketplace notifications on).
  pal_publish.py fetch --adp-id <id> --out <dir> [--interval <s>] [--timeout <s>]
  pal_publish.py fetch --from <zip or directory> --out <dir>
      waits until AltStore's `GET /adps/<id>` has a `downloadURL`, downloads the ADP and unpacks it; or takes an
      ADP that is already on disk. Writes <dir>/adp/ (the files, byte for byte), <dir>/adp-files.json (the SHA-256
      of each) and, for a zip, <dir>/adp.zip.
  pal_publish.py publish --version <x.y.z> --adp <dir> --repo <owner/name> --notes <file>
                         --marketplace-id <id> [--work <dir>] [--retry-delay <s>] [--dry-run]
      run in a checkout whose `origin` is the repository: checks the fetched ADP against its hashes, finds the
      release tagged <x.y.z> (it never creates one), uploads each ADP file as `EhPanda-AltStorePAL-<file name>`,
      downloads every uploaded asset again and compares its hash, then adds the version to `AltStorePAL.json` on
      `main` (or to the template if there is none yet) and pushes, retrying up to five times on a fresh `main`.
      With --dry-run it stops after the checks and prints what it would upload and write; the source it would
      write is left in <work>/AltStorePAL.json.

An ADP is `manifest.json`, `signature` and one `.ipa` per variant, in any folders. AltStore asks that no file be
changed, "DO NOT modify the manifest.json in any way", so every file is only ever copied as bytes and its hash is
compared at download, at staging and after upload. `assetURLs` maps each file name without its extension to its
asset's URL, which is how AltStore takes an ADP hosted on GitHub Releases.

Environment:
  ALTSTORE_API_URL   AltStore's API (default https://api.altstore.io; tests point it at a local fake)
  PAL_GH, PAL_CODESIGN, PAL_JQ, PAL_GIT   the tools to run (default gh, codesign, jq, git)

The standard library, `gh`, `codesign`, `jq` and `git` only. Nothing here talks to App Store Connect.
"""

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

TOOLS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import altstore_languages  # noqa: E402
import release_notes  # noqa: E402

DEFAULT_API_URL = "https://api.altstore.io"
FILTER = TOOLS / "altstore-add-version.jq"
TEMPLATE = TOOLS / "altstore-pal.template.json"
SOURCE_NAME = "AltStorePAL.json"
ASSET_PREFIX = "EhPanda-AltStorePAL-"
PUSH_ATTEMPTS = 5
# AltStore does not want these listed (Make a Source, appPermissions); the filter drops them as well.
UNLISTED_ENTITLEMENTS = {"application-identifier", "com.apple.developer.team-identifier"}
VERSION = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


class PublishError(Exception):
    pass


def say(message):
    print(message, file=sys.stderr, flush=True)


def tool(name):
    return os.environ.get(f"PAL_{name.upper()}") or name


def run(command, cwd=None, check=True, binary=False):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=not binary)
    if check and result.returncode != 0:
        detail = result.stderr if not binary else result.stderr.decode(errors="replace")
        raise PublishError(f"{pathlib.Path(command[0]).name} {' '.join(command[1:3])} failed: {detail.strip()}")
    return result


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


# AltStore ------------------------------------------------------------------------------------------------------

def api_url():
    return (os.environ.get("ALTSTORE_API_URL") or DEFAULT_API_URL).rstrip("/")


def origin(url):
    parts = urllib.parse.urlsplit(url)
    return parts.scheme, parts.hostname, parts.port


def request_json(method, url, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, method=method,
                                     headers={"Accept": "application/json", "User-Agent": "EhPanda-pal-publish"})
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            text = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:500]
        raise PublishError(f"AltStore answered {method} {urllib.parse.urlsplit(url).path} with HTTP {error.code}: "
                           f"{detail}") from None
    except urllib.error.URLError as error:
        raise PublishError(f"AltStore could not be reached ({method} {url}): {error.reason}") from None
    try:
        return json.loads(text) if text.strip() else {}
    except json.JSONDecodeError:
        raise PublishError(f"AltStore's reply to {method} {urllib.parse.urlsplit(url).path} is not JSON.") from None


def process(args):
    reply = request_json("POST", f"{api_url()}/adps", {"adpID": args.adp_id})
    status = reply.get("status") if isinstance(reply, dict) else None
    say(f"AltStore is processing ADP {args.adp_id}" + (f" (status: {status})." if status else "."))


def wait_for_download_url(adp_id, interval, timeout):
    deadline = time.monotonic() + timeout
    while True:
        reply = request_json("GET", f"{api_url()}/adps/{urllib.parse.quote(adp_id, safe='')}")
        if not isinstance(reply, dict):
            raise PublishError(f"AltStore's status for ADP {adp_id} is not an object.")
        url = reply.get("downloadURL")
        if url:
            return url
        status = reply.get("status", "unknown")
        if time.monotonic() + interval > deadline:
            raise PublishError(f"Waiting for AltStore timed out after {timeout:g} s: ADP {adp_id} has no "
                               f"downloadURL yet, and AltStore's status is {status!r}. Dispatch publish again "
                               f"later, or check the ADP ID.")
        say(f"ADP {adp_id}: {status}; waiting {interval:g} s.")
        time.sleep(interval)


def download(url, path):
    # The download is AltStore's: https, or the API's own origin (a local fake in the tests).
    if urllib.parse.urlsplit(url).scheme != "https" and origin(url) != origin(api_url()):
        raise PublishError(f"AltStore's downloadURL is not an https URL: {url}")
    request = urllib.request.Request(url, headers={"User-Agent": "EhPanda-pal-publish"})
    try:
        with urllib.request.urlopen(request, timeout=600) as response, open(path, "wb") as handle:
            shutil.copyfileobj(response, handle, 1 << 20)
    except (urllib.error.URLError, OSError) as error:
        raise PublishError(f"The ADP could not be downloaded from AltStore: {error}") from None


# The ADP on disk -----------------------------------------------------------------------------------------------

def adp_role(name):
    """The asset key AltStore expects for an ADP file (its name without the extension), or None if the file is
    not part of an ADP."""
    if name == "manifest.json":
        return "manifest"
    if name == "signature":
        return "signature"
    if name.endswith(".ipa") and len(name) > len(".ipa"):
        return name[:-len(".ipa")]
    return None


def check_files(relative_paths):
    """Fails unless the files are one manifest.json, one signature and at least one .ipa, with no other file and
    no two files of the same name (they become asset names in one release)."""
    names = {}
    for relative in relative_paths:
        name = pathlib.PurePosixPath(relative).name
        if name in names:
            raise PublishError(f"The ADP has two files named {name}: {names[name]} and {relative}.")
        names[name] = relative
        if adp_role(name) is None:
            raise PublishError(f"The ADP has an unexpected file {relative}: only manifest.json, signature and .ipa "
                               f"variants are published (the ADP layout is checked at 20-08).")
    for required in ("manifest.json", "signature"):
        if required not in names:
            raise PublishError(f"The ADP has no {required}.")
    if not any(name.endswith(".ipa") for name in names):
        raise PublishError("The ADP has no variant (.ipa).")


def safe_member(name):
    path = pathlib.PurePosixPath(name)
    return not (name.startswith("/") or "\\" in name or ".." in path.parts or not path.parts)


def unpack_zip(archive_path, destination):
    try:
        archive = zipfile.ZipFile(archive_path)
    except zipfile.BadZipFile:
        raise PublishError(f"{archive_path} is not a zip archive; AltStore's ADP download format is first seen at "
                           f"20-08.") from None
    with archive:
        members = [member for member in archive.infolist() if not member.is_dir()]
        for member in members:
            if not safe_member(member.filename):
                raise PublishError(f"The ADP zip has an entry outside its folder: {member.filename}")
            if stat.S_ISLNK(member.external_attr >> 16):
                raise PublishError(f"The ADP zip has a symbolic link: {member.filename}")
        check_files([member.filename for member in members])
        for member in members:
            target = destination / member.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as source, open(target, "wb") as handle:
                shutil.copyfileobj(source, handle, 1 << 20)


def copy_directory(source, destination):
    files = []
    for path in sorted(source.rglob("*")):
        if path.is_symlink():
            raise PublishError(f"The ADP folder has a symbolic link: {path.relative_to(source)}")
        if path.is_file():
            files.append(path.relative_to(source).as_posix())
    check_files(files)
    for relative in files:
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / relative, target)


def hash_tree(root):
    return {path.relative_to(root).as_posix(): sha256(path) for path in sorted(root.rglob("*")) if path.is_file()}


def fetch(args):
    out = pathlib.Path(args.out)
    adp = out / "adp"
    if adp.exists():
        raise PublishError(f"{adp} already exists; fetch into a new folder.")
    out.mkdir(parents=True, exist_ok=True)
    if args.adp_id:
        url = wait_for_download_url(args.adp_id, args.interval, args.timeout)
        say(f"ADP {args.adp_id} is ready; downloading it.")
        download(url, out / "adp.zip")
        source = out / "adp.zip"
    else:
        source = pathlib.Path(getattr(args, "from"))
        if not source.exists():
            raise PublishError(f"{source} does not exist.")
    staging = out / "adp.partial"
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir()
    if source.is_dir():
        copy_directory(source, staging)
    else:
        if source != out / "adp.zip":
            shutil.copyfile(source, out / "adp.zip")
        unpack_zip(out / "adp.zip", staging)
    staging.rename(adp)
    hashes = hash_tree(adp)
    (out / "adp-files.json").write_text(json.dumps(hashes, indent=2, sort_keys=True) + "\n")
    for relative, digest in hashes.items():
        say(f"  {relative}  sha256 {digest}")
    say(f"The ADP is in {adp}.")


# The signed variant --------------------------------------------------------------------------------------------

def read_plist(path, what):
    try:
        return plistlib.loads(path.read_bytes())
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        raise PublishError(f"{what} could not be read: {error}") from None


def bundle_facts(ipa, work):
    """The app's Info.plist facts, its privacy usage descriptions and the entitlement keys of the app and each
    extension, read from the signed variant."""
    unpacked = work / ipa.stem
    with zipfile.ZipFile(ipa) as archive:
        for member in archive.infolist():
            if not safe_member(member.filename):
                raise PublishError(f"{ipa.name} has an entry outside its folder: {member.filename}")
        archive.extractall(unpacked)
    apps = sorted((unpacked / "Payload").glob("*.app"))
    if len(apps) != 1:
        raise PublishError(f"{ipa.name} has {len(apps)} apps in Payload, not one.")
    app = apps[0]
    info = read_plist(app / "Info.plist", f"{ipa.name}'s Info.plist")
    bundles = [app] + sorted(app.glob("PlugIns/*.appex")) + sorted(app.glob("Extensions/*.appex"))
    privacy = {}
    entitlements = set()
    for bundle in bundles:
        bundle_info = info if bundle == app else read_plist(bundle / "Info.plist", f"{bundle.name}'s Info.plist")
        privacy.update({key: str(value) for key, value in bundle_info.items() if key.endswith("UsageDescription")})
        result = run([tool("codesign"), "-d", "--entitlements", "-", "--xml", str(bundle)], check=False,
                     binary=True)
        if result.returncode != 0:
            raise PublishError(f"The entitlements of {bundle.name} in {ipa.name} could not be read: "
                               f"{result.stderr.decode(errors='replace').strip()}")
        if result.stdout.strip():
            granted = plistlib.loads(result.stdout)
            if not isinstance(granted, dict):
                raise PublishError(f"The entitlements of {bundle.name} are not a dictionary.")
            entitlements |= set(granted)
    facts = {key: info.get(key) for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
                                            "MinimumOSVersion")}
    for key, value in facts.items():
        if not isinstance(value, str) or not value:
            raise PublishError(f"{ipa.name}'s Info.plist has no {key}.")
    return facts, privacy, sorted(entitlements - UNLISTED_ENTITLEMENTS)


# GitHub --------------------------------------------------------------------------------------------------------

def gh(*args, check=True):
    return run([tool("gh"), *args], check=check)


def find_release(repo, version):
    result = gh("api", f"repos/{repo}/releases/tags/{version}", check=False)
    if result.returncode != 0:
        raise PublishError(f"There is no GitHub release for {version} in {repo} ({result.stderr.strip()}). Publish "
                           f"the release first; this tool never creates a release or a tag (D-19).")
    try:
        release = json.loads(result.stdout)
    except json.JSONDecodeError:
        raise PublishError(f"gh's reply for the release {version} is not JSON.") from None
    if release.get("tag_name") != version:
        raise PublishError(f"The release found for {version} is tagged {release.get('tag_name')!r}.")
    if release.get("draft") or not release.get("published_at"):
        raise PublishError(f"The release {version} is not published yet.")
    return release


def asset_url(repo, version, name):
    return f"https://github.com/{repo}/releases/download/{version}/{name}"


# The source ----------------------------------------------------------------------------------------------------

def version_key(version, build):
    numbers = [int(part) for part in re.findall(r"[0-9]+", version or "")]
    builds = [int(part) for part in re.findall(r"[0-9]+", build or "")]
    return (numbers + [0, 0, 0, 0])[:4] + (builds + [0])[:1]


def build_source(source_path, entry, out_path):
    source = json.loads(source_path.read_text(encoding="utf-8"))
    new_key = version_key(entry["version"], entry["buildVersion"])
    for existing in (source.get("apps") or [{}])[0].get("versions") or []:
        if version_key(existing.get("version"), existing.get("buildVersion")) > new_key:
            raise PublishError(f"{SOURCE_NAME} already lists {existing.get('version')} "
                               f"({existing.get('buildVersion')}), newer than {entry['version']} "
                               f"({entry['buildVersion']}); AltStore offers the first entry, so an older build is "
                               f"not added on top.")
    command = [tool("jq"),
               "--arg", "bundleIdentifier", entry["bundleIdentifier"],
               "--arg", "version", entry["version"],
               "--arg", "buildVersion", entry["buildVersion"],
               "--arg", "marketingVersion", entry["version"],
               "--arg", "date", entry["date"],
               "--arg", "localizedDescription", entry["notes"]["en"],
               "--arg", "downloadURL", entry["assetURLs"]["manifest"],
               "--arg", "minOSVersion", entry["minOSVersion"],
               "--arg", "marketplaceID", entry["marketplaceID"],
               "--argjson", "size", str(entry["size"]),
               "--argjson", "privacy", json.dumps(entry["privacy"]),
               "--argjson", "releaseVersions", "null",
               "--argjson", "localizedDescriptions", json.dumps(entry["notes"], ensure_ascii=False),
               "--argjson", "assetURLs", json.dumps(entry["assetURLs"]),
               "--argjson", "entitlements", json.dumps(entry["entitlements"]),
               "-f", str(FILTER), str(source_path)]
    result = run(command, check=False, binary=True)
    if result.returncode != 0:
        raise PublishError(f"The source filter refused the update: {result.stderr.decode(errors='replace').strip()}")
    written = json.loads(result.stdout)
    problems = altstore_languages.check_source(written, pal=True)
    if problems:
        raise PublishError(f"The {SOURCE_NAME} this would write has problems:\n  " + "\n  ".join(problems))
    out_path.write_bytes(result.stdout)


def git(*args, cwd=None, check=True):
    return run([tool("git"), *args], cwd=cwd, check=check)


def fresh_main(main_path):
    git("fetch", "--no-tags", "--depth", "1", "origin", "main")
    main_sha = git("rev-parse", "FETCH_HEAD").stdout.strip()
    if (main_path / ".git").exists():
        git("checkout", "--force", "--detach", main_sha, cwd=main_path)
    else:
        git("worktree", "add", "--force", "--detach", str(main_path), main_sha)
    return main_path / SOURCE_NAME


def update_main(entry, work, retry_delay):
    main_path = (work / "main").resolve()
    for attempt in range(1, PUSH_ATTEMPTS + 1):
        source_path = fresh_main(main_path)
        build_source(source_path if source_path.exists() else TEMPLATE, entry, work / "source.json")
        shutil.copyfile(work / "source.json", source_path)
        if not git("status", "--porcelain", "--", SOURCE_NAME, cwd=main_path).stdout.strip():
            say(f"{SOURCE_NAME} on main is already up to date.")
            return
        git("add", "--", SOURCE_NAME, cwd=main_path)
        git("commit", "-q", "-m", f"Update {SOURCE_NAME}", cwd=main_path)
        if git("push", "origin", "HEAD:refs/heads/main", cwd=main_path, check=False).returncode == 0:
            say(f"{SOURCE_NAME} on main now lists {entry['version']} ({entry['buildVersion']}).")
            return
        say(f"Push to main was rejected (attempt {attempt}); retrying with the latest main.")
        if attempt < PUSH_ATTEMPTS:
            time.sleep(retry_delay * attempt)
    raise PublishError(f"Push to main was rejected {PUSH_ATTEMPTS} times; {SOURCE_NAME} is unchanged. The release "
                       f"assets are in place, so dispatch publish again.")


# Publish -------------------------------------------------------------------------------------------------------

def verified_adp(adp_dir):
    """{relative path: sha256} of the fetched ADP, after checking each file against fetch's record."""
    recorded = json.loads((adp_dir / "adp-files.json").read_text())
    actual = hash_tree(adp_dir / "adp")
    for relative in sorted(set(recorded) | set(actual)):
        if recorded.get(relative) != actual.get(relative):
            raise PublishError(f"The fetched ADP's {relative} differs from what fetch recorded; fetch it again.")
    check_files(list(actual))
    return actual


def publish(args):
    if not VERSION.match(args.version):
        raise PublishError(f"{args.version!r} is not a version like 3.0.0.")
    if not re.fullmatch(r"[0-9]+", args.marketplace_id or ""):
        raise PublishError("The marketplace ID must be the app's Apple ID (digits): set PAL_MARKETPLACE_ID.")
    adp_dir = pathlib.Path(args.adp)
    work = pathlib.Path(args.work)
    work.mkdir(parents=True, exist_ok=True)
    for part in ("assets", "existing", "verify", "variants"):
        shutil.rmtree(work / part, ignore_errors=True)
        (work / part).mkdir()

    files = verified_adp(adp_dir)
    variants = sorted(relative for relative in files if relative.endswith(".ipa"))
    facts = privacy = entitlements = None
    for relative in variants:
        variant_facts, variant_privacy, variant_entitlements = bundle_facts(adp_dir / "adp" / relative,
                                                                            work / "variants")
        if facts is not None and (variant_facts, variant_privacy, variant_entitlements) != \
                (facts, privacy, entitlements):
            raise PublishError(f"The variants differ in their Info.plist or entitlements ({relative}).")
        facts, privacy, entitlements = variant_facts, variant_privacy, variant_entitlements
    if facts["CFBundleShortVersionString"] != args.version:
        raise PublishError(f"The ADP is version {facts['CFBundleShortVersionString']}, not {args.version}.")
    try:
        notes = release_notes.read(args.notes)
    except release_notes.NotesError as error:
        raise PublishError(str(error)) from None

    release = find_release(args.repo, args.version)
    existing = {asset["name"]: asset for asset in release.get("assets") or []}

    # Stage each file under its asset name: a byte copy, checked against the fetched hash.
    staged = {}
    for relative, digest in files.items():
        name = ASSET_PREFIX + pathlib.PurePosixPath(relative).name
        target = work / "assets" / name
        shutil.copyfile(adp_dir / "adp" / relative, target)
        if sha256(target) != digest:
            raise PublishError(f"Staging changed {name}.")
        staged[name] = (relative, digest)

    # An asset already on the release is reused only if it is the same file.
    to_upload = []
    for name, (relative, digest) in sorted(staged.items()):
        if name not in existing:
            to_upload.append(name)
            continue
        gh("release", "download", args.version, "--repo", args.repo, "--pattern", name, "--dir",
           str(work / "existing"))
        if sha256(work / "existing" / name) != digest:
            raise PublishError(f"The release {args.version} already has an asset {name} with other bytes; remove it "
                               f"by hand if it is stale (this tool never replaces an asset).")
        say(f"{name} is already up to date on the release.")

    def entry_for(urls):
        return {"bundleIdentifier": facts["CFBundleIdentifier"], "version": args.version,
                "buildVersion": facts["CFBundleVersion"], "minOSVersion": facts["MinimumOSVersion"],
                "date": release["published_at"], "notes": notes, "privacy": privacy, "entitlements": entitlements,
                "marketplaceID": args.marketplace_id,
                "size": (adp_dir / "adp" / variants[0]).stat().st_size,
                "assetURLs": {altstore_key(relative): urls[name] for name, (relative, _) in staged.items()}}

    def altstore_key(relative):
        return adp_role(pathlib.PurePosixPath(relative).name)

    planned = {name: (existing[name]["browser_download_url"] if name in existing
                      else asset_url(args.repo, args.version, name)) for name in staged}
    preview_source = work / SOURCE_NAME
    fresh = fresh_main((work / "main").resolve())
    build_source(fresh if fresh.exists() else TEMPLATE, entry_for(planned), preview_source)

    if args.dry_run:
        print("dry run: nothing is uploaded or committed.")
        for name in sorted(staged):
            print(f"  {'upload' if name in to_upload else 'keep  '} {name}  sha256 {staged[name][1]}")
        print(f"  write  {SOURCE_NAME} on main (preview: {preview_source})")
        return

    if to_upload:
        gh("release", "upload", args.version, *[str(work / "assets" / name) for name in to_upload],
           "--repo", args.repo)
        say(f"Uploaded {', '.join(to_upload)} to the release {args.version}.")

    # Every asset is downloaded again: what AltStore will fetch must be the ADP's bytes.
    uploaded = {asset["name"]: asset for asset in find_release(args.repo, args.version).get("assets") or []}
    urls = {}
    for name, (relative, digest) in sorted(staged.items()):
        if name not in uploaded:
            raise PublishError(f"The release {args.version} has no asset {name} after the upload.")
        target = work / "verify" / name
        gh("release", "download", args.version, "--repo", args.repo, "--pattern", name, "--dir", str(work / "verify"))
        if sha256(target) != digest:
            raise PublishError(f"The uploaded asset {name} changed: its SHA-256 is {sha256(target)}, the ADP's "
                               f"{relative} is {digest}. {SOURCE_NAME} is not updated; remove the asset by hand "
                               f"and dispatch publish again.")
        urls[name] = uploaded[name]["browser_download_url"]
    say("Every uploaded asset matches the ADP byte for byte.")

    update_main(entry_for(urls), work, args.retry_delay)


# ---------------------------------------------------------------------------------------------------------------

def parse(argv):
    parser = argparse.ArgumentParser(description="Publishes a notarized ADP to AltStore PAL.")
    commands = parser.add_subparsers(dest="command", required=True)

    command = commands.add_parser("process")
    command.add_argument("--adp-id", required=True)

    command = commands.add_parser("fetch")
    origin_group = command.add_mutually_exclusive_group(required=True)
    origin_group.add_argument("--adp-id")
    origin_group.add_argument("--from")
    command.add_argument("--out", required=True)
    command.add_argument("--interval", type=float, default=30)
    command.add_argument("--timeout", type=float, default=3600)

    command = commands.add_parser("publish")
    command.add_argument("--version", required=True)
    command.add_argument("--adp", required=True)
    command.add_argument("--repo", required=True)
    command.add_argument("--notes", required=True)
    command.add_argument("--marketplace-id", required=True)
    command.add_argument("--work", default="pal-publish-work")
    command.add_argument("--retry-delay", type=float, default=5)
    command.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv):
    args = parse(argv)
    if getattr(args, "adp_id", None) is not None and not re.fullmatch(r"[A-Za-z0-9-]+", args.adp_id):
        print(f"::error::{args.adp_id!r} is not an ADP ID.", file=sys.stderr)
        return 1
    try:
        {"process": process, "fetch": fetch, "publish": publish}[args.command](args)
    except PublishError as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
