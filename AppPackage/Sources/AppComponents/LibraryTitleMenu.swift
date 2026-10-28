public import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
public import SwiftUI

public struct LibraryTitleMenu: View {
    @Binding private var selection: LibraryGroup?
    private let favoritesIndex: Int
    private let downloadFilter: DownloadFolderFilter

    public init(
        selection: Binding<LibraryGroup?>,
        favoritesIndex: Int,
        downloadFilter: DownloadFolderFilter
    ) {
        _selection = selection
        self.favoritesIndex = favoritesIndex
        self.downloadFilter = downloadFilter
    }

    var sourceTitle: LocalizedStringResource {
        switch selection {
        case .downloads: .RLocalizable.downloads
        case .favorites: .RLocalizable.favorites
        case .none: .RLocalizable.library
        }
    }

    public var body: some View {
        Menu {
            Picker(.RLocalizable.library, selection: $selection) {
                Label(.RLocalizable.favorites, systemSymbol: .heart)
                    .tag(Optional(LibraryGroup.favorites(favoritesIndex)))
                Label(.RLocalizable.downloads, systemSymbol: .arrowDownCircle)
                    .tag(Optional(LibraryGroup.downloads(downloadFilter)))
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Text(.RLocalizable.library)
                    .font(.title2.bold())
                LibraryTitleMenuIndicator()
            }
            .foregroundStyle(.primary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityValue(sourceTitle)
        .accessibilityIdentifier("library-title-menu")
    }
}
