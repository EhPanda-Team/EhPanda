<!-- refreshed: 2026-07-09 -->
# Architecture

**Analysis Date:** 2026-07-09

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                       App Shell (target)                     │
│   `App/EhPandaApp.swift`  →  imports AppFeature, renders      │
│   RootView; @UIApplicationDelegateAdaptor(AppDelegate)       │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     AppFeature (root)                        │
│  `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift`   │
│  Composes AppRoute, AppLock, TabBar + all tab features       │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│  Home    │ Favorites│  Search  │ Downloads│    Setting      │
│ Feature  │ Feature  │ Feature  │ Feature  │   Feature       │
└────┬─────┴────┬─────┴────┬─────┴────┬─────┴───────┬─────────┘
     │          │          │          │             │
     ▼          ▼          ▼          ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│          Leaf feature reducers (@Presents / StackState)      │
│  Detail · Reading · ReadingSetting · Filters · QuickSearch · │
│  DateSeek · TagTranslation · Networking · Parser             │
└──────────────────────────────┬──────────────────────────────┘
                               │  @Dependency clients
                               ▼
┌─────────────────────────────────────────────────────────────┐
│  Client layer (Dependencies): CookieClient · DownloadClient ·│
│  ImageClient · FileClient · URLClient · DeviceClient · …      │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│  AppModels (@Shared persisted state + schema migration)      │
│  AppTools (utilities) · Networking (Kanna HTML parsing)      │
│  Store: file-backed @Shared keys + rebuilt cache files       │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App shell | `@main` scene, delegate adaptor, mounts `RootView` | `App/EhPandaApp.swift` |
| AppReducer | Root TCA reducer; composes tabs, routing, lock, scene phase, launch automation | `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` |
| AppRouteReducer | App-wide modal/deep-link routing destinations | `AppPackage/Sources/AppFeature/DataFlow/AppRouteReducer.swift` |
| AppLockReducer | Biometric/auto-lock gating on scene phase | `AppPackage/Sources/AppFeature/DataFlow/AppLockReducer.swift` |
| TabBarReducer | Tab selection + tab container | `AppPackage/Sources/AppFeature/View/TabBar/TabBarReducer.swift` |
| Feature modules | One TCA `*Reducer` + SwiftUI views per screen domain | `AppPackage/Sources/<Name>Feature/` |
| Client modules | `@DependencyClient` wrappers over side-effecting systems | `AppPackage/Sources/<Name>Client/` |
| AppModels | Domain models + `@Shared` persistence + schema migration | `AppPackage/Sources/AppModels/` |
| NetworkingFeature | HTTP requests + Kanna HTML scraping of EHentai | `AppPackage/Sources/NetworkingFeature/` |
| ParserFeature | Parses scraped HTML into domain models | `AppPackage/Sources/ParserFeature/` |

## Pattern Overview

**Overall:** The Composable Architecture (TCA) on a modularized Swift Package + thin app-shell layout.

**Key Characteristics:**
- App-shell (`App/`) holds zero business logic; all logic lives in `AppPackage/` local Swift package.
- Each screen domain is an isolated module exposing a `@Reducer struct <Name>Feature`/`<Name>Reducer` with `@ObservableState`.
- Side effects are isolated behind `@DependencyClient` modules and injected via `@Dependency`.
- Composition is hierarchical: `AppReducer` scopes child reducers via `Scope`/`ifLet`/`forEach`; navigation uses `@Presents` Destination enums and `StackState`.
- Persistence uses the Sharing library (`@Shared`/`@SharedReader`) over file-backed keys — no Core Data / no database.

## Layers

**App shell:**
- Purpose: Boot the SwiftUI scene and mount the root feature.
- Location: `App/`
- Contains: `EhPandaApp.swift`, `Info.plist`, entitlements, assets, app icons.
- Depends on: `AppFeature` product only.
- Used by: iOS runtime.

**Feature layer:**
- Purpose: UI + reducer logic per domain.
- Location: `AppPackage/Sources/*Feature`, plus `AppFeature` (root).
- Contains: `@Reducer` types, `@ObservableState` State, Action enums, SwiftUI views.
- Depends on: ComposableArchitecture, sibling feature modules, client modules, AppModels, AppComponents.
- Used by: `AppReducer`.

**Client layer:**
- Purpose: Wrap side-effecting systems (network, cookies, files, images, device) behind testable interfaces.
- Location: `AppPackage/Sources/*Client`.
- Contains: `@DependencyClient` structs + live/test/preview values.
- Depends on: AppModels, AppTools, third-party SDKs.
- Used by: feature reducers via `@Dependency`.

**Model / data layer:**
- Purpose: Domain models, `@Shared` persisted state, schema migration engine.
- Location: `AppPackage/Sources/AppModels`.
- Contains: `Persistent/` (Setting, Filter, User, GalleryHistory, AppIconType), `Persistence/` (AppSharedKeys, SchemaMigrator, SchemaVersion, VersionedSchema, JSONValue), Gallery/Download/Tags/Support models.
- Depends on: CasePaths, Sharing.
- Used by: all feature + client modules.

**Support / shared:**
- Purpose: Reusable UI, utilities, resources, catalog extensions.
- Location: `AppTools`, `AppComponents`, `GalleryListComponents`, `Resources`, `TestingSupport`, and `*Ext` modules (`CommonMarkExt`, `OSLogExt`, `OpenCCExt`, `SFSafeSymbolsExt`, `SystemNotificationExt`).

## Data Flow

### Primary Request Path (browse galleries)

1. User action dispatches an Action into a feature reducer (e.g. `HomeReducer`) (`AppPackage/Sources/HomeFeature/`).
2. Reducer returns an `Effect` invoking a client, e.g. `@Dependency(\.urlClient)` / networking request (`AppPackage/Sources/NetworkingFeature/Request+Gallery.swift`).
3. NetworkingFeature performs the HTTP request and scrapes HTML via Kanna.
4. `ParserFeature` parses the response into `AppModels` gallery types (`AppPackage/Sources/ParserFeature/`).
5. Parsed models flow back as a follow-up Action; reducer mutates `@ObservableState`; SwiftUI view re-renders.

### Persistence Flow

1. Feature reads/writes light domain data through `@Shared`/`@SharedReader` keys defined in `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift`.
2. On decode, `SchemaMigrator` walks the ordered array of `VersionedSchema` types, progressively migrating stored data to the current schema version (`AppPackage/Sources/AppModels/Persistence/SchemaMigrator.swift`).
3. `tagTranslator` stores thin info in `@Shared` and rebuilds its lookup cache into a separate cache file.

**State Management:**
- In-memory UI state: TCA `@ObservableState` held in each reducer's `State`, rooted at `AppReducer.State`.
- Cross-cutting persisted state: Sharing library `@Shared` (file-backed), NOT `fileStorage`, NO database.

### App Lifecycle Flow

1. `AppDelegate` events arrive via `AppDelegateClient` into `AppDelegateReducer`.
2. `AppReducer.onScenePhaseChange` drives auto-lock (blur + `AppLockReducer`) and background handling.
3. Launch automation runs once (`runLaunchAutomation` via `AppLaunchAutomationClient`).

## Key Abstractions

**Feature (`@Reducer`):**
- Purpose: Self-contained screen domain (State + Action + body).
- Examples: `AppPackage/Sources/DetailFeature/`, `AppPackage/Sources/SettingFeature/`.
- Pattern: Project convention names reducers with a `Feature`/`Reducer` suffix (e.g. `SettingFeature`).

**Client (`@DependencyClient`):**
- Purpose: Injectable, testable boundary around a side effect.
- Examples: `AppPackage/Sources/CookieClient/CookieClient.swift`, `AppPackage/Sources/DownloadClient/DownloadClient.swift`.
- Pattern: struct of closures with live/test/preview values, accessed via `@Dependency`.

**Shared persisted key (`@Shared`):**
- Purpose: Durable app state without a database.
- Examples: `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift`.
- Pattern: Sharing library keys + `SchemaVersion<Model>` gate + progressive migration.

**Navigation Destination:**
- Purpose: State-driven modals / stacks.
- Pattern: `@Presents var destination` enums (AppRouteReducer) and `StackState` paths (e.g. Setting stack).

## Entry Points

**App scene:**
- Location: `App/EhPandaApp.swift`
- Triggers: iOS launch.
- Responsibilities: create `WindowGroup`, mount `RootView(appDelegate:)`.

**Root view + store:**
- Location: `AppPackage/Sources/AppFeature/RootView.swift`
- Triggers: mounted by app shell.
- Responsibilities: create the root `StoreOf<AppReducer>` and render the tab bar hierarchy.

**Share extension:**
- Location: `ShareExtension/ShareViewController.swift`
- Triggers: iOS share sheet.
- Responsibilities: receive shared URLs into the app.

## Architectural Constraints

- **Modularity:** No business logic in the `App/` shell; it links only the `AppFeature` product. Third-party dependencies are declared in `AppPackage/Package.swift`, never in the Xcode project.
- **Dependency direction:** Features depend on clients and AppModels, never the reverse. AppModels must not import feature/client modules (breaks Tools↔Models cycles by pushing runtime behavior to app-layer extensions).
- **Persistence:** No Core Data / no database — light data on `@Shared` file-backed keys only; `tagTranslator` cache is a rebuilt file, not `@Shared`.
- **Global state:** Prefer injected dependencies over singletons; e.g. `ImageClient.dataCache` is injectable rather than always `DataCache.shared`.
- **Lint-as-error:** SwiftLint (incl. custom regex rules + banned APIs) runs as a build plugin; new modules must add a `.swiftlint.yml` with `parent_config`.

## Anti-Patterns

### Empty / leftover TCA action stubs

**What happens:** An action case is emptied during refactor but left in the enum.
**Why it's wrong:** Dead cases mislead readers and bloat the reducer switch.
**Do this instead:** Delete the case and every call site (see reducer `Action` enums such as `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift`).

### Hoisting confirmation dialogs onto containers

**What happens:** A `.confirmationDialog`/`.alert` is attached to a whole `Form`/`List` for convenience.
**Why it's wrong:** On iPad these render as popovers anchored to the modifier's view; a transient/unrelated anchor points the arrow wrong or tears the dialog down.
**Do this instead:** Attach it to the stable triggering control; thread the dialog binding into the subview that owns the trigger.

### Using `DataCache.shared` in image tests

**What happens:** Tests touch the shared image cache.
**Why it's wrong:** Cross-test pollution; flaky assertions on cached pixels.
**Do this instead:** Inject a per-test `DataCache` via `ImageClient.dataCache` and compare pixel dimensions.

### Dragging utilities into AppModels to break cycles

**What happens:** A Tools↔Models import cycle is "fixed" by moving utils into the model module.
**Why it's wrong:** Inverts the dependency direction and re-creates cycles.
**Do this instead:** Move runtime behavior to app-layer extensions, keeping models behavior-free.

## Error Handling

**Strategy:** Effects surface failures back as Actions; reducers translate them into user-facing state (native alerts/HUDs).

**Patterns:**
- Prefer native SwiftUI / system presentation surfaces for alerts and HUDs; unify the state type but don't rebuild native affordances as custom cards.
- Rejected/invalid persisted data (e.g. bad `schemaVersion`) is logged via OSLog (`AppPackage/Sources/OSLogExt/`).

## Cross-Cutting Concerns

**Logging:** OSLog wrapper; `Logger+.swift` is init-only, so each logging file declares its own `private let logger` at the top (`AppPackage/Sources/*/Logger+.swift`).
**Validation:** Schema-version gate + progressive migration on decode of persisted models.
**Authentication:** Cookie-based session via `CookieClient` + `AuthorizationClient`; auto-lock via `AppLockReducer` and `AuthorizationClient`.

---

*Architecture analysis: 2026-07-09*
