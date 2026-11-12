#!/usr/bin/env python3
"""Fetches a shard's baseline slices from the snapshot repository and checks every picture (19-CONTEXT D-14).

The pictures live in a public snapshot repository, one slice per `<family>/<locale>/<size>` (19-RESEARCH §6). The
app repository pins the approved set in `AppPackage/Tests/VisualSnapshotTests/Baseline/fingerprints.json` (schema 1:
`repository`, `commit`, `tag`, `count`, `pictures: {key: sha256}`). This fetches only the requested slices at the
pinned commit (a blobless, sparse, depth-1 clone, then the pinned commit), hashes every file in them and compares the
set with the fingerprints: a picture whose SHA-256 differs, a fingerprinted picture that is missing and a file that
is not fingerprinted all fail the shard as `baseline-mismatch`, naming the key. A baseline swapped or edited in the
snapshot repository therefore never reaches a comparison (T-19-20).

usage: snapshot_fetch.py --fingerprints FILE --slices iphone/en/large,iphone/ja/large --dest DIR

Exit status: 0 the slices match; 3 baseline-mismatch; 4 no approved baseline yet (no fingerprints.json, so a compare
run has nothing to compare against); 1 the fetch itself failed (network, repository, git), which is not a mismatch.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

MISMATCH = 3
NO_BASELINE = 4
FETCH_FAILED = 1
SHOWN = 20
SLICE = re.compile(r'^[a-z]+/[A-Za-z-]+/[A-Za-z0-9]+$')


class Mismatch(Exception):
    """The fetched slices are not the approved pictures; each argument is one problem line."""


def repository_url(name):
    """A URL or path as given; an `owner/name` GitHub repository as its HTTPS clone URL."""
    if '://' in name or name.startswith(('/', 'git@')):
        return name
    return f'https://github.com/{name}.git'


def key_path(key):
    """`scenario__locale__size__orientation__family__theme` → `<family>/<locale>/<size>/<scenario>/<o>-<t>.png`."""
    scenario, locale, size, orientation, family, theme = key.split('__')
    return f'{family}/{locale}/{size}/{scenario}/{orientation}-{theme}.png'


def path_key(path):
    """The key of a slice-relative picture path, or the path itself when it is not one."""
    parts = path.split('/')
    if len(parts) == 5 and parts[4].endswith('.png') and parts[4].count('-') >= 1:
        orientation, theme = parts[4][:-4].split('-', 1)
        return '__'.join((parts[3], parts[1], parts[2], orientation, parts[0], theme))
    return path


def git(*args):
    subprocess.run(['git', *args], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)


def clone(url, commit, slices, dest):
    """Only the slices' blobs at the pinned commit: GitHub serves a commit by ID, so no history is fetched."""
    git('clone', '--quiet', '--no-checkout', '--depth', '1', '--filter=blob:none', '--sparse', url, str(dest))
    git('-C', str(dest), 'sparse-checkout', 'set', '--cone', '--', *slices)
    git('-C', str(dest), 'fetch', '--quiet', '--depth', '1', '--filter=blob:none', 'origin', commit)
    git('-C', str(dest), 'checkout', '--quiet', '--detach', commit)
    head = subprocess.run(['git', '-C', str(dest), 'rev-parse', 'HEAD'], check=True, capture_output=True,
                          text=True).stdout.strip()
    if head != commit:
        raise Mismatch(f'checked out {head}, not the pinned {commit}')


def verify(document, slices, dest):
    """Every problem with the fetched slices, as lines naming the key."""
    wanted = {}
    for key, digest in document['pictures'].items():
        path = key_path(key)
        if '/'.join(path.split('/')[:3]) in slices:
            wanted[path] = digest
    problems = [f'slice {name} has no pictures in fingerprints.json' for name in slices
                if not any(path.startswith(name + '/') for path in wanted)]
    found = {}
    for path in sorted(dest.rglob('*')):
        relative = path.relative_to(dest)
        if not path.is_file() or relative.parts[0] == '.git' or len(relative.parts) == 1:
            continue
        found[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted(wanted.keys() - found.keys()):
        problems.append(f'{path_key(path)}: missing')
    for path in sorted(found.keys() - wanted.keys()):
        problems.append(f'{path_key(path)}: extra file {path}')
    for path in sorted(wanted.keys() & found.keys()):
        if wanted[path] != found[path]:
            problems.append(f'{path_key(path)}: sha256 differs')
    return problems, len(wanted)


def fetch(fingerprints, slices, dest):
    """The number of verified pictures; raises `Mismatch`, `FileNotFoundError` (no baseline) or a git error."""
    if not fingerprints.is_file():
        raise FileNotFoundError(fingerprints)
    document = json.loads(fingerprints.read_text())
    commit = document.get('commit') or ''
    if document.get('schema') != 1 or not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise Mismatch('fingerprints.json is not schema 1 with a pinned 40-character commit')
    if document.get('count') != len(document.get('pictures', {})):
        raise Mismatch(f"fingerprints.json counts {document.get('count')} pictures but lists "
                       f"{len(document.get('pictures', {}))}")
    if dest.exists():
        shutil.rmtree(dest)
    clone(repository_url(document['repository']), commit, slices, dest)
    problems, count = verify(document, slices, dest)
    if problems:
        raise Mismatch(*problems)
    return count


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--fingerprints', type=Path, required=True)
    parser.add_argument('--slices', required=True, help='comma-separated <family>/<locale>/<size> slices')
    parser.add_argument('--dest', type=Path, required=True)
    args = parser.parse_args(argv)
    slices = [name for name in args.slices.split(',') if name]
    if not slices or not all(SLICE.match(name) for name in slices):
        parser.error(f'--slices must be <family>/<locale>/<size>, comma-separated: {args.slices!r}')
    try:
        count = fetch(args.fingerprints, slices, args.dest)
    except FileNotFoundError:
        print(f'no approved baseline yet: {args.fingerprints} does not exist', file=sys.stderr)
        return NO_BASELINE
    except Mismatch as error:
        problems = error.args
        for problem in problems[:SHOWN]:
            print(f'baseline-mismatch: {problem}', file=sys.stderr)
        if len(problems) > SHOWN:
            print(f'baseline-mismatch: … and {len(problems) - SHOWN} more', file=sys.stderr)
        return MISMATCH
    except subprocess.CalledProcessError as error:
        print(f'fetch failed: {" ".join(error.cmd)}: {(error.stderr or "").strip()}', file=sys.stderr)
        return FETCH_FAILED
    print(f'{count} pictures in {len(slices)} slices match fingerprints.json')
    return 0


if __name__ == '__main__':
    sys.exit(main())
