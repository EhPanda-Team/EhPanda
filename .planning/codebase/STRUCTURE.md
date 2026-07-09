# Codebase Structure

**Analysis Date:** 2026-07-09

## Directory Layout

```
EhPanda/
├── App/                       # Thin app-shell target (no business logic)
│   ├── EhPandaApp.swift        # @main App scene
│   ├── Info.plist / *.entitlements
│   ├── Assets.xcassets/        # App assets + category icons
│   └── Icons/                  # Alternate app icon PNGs
├── AppPackage/                # Local Swift package — ALL logic lives here
│   ├── Package.swift           # Targets + third-party dependencies
│   ├── Sources/<Module>/       # One directory per module
│   └── Tests/<Module>Tests/    # Mirrored test targets + .xctestplan
├── ShareExtension/            # Share extension target
│   └── ShareViewController.swift
├── EhPanda.xcodeproj          # References AppPackage as XCLocalSwiftPackageReference
├── .swiftlint.yml             # Root lint config (custom regex rules, banned APIs)
├── Scripts/                   # Build/tooling scripts
├── actions-tool/              # CI/GitHub actions helper tool
├── READMEs/                   # Additional docs
└── .planning/                 # GSD planning artifacts (this doc)
```

## Directory Purposes

**`App/`:**
- Purpose: Thin app-shell target; boots the scene, mounts the root view.
- Contains: `EhPandaApp.swift`, Info.plist, entitlements, assets, icons.
- Key files: `App/EhPandaApp.swift`

**`AppPackage/Sources/`:**
- Purpose: Every module (features, clients, models, utilities).
- Contains: one subdirectory per module.
- Key files: `AppPackage/Package.swift`, `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift`

**`AppPackage/Tests/`:**
- Purpose: Swift Testing test targets, mirroring source module names.
- Contains: `AppModelsTests`, `DetailFeatureTests`, `DownloadsFeatureTests`, `FileClientTests`, `NetworkingFeatureTests`, `ParserFeatureTests`, `SettingFeatureTests`, and `FeatureTests.xctestplan`.

**`ShareExtension/`:**
- Purpose: iOS share-sheet extension target.
- Key files: `ShareExtension/ShareViewController.swift`

## Module Categories (AppPackage/Sources)

**Root / composition:**
- `AppFeature` — root reducer (`DataFlow/AppReducer.swift`, `AppRouteReducer.swift`, `AppLockReducer.swift`, `AppDelegateReducer.swift`), `RootView.swift`, `View/TabBar/`.

**Feature modules (`@Reducer` + SwiftUI views):**
- `HomeFeature`, `SearchFeature`, `FavoritesFeature`, `DownloadsFeature`, `SettingFeature`, `DetailFeature`, `ReadingFeature`, `ReadingSettingFeature`, `FiltersFeature`, `QuickSearchFeature`, `DateSeekFeature`, `TagTranslationFeature`, `AnimatedImageFeature`, `NetworkingFeature`, `ParserFeature`.

**Client modules (`@DependencyClient` side-effect boundaries):**
- `AppDelegateClient`, `AppLaunchAutomationClient`, `ApplicationClient`, `AuthorizationClient`, `BackgroundProcessingClient`, `ClipboardClient`, `CookieClient`, `DFClient`, `DeviceClient`, `DownloadClient`, `FileClient`, `HapticsClient`, `ImageClient`, `LibraryClient`, `LogsClient`, `URLClient`, `UserDefaultsClient`.

**Model / data:**
- `AppModels` — `Persistent/` (Setting, Filter, User, GalleryHistory, AppIconType), `Persistence/` (AppSharedKeys, SchemaMigrator, SchemaVersion, VersionedSchema, JSONValue), plus `Gallery/`, `Download/`, `Tags/`, `Support/`, `Utilities/`, `Resources/`.

**Shared UI / utilities:**
- `AppComponents`, `GalleryListComponents`, `AppTools` (CookieUtil, FileUtil, DataCache, Extensions), `Resources`, `TestingSupport`.

**Catalog / library extensions:**
- `CommonMarkExt`, `OSLogExt`, `OpenCCExt`, `SFSafeSymbolsExt`, `SystemNotificationExt`.

## Key File Locations

**Entry Points:**
- `App/EhPandaApp.swift`: `@main` scene.
- `AppPackage/Sources/AppFeature/RootView.swift`: root store + view.
- `ShareExtension/ShareViewController.swift`: share extension.

**Configuration:**
- `AppPackage/Package.swift`: targets + all third-party dependencies.
- `.swiftlint.yml`: root lint rules (per-module `.swiftlint.yml` reference it via `parent_config`).
- `App/Info.plist`, `App/EhPanda.entitlements`.

**Core Logic:**
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift`: root composition.
- `AppPackage/Sources/AppModels/Persistence/`: schema migration engine + `@Shared` keys.
- `AppPackage/Sources/NetworkingFeature/`: requests + HTML scraping.

**Testing:**
- `AppPackage/Tests/<Module>Tests/`; test plan `AppPackage/Tests/FeatureTests.xctestplan`.

## Naming Conventions

**Modules:**
- Feature module → `<Domain>Feature` directory (reducer type named with a `Feature`/`Reducer` suffix, e.g. `SettingFeature`).
- Side-effect boundary → `<Name>Client` directory.
- Library/catalog extension → `<Library>Ext` directory.
- Reusable UI → `<Name>Components`.

**Files:**
- Reducers: `<Name>Reducer.swift`; views: `<Name>View.swift`.
- Feature split: State/Action/body co-located per reducer; large clients split by concern with `+` suffix (e.g. `DownloadClient+Scheduling.swift`, `Request+Gallery.swift`).
- Per-file logger: `Logger+.swift` (init-only helper) with a `private let logger` declared in each file that logs.

**Test targets:**
- `<Module>Tests/` mirroring the source module name; Swift Testing (`@Suite`/`@Test`).

## Where to Add New Code

**New feature/screen:**
- Create module dir `AppPackage/Sources/<Name>Feature/` with `<Name>Reducer.swift` + views.
- Add a `.target` in `AppPackage/Package.swift` (depend on `.composableArchitecture` and needed siblings).
- Add `AppPackage/Sources/<Name>Feature/.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml`.
- Compose it into `AppReducer` (State/Action/body) if it belongs at app root.
- Add matching `AppPackage/Tests/<Name>FeatureTests/`.

**New side-effecting dependency:**
- Create `AppPackage/Sources/<Name>Client/<Name>Client.swift` as a `@DependencyClient` with live/test/preview values.
- Register the target in `AppPackage/Package.swift`; inject via `@Dependency` in features.

**New persisted model / field:**
- Add/modify types under `AppPackage/Sources/AppModels/Persistent/`.
- For breaking changes, add a new `VersionedSchema` to the ordered array and bump the schema head (`AppPackage/Sources/AppModels/Persistence/`).

**Shared UI:**
- Reusable views → `AppComponents` or `GalleryListComponents`.
- Utilities → `AppTools` (avoid importing feature/client modules to prevent cycles).

**New third-party dependency:**
- Declare in `AppPackage/Package.swift` only (never in the Xcode project); add a `static let` alias in the `Target.Dependency` extension.

## Special Directories

**`node_modules/` (repo root):**
- Purpose: JS tooling (e.g. GSD/hooks); Generated: Yes; Committed: No (gitignored).

**`build/`, `.build`:**
- Purpose: Xcode/SwiftPM build output; Generated: Yes; Committed: No.

**`.xcode-home/`:**
- Purpose: Sandboxed Xcode home for CI/tooling; Committed: partial config only.

**`actions-tool/`, `Scripts/`:**
- Purpose: CI + release automation; Committed: Yes.

---

*Structure analysis: 2026-07-09*
