#!/usr/bin/env python3
"""The lint gate: a compiler warning or error, or a SwiftLint violation of any severity, in any target fails it.
The one exception is a warning inside a third-party package.

    python3 Scripts/lint/lint_check.py --output <directory>

Before the builds it checks the app-storage isolation rule over the test sources (`app_storage_isolation.py`, whose
docstring states the rule and the targets it leaves out): every Swift Testing suite that can reach app storage carries
TestingSupport's `.isolatedAppStorage` trait, and no other suite does. It reads the sources alone, so it needs no
build. Each break is an error finding, and so is a tree the check cannot read.

It builds every test plan of the app scheme for testing into a build folder of its own. A fresh folder compiles
every file of every target once (the app, the share extension, the package's modules and test targets, the
app-hosted tests and the UI tests), and a file only says what the compiler has against it when it is compiled: an
incremental build is silent about the files it skips. The plans are read from the scheme, so a new plan's targets
are built without a change here.

Then it runs SwiftLint itself, with the binary the build's plug-in uses, over every module from the module's own
directory, where its `.swiftlint.yml` and the parent it names apply. The plug-in runs the same lint during the
build, but `xcodebuild` now and then stops recording the plug-in's output before the output has arrived ("log
recorder ... was sent -appendText: after it had already been asked to stop recording"), and what arrives late is
lost. A violation of error severity still fails that build; one of warning severity is gone from its log. A clean
build of 2026-11-15 lost one that way, which the direct run reported.

A warning is allowed where the file it points at belongs to a package the build fetched: that code is not this
repository's to fix. Where the warning is decides, not who defined it. A deprecation a library declares, or a
diagnostic a library's macro emits, points at the file of this repository that triggers it, and fails the gate. So
does a warning that names no file, whose origin the output does not tell. Allowed warnings are still printed.

Everything found is printed as `path:line:column: severity: message`, once each, and the exit status is 1 when
anything fails. A build that fails, a module without a `.swiftlint.yml`, and a SwiftLint run that ends without a
result count as findings too, so the gate cannot pass by not having looked. The logs stay in the output directory.
"""

import argparse
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
from typing import NamedTuple, Optional
import xml.etree.ElementTree as ElementTree

import app_storage_isolation

ROOT = Path(__file__).resolve().parents[2]
PROJECT = 'EhPanda.xcodeproj'
SCHEME = 'EhPanda'

# Each directory here is linted from inside, under its own `.swiftlint.yml`: one per module and test target.
MODULE_PARENTS = ('AppPackage/Sources', 'AppPackage/Tests')
MODULES = ('EhPandaUITests',)
# Linted from the repository root, under the root configuration: the app shell, the share extension, the manifest and
# the Swift scripts the screenshot pre-check compiles.
ROOT_PATHS = ('App', 'ShareExtension', 'AppPackage/Package.swift', 'Scripts/visual')
# Swift files that belong to no target: evidence kept with the planning records, and fixtures of the script tests.
UNLINTED = ('.planning/', 'Scripts/Tests/fixtures/')
# What `xcrun` adds to the environment of a tool it starts, and the system's `python3` is started by it. They name
# the macOS SDK. `xcodebuild` would hand them on to the linker of each iOS test product, which then warns that the
# sysroot is not the target's: a warning of the gate's own making, in a tree that has none.
XCRUN_VARIABLES = ('SDKROOT', 'CPATH', 'LIBRARY_PATH')

LOCATED = re.compile(
    r'^(?P<path>/[^:]+):(?P<line>\d+):(?P<column>\d+): (?P<severity>warning|error): (?P<message>.+)$'
)
# The compiler repeats a diagnostic under the source line it points at: ` 44 |   code` and `    |   `- warning: ...`.
SOURCE_CONTEXT = re.compile(r'^\s*\d*\s*\|')
UNLOCATED = re.compile(r'(?:^|[\s:])(?P<severity>warning|error): (?P<message>\S.*)$')


class Finding(NamedTuple):
    """One warning or error. `path` is relative to the repository where the file is inside it."""
    path: str
    line: int
    column: int
    severity: str
    message: str

    def __str__(self):
        if self.path and self.line:
            return f'{self.path}:{self.line}:{self.column}: {self.severity}: {self.message}'
        if self.path:
            return f'{self.path}: {self.severity}: {self.message}'
        # A line of output without a place is kept whole, and names its severity itself.
        return self.message if f'{self.severity}: ' in self.message else f'{self.severity}: {self.message}'


def scheme_test_plans(scheme):
    """The names of the test plans a scheme lists, in its order."""
    plans = []
    for reference in ElementTree.parse(scheme).getroot().iter('TestPlanReference'):
        name = Path(reference.get('reference', '').split(':', 1)[-1]).stem
        if name and name not in plans:
            plans.append(name)
    return plans


def swift_modules(root):
    """The directories linted from inside, as (those with a `.swiftlint.yml`, those without).

    A directory without Swift files, such as an Objective-C module, has nothing for SwiftLint and is in neither.
    """
    candidates = [root / module for module in MODULES]
    for parent in MODULE_PARENTS:
        candidates += sorted(path for path in (root / parent).iterdir() if path.is_dir())
    configured, missing = [], []
    for directory in candidates:
        if not any(directory.rglob('*.swift')):
            continue
        (configured if (directory / '.swiftlint.yml').is_file() else missing).append(directory)
    return configured, missing


def is_linted(path):
    """Whether a Swift file at `path`, relative to the repository, is in a place the gate lints or leaves out."""
    if path.startswith(UNLINTED):
        return True
    if any(path == item or path.startswith(item + '/') for item in ROOT_PATHS + MODULES):
        return True
    return any(path.startswith(parent + '/') and '/' in path[len(parent) + 1:] for parent in MODULE_PARENTS)


def findings(text, root):
    """Every warning and error in the output of `xcodebuild` or SwiftLint, once each."""
    found = set()
    for line in text.splitlines():
        located = LOCATED.match(line)
        if located:
            found.add(Finding(
                relative(located['path'], root), int(located['line']), int(located['column']),
                located['severity'], located['message'].strip()
            ))
            continue
        if SOURCE_CONTEXT.match(line):
            continue
        unlocated = UNLOCATED.search(line)
        if unlocated:
            found.add(Finding('', 0, 0, unlocated['severity'], line.strip()))
    return found


def relative(path, root):
    try:
        return str(Path(path).resolve().relative_to(root.resolve()))
    except ValueError:
        return path


def ordered(found):
    """Located findings by place, then the rest by text."""
    return sorted(found, key=lambda item: (not item.path, item.path, item.line, item.column, item.message))


def is_third_party(item, packages, root):
    """Whether a warning points at a file of a package the build fetched into `packages`.

    A warning this repository's code triggers points at that code, whichever library defined the warning, and is
    not one of these. An error is never allowed: it fails the build as well.
    """
    if item.severity != 'warning':
        return False
    if item.path:
        return packages.resolve() in (root / item.path).resolve().parents
    # A finding without a place is a whole line of output; it counts where the line names such a file.
    return any(f'{form}/' in item.message for form in {packages.absolute(), packages.resolve()})


def judged(found, packages, root):
    """The findings in order, as (those that fail the gate, the third-party warnings it allows)."""
    result = ordered(found)
    allowed = [item for item in result if is_third_party(item, packages, root)]
    return [item for item in result if item not in allowed], allowed


def build_environment(environment):
    """The environment `xcodebuild` runs in: this process's, without what `xcrun` added to it."""
    return {name: value for name, value in environment.items() if name not in XCRUN_VARIABLES}


def build(plan, output, destination, cloned_packages):
    """Builds one test plan for testing, into the gate's own build folder. Returns the build's findings."""
    command = [
        'xcodebuild', 'build-for-testing', '-skipMacroValidation', '-skipPackagePluginValidation',
        '-project', PROJECT, '-scheme', SCHEME, '-testPlan', plan, '-destination', destination,
        '-derivedDataPath', str(output / 'derived-data'), '-onlyUsePackageVersionsFromResolvedFile'
    ]
    if cloned_packages:
        command += ['-clonedSourcePackagesDirPath', str(cloned_packages)]
    if destination.startswith('generic/'):
        # A generic destination builds every architecture; the host's alone compiles every file once.
        command.append(f'ARCHS={platform.machine()}')
    log = output / f'build-{plan}.log'
    with log.open('w') as stream:
        status = subprocess.run(
            command, cwd=ROOT, env=build_environment(os.environ), stdout=stream, stderr=subprocess.STDOUT, check=False
        ).returncode
    found = findings(log.read_text(errors='replace'), ROOT)
    if status != 0:
        message = f'The build of the {plan} plan failed with status {status} ({log.name}).'
        found.add(Finding('', 0, 0, 'error', message))
    return found


def swiftlint_binary(packages):
    """The SwiftLint binary of the plug-in's artifact bundle, among the build's packages."""
    matches = sorted(packages.glob('artifacts/**/SwiftLintBinary.artifactbundle/macos/swiftlint'))
    return matches[0] if matches else None


def lint(binary, output):
    """Runs SwiftLint over every module and the root paths. Returns its findings."""
    configured, missing = swift_modules(ROOT)
    found = {
        Finding(relative(str(directory), ROOT), 0, 0, 'error', 'This module has Swift files and no .swiftlint.yml.')
        for directory in missing
    }
    runs = [(directory, []) for directory in configured] + [(ROOT, list(ROOT_PATHS))]
    with (output / 'swiftlint.txt').open('w') as stream:
        for directory, paths in runs:
            result = subprocess.run(
                [str(binary), 'lint', '--quiet'] + paths, cwd=directory, capture_output=True, text=True, check=False
            )
            text = result.stdout + result.stderr
            stream.write(text)
            reported = findings(text, ROOT)
            found |= reported
            if result.returncode != 0 and not reported:
                found.add(Finding(
                    relative(str(directory), ROOT), 0, 0, 'error',
                    f'SwiftLint ended with status {result.returncode} and no finding: {text.strip() or "no output"}'
                ))
    return found


def app_storage_findings(root):
    """The breaks of the app-storage isolation rule, each an error at its place; a tree the check cannot read is
    one finding."""
    try:
        broken = app_storage_isolation.violations(root)
    except app_storage_isolation.ScopeError as error:
        return {Finding('', 0, 0, 'error', f'The app-storage isolation check could not read the tree: {error}')}
    return {Finding(item.path, item.line, 1 if item.line else 0, 'error', item.message) for item in broken}


def annotate(found):
    """GitHub's workflow commands for the findings that have a place, so they show beside the code."""
    def escaped(text):
        return text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')

    def escaped_property(text):
        return escaped(text).replace(':', '%3A').replace(',', '%2C')

    return [
        f'::{item.severity} file={escaped_property(item.path)},line={item.line},col={item.column}'
        f'::{escaped(item.message)}'
        for item in found if item.path and item.line
    ]


def summary(failing, allowed=()):
    """The findings as Markdown, for the job's summary: what fails the gate first, then what it allows."""
    def table(found):
        rows = ['| Where | Severity | Message |', '| --- | --- | --- |']
        for item in found:
            where = f'`{item.path}:{item.line}`' if item.path and item.line else f'`{item.path}`' if item.path else ''
            rows.append(f'| {where} | {item.severity} | {item.message.replace("|", "&#124;")} |')
        return rows

    if failing:
        lines = [f'{len(failing)} finding(s): each one fails the gate.', ''] + table(failing)
    else:
        lines = [
            'No compiler warning or error, no SwiftLint violation in any target of this repository, and no break of '
            'the app-storage isolation rule.'
        ]
    if allowed:
        lines += ['', f'{len(allowed)} warning(s) inside third-party packages, allowed.', ''] + table(allowed)
    return '\n'.join(lines) + '\n'


def main(argv: Optional[list] = None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--output', required=True, type=Path, help='where the build folder and the logs go')
    parser.add_argument(
        '--destination', default='generic/platform=iOS Simulator', help='the destination every plan is built for'
    )
    parser.add_argument(
        '--cloned-packages', type=Path,
        help='a directory of package checkouts to reuse (xcodebuild -clonedSourcePackagesDirPath), for a local run'
    )
    arguments = parser.parse_args(argv)
    output = arguments.output.resolve()
    shutil.rmtree(output / 'derived-data', ignore_errors=True)
    output.mkdir(parents=True, exist_ok=True)

    # Where the build keeps the packages it fetched: their checkouts and binary artifacts.
    packages = arguments.cloned_packages or output / 'derived-data' / 'SourcePackages'
    print('Checking the app-storage isolation rule.', flush=True)
    found = app_storage_findings(ROOT)
    for plan in scheme_test_plans(ROOT / PROJECT / 'xcshareddata' / 'xcschemes' / f'{SCHEME}.xcscheme'):
        print(f'Building the {plan} plan.', flush=True)
        found |= build(plan, output, arguments.destination, arguments.cloned_packages)
    binary = swiftlint_binary(packages)
    if binary:
        print('Running SwiftLint over every module.', flush=True)
        found |= lint(binary, output)
    else:
        found.add(Finding('', 0, 0, 'error', "SwiftLint's binary is not among the build's packages."))

    failing, allowed = judged(found, packages, ROOT)
    for item in failing:
        print(item)
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        print('\n'.join(annotate(failing)))
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write(summary(failing, allowed))
    print(summary(failing).splitlines()[0])
    if allowed:
        print(f'{len(allowed)} warning(s) inside third-party packages, allowed:')
        for item in allowed:
            print(item)
    return 1 if failing else 0


if __name__ == '__main__':
    sys.exit(main())
