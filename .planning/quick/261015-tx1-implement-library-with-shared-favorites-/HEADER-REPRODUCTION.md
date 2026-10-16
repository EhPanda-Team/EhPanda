# Native tab/split header reproduction

This is an independent diagnostic, not production app source or a proposed fix. It intentionally
uses only the Apple SDK so the case can be reproduced in a fresh SwiftUI iOS app. Tested with
Xcode 27.1.0, deployment target 27.0, iPadOS 27.0 runtime build 24A434, standard Dynamic Type,
landscape-right, full-screen window. No network, account data or third-party libraries are used.

1. Replace the fresh project's App source with the snippet below.
2. Launch with `tab = 0`, then tap Library. The two title origins are y=152 pt; search is y=204 pt.
3. Stop the app, change the initial tab to 1, and launch again. Title origins are y=88 pt; search
   is y=140 pt. These are recorded results on this simulator, not hard-coded app layout values.
4. Compare actual navigation bar frames and settled accessibility geometry, not just List rows.

The owner also reported a rarer close/reopen sequence while the sidebar toggle remained visible.
For that diagnostic, remove `.toolbar(removing: .sidebarToggle)` and bind columnVisibility to
a @State NavigationSplitViewVisibility initialized to .all. The recorded cold-Library run and
three subsequent tab/close/reopen cycles did not reproduce that rare sequence.

```swift
import SwiftUI

@main struct HeaderProbeApp: App {
    var body: some Scene { WindowGroup { ProbeRoot() } }
}
struct ProbeRoot: View {
    @State private var tab = 0
    @State private var selection: Int? = 0
    @State private var search = ""
    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: 0) {
                NavigationStack { Text("Home").navigationTitle("Home").toolbarTitleDisplayMode(.inlineLarge) }
            }
            Tab("Library", systemImage: "books.vertical", value: 1) {
                NavigationSplitView(columnVisibility: .constant(.all)) {
                    List(selection: $selection) {
                        Section("Downloads") { NavigationLink("Downloads", value: 0) }
                        Section("Favorites") { ForEach(1..<10) { NavigationLink("Favorites \($0)", value: $0) } }
                    }
                    .listStyle(.sidebar)
                    .toolbar(removing: .sidebarToggle)
                    .navigationTitle("Library")
                    .toolbarTitleDisplayMode(.inlineLarge)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                } detail: {
                    NavigationStack {
                        ContentUnavailableView("No Items", systemImage: "person")
                            .navigationTitle("Favorites")
                            .toolbarTitleDisplayMode(.inlineLarge)
                            .searchable(text: $search, placement: .navigationBarDrawer)
                            .toolbar { Button("Action", systemImage: "plus") {} }
                            .scrollEdgeEffectStyle(.soft, for: .top)
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

No feedback submission or external upload has been made. Raw local evidence is under
`.build/library/header-stability/`. See [investigation](HEADER-STABILITY.md) for rejected changes,
remaining uncertainty and the owner's pending design choice.
