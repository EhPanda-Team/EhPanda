#!/usr/bin/env python3
"""Run the Phase 17 native full-content feasibility gate, serially, without retries."""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
import plistlib
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GATE_SCRIPT = Path(__file__).resolve().relative_to(ROOT).as_posix()
FEASIBILITY = "VisualSnapshotTests/FullContentFeasibilityTests/"
ROTATION = "EhPandaUITests/VisualCaptureOrientationUITests/"
CONTENT_SIZES = {"large": "large", "AX5": "accessibility-extra-extra-extra-large"}
NATIVE_TESTS = [
    FEASIBILITY + name for name in (
        "testExportPublicFixtures", "testExportRendersReaderPagesAtRequestedPixelWidth",
        "testExportRejectsMissingFixtureAssetAndRoute", "testCommentsNativeCapture",
        "testDownloadsNativeCapture", "testReaderNativeCapture",
    )
] + [
    "VisualSnapshotTests/RenderServerCaptureTests", "VisualSnapshotTests/RenderSettlementTests",
    "VisualSnapshotTests/VisibleViewportTests", "VisualSnapshotTests/RenderedContentInspectionTests",
    "VisualSnapshotTests/FixtureArtworkTests", "VisualSnapshotTests/HostedHierarchyTests",
]


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def source_hashes():
    # Untracked, non-ignored files are listed too: uncommitted sources compile into every capture build.
    listed = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT)
    return {
        path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        for path in sorted(listed.decode().split("\0"))
        if path and (ROOT / path).is_file()
        and (path.startswith(("App/", "AppPackage/", "EhPandaUITests/", "EhPanda.xcodeproj/"))
             or path == GATE_SCRIPT or Path(path).name == ".swiftlint.yml")
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
        self.lifecycle = None

    def simulator_state(self, device):
        inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "--json"]))
        matches = [item for devices in inventory["devices"].values() for item in devices if item["udid"] == device]
        if len(matches) != 1:
            raise RuntimeError(f"Expected one simulator matching {device}, found {len(matches)}")
        return matches[0]["state"]

    def record_simulator_state(self, stage):
        state = self.simulator_state(self.lifecycle["device"])
        self.lifecycle["samples"].append({
            "stage": stage, "state": state, "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        save_json(self.output / f"{self.lifecycle['family']}-simulator-lifecycle.json", self.lifecycle)
        return state

    @contextmanager
    def simulator_session(self, family, device):
        original = self.simulator_state(device)
        original_content_size = None
        self.lifecycle = {
            "family": family, "device": device, "originalState": original,
            "bootedByGate": original != "Booted", "samples": [],
        }
        self.record_simulator_state("before-session")
        try:
            if self.lifecycle["bootedByGate"]:
                command = ["xcrun", "simctl", "bootstatus", device, "-b"]
                save_json(self.output / f"{family}-boot.command.json", command)
                with (self.output / f"{family}-boot.log").open("w") as stream:
                    subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
            if self.record_simulator_state("session-ready") != "Booted":
                raise RuntimeError(f"{family} simulator did not remain Booted after bootstatus")
            observed_size = subprocess.check_output(
                ["xcrun", "simctl", "ui", device, "content_size"], text=True
            ).strip()
            save_json(self.output / f"{family}-original.content-size.json", {
                "device": device, "observed": observed_size,
            })
            if observed_size in ("", "unknown", "unsupported"):
                raise RuntimeError(f"{family}: cannot preserve original content size {observed_size!r}")
            original_content_size = observed_size
            self.lifecycle["originalContentSize"] = original_content_size
            save_json(self.output / f"{family}-simulator-lifecycle.json", self.lifecycle)
            yield
        finally:
            try:
                if original_content_size is not None:
                    self.lifecycle["restoredOriginalContentSize"] = False
                    self.set_content_size(f"{family}-restore", device, original_content_size)
                    self.lifecycle["restoredOriginalContentSize"] = True
            finally:
                try:
                    if self.lifecycle["bootedByGate"] and self.simulator_state(device) != "Shutdown":
                        command = ["xcrun", "simctl", "shutdown", device]
                        save_json(self.output / f"{family}-shutdown.command.json", command)
                        with (self.output / f"{family}-shutdown.log").open("w") as stream:
                            subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
                finally:
                    final = self.record_simulator_state("after-session")
                    expected = "Shutdown" if self.lifecycle["bootedByGate"] else "Booted"
                    self.lifecycle["restoredOriginalState"] = final == expected
                    save_json(self.output / f"{family}-simulator-lifecycle.json", self.lifecycle)
                    self.lifecycle = None
            if final != expected:
                raise RuntimeError(f"{family} simulator cleanup left {final}; expected {expected}")

    def set_content_size(self, name, device, requested):
        command = ["xcrun", "simctl", "ui", device, "content_size", requested]
        result = subprocess.run(command, capture_output=True, text=True)
        readback = subprocess.run(command[:-1], capture_output=True, text=True)
        observed = readback.stdout.strip()
        # iOS 27 simctl returns "extra-Small" / "Small" for its documented lowercase category names.
        # Preserve both raw spellings in evidence, but compare the same category without case sensitivity.
        matched = result.returncode == 0 and readback.returncode == 0 and observed.lower() == requested.lower()
        save_json(self.output / f"{name}.content-size.json", {
            "device": device, "command": command, "requested": requested, "observed": observed,
            "exitCode": result.returncode, "stdout": result.stdout, "stderr": result.stderr,
            "readbackExitCode": readback.returncode, "readbackStderr": readback.stderr,
            "matched": matched,
        })
        result.check_returncode()
        readback.check_returncode()
        if not matched:
            raise RuntimeError(f"{name}: content size {observed!r} does not match {requested!r}")

    def run(self, name, actions, plan, device, tests=(), expected_count=None, cleanup=False, content_size=None):
        if not cleanup and source_hashes() != self.sources:
            raise RuntimeError("Sources changed during the gate; start a fresh run.")
        if self.lifecycle is None or self.lifecycle["device"] != device:
            raise RuntimeError(f"{name} has no simulator session for {device}")
        if self.record_simulator_state(f"before-{name}") != "Booted":
            raise RuntimeError(f"{name}: simulator stopped between invocations; rotation is no longer trustworthy")
        if plan == "FeatureTests":
            if content_size is None:
                raise RuntimeError(f"{name}: FeatureTests requires an explicit device content size")
            self.set_content_size(name, device, content_size)
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
        try:
            with log.open("w") as stream:
                result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        finally:
            after_state = self.record_simulator_state(f"after-{name}")
        save_json(self.output / f"{name}.exit.json", {"exitCode": result.returncode})
        summary = tree = None
        if bundle.exists():
            summary = result_json(bundle, "summary", self.output / f"{name}.summary.json")
            tree = result_json(bundle, "tests", self.output / f"{name}.tests.json")
            self.export_attachments(bundle, name)
        if after_state != "Booted":
            raise RuntimeError(f"{name}: simulator changed to {after_state}; rotation was not preserved")
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

    def verify_matrix(self, name, family, orientation, size):
        files = list((self.output / f"{name}-attachments").rglob("outcomes.json"))
        if len(files) != 1:
            raise RuntimeError(f"{name}: expected one outcomes.json, found {len(files)}")
        outcomes = json.loads(files[0].read_text())
        expected = {f"{family}-{orientation}-{size}-{shape}"
                    for shape in ("home", "comments", "downloads", "reader")}
        if (len(outcomes) != 4 or {item["coordinate"] for item in outcomes} != expected
                or any(item["status"] != "captured" for item in outcomes)):
            raise RuntimeError(f"{name}: incomplete coordinate coverage")
        for coordinate in sorted(expected):
            directory = files[0].parent / coordinate
            for filename in ("native-viewport-parity.json", "visible-viewport-freeze-parity.json"):
                if json.loads((directory / filename).read_text())["matched"] is not True:
                    raise RuntimeError(f"{coordinate}: {filename} failed")
            geometry = json.loads((directory / "geometry.json").read_text())
            self.verify_size_classes(geometry, coordinate)
            self.verify_full_content_settle(geometry, directory, coordinate)
            self.verify_read_verification(geometry, directory, coordinate)
            self.verify_content_size(directory)
            acceptance = json.loads((directory / "acceptance.json").read_text())
            if acceptance["coordinate"] != coordinate or acceptance["status"] != "captured":
                raise RuntimeError(f"{coordinate}: missing acceptance")
        return outcomes

    @staticmethod
    def verify_content_size(directory):
        evidence = json.loads((directory / "content-size-readiness.json").read_text())
        if (evidence["matched"] is not True
                or evidence["appCategory"] != evidence["requestedCategory"]
                or evidence["sceneCategory"] != evidence["requestedCategory"]):
            raise RuntimeError(f"{directory.name}: app/scene content size mismatch: {evidence}")

    @staticmethod
    def verify_size_classes(geometry, coordinate):
        classes = geometry["sizeClasses"]
        expected = classes["sceneAtViewport"]
        keys = ("windowAtViewport", "sceneCurrent", "windowCurrent")
        if any(classes[key] != expected for key in keys):
            raise RuntimeError(f"{coordinate}: capture changed native size classes: {classes}")

    @staticmethod
    def verify_read_verification(geometry, directory, coordinate):
        """Owned-row digests gate both passes; whole-read digests are evidence that must describe themselves."""
        evidence = json.loads((directory / "render-read-verification.json").read_text())
        reads = evidence.get("reads")
        slices = geometry.get("renderSlices")
        if (evidence.get("status") != "passed" or evidence.get("requestedPasses") != 2
                or evidence.get("failedSliceIndex") is not None
                or evidence.get("displayScale") != geometry.get("displayScale")
                or geometry.get("renderReadVerificationPasses") != 2
                or not isinstance(reads, list) or not reads or not isinstance(slices, list)
                or len(reads) != len(slices) or reads != geometry.get("renderReadVerifications")):
            raise RuntimeError(f"{coordinate}: incomplete same-rect read verification")
        scale = geometry["displayScale"]

        def rect(value):
            numbers = re.findall(r"-?\d+(?:\.\d+)?", value or "")
            return [float(number) for number in numbers] if len(numbers) == 4 else None

        def digest(value):
            return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None

        output_end = 0
        for index, (read, planned) in enumerate(zip(reads, slices)):
            frame, read_frame = rect(planned.get("frame")), rect(planned.get("readFrame"))
            pixels, owned = read.get("pixels"), read.get("ownedRows")
            owned_first, owned_second = read.get("firstPassOwnedSHA256"), read.get("secondPassOwnedSHA256")
            whole_first, whole_second = read.get("firstPassReadSHA256"), read.get("secondPassReadSHA256")
            if (frame is None or read_frame is None or read.get("sliceIndex") != index
                    or read.get("frame") != planned.get("frame") or read.get("readFrame") != planned.get("readFrame")
                    or not isinstance(pixels, list) or len(pixels) != 2
                    or any(type(value) is not int or value <= 0 for value in pixels)
                    or pixels != [round(value * scale) for value in read_frame[2:]]
                    or read.get("matched") is not True or not digest(owned_first) or owned_second != owned_first
                    or not digest(whole_first) or not digest(whole_second)
                    or not isinstance(read.get("readMatched"), bool)
                    or read["readMatched"] != (whole_first == whole_second)):
                raise RuntimeError(f"{coordinate}: invalid same-rect verification for read {index}")
            owned_start = round((frame[1] - read_frame[1]) * scale)
            expected_owned = [owned_start, owned_start + round(frame[3] * scale)]
            if (owned != expected_owned or not 0 <= owned_start < expected_owned[1] <= pixels[1]
                    or round(frame[1] * scale) != output_end):
                raise RuntimeError(f"{coordinate}: read {index} does not own exactly its composed rows")
            # Read 0 is the native rect: it owns, and therefore gates, every row it reads.
            if index == 0 and (frame != read_frame or owned != [0, pixels[1]]
                               or whole_first != owned_first or whole_second != owned_second):
                raise RuntimeError(f"{coordinate}: native read 0 must gate its whole read")
            output_end += expected_owned[1] - owned_start
        output_size = geometry.get("outputSize")
        if not isinstance(output_size, list) or len(output_size) != 2 or round(output_size[1] * scale) != output_end:
            raise RuntimeError(f"{coordinate}: owned rows do not partition the output")

    @staticmethod
    def verify_full_content_settle(geometry, directory, coordinate):
        """The grown window settled: consecutive identical owned-row passes over at least the stable span."""
        ledger = json.loads((directory / "full-content-settle.json").read_text())
        passes = ledger.get("passes")
        accepted = ledger.get("acceptedPass")
        maximum = ledger.get("maximumPasses")
        settled = ledger.get("settledMilliseconds")
        if (ledger.get("status") != "settled" or ledger.get("stableSpanMilliseconds") != 500 or maximum != 40
                or not isinstance(passes, list) or type(accepted) is not int or not 2 <= accepted <= maximum
                or len(passes) != accepted or type(settled) is not int or settled < 500):
            raise RuntimeError(f"{coordinate}: full-content rendering did not settle")
        reads = len(geometry.get("renderSlices") or [])
        previous = None
        elapsed = 0
        for number, record in enumerate(passes, start=1):
            digests = record.get("ownedSHA256")
            if (record.get("pass") != number or type(record.get("elapsedMilliseconds")) is not int
                    or record["elapsedMilliseconds"] < elapsed or not isinstance(digests, list)
                    or len(digests) != reads or not reads
                    or any(not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None
                           for value in digests)):
                raise RuntimeError(f"{coordinate}: invalid full-content settle pass {number}")
            changed = None if previous is None else [
                index for index, value in enumerate(digests) if value != previous[index]
            ]
            if record.get("changedSliceIndices") != changed:
                raise RuntimeError(f"{coordinate}: settle pass {number} misreports its changed reads")
            previous = digests
            elapsed = record["elapsedMilliseconds"]
        if passes[-1]["ownedSHA256"] != passes[-2]["ownedSHA256"]:
            raise RuntimeError(f"{coordinate}: the accepted settle pass differs from the one before it")

    def report_comments(self):
        directory = self.output / "iphone-AX5-comments-attachments"
        geometries = list(directory.rglob("geometry.json"))
        if len(geometries) != 1:
            raise RuntimeError("Expected one AX5 Comments geometry result")
        geometry = json.loads(geometries[0].read_text())
        self.verify_size_classes(geometry, "iphone-portrait-AX5-comments")
        self.verify_full_content_settle(geometry, geometries[0].parent, "iphone-portrait-AX5-comments")
        self.verify_read_verification(geometry, geometries[0].parent, "iphone-portrait-AX5-comments")
        self.verify_content_size(geometries[0].parent.parent)
        parity = json.loads((geometries[0].parent / "native-viewport-parity.json").read_text())
        evidence = {
            "outputSize": geometry["outputSize"], "displayScale": geometry["displayScale"],
            "requestedOutputHeights": geometry["requestedOutputHeights"],
            "sliceCount": len(geometry["renderSlices"]), "nativeViewportParity": parity["matched"],
            "census": geometry["census"],
        }
        if evidence["nativeViewportParity"] is not True:
            raise RuntimeError("AX5 Comments strict viewport parity failed")
        save_json(self.output / "iphone-AX5-comments-evidence.json", evidence)
        print("AX5 Comments: " + json.dumps(evidence, sort_keys=True), flush=True)

    def execute(self):
        inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
        save_json(self.output / "simulators.json", inventory)
        available = {device["udid"]: device for devices in inventory["devices"].values() for device in devices}
        for device, family in ((self.args.phone, "iPhone"), (self.args.tablet, "iPad")):
            if device not in available or family not in available[device]["deviceTypeIdentifier"]:
                raise RuntimeError(f"{device} is not an available {family} simulator")
        outcomes = []
        for family, device in (("iphone", self.args.phone), ("ipad", self.args.tablet)):
            with self.simulator_session(family, device):
                if family == "iphone":
                    self.run("clean-feature-build", ["clean", "build-for-testing"], "FeatureTests", device,
                             content_size=CONTENT_SIZES["large"])
                    self.run("orientation-build", ["build-for-testing"], "UITests", device)
                    self.single_pass_run("FeatureTests")
                    self.single_pass_run("UITests")
                try:
                    self.run(f"{family}-rotate-portrait", ["test-without-building"], "UITests", device,
                             [ROTATION + "testRotateToPortrait"], 1)
                    tests = NATIVE_TESTS + (["VisualSnapshotTests/VisualTracerTests"] if family == "iphone" else [])
                    self.run(f"{family}-native", ["test-without-building"], "FeatureTests", device,
                             tests, 60 if family == "iphone" else 57, content_size=CONTENT_SIZES["large"])
                    for orientation in ("portrait", "landscape"):
                        if orientation == "landscape":
                            self.run(f"{family}-rotate-landscape", ["test-without-building"], "UITests", device,
                                     [ROTATION + "testRotateToLandscape"], 1)
                        sizes = ("large", "AX5") if orientation == "portrait" else ("AX5", "large")
                        for size in sizes:
                            if family == "iphone" and orientation == "portrait" and size == "AX5":
                                self.run("iphone-AX5-comments", ["test-without-building"], "FeatureTests", device,
                                         [FEASIBILITY + "testAX5CommentsFullContentCapture"], 1,
                                         content_size=CONTENT_SIZES[size])
                                self.report_comments()
                            name = f"{family}-{orientation}-{size}"
                            test_size = "Large" if size == "large" else "AX5"
                            self.run(name, ["test-without-building"], "FeatureTests", device,
                                     [FEASIBILITY + f"test{orientation.title()}{test_size}FullContentMatrix"], 1,
                                     content_size=CONTENT_SIZES[size])
                            outcomes += self.verify_matrix(name, family, orientation, size)
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
