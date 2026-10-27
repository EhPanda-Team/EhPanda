---
phase: quick-261027-vgt
plan: "01"
type: execute
wave: 1
depends_on: []
autonomous: true
requirements: [QUICK-261027-vgt]
files_modified:
  - AppPackage/Sources/AppFeature/RootView.swift
  - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
  - AppPackage/Sources/AppFeature/UITestSupport/AppshotCapture.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift
  - EhPandaUITests/AppshotCaptureUITests.swift
  - AppPackage/Package.swift
  - EhPanda.xcodeproj/project.pbxproj
  - AppPackage/Tests/AppFeatureTests/UITestSupport/AppshotCaptureTests.swift
  - Scripts/visual/prepare-local-capture.py
  - Scripts/visual/test_prepare_local_capture.py
  - AppPackage/Tests/AppFeatureTests/UITestSupport/CaptureSDKAvailabilityTests.swift
  - Scripts/visual/README.md
  - appshot.json5
estimate:
  tokens: 26000
  raw_tokens: 26000
  tasks: 3
  confidence: low
must_haves:
  truths:
    - Ordinary Debug tests and Debug/Release builds resolve without any private checkout, credentials, or configuration.
    - An explicit local composition uses the real capture SDK and unchanged geometry, probe, stability, and app-content checks.
    - Capture launch keys cannot silently fall through to a live-data launch when the SDK is unavailable.
    - Preparing local capture never edits the canonical checkout or copies private SDK source into this repository.
  artifacts:
    - path: Scripts/visual/prepare-local-capture.py
      provides: Explicit isolated source snapshot with optional real SDK composition
    - path: Scripts/visual/test_prepare_local_capture.py
      provides: Dependency graph, snapshot integrity, and unsafe-output regression checks
    - path: AppPackage/Tests/AppFeatureTests/UITestSupport/CaptureSDKAvailabilityTests.swift
      provides: SDK-absent launch refusal coverage
  key_links:
    - from: Scripts/visual/prepare-local-capture.py
      to: AppPackage/Package.swift
      via: Generated-snapshot-only real SDK dependency insertion
    - from: Scripts/visual/prepare-local-capture.py
      to: EhPanda.xcodeproj/project.pbxproj
      via: Generated-snapshot-only SDK product linkage for EhPandaUITests
    - from: UITestAutomation.resolve
      to: CaptureScenePreparation
      via: SDK-present validated translation or unchanged app-owned capture configuration
---

<objective>
Make ordinary public builds independent of the private capture tool while preserving its local integration. The failed CI package resolution is caused by mandatory local references in both the Swift package and the Xcode project. Remove those mandatory edges and compose them only in an explicitly generated local source snapshot.

Do not edit the private tool. Do not restore removed CI checks or visual workflows. Do not introduce a substitute SDK, CI-specific source branches, package publishing, credentials, environment-sensitive manifest evaluation, or assumed dependency pruning through SwiftPM traits.
</objective>

<execution_context>
@$HOME/.codex/gsd-core/workflows/execute-plan.md
@$HOME/.codex/gsd-core/templates/summary.md
@$HOME/.agents/skills/pfw-spm/SKILL.md
</execution_context>

<context>
@AGENTS.md
@.swiftlint.yml
@.planning/STATE.md
@AppPackage/Package.swift
@EhPanda.xcodeproj/project.pbxproj
@AppshotCapture.xctestplan
@appshot.json5
@Scripts/visual/README.md

This is standard quick execution, not a milestone phase. Preserve unrelated work, especially the existing STATE.md edit. All implementation paths and verification working directories below are relative to the repository root. Use the tracked capitalization Scripts even on the case-insensitive local filesystem. Set author and committer timestamps to UTC+8 for every commit.

Follow the plan exactly. If repository state, APIs, compilation, or capture requirements demand a deviation, stop and report it to the orchestrator before implementing a different design. Use the Swift package skill and SwiftLint rules. No warning/error suppression and no new lint exemptions.

Known existing capture limitation: the checked-in capture pin has schemaVersion 1, whereas the current local tool documents a newer pin schema. Preserve pin values and the selected Xcode/runtime. SDK-enabled compilation and adapter tests are required; attempt an actual capture and report pre-existing pin incompatibility separately. Do not claim a successful screenshot capture when the tool refuses that pin, and do not migrate or remeasure it in this task.
</context>

<assumption_delta_decision>
Primary noun: public app build. Decision: promote. The app-owned capture interface remains available independently; the private SDK becomes an explicit local composition of the same sources. No SDK detection from a conventional sibling location and no ambient opt-in affect ordinary resolution. A separate snapshot prevents temporary dependency edits from leaking into public builds or concurrent work.
</assumption_delta_decision>

<tasks>

<task type="tracer">
  <name>Task 1: Isolate the real SDK integration without altering its capture behavior</name>
  <files>AppPackage/Sources/AppFeature/RootView.swift, AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift, AppPackage/Sources/AppFeature/UITestSupport/AppshotCapture.swift, AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift, EhPandaUITests/AppshotCaptureUITests.swift</files>
  <action>
  Guard the adapter file and its app imports/uses with DEBUG and canImport(Appshot) and canImport(AppshotProtocol). Guard the capture UI-test class with DEBUG and canImport(AppshotXCTest) and canImport(AppshotProtocol). These are optional real-integration compilation boundaries, not substitute implementations. Keep every enabled adapter validation, probe-isolation rule, state bridge, SDK geometry measurement, captureAppshotScene call, and CaptureContentVerifier invocation unchanged.

  In UITestAutomation.Configuration make the SDK scene a conditionally compiled stored property with a nil default; do not expose a private SDK type in the SDK-absent compilation. Construct ordinary configuration values first, then assign the SDK scene inside the enabled branch, avoiding conditional compilation inside argument lists. In resolve, keep SDK decode/translation and probe detection inside the same availability condition. In the unavailable branch, reject the presence of APPSHOT_SCENE, including an empty value or malformed JSON, by throwing CaptureFailure.malformedConfiguration with an actionable local-composition message before any normal-launch fallback. An absent key retains current behavior. Preserve the existing prepare error path that terminates before constructing app state. App-owned EHPANDA_CAPTURE_CONFIGURATION and EHPANDA_CAPTURE_FIXTURES remain functional, including their existing malformed-input and conflicting-key refusal.

  In CaptureDiagnostics, keep the app-owned accessibility JSON element unconditional within DEBUG. Construct that element without an SDK-typed initializer parameter. Only in an enabled composition, obtain AppshotCapture.launchedScene and add the actual AppshotStateView; preserve its diagnostics closure and visibility behavior. In RootView preserve the installed app-owned capture branch and put the probe-only SDK fallback inside the else branch under the SDK condition. Do not change navigation, layout, scroll edges, or capture readiness semantics.
  </action>
  <verify><automated>xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'</automated></verify>
  <done>The existing SDK-present path still compiles with unchanged checks, and no unavailable SDK type or member escapes the conditional boundary. Task 2 proves the absent dependency graph.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Remove mandatory dependencies and generate an explicit local composition</name>
  <files>AppPackage/Package.swift, EhPanda.xcodeproj/project.pbxproj, AppPackage/Tests/AppFeatureTests/UITestSupport/AppshotCaptureTests.swift, Scripts/visual/prepare-local-capture.py, Scripts/visual/test_prepare_local_capture.py</files>
  <behavior>
  - The ordinary manifest has no private local dependency or Appshot/AppshotProtocol target product edges; the ordinary Xcode project has no private package or AppshotXCTest/AppshotProtocol product/build-file references.
  - Snapshot preparation preserves current modified and untracked nonignored source bytes and relative layout, and does not copy Git metadata, ignored fixtures, build outputs, or the SDK source.
  - With explicit --sdk, only the snapshot gains the real package/product edges. Without it, the snapshot is a public build with no SDK edges.
  - Existing/nonempty destinations, destinations outside the permitted local-output root, invalid SDK paths, missing target identities, and missing or repeated insertion anchors fail without editing the source tree.
  - Generated project linkage preserves all pre-existing targets, settings, schemes and unrelated package edges.
  </behavior>
  <action>
  Remove the private dependency declaration and both targets' SDK product entries from Package.swift. Remove the private XCLocalSwiftPackageReference, its PBXProject packageReferences membership, the two UI-test XCSwiftPackageProductDependency objects, PBXBuildFile objects, framework-phase membership and target packageProductDependencies entries. Preserve AppPackage linkage and all unrelated UUIDs. Wrap the existing AppshotCaptureTests file in DEBUG plus both SDK canImport checks; keep every existing test assertion.

  Add a Python-standard-library-only preparer with CLI --output PATH and optional --sdk PATH. Resolve output under the repository's ignored .capture directory and require a nonexistent destination; refuse repository root, ancestor paths, symlinks, and any existing destination. With --sdk require an existing real package root containing Package.swift; do not infer a checkout location or access credentials. This parameter may point outside the repository but is never recorded in tracked files.

  Snapshot the current working tree using git ls-files -z --cached --others --exclude-standard. Copy existing ordinary files with metadata and preserve repository-relative names, including modifications and untracked nonignored sources; omit deleted entries. Reject submodules. Preserve a relative source symlink only when its direct target is an included ordinary file within the source root; copy the link itself without following it. Reject absolute, escaping, dangling, cyclic, directory, ignored-target, or chained links with an explicit diagnostic. This supports the repository's tracked CLAUDE.md to AGENTS.md link without changing repository state or copying outside files. Do not copy .git or ignored inputs. Create a new independent Git repository in the destination with git init, without staging or committing: the unchanged runner enumerates its sources with Git, including untracked nonignored files. Preserve the complete layout so test plans, local AppPackage paths, assets, schemes, SwiftLint configs and provenance glob patterns continue resolving. Keep failed snapshots for diagnosis; never automatically remove an existing directory. Print the resulting relative build root and whether SDK composition is enabled.

  In SDK mode insert one checked Swift manifest block immediately before the unique let package = Package( declaration in the snapshot only. It appends the real package named Appshot using the supplied path relative to the snapshot's AppPackage directory, then appends the real Appshot and AppshotProtocol product dependencies to the existing AppFeature and AppFeatureTests Target objects by exact name. Require both target identities. No environment variables, FileManager discovery or manifest switches are added to the canonical manifest. Escape generated Swift string literals correctly and reject control characters in the supplied path.

  Parse the copied Xcode project using plutil -convert json -o - and the Python json module; locate the PBXProject, EhPandaUITests target and its PBXFrameworksBuildPhase by isa and target name, asserting uniqueness. Add the actual local package path relative to the snapshot root, AppshotXCTest/AppshotProtocol product objects, target product memberships and corresponding PBXBuildFile/framework entries. Allocate deterministic unused 24-character hexadecimal IDs; fail on collision. Write the generated project as an XML property list with plistlib, which Xcode reads as a property list; run plutil -lint and xcodebuild -list against the generated project to verify acceptance before proceeding. Keep the canonical OpenStep project untouched by generation. No external parser installation is needed.

  Add unittest coverage for the above behavior using temporary source-tree fixtures and property-list fixtures, not a fake compilable SDK. Exercise dependency projection functions directly, preserving object identities and count/link invariants; tests must inspect semantics, not just string-presence gates. Add a test that the real canonical manifest dump and canonical project have no private edges after this change. Existing count/match gates are not the completion evidence; actual dependency resolution follows in Task 3.
  </action>
  <verify><automated>python3 -B -m unittest discover -s Scripts/visual -p test_prepare_local_capture.py</automated></verify>
  <done>Public manifests contain no private dependency edges; the preparer builds a separate self-contained source tree and adds the actual SDK graph only when explicitly requested. Snapshot provenance sees the generated manifest/project and copied sources.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Prove both compositions and document local capture setup</name>
  <files>AppPackage/Tests/AppFeatureTests/UITestSupport/CaptureSDKAvailabilityTests.swift, Scripts/visual/README.md, appshot.json5</files>
  <behavior>
  - In the public composition, no capture key leaves ordinary launch unchanged; every APPSHOT_SCENE value, including empty, valid-looking and invalid JSON, fails before fallback to live state.
  - Combining the unavailable SDK key with app-owned capture or UI-test keys also fails closed.
  - Existing app-owned capture validation tests pass without the SDK; existing real adapter tests run in the enabled composition.
  </behavior>
  <action>
  Add a Swift Testing suite for SDK absence under the inverse SDK canImport condition. Test resolve with isTesting false and true, empty environment, APPSHOT_SCENE values empty/invalid/valid-looking, and mixed app-owned capture/UI-test keys. Assert the typed malformedConfiguration failure, not nil or a live configuration. Keep the existing CaptureSceneTests and other capture suites as the independent app-owned contract coverage. In the enabled build run the existing AppshotCaptureTests rather than allowing this entire area to become untested through conditional exclusion.

  Replace the standalone local-capture section of Scripts/visual/README.md with explicit public/default and local-enabled commands. Remove the private repository name from the existing prose and appshot.json5 leading comment; call it the private capture tool. Preserve config values, axes, test selector, pin reference, fixtures and provenance patterns. Show --sdk "$CAPTURE_SDK" using an owner-supplied path and an independently supplied "$CAPTURE_CLI" executable; never document a hard-coded private repository name. Explain the copied tree reflects preparation time, so regenerate into a new output directory after edits. The runner is invoked with the snapshot as working directory, and fixture/output paths must be absolute runtime inputs so they do not resolve against the copied tree. No private files or absolute home paths enter generated documentation.

  From repository root create .capture/public-build with the preparer without --sdk. Use a fresh source-packages directory under that snapshot and run xcodebuild -resolvePackageDependencies -project .capture/public-build/EhPanda.xcodeproj -scheme EhPanda. This tree has no sibling private package: do not rename or remove the user's real private checkout. Resolve the package directly too with swift package --package-path .capture/public-build/AppPackage resolve. Build ordinary Debug and Release with xcodebuild build -project .capture/public-build/EhPanda.xcodeproj -scheme EhPanda -configuration Debug (then Release) -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO. Build the public UI test bundle with build-for-testing and testPlan UITests if the shared scheme declares that exact plan; otherwise stop for the orchestrator to select its declared ordinary UI plan. Do not substitute the SDK capture plan for this check.

  Run FeatureTests on the configured available simulator, limiting to AppFeatureTests; use the existing configured destination id=8E3EA338-4F93-40A7-BE4F-1F6E7C855F32 after confirming availability. If absent, ask the orchestrator for a verified replacement, without inventing a device. Repeat enabled-snapshot resolution/build-for-testing and AppshotCaptureTests using .capture/local-build generated with the real --sdk path. Resolve both graphs independently and inspect the enabled manifest dump/project product references. Run one xcodebuild test invocation at a time; never terminate another process.

  Attempt one real local capture with the unchanged CLI from .capture/local-build: capture --filter 'device=iphone,locale=en,screen=home,appearance=light,set=nonexplicit' --input "fixtures=$CAPTURE_FIXTURES" --output "$CAPTURE_OUTPUT". Use existing licensed fixtures and the existing pinned environment; do not download inputs or choose a different pin. If the CLI rejects the pre-existing pin schema, record the exact refusal and stop capture verification there while completing all public/enabled compilation and unit-test checks. Report preserved integration plus the capture blocker accurately. If capture succeeds, run verify on that output and require successful geometry/probe/content/stability evidence. Never turn the tool's required checks off to obtain a screenshot.

  Run SwiftLint on changed Swift files using the existing installation/config and the Python unittest suite. Record commands/results, the snapshot mode, and any pre-existing local capture blocker in the quick summary. Do not add CI workflows or CI validation promises.
  </action>
  <verify><automated>xcodebuild test -project .capture/public-build/EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=8E3EA338-4F93-40A7-BE4F-1F6E7C855F32' -only-testing:AppFeatureTests</automated></verify>
  <done>Public SwiftPM/Xcode resolution, Debug/Release builds and ordinary test compilation succeed without private files; public capture-refusal tests and enabled adapter tests pass. Local capture is preserved with the real SDK and its actual run outcome is recorded without concealing existing pin drift.</done>
</task>

</tasks>

<approved_checkpoint_resolution>
The first public snapshot encountered the existing tracked CLAUDE.md relative symlink. Task 2's policy above is revised to preserve direct relative links to included files. Add meaningful tests for preserved link bytes/target contents and each rejected category, then commit that bounded correction before resuming Task 3.

Also finish the original Task 1 boundaries during Task 3: the SDK scene declaration and probe detection must both be inside the SDK condition, with isProbe false when unavailable. Use let for the decoded SDK scene. For captureEnvironment assign a declared let in both compilation branches. For Configuration locals use a conditionally declared var in the SDK branch and let in the SDK-absent branch, followed by the shared initializer and enabled-only scene assignment. This preserves the planned common construction without unused-mutability warnings. Fix the nested appshotState indentation in RootView. These are corrections to the planned behavior, not a new design.

The generated manifest must mutate the existing Target objects directly in a for loop after exact-name validation. Keep the canonical targets array declared let; do not map/reassign the array or introduce an unused mutable local. Verify the SDK-enabled manifest with swift package dump-package so generated Swift is actually compiled, and inspect stderr for warnings. Make the canonical graph test assert that every local dependency is the existing AppPackage reference, rather than relying on a case-sensitive private-name substring. Keep the output source trees fresh after these corrections.

The originally configured simulator no longer exists. The orchestrator verified the available existing EhPanda Review iPhone 17 on iOS 27.0 with identifier CC444738-6672-47F8-BCCC-AC3BFBC344C5; use that identifier for the ordinary and SDK adapter unit-test runs in this task. The shared scheme declares UITests, so use that plan for ordinary UI-test compilation. This changes no pin or capture-device selection. The real local tool executable is already built; fixture availability and pin validation must be reported accurately without inventing fixture inputs.
</approved_checkpoint_resolution>

<threat_model>
## Trust boundaries

| Boundary | Data crossing it |
|---|---|
| Launch environment to application state | Untrusted capture keys and encoded scene |
| Explicit SDK/output paths to local filesystem | Owner-supplied local paths |
| Copied source graph to capture evidence | Current source bytes and generated composition |

## STRIDE threat register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|---|---|---|---|---|---|
| T-261027-vgt-01 | Information disclosure | Capture launch | high | mitigate | Reject SDK scene keys when SDK absent before state creation; retain all enabled validation and offline isolation. |
| T-261027-vgt-02 | Tampering | Snapshot preparer | high | mitigate | Nonexistent output under ignored local root only; reject symlinks/ancestors; never mutate canonical source or delete existing outputs. |
| T-261027-vgt-03 | Repudiation | Capture provenance | medium | mitigate | Independent snapshot Git root, current source bytes, generated graph included in unchanged provenance patterns; retain failed evidence. |
| T-261027-vgt-SC | Tampering | Dependency composition | high | mitigate | No new registry package installs; SDK path explicit, real products only; no credentials or vendored private source. |
</threat_model>

<verification>
Task 1 proves the real integration still compiles. Task 2 tests graph generation and source isolation. Task 3 proves real public dependency resolution/builds and both launch contracts using separate snapshots. Runtime verification of the existing pin is distinct from proving the new dependency composition; record its actual result. Do not imply a CI run was observed merely because local public checks passed.
</verification>

<source_audit>
| Source | Item | Coverage |
|---|---|---|
| GOAL | Public CI must resolve without private local files/access | Tasks 2–3 |
| REQ | QUICK-261027-vgt: preserve local capture | Tasks 1–3 |
| RESEARCH | Existing code has two independent package graphs | Task 2 removes and explicitly recomposes both |
| RESEARCH | SDK owns geometry/probes/stability; app owns content | Task 1 preserves actual SDK path; Task 3 exercises it |
| RESEARCH | Runner hashes Git-listed source files | Task 2 creates independent Git snapshot with complete relative layout |
| RESEARCH | Existing pin schema drift | Task 3 reports separate blocker without changing values |
| CONTEXT | Private source cannot be published or accessed from CI | Tasks 2–3; no remote private dependency |
| CONTEXT | Preserve prior CI cleanup; no suppressions or fake SDK | Objective and all tasks |
| CONTEXT | Malformed capture launches stay fail-closed | Tasks 1 and 3 |
| CONTEXT | No private repository names/home paths in public artifacts | Task 3 and execution constraints |
| CONTEXT | Preserve unrelated work; UTC+8 commit metadata | Execution context |

No deferred ideas are introduced. No external service capability is newly integrated; existing local integration is retained. No database/schema change is present. Assumption scan returned phase_unresolved for this quick identifier; the composition decision is nevertheless recorded explicitly above. Estimate calibration: factor 1, zero samples, confidence low.
</source_audit>

<success_criteria>
The public app's build graphs are independent of private files. An explicit local snapshot restores the real SDK integration without edits to the canonical checkout or private tool. Both compilation modes preserve capture validation, and verification clearly distinguishes passed checks from existing environment blockers.
</success_criteria>

<output>
Create .planning/quick/261027-vgt-make-ci-builds-independent-of-private-lo/261027-vgt-SUMMARY.md with implementation, verification, and local capture limitations.
</output>
