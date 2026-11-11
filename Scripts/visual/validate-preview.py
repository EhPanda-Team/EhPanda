#!/usr/bin/env python3
"""Validate the stored result of one Xcode preview render before it is kept as review evidence (19-17, CAP-17-06).

usage: validate-preview.py --response PATH --expected-environment PATH --output DIR

`--response` is the parsed result of one RenderPreview call (see preview-review.md): `previewSnapshotPath`,
`renderedDestination`, `displayName`, `sourceLineNumber`, `errors`, optionally the `locale` and `variant` it rendered,
and the reviewer's `review` note (`liveContent`, `note`). `--expected-environment` is what was asked for and what the
tool said it supports: `destination`, `locale`, `variant`, `supportedLocales`, `supportedVariants`.

The response is rejected, and nothing is written, when:
- the returned destination is not the requested one (a requested iPhone Air rendered on another device is no evidence);
- `errors` is not an empty list;
- the snapshot path is missing, or names no non-empty file;
- the requested locale or variant is not one the tool supports, or the render is in another one than requested;
- the reviewer recorded a live date, spinner or other live content (never evidence).

An accepted response writes `preview-metadata.json` and a copy of the snapshot into `--output`, which must not exist
yet. A preview render is a review aid: the record says it never counts as snapshot acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

SIGNATURES = (('png', b'\x89PNG\r\n\x1a\n'), ('jpeg', b'\xff\xd8\xff'))
NOTICE = ('A preview render is a review aid. It is not snapshot acceptance and does not count toward any '
          'snapshot coordinate.')


def load(path, label, problems):
    try:
        value = json.loads(Path(path).read_text())
    except (OSError, ValueError) as error:
        problems.append(f'{label}: cannot read {Path(path).name}: {error}')
        return None
    if not isinstance(value, dict):
        problems.append(f'{label}: {Path(path).name} is not a JSON object')
        return None
    return value


def normalized(name):
    return ''.join(str(name).split()).casefold()


def check_text(value, field, problems):
    if not isinstance(value, str) or not value.strip():
        problems.append(f'{field} must be a non-empty string')
        return False
    return True


def check_expectation(expected, problems):
    check_text(expected.get('destination'), 'expected destination', problems)
    for field in ('supportedLocales', 'supportedVariants'):
        values = expected.get(field)
        if not isinstance(values, list) or not values or not all(isinstance(item, str) for item in values):
            problems.append(f'expected environment: {field} must be a non-empty list of strings')
    locale, variant = expected.get('locale'), expected.get('variant')
    if locale is not None and isinstance(expected.get('supportedLocales'), list) \
            and locale not in expected['supportedLocales']:
        problems.append(f'locale {locale!r} is not supported; the tool lists {expected["supportedLocales"]}')
    if variant is not None and isinstance(expected.get('supportedVariants'), list) \
            and variant not in expected['supportedVariants']:
        problems.append(f'variant {variant!r} is not supported; the tool lists {expected["supportedVariants"]}')


def check_response(response, expected, base, problems):
    """The snapshot file when everything holds, else None; each problem is appended as one line."""
    destination = response.get('renderedDestination')
    if check_text(destination, 'renderedDestination', problems) and isinstance(expected.get('destination'), str) \
            and normalized(destination) != normalized(expected['destination']):
        problems.append(f'destination mismatch: requested {expected["destination"]!r}, '
                        f'the tool rendered {destination!r}')
    check_text(response.get('displayName'), 'displayName', problems)
    line = response.get('sourceLineNumber')
    if isinstance(line, bool) or not isinstance(line, int) or line < 1:
        problems.append('response: sourceLineNumber must be a positive integer')
    errors = response.get('errors')
    if not isinstance(errors, list):
        problems.append('response: errors must be a list')
    elif errors:
        problems.append(f'response: errors is not empty ({len(errors)}): {errors}')
    for field in ('locale', 'variant'):
        requested, rendered = expected.get(field), response.get(field)
        if requested is not None and rendered is not None and rendered != requested:
            problems.append(f'{field} mismatch: requested {requested!r}, the tool rendered {rendered!r}')
    review = response.get('review')
    if review is not None:
        if not isinstance(review, dict) or not isinstance(review.get('liveContent'), bool):
            problems.append('response: review.liveContent must be true or false')
        elif review['liveContent']:
            problems.append('live content (a date, spinner or progress ring) is never evidence; '
                            f'review note: {review.get("note", "")!r}')
    path = response.get('previewSnapshotPath')
    if not isinstance(path, str) or not path.strip():
        problems.append('snapshot: previewSnapshotPath is missing')
        return None
    snapshot = Path(path)
    if not snapshot.is_absolute():
        snapshot = base / snapshot
    if not snapshot.is_file() or snapshot.stat().st_size == 0:
        problems.append(f'snapshot: {Path(path).name} is missing or empty')
        return None
    return snapshot


def sniff(data):
    return next((name for name, signature in SIGNATURES if data.startswith(signature)), 'unknown')


def validate(args):
    problems = []
    response = load(args.response, 'response', problems)
    expected = load(args.expected_environment, 'expected environment', problems)
    if response is None or expected is None:
        return problems
    check_expectation(expected, problems)
    snapshot = check_response(response, expected, Path(args.response).resolve().parent, problems)
    if problems or snapshot is None:
        return problems
    if args.output.exists():
        return [f'output: {args.output.name} already exists; use a new directory']
    data = snapshot.read_bytes()
    kind = sniff(data)
    suffix = {'png': '.png', 'jpeg': '.jpg'}.get(kind, '')
    args.output.mkdir(parents=True)
    shutil.copyfile(snapshot, args.output / f'snapshot{suffix}')
    record = {
        'schemaVersion': 1,
        'kind': 'preview-review-metadata',
        'status': 'accepted',
        'countsAsSnapshotAcceptance': False,
        'notice': NOTICE,
        'requested': {'destination': expected['destination'], 'locale': expected.get('locale'),
                      'variant': expected.get('variant')},
        'source': expected.get('source'),
        'returned': {
            'renderedDestination': response['renderedDestination'],
            'displayName': response['displayName'],
            'sourceLineNumber': response['sourceLineNumber'],
            'errors': response['errors'],
            'locale': response.get('locale'),
            'variant': response.get('variant'),
        },
        'snapshot': {'file': f'snapshot{suffix}', 'originalName': snapshot.name, 'format': kind,
                     'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()},
        'review': response.get('review'),
    }
    (args.output / 'preview-metadata.json').write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    return []


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--response', type=Path, required=True, help='stored result of one RenderPreview call')
    parser.add_argument('--expected-environment', type=Path, required=True,
                        help='the requested destination, locale and variant, and the values the tool supports')
    parser.add_argument('--output', type=Path, required=True, help='new directory for the metadata and snapshot')
    args = parser.parse_args(argv)
    problems = validate(args)
    for problem in problems:
        print(f'REJECTED: {problem}', file=sys.stderr)
    if problems:
        return 1
    print(f'ACCEPTED: {args.output / "preview-metadata.json"}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
