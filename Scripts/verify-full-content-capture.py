#!/usr/bin/env python3
"""Run the Phase 17 native full-content feasibility gate, serially, without retries."""

import argparse
import hashlib
import json
import os
import plistlib
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FEASIBILITY = "VisualSnapshotTests/FullContentFeasibilityTests/"
ROTATION = "EhPandaUITests/VisualCaptureOrientationUITests/"
NATIVE_TESTS = [
    FEASIBILITY + name for name in (
        "testExportPublicFixtures", "testExportRendersReaderPagesAtRequestedPixelWidth",
        "testExportRejectsMissingFixtureAssetAndRoute", "testCommentsNativeCapture",
        "testDownloadsNativeCapture", "testReaderNativeCapture",
    )
] + ["VisualSnapshotTests/RenderServerCaptureTests", "VisualSnapshotTests/VisibleViewportTests"]


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def source_hashes():
    paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    paths += ["AppPackage/Tests/VisualSnapshotTests/VisibleViewportTests.swift"]
    paths += ["EhPandaUITests/VisualCaptureOrientationUITests.swift", str(Path(__file__).relative_to(ROOT))]
    return {
        path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        for path in sorted(set(paths))
        if path and (ROOT / path).is_file()
        and (path.startswith(("App/", "AppPackage/", "EhPandaUITests/", "EhPanda.xcodeproj/"))
             or path == str(Path(__file__).relative_to(ROOT)) or Path(path).name == ".swiftlint.yml")
    }


def result_json(bundle, kind, destination):
    data = json.loads(subprocess.check_output([
        "xcrun", "xcresulttool", "get", "test-results", kind, "--path", str(bundle)
    ]))
    save_json(destination, data)
    return data


def nodes(value):
    if isinstance(value, dict):
        yield value
        for item in value.values():
            yield from nodes(item)
    elif isinstance(value, list):
        for item in value:
            yield from nodes(item)


class Gate:
    def __init__(self, arguments):
        self.args = arguments
        self.output = arguments.output.resolve()
        self.output.mkdir(parents=True, exist_ok=False)
        self.sources = source_hashes()
        save_json(self.output / "source-hashes.json", self.sources)
        self.common = [
            "-project", "EhPanda.xcodeproj", "-scheme", "EhPanda",
            "-derivedDataPath", str(arguments.derived_data.resolve()),
            "-parallel-testing-enabled", "NO",
        ]
        self.test_runs = {}

    def run(self, name, actions, plan, device, tests=(), expected_count=None, cleanup=False):
        if not cleanup and source_hashes() != self.sources:
            raise RuntimeError("Sources changed during the gate; start a fresh run.")
        bundle = self.output / f"{name}.xcresult"
        if expected_count is None:
            command = ["xcodebuild", *actions, *self.common, "-testPlan", plan]
        else:
            command = ["xcodebuild", *actions, "-xctestrun", str(self.test_runs[plan]),
                       "-parallel-testing-enabled", "NO"]
        command += ["-destination", f"platform=iOS Simulator,id={device}"]
        command += [f"-only-testing:{test}" for test in tests]
        if expected_count is not None:
            command += ["-resultBundlePath", str(bundle)]
        save_json(self.output / f"{name}.command.json", command)
        log = self.output / f"{name}.log"
        print(f"Starting {name}", flush=True)
        with log.open("w") as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        save_json(self.output / f"{name}.exit.json", {"exitCode": result.returncode})
        summary = tree = None
        if bundle.exists():
            summary = result_json(bundle, "summary", self.output / f"{name}.summary.json")
            tree = result_json(bundle, "tests", self.output / f"{name}.tests.json")
            self.export_attachments(bundle, name)
        if result.returncode:
            raise RuntimeError(f"{name} exited {result.returncode}; inspect {log}")
        diagnostics = re.findall(r"^.*\b(?:warning|error):.*$", log.read_text(), re.MULTILINE)
        save_json(self.output / f"{name}.diagnostics.json", diagnostics)
        if diagnostics:
            raise RuntimeError(f"{name} has compiler/lint diagnostics; inspect {log}")
        if expected_count is not None:
            if (summary is None or summary["totalTestCount"] != expected_count
                    or summary["passedTests"] != expected_count
                    or any(summary[key] for key in ("failedTests", "skippedTests", "expectedFailures"))
                    or any("Repetition" in item.get("nodeType", "") for item in nodes(tree))):
                raise RuntimeError(f"{name} did not pass exactly {expected_count} tests without skips/repetitions")
            devices = {item["device"]["deviceId"] for item in summary["devicesAndConfigurations"]}
            if devices != {device}:
                raise RuntimeError(f"{name} ran on unexpected devices: {devices}")
        print(f"Passed {name}", flush=True)

    def single_pass_run(self, plan):
        products = self.args.derived_data.resolve() / "Build/Products"
        candidates = []
        for path in products.glob("*.xctestrun"):
            if path.name.startswith("phase17-"):
                continue
            data = plistlib.loads(path.read_bytes())
            if data.get("TestPlan", {}).get("Name") == plan:
                candidates.append((path, data))
        if len(candidates) != 1:
            raise RuntimeError(f"Expected one generated {plan} test run, found {len(candidates)}")
        source, data = candidates[0]
        removed = []
        for item in nodes(data):
            if "TestRepetitionPolicy" in item:
                removed.append({"key": "TestRepetitionPolicy", "value": item.pop("TestRepetitionPolicy")})
        save_json(self.output / f"{plan}-single-pass.json", {"source": source.name, "removed": removed})
        destination = products / f"phase17-{plan}.xctestrun"
        destination.write_bytes(plistlib.dumps(data))
        self.test_runs[plan] = destination

    def export_attachments(self, bundle, name):
        directory = self.output / f"{name}-attachments"
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle),
                        "--output-path", str(directory)], check=True, stdout=subprocess.DEVNULL)
        manifest = json.loads((directory / "manifest.json").read_text())
        for test in manifest:
            for attachment in test["attachments"]:
                archive = directory / attachment["exportedFileName"]
                if archive.suffix != ".zip":
                    continue
                destination = directory / archive.stem
                with zipfile.ZipFile(archive) as zipped:
                    for entry in zipped.infolist():
                        if not (destination / entry.filename).resolve().is_relative_to(destination.resolve()):
                            raise RuntimeError(f"Unsafe attachment path: {entry.filename}")
                    zipped.extractall(destination)

    def verify_matrix(self, name, family, orientation):
        files = list((self.output / f"{name}-attachments").rglob("outcomes.json"))
        if len(files) != 1:
            raise RuntimeError(f"{name}: expected one outcomes.json, found {len(files)}")
        outcomes = json.loads(files[0].read_text())
        expected = {f"{family}-{orientation}-{size}-{shape}"
                    for size in ("large", "AX5") for shape in ("home", "comments", "downloads", "reader")}
        if (len(outcomes) != 8 or {item["coordinate"] for item in outcomes} != expected
                or any(item["status"] != "captured" for item in outcomes)):
            raise RuntimeError(f"{name}: incomplete coordinate coverage")
        for coordinate in sorted(expected):
            directory = files[0].parent / coordinate
            for filename in ("native-viewport-parity.json", "visible-viewport-freeze-parity.json"):
                if json.loads((directory / filename).read_text())["matched"] is not True:
                    raise RuntimeError(f"{coordinate}: {filename} failed")
            acceptance = json.loads((directory / "acceptance.json").read_text())
            if acceptance["coordinate"] != coordinate or acceptance["status"] != "captured":
                raise RuntimeError(f"{coordinate}: missing acceptance")
        return outcomes

    def execute(self):
        inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
        save_json(self.output / "simulators.json", inventory)
        available = {device["udid"]: device for devices in inventory["devices"].values() for device in devices}
        for device, family in ((self.args.phone, "iPhone"), (self.args.tablet, "iPad")):
            if device not in available or family not in available[device]["deviceTypeIdentifier"]:
                raise RuntimeError(f"{device} is not an available {family} simulator")
        self.run("clean-feature-build", ["clean", "build-for-testing"], "FeatureTests", self.args.phone)
        self.run("orientation-build", ["build-for-testing"], "UITests", self.args.phone)
        self.single_pass_run("FeatureTests")
        self.single_pass_run("UITests")
        outcomes = []
        for family, device in (("iphone", self.args.phone), ("ipad", self.args.tablet)):
            try:
                self.run(f"{family}-rotate-portrait", ["test-without-building"], "UITests", device,
                         [ROTATION + "testRotateToPortrait"], 1)
                tests = NATIVE_TESTS + (["VisualSnapshotTests/VisualTracerTests"] if family == "iphone" else [])
                self.run(f"{family}-native", ["test-without-building"], "FeatureTests", device,
                         tests, 15 if family == "iphone" else 12)
                for orientation in ("portrait", "landscape"):
                    if orientation == "landscape":
                        self.run(f"{family}-rotate-landscape", ["test-without-building"], "UITests", device,
                                 [ROTATION + "testRotateToLandscape"], 1)
                    name = f"{family}-{orientation}"
                    self.run(name, ["test-without-building"], "FeatureTests", device,
                             [FEASIBILITY + f"test{orientation.title()}FullContentMatrix"], 1)
                    outcomes += self.verify_matrix(name, family, orientation)
                    save_json(self.output / "matrix-outcomes.json", outcomes)
            finally:
                self.run(f"{family}-restore-portrait", ["test-without-building"], "UITests", device,
                         [ROTATION + "testRotateToPortrait"], 1, cleanup=True)
        if len(outcomes) != 32 or source_hashes() != self.sources:
            raise RuntimeError("Incomplete matrix or source changes during capture")
        save_json(self.output / "gate.json", {"status": "passed", "captured": len(outcomes)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phone", required=True)
    parser.add_argument("--tablet", required=True)
    parser.add_argument("--output", type=Path, required=True, help="Fresh external evidence directory")
    parser.add_argument("--derived-data", type=Path, required=True)
    args = parser.parse_args()
    os.chdir(ROOT)
    Gate(args).execute()


if __name__ == "__main__":
    main()
