#!/usr/bin/env python3
"""Every Swift Testing suite that can reach app storage carries `.isolatedAppStorage`, and no other suite does.

    python3 Scripts/lint/app_storage_isolation.py check
    python3 Scripts/lint/app_storage_isolation.py report
    python3 Scripts/lint/app_storage_isolation.py apply [repo-relative file ...]

`check` prints every break of the rule and exits 1 when there is one; the lint gate (`lint_check.py`) runs the same
check and fails on it. `report` lists the scope suite by suite. `apply` adds the trait, and the `import TestingSupport`
it needs, wherever the rule asks for them and they are missing; the file arguments limit it to those files. It never
removes anything and never edits `Package.swift`.

Why: the `defaultAppStorage` dependency's test value is Sharing's `UserDefaults.inMemory`, whose suite is named by a
path under the temporary directory. Such a file-backed suite can stop reflecting new writes in the simulator test
process under parallel load, so a later read returns an earlier value. TestingSupport's `.isolatedAppStorage` gives
every test case a plain-named suite of its own instead (quick task 261123-bcj). A suite that can reach app storage
without the trait runs on the stale-prone value, and nothing in the build would say so.

The rule:

1. Reader modules are the `AppPackage/Sources` modules whose code names an app-storage key (one that
   `AppModels/Persistence/AppSharedKeys.swift` declares with `.appStorage(`) inside `Shared(` or `SharedReader(`,
   closed over the package's `.module(...)` dependencies: a module that depends on a reader module is one too.
   AppModels only declares the keys and is not one by that alone.
2. A test file reaches app storage when its code, comments and string literals left out, imports a reader module, or
   names `defaultAppStorage`, `UserDefaults`, `.appStorage(` or an app-storage key inside `Shared(`/`SharedReader(`.
   With MemberImportVisibility on, nothing else in a file can drive a reader module. The rule is deliberately broad:
   reducers write app storage deep inside, so which suites write it cannot be told apart from their source.
3. A suite is a top-level `struct`, `class`, `enum` or `actor` of a test target with an `@Test` in its body or in a
   top-level `extension` of it in the same target. It needs the trait, once, on its own declaration, when any file
   that declares or extends it reaches app storage; a file-scope `@Test` function of such a file needs it on itself.
   The trait is recursive, so a nested suite or test never repeats it.
4. Every file that carries the trait imports TestingSupport, and every test target that holds such a suite links
   `.module(.testingSupport)` in `AppPackage/Package.swift`.

Out of scope, by design:

- VisualSnapshotTests: an XCTest target of the Xcode project. It cannot link TestingSupport, which is not a product,
  and isolates each former `.inMemory` site with its own `makeIsolatedAppStorage()`.
- HostedViewTests: an app-hosted Swift Testing target of the Xcode project that cannot link TestingSupport either. Its
  tests render views that read app storage and never write it, so they cannot see a stale value.
- LiveCheckTests: XCTest cases that read the live site only.
"""

import pathlib
import re
import sys
from typing import NamedTuple

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_OF_SCOPE = ('VisualSnapshotTests', 'HostedViewTests', 'LiveCheckTests')
TRAIT = '.isolatedAppStorage'
SUITE_ATTRIBUTE = '@Suite(.isolatedAppStorage)'
TEST_ATTRIBUTE = '@Test(.isolatedAppStorage)'
DECLARATION = re.compile(
    r'^(?:(?:private|fileprivate|internal|public|package|final|nonisolated)\s+)*'
    r'(struct|class|enum|actor|extension)\s+([A-Za-z_]\w*)'
)


class ScopeError(Exception):
    """The tree cannot be read the way the rule needs; the check reports it rather than passing."""


class Violation(NamedTuple):
    """One break of the rule. `path` is relative to the repository; `line` is 0 where the whole file is meant."""
    path: str
    line: int
    message: str

    def __str__(self):
        return f'{self.path}:{self.line}: {self.message}' if self.line else f'{self.path}: {self.message}'


def strip(text):
    """Blanks comments and string literals, keeping the line structure, so what they say counts for nothing."""
    out = []
    index, length = 0, len(text)
    while index < length:
        if text.startswith('"""', index):
            end = text.find('"""', index + 3)
            end = length if end < 0 else end + 3
            out.append(re.sub(r'[^\n]', ' ', text[index:end]))
        elif text[index] == '"':
            end = index + 1
            while end < length and text[end] not in '"\n':
                end += 2 if text[end] == '\\' else 1
            end = min(end + 1, length)
            out.append(' ' * (end - index))
        elif text.startswith('//', index):
            end = text.find('\n', index)
            end = length if end < 0 else end
            out.append(' ' * (end - index))
        elif text.startswith('/*', index):
            end = text.find('*/', index + 2)
            end = length if end < 0 else end + 2
            out.append(re.sub(r'[^\n]', ' ', text[index:end]))
        else:
            end = index + 1
            out.append(text[index])
        index = end
    return ''.join(out)


class SourceFile:
    """A test file: its lines, its code with comments and strings blanked, and its top-level declarations."""

    def __init__(self, root, path):
        self.path = path
        self.relative = str(path.relative_to(root))
        self.target = path.relative_to(root / 'AppPackage' / 'Tests').parts[0]
        self.lines = path.read_text().split('\n')
        self.code = strip('\n'.join(self.lines)).split('\n')
        self.declarations = []    # (kind, name, line index) at brace depth 0
        self.tested = set()       # names of the top-level declarations whose bodies hold an @Test
        self.global_tests = []    # line indices of file-scope @Test attributes
        self.reaches = False      # set by `scope`
        depth, current = 0, None
        for index, code in enumerate(self.code):
            if depth == 0:
                match = DECLARATION.match(code)
                if match:
                    current = (match.group(1), match.group(2), index)
                    self.declarations.append(current)
                elif re.match(r'^@Test\b', code):
                    self.global_tests.append(index)
            elif current and re.match(r'^\s+@Test\b', code):
                self.tested.add(current[1])
            depth += code.count('{') - code.count('}')

    def attribute_block(self, index):
        """The indices of the attribute lines directly above a declaration."""
        block = []
        above = index - 1
        while above >= 0 and self.code[above].startswith('@'):
            block.insert(0, above)
            above -= 1
        return block

    def carries_trait(self, index):
        return any(TRAIT in self.code[line] for line in self.attribute_block(index))

    def imports_testing_support(self):
        return any(re.match(r'^\s*(?:@testable\s+)?import\s+TestingSupport\b', code) for code in self.code)


class Scope(NamedTuple):
    readers: list
    files: list
    declared: dict    # (target, name) -> (SourceFile, line index)
    needed: list      # (target, name), sorted
    global_tests: list    # (SourceFile, line index)


def app_storage_keys(root):
    path = root / 'AppPackage' / 'Sources' / 'AppModels' / 'Persistence' / 'AppSharedKeys.swift'
    if not path.is_file():
        raise ScopeError(f'{path.relative_to(root)} is missing')
    keys = re.findall(r'public static var (\w+): Self \{\s*Self\[\.appStorage\(', path.read_text())
    if not keys:
        raise ScopeError(f'{path.relative_to(root)} declares no app-storage key')
    return keys


def package(root):
    """The package's module names by case, and each target's `.module(...)` dependencies by module name."""
    text = (root / 'AppPackage' / 'Package.swift').read_text()
    names = dict(re.findall(r'case (\w+) = "(\w+)"', text))
    targets = {}
    for match in re.finditer(r'\.(?:target|testTarget)\(\s*module: \.(\w+),\s*dependencies: \[(.*?)\]', text, re.S):
        if match.group(1) not in names:
            raise ScopeError(f'Package.swift names an unknown module case .{match.group(1)}')
        targets[names[match.group(1)]] = match.group(2)
    return names, targets


def reader_modules(root, key_use):
    names, targets = package(root)
    dependencies = {target: [names.get(case, case) for case in re.findall(r'\.module\(\.(\w+)\)', body)]
                    for target, body in targets.items()}
    sources = root / 'AppPackage' / 'Sources'
    readers = set()
    for module in sorted(path for path in sources.iterdir() if path.is_dir()):
        if module.name == 'AppModels':
            continue
        if any(key_use.search(strip(file.read_text())) for file in module.rglob('*.swift')):
            readers.add(module.name)
    changed = True
    while changed:
        changed = False
        for target, needs in dependencies.items():
            if target.endswith('Tests') or target == 'TestingSupport' or target in readers:
                continue
            if any(need in readers for need in needs):
                readers.add(target)
                changed = True
    return sorted(readers)


def scope(root=ROOT):
    keys = '|'.join(app_storage_keys(root))
    key_use = re.compile(r'Shared(?:Reader)?\((?:wrappedValue:[^)\n]*?,\s*)?\.(?:' + keys + r')\)')
    readers = reader_modules(root, key_use)
    imports = '|'.join(readers) if readers else r'(?!)'
    reach = re.compile(
        r'^\s*(?:@testable\s+)?(?:(?:public|internal|package)\s+)?import\s+(?:' + imports + r')\b'
        r'|\bdefaultAppStorage\b|\bUserDefaults\b|\.appStorage\(|' + key_use.pattern,
        re.M,
    )
    tests = root / 'AppPackage' / 'Tests'
    files = [SourceFile(root, path) for path in sorted(tests.rglob('*.swift'))
             if path.relative_to(tests).parts[0] not in OUT_OF_SCOPE]
    declared, tested, reaching = {}, set(), set()
    for file in files:
        reaches = bool(reach.search('\n'.join(file.code)))
        file.reaches = reaches
        for kind, name, index in file.declarations:
            key = (file.target, name)
            if kind != 'extension':
                declared[key] = (file, index)
            if name in file.tested:
                tested.add(key)
            if reaches:
                reaching.add(key)
    needed = sorted(key for key in tested if key in reaching)
    undeclared = [key for key in needed if key not in declared]
    if undeclared:
        raise ScopeError(f'suites with tests but no top-level declaration in their target: {undeclared}')
    global_tests = [(file, index) for file in files if file.reaches for index in file.global_tests]
    return Scope(readers, files, declared, needed, global_tests)


def violations(root=ROOT):
    """Every break of the rule, in file order. Raises `ScopeError` when the tree cannot be read."""
    found = []
    current = scope(root)
    allowed = set()
    for key in current.needed:
        file, index = current.declared[key]
        allowed.update((file.relative, line) for line in file.attribute_block(index))
        if not file.carries_trait(index):
            found.append(Violation(
                file.relative, index + 1,
                f'The suite {key[1]} can reach app storage and has no .isolatedAppStorage trait.'
            ))
    for file, index in current.global_tests:
        allowed.add((file.relative, index))
        if TRAIT not in file.code[index]:
            found.append(Violation(
                file.relative, index + 1,
                'This file-scope test can reach app storage and has no .isolatedAppStorage trait.'
            ))
    carriers = set()
    for file in current.files:
        for index, code in enumerate(file.code):
            # Only an attribute applies the trait; a value expression, in a test of the trait itself, is not a use.
            if TRAIT not in code or not re.match(r'^\s*@(?:Suite|Test)\b', code):
                continue
            carriers.add(file)
            if (file.relative, index) not in allowed:
                found.append(Violation(
                    file.relative, index + 1,
                    '.isolatedAppStorage belongs only on the top-level suite of a file that can reach app storage.'
                ))
    for file in sorted(carriers, key=lambda item: item.relative):
        if not file.imports_testing_support():
            found.append(Violation(
                file.relative, 0, 'This file carries .isolatedAppStorage and does not import TestingSupport.'
            ))
    names, targets = package(root)
    cases = {name: case for case, name in names.items()}
    for target in sorted({key[0] for key in current.needed}):
        body = targets.get(target, '')
        if target not in cases or '.module(.testingSupport)' not in body:
            found.append(Violation(
                'AppPackage/Package.swift', 0,
                f'The test target {target} holds suites that need .isolatedAppStorage and does not link TestingSupport.'
            ))
    return sorted(found, key=lambda item: (item.path, item.line, item.message))


def with_trait(line, location):
    if line == '@Suite':
        return SUITE_ATTRIBUTE
    if line == '@Test':
        return TEST_ATTRIBUTE
    match = re.fullmatch(r'(@Suite|@Test)\((.*)\)', line)
    if not match or match.group(2).count('(') != match.group(2).count(')'):
        raise ScopeError(f'{location}: an attribute of a shape apply does not edit: {line!r}')
    return f'{match.group(1)}({match.group(2)}, {TRAIT})'


def apply(root=ROOT, only=()):
    """Adds the trait and the import where the rule needs them; returns the files it changed, in order."""
    current = scope(root)
    only = set(only)
    if only:
        unknown = sorted(only - {file.relative for file in current.files})
        if unknown:
            raise ScopeError(f'not test files in scope: {unknown}')
    edits = {}
    for key in current.needed:
        file, index = current.declared[key]
        if (only and file.relative not in only) or file.carries_trait(index):
            continue
        block = file.attribute_block(index)
        suites = [line for line in block if file.code[line].startswith('@Suite')]
        if suites:
            edits.setdefault(file, []).append((suites[0], 'replace'))
        else:
            edits.setdefault(file, []).append((block[0] if block else index, 'insert'))
    for file, index in current.global_tests:
        if (only and file.relative not in only) or TRAIT in file.code[index]:
            continue
        edits.setdefault(file, []).append((index, 'replace'))
    changed = []
    for file in sorted(edits, key=lambda item: item.relative):
        lines = list(file.lines)
        for index, kind in sorted(edits[file], reverse=True):
            if kind == 'replace':
                lines[index] = with_trait(lines[index], f'{file.relative}:{index + 1}')
            else:
                lines.insert(index, SUITE_ATTRIBUTE)
        if 'import TestingSupport' not in lines:
            if 'import Testing' not in lines:
                raise ScopeError(f'{file.relative}: no `import Testing` line to put `import TestingSupport` after')
            lines.insert(lines.index('import Testing') + 1, 'import TestingSupport')
        for number, line in enumerate(lines, 1):
            if len(line) > 120:
                raise ScopeError(f'{file.relative}:{number}: longer than 120 columns after apply')
        if len(lines) - (1 if lines and lines[-1] == '' else 0) > 1000:
            raise ScopeError(f'{file.relative}: longer than 1000 lines after apply')
        file.path.write_text('\n'.join(lines))
        changed.append(file.relative)
    return changed


def report(root=ROOT):
    current = scope(root)
    found = violations(root)
    lines = [f'READER_MODULES {len(current.readers)}: {" ".join(current.readers)}',
             f'NEEDS {len(current.needed) + len(current.global_tests)}']
    for key in current.needed:
        file, index = current.declared[key]
        state = 'has' if file.carries_trait(index) else 'missing'
        lines.append(f'  {file.relative}:{index + 1} {key[1]} [{state}]')
    for file, index in current.global_tests:
        state = 'has' if TRAIT in file.code[index] else 'missing'
        lines.append(f'  {file.relative}:{index + 1} file-scope @Test [{state}]')
    lines.append(f'VIOLATIONS {len(found)}')
    lines += [f'  {item}' for item in found]
    return '\n'.join(lines)


def main(argv=None):
    arguments = sys.argv[1:] if argv is None else argv
    mode = arguments[0] if arguments else ''
    try:
        if mode == 'check' and len(arguments) == 1:
            found = violations()
            for item in found:
                print(item)
            print(f'{len(found)} break(s) of the app-storage isolation rule.')
            return 1 if found else 0
        if mode == 'report' and len(arguments) == 1:
            print(report())
            return 0
        if mode == 'apply':
            for path in apply(only=arguments[1:]):
                print(f'applied {path}')
            return 0
    except ScopeError as error:
        print(f'error: {error}')
        return 1
    print('usage: app_storage_isolation.py check | report | apply [repo-relative file ...]')
    return 2


if __name__ == '__main__':
    sys.exit(main())
