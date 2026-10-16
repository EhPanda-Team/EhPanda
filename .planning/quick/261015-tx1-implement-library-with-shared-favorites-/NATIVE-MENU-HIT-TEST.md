# Native context-menu first-item hit test — D90

## Status

Open, reproduced on iPhone Air Simulator / iOS 27.0 (24A434), built with Xcode 27.1.
This is an investigation artifact, not an approved change to navigation or scroll-edge policy.

## Reproduce

1. Build the following standalone SwiftUI app with iPhone/iPad device families and all four
   supported interface orientations. No package dependencies are needed.
2. Launch in landscape-left at 912 × 420 points. Long-press Card.
3. Activate Pages at the center of the native menu item (approximately 335,51).
4. Observe that the menu stays visible. Tap the lower part of the same item (300,65): the
   `Opened Pages` sheet appears. Coordinates are diagnostic observations, not a test workaround.

Removing the ScrollView wrapper makes center activation work with the same native navigation
composition. Keeping ScrollView but removing every source-page `scrollEdgeEffectStyle` reproduces
the failure; clearing the inherited style at the card also fails. The code below is that default-style
control. Production retains its required soft top edge. Direct activation uses the same app-level
session as the real-app reproduction; no Device Hub is involved.

```swift
import SwiftUI
@main struct MenuProbeApp: App {
    var body: some Scene { WindowGroup { ProbeRoot() } }
}
struct MenuProbe: View {
    @State private var opened = false
    var body: some View {
        ScrollView {
        Button("Card") { }
            .frame(width: 230, height: 370)
            .background(.blue.opacity(0.2))
            .contextMenu {
                Button("Pages", systemImage: "list.bullet.rectangle.portrait") { opened = true }
                Menu("Move to Folder", systemImage: "folder") { Button("Reading") {} }
                Button("Delete", systemImage: "trash", role: .destructive) {}
            } preview: {
                Text("Card preview").frame(width: 230, height: 395).background(.background)
            }
            .sheet(isPresented: $opened) { Text("Opened Pages").scrollEdgeEffectStyle(.soft, for: .top) }
        }
    }
}

struct ProbeRoot: View {
    @State private var tab = 1
    @State private var visibility = NavigationSplitViewVisibility.all
    @State private var selection: Int? = 0
    @State private var search = ""
    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: 0) {
                NavigationStack { Text("Home").navigationTitle("Home").toolbarTitleDisplayMode(.inlineLarge) }
            }
            Tab("Library", systemImage: "books.vertical", value: 1) {
                NavigationSplitView(columnVisibility: $visibility) {
                    List(selection: $selection) {
                        Section("Downloads") { NavigationLink("Downloads", value: 0) }
                        Section("Favorites") { ForEach(1..<10) { NavigationLink("Favorites \($0)", value: $0) } }
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("Library")
                    .toolbarTitleDisplayMode(.inlineLarge)
                } detail: {
                    NavigationStack {
                        MenuProbe()
                            .navigationTitle("Favorites")
                            .toolbarTitleDisplayMode(.inlineLarge)
                            .searchable(text: $search, placement: .navigationBarDrawer)
                            .toolbar { Button("Action", systemImage: "plus") {} }
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .top)
            }
        }
    }
}
```

## Evidence

- Real app: `library-polish-iphone-01` and `library-polish-iphone-02` under `.build/library/`;
  both fail `LibraryPresentationUITests/testDownloadManagementInBothLayouts` at the Pages-sheet
  expectation. The first run retains the complete native recording and accessibility hierarchy.
- Interactive reproduction: local `agent-device` session `ehpanda-polish`; its timestamped
  request/snapshot history records center activation with unchanged menu and lower-item activation
  opening Download Status. The source-only and default-scroll controls were separate builds.
- A read-only debugger check through public `UIWindow.hitTest` reaches the native menu cell for
  both points. It therefore does not substantiate the earlier suspected overlay interception.
- The standalone probe is uninstalled after diagnosis. No temporary probe or diagnostic patch is
  linked into the production app. No runtime patching or private API is added to production or the reproducer.

The exact UIKit cause and physical-device behavior are unverified. This finding is retained as an
open native interaction issue; the requested visual/menu changes are not represented as an
all-device management pass.
