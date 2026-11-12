#!/usr/bin/env python3
"""Acquire a declared real-gallery selection into a versioned, checksummed, scrubbed local fixture.

Acquisition is anonymous: it reads no credentials and sends only the app's offensive-content preference
cookie to the gallery host. Real assets stay in the git-ignored output and are never public baselines.
"""
import argparse
from datetime import datetime, timezone
import http.client
import json
from pathlib import Path
import signal
import time
import urllib.request
from urllib.parse import urlsplit

import fixtures

USER_AGENT = 'EhPanda-fixture-acquisition/1'
# Minimum spacing between requests: acquisition is explicit and rare, so it stays well below browsing rates.
PACE = 1.0


class RefuseRedirects(urllib.request.HTTPRedirectHandler):
    """A redirect could leave the allowed hosts or substitute another page, so it fails the request instead."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(url):
    headers = {'User-Agent': USER_AGENT}
    if urlsplit(url).hostname == fixtures.GALLERY_HOST:
        # Defaults.Cookie.ignoreOffensive: the app always sets nw=1 so flagged galleries open without a warning page.
        headers['Cookie'] = 'nw=1'
    return urllib.request.Request(url, headers=headers)


class Fetcher:
    def __init__(self):
        self.opener = urllib.request.build_opener(RefuseRedirects)
        self.last = None

    def __call__(self, url):
        if self.last is not None:
            time.sleep(max(0.0, self.last + PACE - time.monotonic()))
        try:
            with self.opener.open(request(url), timeout=60) as response:
                return response.read(), response.headers.get_content_type()
        finally:
            self.last = time.monotonic()


def now():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def acquire(selection_path, output, refresh=False, fetch=None, clock=now):
    """Acquire, verify and publish one version; returns its directory and whether `current` changed."""
    selection = fixtures.validate_selection(json.loads(Path(selection_path).read_text()))
    output = Path(output).absolute()
    fixtures.check_output(output)
    fetch = fetch or Fetcher()
    with fixtures.Writer(output) as writer:
        if writer.published() and not refresh:
            raise ValueError(f'{output / "current"} is already published; pass --refresh to acquire again')
        acquired_at, assets = clock(), []

        def retrieve(kind, gid, index, url):
            fixtures.check_url(url, kind)
            try:
                data, declared = fetch(url)
            except (OSError, http.client.HTTPException) as error:
                raise ValueError(f'{kind} {gid}: {fixtures.scrub(url)}: {type(error).__name__}: {error}') from None
            stored, mime = fixtures.sanitize(kind, data, declared)
            relative = fixtures.asset_path(kind, gid, index, mime)
            (writer.staging / relative).parent.mkdir(parents=True, exist_ok=True)
            (writer.staging / relative).write_bytes(stored)
            assets.append({'kind': kind, 'gid': gid, 'index': index, 'url': fixtures.scrub(url), 'path': relative,
                           'mime': mime, 'bytes': len(stored), 'sha256': fixtures.sha256(stored),
                           'retrievedAt': clock()})
            return data

        fixtures.collect(selection, retrieve)
        return writer.publish(fixtures.write_manifest(writer.staging, selection, assets, acquired_at))


def interrupt(signum, frame):
    raise KeyboardInterrupt(f'signal {signum}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--selection', type=Path, required=True, help='Selection JSON declaring galleries and scenes')
    parser.add_argument('--output', type=Path, required=True, help='Fixture root, normally .capture/marketing')
    parser.add_argument('--refresh', action='store_true', help='Acquire again although a version is published')
    arguments = parser.parse_args()
    signal.signal(signal.SIGTERM, interrupt)
    try:
        target, changed = acquire(arguments.selection, arguments.output, arguments.refresh)
    except (OSError, ValueError, KeyboardInterrupt) as error:
        parser.exit(1, f'Fixture acquisition failed: {type(error).__name__}: {error}\n')
    print(f'{"Published" if changed else "Unchanged"}: {target}')


if __name__ == '__main__':
    main()
