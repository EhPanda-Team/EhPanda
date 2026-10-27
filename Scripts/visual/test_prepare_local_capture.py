"""Behavior tests for the local capture source snapshot preparer."""

from __future__ import annotations

import copy
import importlib.util
import json
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("prepare-local-capture.py")
SPEC = importlib.util.spec_from_file_location("prepare_local_capture", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
capture = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(capture)


class SnapshotTests(unittest.TestCase):
    def test_copy_uses_git_source_list_and_preserves_current_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "source"
            root.mkdir()
            subprocess.run(["git", "init", "--quiet"], cwd=root, check=True)
            (root / ".gitignore").write_text("ignored.txt\nbuild/\n", encoding="utf-8")
            tracked = root / "tracked.swift"
            tracked.write_text("before staging", encoding="utf-8")
            subprocess.run(["git", "add", ".gitignore", "tracked.swift"], cwd=root, check=True)
            tracked.write_text("current working tree bytes", encoding="utf-8")
            (root / "untracked.swift").write_text("untracked source", encoding="utf-8")
            (root / "ignored.txt").write_text("ignored input", encoding="utf-8")
            (root / "build").mkdir()
            (root / "build/generated.swift").write_text("build output", encoding="utf-8")
            sources = capture.listed_sources(root)
            destination = Path(temporary) / "snapshot"

            capture.copy_snapshot(root, destination, sources)

            self.assertEqual((destination / "tracked.swift").read_text(), "current working tree bytes")
            self.assertEqual((destination / "untracked.swift").read_text(), "untracked source")
            self.assertFalse((destination / "ignored.txt").exists())
            self.assertFalse((destination / "build").exists())
            self.assertTrue((destination / ".git").is_dir())
            status = subprocess.run(
                ["git", "status", "--short"], cwd=destination, check=True, capture_output=True, text=True
            ).stdout
            self.assertIn("?? tracked.swift", status)

    def test_direct_relative_symlink_to_included_file_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "target.txt").write_text("data", encoding="utf-8")
            (root / "source-link").symlink_to("./target.txt")
            source_link_bytes = (root / "source-link").readlink().as_posix()
            subprocess.run(["git", "init", "--quiet"], cwd=root, check=True)
            destination = Path(temporary) / "snapshot"

            capture.copy_snapshot(root, destination, capture.listed_sources(root))

            self.assertTrue((destination / "source-link").is_symlink())
            self.assertEqual((destination / "source-link").readlink().as_posix(), source_link_bytes)
            self.assertEqual((destination / "source-link").read_text(encoding="utf-8"), "data")

    def test_unsafe_source_symlink_categories_are_rejected(self) -> None:
        links = {
            "absolute": "/tmp/foreign-target",
            "escaping": "../outside.txt",
            "dangling": "missing.txt",
            "directory-link": "directory",
            "ignored": "ignored.txt",
            "chained": "chain-a",
            "cyclic": "cycle-a",
        }
        for name, target in links.items():
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                (root / "target.txt").write_text("data", encoding="utf-8")
                (root / "directory").mkdir()
                (root / "directory/file.txt").write_text("data", encoding="utf-8")
                (root / ".gitignore").write_text("ignored.txt\n", encoding="utf-8")
                (root / "ignored.txt").write_text("ignored", encoding="utf-8")
                if name == "chained":
                    (root / "chain-a").symlink_to("target.txt")
                if name == "cyclic":
                    (root / "cycle-a").symlink_to("cycle-b")
                    (root / "cycle-b").symlink_to("cycle-a")
                (root / name).symlink_to(target)
                subprocess.run(["git", "init", "--quiet"], cwd=root, check=True)

                with self.subTest(link=name), self.assertRaises(capture.PreparationError):
                    capture.listed_sources(root)

    def test_output_must_be_new_and_inside_capture_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / ".capture").mkdir()
            existing = root / ".capture/existing"
            existing.mkdir()
            with patch.object(capture, "ROOT", root):
                self.assertEqual(capture.permitted_output(Path(".capture/new")), root / ".capture/new")
                for path in (Path("."), Path("outside"), Path(".capture/existing")):
                    with self.subTest(path=path), self.assertRaises(capture.PreparationError):
                        capture.permitted_output(path)

    def test_manifest_projection_requires_unique_anchor_and_targets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "Package.swift"
            path.write_text(
                "let targets = [.target(module: .appFeature, dependencies: []), "
                ".testTarget(module: .appFeatureTests, dependencies: [])]\n"
                "let package = Package(\n",
                encoding="utf-8",
            )
            capture.write_sdk_manifest(path, "../capture-sdk")
            generated = path.read_text(encoding="utf-8")
            self.assertEqual(generated.count("let package = Package("), 1)
            self.assertIn('dependencies.append(.package(name: "Appshot", path: "../capture-sdk"))', generated)
            self.assertIn('"AppFeature", "AppFeatureTests"', generated)
            self.assertIn('.product(name: "AppshotProtocol", package: "Appshot")', generated)

            path.write_text("let package = Package(\nlet package = Package(\n", encoding="utf-8")
            with self.assertRaisesRegex(capture.PreparationError, "declaration anchor"):
                capture.write_sdk_manifest(path, "../capture-sdk")

            path.write_text("let targets = []\nlet package = Package(\n", encoding="utf-8")
            with self.assertRaisesRegex(capture.PreparationError, "target identity"):
                capture.write_sdk_manifest(path, "../capture-sdk")


class ProjectProjectionTests(unittest.TestCase):
    def project_fixture(self) -> dict[str, object]:
        return {
            "objects": {
                "A" * 24: {"isa": "PBXProject", "packageReferences": ["EXISTING_PACKAGE"]},
                "B" * 24: {
                    "isa": "PBXNativeTarget",
                    "name": "EhPandaUITests",
                    "buildPhases": ["C" * 24],
                    "packageProductDependencies": ["EXISTING_PRODUCT"],
                },
                "C" * 24: {"isa": "PBXFrameworksBuildPhase", "files": ["EXISTING_BUILD_FILE"]},
                "D" * 24: {"isa": "XCSwiftPackageProductDependency", "productName": "Existing"},
                "E" * 24: {"isa": "PBXBuildFile", "productRef": "D" * 24},
            }
        }

    def test_projection_adds_linked_products_and_preserves_existing_objects(self) -> None:
        project = self.project_fixture()
        before = copy.deepcopy(project["objects"])
        capture.add_sdk_project_edges(project, "../capture-sdk")
        objects = project["objects"]
        self.assertEqual(len(objects), len(before) + 5)
        for object_id, original in before.items():
            current = copy.deepcopy(objects[object_id])
            if object_id == "A" * 24:
                current["packageReferences"] = original["packageReferences"]
            elif object_id == "B" * 24:
                current["packageProductDependencies"] = original["packageProductDependencies"]
            elif object_id == "C" * 24:
                current["files"] = original["files"]
            self.assertEqual(current, original)
        self.assertEqual(len(objects["A" * 24]["packageReferences"]), 2)
        self.assertEqual(len(objects["B" * 24]["packageProductDependencies"]), 3)
        self.assertEqual(len(objects["C" * 24]["files"]), 3)
        package_ref_id = objects["A" * 24]["packageReferences"][-1]
        self.assertEqual(objects[package_ref_id], {
            "isa": "XCLocalSwiftPackageReference",
            "relativePath": "../capture-sdk",
        })
        products = [objects[product_id] for product_id in objects["B" * 24]["packageProductDependencies"][1:]]
        self.assertEqual({product["productName"] for product in products}, {"AppshotXCTest", "AppshotProtocol"})
        self.assertTrue(all(product["package"] == package_ref_id for product in products))
        frameworks = [objects[file_id] for file_id in objects["C" * 24]["files"][1:]]
        self.assertEqual({objects[file["productRef"]]["productName"] for file in frameworks}, {
            "AppshotXCTest", "AppshotProtocol"
        })

    def test_projection_is_deterministic_and_rejects_missing_target_without_mutation(self) -> None:
        first = self.project_fixture()
        second = self.project_fixture()
        capture.add_sdk_project_edges(first, "../capture-sdk")
        capture.add_sdk_project_edges(second, "../capture-sdk")
        self.assertEqual(first, second)

        missing = self.project_fixture()
        del missing["objects"]["B" * 24]
        original = copy.deepcopy(missing)
        with self.assertRaisesRegex(capture.PreparationError, "EhPandaUITests target"):
            capture.add_sdk_project_edges(missing, "../capture-sdk")
        self.assertEqual(missing, original)

    def test_property_list_fixture_round_trips_through_plutil(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project = self.project_fixture()
            path = Path(temporary) / "project.pbxproj"
            path.write_bytes(plistlib.dumps(project, fmt=plistlib.FMT_XML))
            self.assertEqual(capture.load_project(path), project)


class CanonicalGraphTests(unittest.TestCase):
    def test_public_package_and_xcode_project_have_no_private_sdk_edges(self) -> None:
        root = SCRIPT.parents[2]
        manifest = subprocess.run(
            ["swift", "package", "--package-path", str(root / "AppPackage"), "dump-package"],
            check=True,
            capture_output=True,
            text=True,
        )
        package = json.loads(manifest.stdout)
        self.assertFalse(any(dependency.get("identity") == "appshot" for dependency in package["dependencies"]))
        for target in package["targets"]:
            for dependency in target.get("dependencies", []):
                product_dependency = dependency.get("product")
                if isinstance(product_dependency, list) and product_dependency:
                    self.assertNotIn(product_dependency[0], {"Appshot", "AppshotProtocol"})

        project = capture.load_project(root / "EhPanda.xcodeproj/project.pbxproj")
        objects = project["objects"]
        local_references = {
            object_id: item
            for object_id, item in objects.items()
            if item.get("isa") == "XCLocalSwiftPackageReference"
        }
        self.assertEqual(len(local_references), 1)
        app_package_id, app_package = next(iter(local_references.items()))
        self.assertEqual(app_package.get("relativePath"), "AppPackage")
        projects = [item for item in objects.values() if item.get("isa") == "PBXProject"]
        self.assertEqual(len(projects), 1)
        local_products = [
            item for item in objects.values()
            if item.get("isa") == "XCSwiftPackageProductDependency" and item.get("package") == app_package_id
        ]
        self.assertEqual({item.get("productName") for item in local_products}, {"AppFeature", "VisualSnapshotSupport"})
        self.assertFalse(any(
            item.get("isa") == "XCSwiftPackageProductDependency"
            and item.get("productName") in {"Appshot", "AppshotProtocol", "AppshotXCTest"}
            for item in objects.values()
        ))


if __name__ == "__main__":
    unittest.main()
