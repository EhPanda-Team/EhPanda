#!/usr/bin/env python3
"""Turns a candidate run's pictures into the approved baseline of the snapshot repository (19-12, 19-13; D-14).

The gate's candidate run uploads each shard attempt's pictures as an artifact named `pictures-<attempt>-<shard>`
(`shard`, `retry`, `retry2`, `retry3`), holding the attempt's `results.jsonl` and its pictures at their baseline paths
(`<family>/<locale>/<size>/<scenario>/<orientation>-<theme>.png`, 19-RESEARCH §6). Downloaded with
`gh run download <run> --pattern 'pictures-*' --dir DIR`, each artifact is a directory of DIR.

- `assemble --artifacts DIR --out SET` takes, for every coordinate, the `recorded` line of the latest attempt that
  recorded it, links (or copies) that attempt's picture into `SET/pictures/` after checking its SHA-256 against the
  line, and writes `SET/fingerprints.json` (schema 1, `commit` and `tag` empty until the push) and `SET/slices.json`
  (pictures and bytes per device-and-language slice). A key outside the inventory, an expected coordinate without a
  picture, two different recorded digests in one attempt, or a picture whose bytes differ from its line fails,
  naming the key.
- `plan --set SET --limit-gb 1.8` lists the slices in push order and fails when one is over the limit: GitHub refuses
  a push above 2 GB, so each slice is pushed as its own commit.
- `push --set SET --repo CLONE --tag baseline-<n> --approval FILE` makes, in a local clone of the snapshot
  repository, one commit per slice and then the approval commit with `baseline.json` and an annotated tag, and
  prints the `git push` commands. It never pushes: each push needs the owner's go-ahead. `--dry-run` only lists the
  commits it would make. Commits are dated in UTC+8 and signed as the clone's configuration says.
- `pin --set SET --repo CLONE --tag baseline-<n> --out FILE` checks that the tagged commit holds exactly the set's
  pictures and writes the fingerprints with that commit and tag, for
  `AppPackage/Tests/VisualSnapshotTests/Baseline/fingerprints.json`.

`baseline.json` records the SHA-256 of the set's unpinned `fingerprints.json`, the digest the owner approved.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import snapshot_fetch
import snapshot_matrix

REPOSITORY = 'EhPanda-Team/ehpanda-snapshot'
ATTEMPTS = {'shard': 1, 'retry': 2, 'retry2': 3, 'retry3': 4}
ARTIFACT = re.compile(r'^pictures-(shard|retry|retry2|retry3)-(s\d+)$')
TAG = re.compile(r'^baseline-[1-9][0-9]*$')
SHOWN = 20
GB = 1_000_000_000


class PublishError(Exception):
    """The set cannot be published as asked; each argument is one problem line."""


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, document):
    """Sorted keys and a trailing newline, so the same document always has the same digest."""
    path.write_text(json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + '\n')


def link_or_copy(source, destination):
    """A hard link where the file system allows one, else a copy: the set is about 5 GB and lives three times (the
    downloads, the set and the clone's working tree), and git writes each picture once more as an object."""
    try:
        os.link(source, destination)
    except OSError:
        shutil.copyfile(source, destination)
    return destination


def slice_name(key):
    """The device-and-language slice of a key: `<family>/<locale>`."""
    return '/'.join(snapshot_fetch.key_path(key).split('/')[:2])


def slice_order(name):
    family, locale = name.split('/')
    return snapshot_matrix.FAMILIES.index(family), snapshot_matrix.LOCALES.index(locale)


def recorded_lines(directory):
    """`{key: {digests}}` of the attempt's `recorded` lines."""
    results = directory / 'results.jsonl'
    if not results.is_file():
        return {}
    lines = {}
    for number, text in enumerate(results.read_text().splitlines(), start=1):
        if not text.strip():
            continue
        try:
            line = json.loads(text)
        except json.JSONDecodeError as error:
            raise PublishError(f'{results}:{number}: not JSON ({error.msg})') from error
        if line.get('status') == 'recorded':
            lines.setdefault(line['key'], set()).add(line.get('sha256') or '')
    return lines


def attempts(artifacts):
    """`[(attempt, directory)]` of every picture artifact, latest attempt last."""
    found = []
    for directory in sorted(path for path in artifacts.iterdir() if path.is_dir()):
        match = ARTIFACT.match(directory.name)
        if not match:
            raise PublishError(f'{directory.name}: not a picture artifact (pictures-<attempt>-<shard>)')
        found.append((ATTEMPTS[match.group(1)], directory))
    if not found:
        raise PublishError(f'{artifacts}: no picture artifacts')
    return sorted(found, key=lambda entry: (entry[0], entry[1].name))


def choose(artifacts):
    """`{key: (directory, digest)}` from the latest attempt that recorded each key."""
    chosen, problems = {}, []
    for attempt, directory in attempts(artifacts):
        for key, digests in recorded_lines(directory).items():
            if len(digests) != 1 or '' in digests:
                problems.append(f'{key}: {directory.name} recorded it with {len(digests)} different digests')
                continue
            if key not in chosen or chosen[key][2] <= attempt:
                chosen[key] = (directory, next(iter(digests)), attempt)
    if problems:
        raise PublishError(*problems)
    return {key: (directory, digest) for key, (directory, digest, _) in chosen.items()}


def assemble(artifacts, out, inventory, environment):
    """Lays the candidate set out under `out`; returns the fingerprints document."""
    if out.exists() and any(out.iterdir()):
        raise PublishError(f'{out}: already holds files; assemble into a new directory')
    document, env = snapshot_matrix.load(inventory, environment)
    expected = {row.key for row, reason in snapshot_matrix.coordinates(document, env) if reason is None}
    chosen = choose(artifacts)
    problems = [f'{key}: recorded but not in the inventory' for key in sorted(chosen.keys() - expected)]
    problems += [f'{key}: expected but not recorded' for key in sorted(expected - chosen.keys())]
    pictures, slices = {}, {}
    for key in sorted(expected & chosen.keys()):
        directory, digest = chosen[key]
        source = directory / snapshot_fetch.key_path(key)
        if not source.is_file():
            problems.append(f'{key}: {directory.name} has its line but no picture')
            continue
        data = source.read_bytes()
        if sha256(data) != digest:
            problems.append(f'{key}: the picture in {directory.name} differs from its result line')
            continue
        destination = out / 'pictures' / snapshot_fetch.key_path(key)
        destination.parent.mkdir(parents=True, exist_ok=True)
        link_or_copy(source, destination)
        pictures[key] = digest
        entry = slices.setdefault(slice_name(key), {'pictures': 0, 'bytes': 0})
        entry['pictures'] += 1
        entry['bytes'] += len(data)
    if problems:
        raise PublishError(*problems)
    fingerprints = {'schema': 1, 'repository': REPOSITORY, 'commit': '', 'tag': '', 'count': len(pictures),
                    'pictures': pictures}
    write_json(out / 'fingerprints.json', fingerprints)
    write_json(out / 'slices.json', slices)
    return fingerprints


def plan(set_directory, limit_gb):
    """`[(slice, pictures, bytes)]` in push order; raises when a slice is over the limit."""
    slices = json.loads((set_directory / 'slices.json').read_text())
    ordered = [(name, slices[name]['pictures'], slices[name]['bytes']) for name in sorted(slices, key=slice_order)]
    over = [f'{name}: {size / GB:.2f} GB is over {limit_gb} GB' for name, _, size in ordered if size > limit_gb * GB]
    if over:
        raise PublishError(*over)
    return ordered


def git(repo, *args, capture=True):
    """Runs git in the clone with its own configuration; commits and tags are dated in UTC+8."""
    return subprocess.run(['git', '-C', str(repo), *args], check=True, capture_output=capture, text=True,
                          env={**os.environ, 'TZ': 'Asia/Shanghai'}).stdout.strip()


def check_commit(repo, commit):
    """The commit must carry +08:00 on both dates, and a good signature when the clone signs commits."""
    signature, author, committer = git(repo, 'log', '-1', '--format=%G? %aI %cI', commit).split()
    problems = [f'{commit}: {label} date {value} is not +08:00'
                for label, value in (('author', author), ('committer', committer)) if not value.endswith('+08:00')]
    signs = git(repo, 'config', '--bool', '--default', 'false', 'commit.gpgsign') == 'true'
    if signs and signature != 'G':
        problems.append(f'{commit}: signature status {signature}, not G')
    if problems:
        raise PublishError(*problems)


def push(set_directory, repo, tag, approval, limit_gb, dry_run):
    """Makes the slice commits and the approval commit and tag; returns the push commands, or the plan on a dry run."""
    if not TAG.match(tag):
        raise PublishError(f'{tag}: the tag must be baseline-<n>')
    ordered = plan(set_directory, limit_gb)
    if dry_run:
        return [f'commit {tag}: {name} pictures ({count} pictures, {size / GB:.2f} GB)'
                for name, count, size in ordered] + [f'commit {tag}: approval record, tag {tag}']
    if git(repo, 'status', '--porcelain'):
        raise PublishError(f'{repo}: the clone has uncommitted changes')
    if git(repo, 'tag', '--list', tag):
        raise PublishError(f'{repo}: the tag {tag} already exists')
    branch = git(repo, 'symbolic-ref', '--short', 'HEAD')
    fingerprints_path = set_directory / 'fingerprints.json'
    fingerprints = json.loads(fingerprints_path.read_text())
    if fingerprints.get('commit') or fingerprints.get('tag'):
        raise PublishError(f'{fingerprints_path}: already pinned; push the unpinned set the owner approved')
    commits = []
    for name, _, _ in ordered:
        target = repo / name
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(set_directory / 'pictures' / name, target, copy_function=link_or_copy)
        git(repo, 'add', '--all', '--', name)
        if not git(repo, 'diff', '--cached', '--name-only'):
            continue
        git(repo, 'commit', '--quiet', '-m', f'{tag}: {name.replace("/", " ")} pictures')
        commits.append(git(repo, 'rev-parse', 'HEAD'))
        check_commit(repo, commits[-1])
    record = {'schema': 1, 'tag': tag, 'count': fingerprints['count'],
              'fingerprintsSha256': sha256(fingerprints_path.read_bytes()), 'approval': approval}
    write_json(repo / 'baseline.json', record)
    git(repo, 'add', '--', 'baseline.json')
    git(repo, 'commit', '--quiet', '-m', f'{tag}: approval record')
    commits.append(git(repo, 'rev-parse', 'HEAD'))
    check_commit(repo, commits[-1])
    git(repo, 'tag', '--annotate', '-m', f'Approved baseline {tag}', tag)
    write_json(set_directory / 'push.json', {'tag': tag, 'branch': branch, 'commits': commits})
    return [f'git -C {repo} push origin {commit}:refs/heads/{branch}' for commit in commits] + [
        f'git -C {repo} push origin refs/tags/{tag}']


def pin(set_directory, repo, tag, out):
    """Writes the fingerprints pinned to the tagged commit, after checking that it holds exactly the set."""
    commit = git(repo, 'rev-parse', f'refs/tags/{tag}^{{commit}}')
    listed = git(repo, 'ls-tree', '-r', '--format=%(objectname) %(path)', commit).splitlines()
    tracked = {path: blob for blob, path in (line.split(' ', 1) for line in listed) if '/' in path}
    fingerprints = json.loads((set_directory / 'fingerprints.json').read_text())
    wanted = {snapshot_fetch.key_path(key): digest for key, digest in fingerprints['pictures'].items()}
    problems = [f'{snapshot_fetch.path_key(path)}: missing at {tag}' for path in sorted(wanted.keys() - tracked.keys())]
    problems += [f'{path}: at {tag} but not in the set' for path in sorted(tracked.keys() - wanted.keys())]
    for path in sorted(wanted.keys() & tracked.keys()):
        data = subprocess.run(['git', '-C', str(repo), 'cat-file', 'blob', tracked[path]], check=True,
                              capture_output=True).stdout
        if sha256(data) != wanted[path]:
            problems.append(f'{snapshot_fetch.path_key(path)}: differs at {tag}')
    if problems:
        raise PublishError(*problems)
    write_json(out, {**fingerprints, 'commit': commit, 'tag': tag})
    return commit


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    assemble_parser = commands.add_parser('assemble', help="lay a candidate run's pictures out as the baseline")
    assemble_parser.add_argument('--artifacts', type=Path, required=True)
    assemble_parser.add_argument('--out', type=Path, required=True)
    assemble_parser.add_argument('--inventory', type=Path, default=snapshot_matrix.INVENTORY)
    assemble_parser.add_argument('--environment', type=Path, default=snapshot_matrix.ENVIRONMENT)
    plan_parser = commands.add_parser('plan', help='list the slice commits and check their size')
    push_parser = commands.add_parser('push', help='make the slice and approval commits in a local clone')
    for each in (plan_parser, push_parser):
        each.add_argument('--set', type=Path, required=True)
        each.add_argument('--limit-gb', type=float, default=1.8)
    push_parser.add_argument('--repo', type=Path, required=True)
    push_parser.add_argument('--tag', required=True)
    push_parser.add_argument('--approval', type=Path, required=True, help="JSON file with the owner's approval")
    push_parser.add_argument('--dry-run', action='store_true')
    pin_parser = commands.add_parser('pin', help='write the fingerprints pinned to the tagged commit')
    pin_parser.add_argument('--set', type=Path, required=True)
    pin_parser.add_argument('--repo', type=Path, required=True)
    pin_parser.add_argument('--tag', required=True)
    pin_parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            document = assemble(args.artifacts, args.out, args.inventory, args.environment)
            print(f"{document['count']} pictures assembled in {args.out}")
        elif args.command == 'plan':
            ordered = plan(args.set, args.limit_gb)
            for name, count, size in ordered:
                print(f'{name}\t{count} pictures\t{size / GB:.2f} GB')
            print(f'total\t{sum(row[1] for row in ordered)} pictures\t{sum(row[2] for row in ordered) / GB:.2f} GB')
        elif args.command == 'push':
            approval = json.loads(args.approval.read_text())
            print('\n'.join(push(args.set, args.repo, args.tag, approval, args.limit_gb, args.dry_run)))
        else:
            commit = pin(args.set, args.repo, args.tag, args.out)
            print(f'{args.out} pinned to {commit} ({args.tag})')
    except PublishError as error:
        for problem in error.args[:SHOWN]:
            print(f'error: {problem}', file=sys.stderr)
        if len(error.args) > SHOWN:
            print(f'error: … and {len(error.args) - SHOWN} more', file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        print(f'git failed: {" ".join(error.cmd)}: {(error.stderr or "").strip()}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
