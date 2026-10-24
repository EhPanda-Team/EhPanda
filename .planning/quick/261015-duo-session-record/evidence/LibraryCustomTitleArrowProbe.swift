import SFSafeSymbols
import SwiftUI

@main
struct CustomArrowProbe: App {
    var body: some Scene {
        WindowGroup {
            ProbeTabs()
        }
    }
}

struct ProbeTabs: View {
    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: 0) {
                Text("Home").scrollEdgeEffectStyle(.soft, for: .top)
            } label: {
                Label("Home", systemSymbol: .house)
            }
            Tab(value: 1) {
                ProbeView()
            } label: {
                Label("Library", systemSymbol: .booksVertical)
            }
            Tab(value: 2) {
                Text("Search").scrollEdgeEffectStyle(.soft, for: .top)
            } label: {
                Label("Search", systemSymbol: .magnifyingglass)
            }
            Tab(value: 3) {
                Text("Setting").scrollEdgeEffectStyle(.soft, for: .top)
            } label: {
                Label("Setting", systemSymbol: .gearshape)
            }
        }
        .tint(.green)
    }
}

struct ProbeView: View {
    @State private var source = "Favorites"
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(1...12, id: \.self) { index in
                Text("Gallery \(index)")
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .searchable(text: $query, placement: .navigationBarDrawer)
            .navigationTitle("Library")
            .navigationSubtitle(source)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .largeTitle) {
                    LibraryTitleMenu(source: $source)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Grid", systemSymbol: .squareGrid2x2) {}
                }
            }
        }
    }
}

struct LibraryTitleMenu: View {
    @Binding var source: String

    var body: some View {
        Menu {
            Picker("Library", selection: $source) {
                Label("Favorites", systemSymbol: .heart).tag("Favorites")
                Label("Downloads", systemSymbol: .arrowDownCircle).tag("Downloads")
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Text("Library")
                    .font(.title2.bold())
                TitleMenuIndicator()
            }
            .foregroundStyle(.primary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityValue(source)
        .accessibilityIdentifier("library-title-menu")
    }
}

struct TitleMenuIndicator: View {
    @ScaledMetric(relativeTo: .body) private var diameter = 18.0
    @ScaledMetric(relativeTo: .body) private var chevronSize = 10.0

    var body: some View {
        Image(systemSymbol: .chevronDown)
            .font(.system(size: chevronSize, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: diameter, height: diameter)
            .background(Color(uiColor: .secondarySystemFill), in: .circle)
            .accessibilityHidden(true)
    }
}
