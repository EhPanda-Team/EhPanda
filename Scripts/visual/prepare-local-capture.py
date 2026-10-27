#!/usr/bin/env python3
"""Create an isolated source snapshot for public builds or explicit local capture."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import shutil
import stat
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT_NAME = "EhPandaUITests"
MANIFEST_ANCHOR = "let package = Package("


class PreparationError(Exception):
    """A source snapshot cannot be prepared safely."""


def run(arguments: list[str], *, cwd: Path | None = None, input_text: str | None = None) -> str:
    result = subprocess.run(
        arguments,
        cwd=cwd,
        input=input_text,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise PreparationError(f"Command failed ({result.returncode}): {' '.join(arguments)}\n{detail}")
    return result.stdout


def swift_string(value: str) -> str:
    if any(ord(character) < 0x20 or ord(character) == 0x7F for character in value):
        raise PreparationError("The SDK path contains a control character")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def generated_manifest_block(sdk_path: str) -> str:
    path_literal = swift_string(sdk_path)
    return f'''// Explicit local capture composition, generated only in this snapshot.
dependencies.append(.package(name: "Appshot", path: {path_literal}))
let appshotTargetDependencies: [PackageDescription.Target.Dependency] = [
    .product(name: "Appshot", package: "Appshot"),
    .product(name: "AppshotProtocol", package: "Appshot")
]
let appshotTargetNames = ["AppFeature", "AppFeatureTests"]
for targetName in appshotTargetNames {{
    precondition(targets.filter({{ $0.name == targetName }}).count == 1, "Expected exactly one \\(targetName) target")
}}
for target in targets where appshotTargetNames.contains(target.name) {{
    target.dependencies.append(contentsOf: appshotTargetDependencies)
}}

'''


def project_ids(objects: dict[str, object], seed: str, count: int) -> list[str]:
    ids: list[str] = []
    for index in range(count):
        object_id = hashlib.sha256(f"261027-vgt:{seed}:{index}".encode()).hexdigest()[:24].upper()
        if object_id in objects or object_id in ids:
            raise PreparationError(f"Deterministic project object ID collision: {object_id}")
        ids.append(object_id)
    return ids


def project_object(objects: dict[str, object], object_id: str, isa: str) -> dict[str, object]:
    item = objects.get(object_id)
    if not isinstance(item, dict) or item.get("isa") != isa:
        raise PreparationError(f"Expected project object {object_id} with isa {isa}")
    return item


def add_sdk_project_edges(project: dict[str, object], sdk_relative_path: str) -> None:
    objects = project.get("objects")
    if not isinstance(objects, dict):
        raise PreparationError("The project has no objects dictionary")
    pbx_projects = [item for item in objects.values() if isinstance(item, dict) and item.get("isa") == "PBXProject"]
    ui_targets = [
        (object_id, item)
        for object_id, item in objects.items()
        if isinstance(item, dict) and item.get("isa") == "PBXNativeTarget" and item.get("name") == PROJECT_NAME
    ]
    if len(pbx_projects) != 1 or len(ui_targets) != 1:
        raise PreparationError("Expected exactly one PBXProject and EhPandaUITests target")
    pbx_project = pbx_projects[0]
    target_id, target = ui_targets[0]
    phases = [
        project_object(objects, phase_id, "PBXFrameworksBuildPhase")
        for phase_id in target.get("buildPhases", [])
        if isinstance(objects.get(phase_id), dict) and objects[phase_id].get("isa") == "PBXFrameworksBuildPhase"
    ]
    if len(phases) != 1:
        raise PreparationError("Expected exactly one EhPandaUITests PBXFrameworksBuildPhase")
    package_refs = pbx_project.get("packageReferences")
    products = target.get("packageProductDependencies")
    framework_files = phases[0].get("files")
    if not all(isinstance(value, list) for value in (package_refs, products, framework_files)):
        raise PreparationError("The project dependency arrays are missing or malformed")

    ids = project_ids(objects, sdk_relative_path, 5)
    package_id, test_product_id, protocol_product_id, test_build_id, protocol_build_id = ids
    pbx_project["packageReferences"].append(package_id)
    target["packageProductDependencies"].extend([test_product_id, protocol_product_id])
    phases[0]["files"].extend([test_build_id, protocol_build_id])
    objects[package_id] = {
        "isa": "XCLocalSwiftPackageReference",
        "relativePath": sdk_relative_path,
    }
    for product_id, product_name in (
        (test_product_id, "AppshotXCTest"),
        (protocol_product_id, "AppshotProtocol"),
    ):
        objects[product_id] = {
            "isa": "XCSwiftPackageProductDependency",
            "package": package_id,
            "productName": product_name,
        }
    objects[test_build_id] = {"isa": "PBXBuildFile", "productRef": test_product_id}
    objects[protocol_build_id] = {"isa": "PBXBuildFile", "productRef": protocol_product_id}


def load_project(project_path: Path) -> dict[str, object]:
    converted = run(["plutil", "-convert", "json", "-o", "-", str(project_path)])
    try:
        project = json.loads(converted)
    except json.JSONDecodeError as error:
        raise PreparationError(f"Could not parse the Xcode project as JSON: {error}") from error
    if not isinstance(project, dict):
        raise PreparationError("The Xcode project root is not a dictionary")
    return project


def write_sdk_manifest(manifest_path: Path, sdk_relative_path: str) -> None:
    source = manifest_path.read_text(encoding="utf-8")
    if source.count(MANIFEST_ANCHOR) != 1:
        raise PreparationError("Expected exactly one Swift package declaration anchor")
    if source.count("module: .appFeature,") != 1 or source.count("module: .appFeatureTests,") != 1:
        raise PreparationError("Expected exactly one AppFeature and AppFeatureTests target identity")
    block = generated_manifest_block(sdk_relative_path)
    manifest_path.write_text(source.replace(MANIFEST_ANCHOR, block + MANIFEST_ANCHOR), encoding="utf-8")


def permitted_output(output: Path) -> Path:
    if output.is_absolute():
        candidate = output
    else:
        candidate = ROOT / output
    output_root = ROOT / ".capture"
    if output_root.is_symlink():
        raise PreparationError("The .capture output root must not be a symlink")
    candidate = Path(os.path.abspath(candidate))
    root = Path(os.path.abspath(output_root))
    if candidate == root or root not in candidate.parents:
        raise PreparationError("Output must be a new destination beneath the repository .capture directory")
    relative_parts = candidate.relative_to(root).parts
    cursor = root
    for part in relative_parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise PreparationError(f"Output path contains a symlink: {cursor}")
    if candidate.exists():
        raise PreparationError(f"Output destination already exists: {candidate}")
    return candidate


def listed_sources(root: Path) -> list[str]:
    paths = run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root
    ).encode()
    result = [os.fsdecode(path) for path in paths.split(b"\0") if path]
    index = run(["git", "ls-files", "--stage", "-z"], cwd=root).encode()
    submodules = [
        entry.split(b"\t", 1)[1].decode(errors="surrogateescape")
        for entry in index.split(b"\0")
        if entry and entry.startswith(b"160000 ")
    ]
    if submodules:
        raise PreparationError(f"Cannot snapshot Git submodules: {', '.join(submodules)}")
    included = set(result)
    for relative in result:
        source = root / relative
        if source.is_symlink():
            target = os.readlink(source)
            if os.path.isabs(target):
                raise PreparationError(f"Cannot snapshot absolute source symlink: {relative}")
            target_relative = os.path.normpath(os.path.join(os.path.dirname(relative), target))
            if target_relative == ".." or target_relative.startswith(f"..{os.sep}"):
                raise PreparationError(f"Cannot snapshot escaping source symlink: {relative}")
            if target_relative not in included:
                raise PreparationError(f"Cannot snapshot dangling or ignored-target source symlink: {relative}")
            target_path = root / target_relative
            if target_path.is_symlink():
                raise PreparationError(f"Cannot snapshot chained or cyclic source symlink: {relative}")
            try:
                target_mode = target_path.lstat().st_mode
            except OSError as error:
                raise PreparationError(f"Cannot inspect source symlink target: {relative}") from error
            if not stat.S_ISREG(target_mode):
                raise PreparationError(f"Cannot snapshot directory or non-file source symlink: {relative}")
        if source.exists() and not source.is_file():
            raise PreparationError(f"Cannot snapshot non-file source entry: {relative}")
    return result


def copy_snapshot(root: Path, destination: Path, sources: list[str]) -> None:
    destination.mkdir(parents=True, exist_ok=False)
    for relative in sources:
        source = root / relative
        if not source.exists() or source.is_symlink():
            continue
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    for relative in sources:
        source = root / relative
        if not source.is_symlink():
            continue
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(os.readlink(source), target)
    run(["git", "init", "--quiet"], cwd=destination)


def prepare(output: Path, sdk: Path | None) -> Path:
    destination = permitted_output(output)
    sdk_root: Path | None = None
    if sdk is not None:
        if sdk.is_symlink():
            raise PreparationError("The SDK package root must not be a symlink")
        try:
            sdk_root = sdk.resolve(strict=True)
        except OSError as error:
            raise PreparationError(f"SDK path does not exist: {sdk}") from error
        if not sdk_root.is_dir() or not (sdk_root / "Package.swift").is_file():
            raise PreparationError("--sdk must name an existing Swift package root containing Package.swift")
    sources = listed_sources(ROOT)
    copy_snapshot(ROOT, destination, sources)
    if sdk_root is not None:
        manifest_sdk_path = os.path.relpath(sdk_root, destination / "AppPackage")
        project_sdk_path = os.path.relpath(sdk_root, destination)
        write_sdk_manifest(destination / "AppPackage/Package.swift", manifest_sdk_path)
        project_path = destination / "EhPanda.xcodeproj/project.pbxproj"
        project = load_project(project_path)
        add_sdk_project_edges(project, project_sdk_path)
        project_path.write_bytes(plistlib.dumps(project, fmt=plistlib.FMT_XML, sort_keys=True))
    project_path = destination / "EhPanda.xcodeproj/project.pbxproj"
    run(["plutil", "-lint", str(project_path)])
    run(["xcodebuild", "-list", "-project", str(destination / "EhPanda.xcodeproj")])
    return destination


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path, metavar="PATH")
    parser.add_argument("--sdk", type=Path, metavar="PATH")
    args = parser.parse_args(argv)
    try:
        destination = prepare(args.output, args.sdk)
    except (PreparationError, OSError) as error:
        print(f"prepare-local-capture: {error}", file=sys.stderr)
        return 1
    mode = "SDK-enabled local capture" if args.sdk is not None else "public build"
    print(f"Build root: {destination.relative_to(ROOT)} ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
