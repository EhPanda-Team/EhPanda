public import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import Sharing
public import SwiftUI

/// A shared picker for the presentation of one semantic gallery list.
public struct GalleryLayoutPicker: View {
    @Shared(.setting) private var setting: Setting
    private let scope: GalleryListScope

    public init(scope: GalleryListScope) {
        self.scope = scope
    }

    public var body: some View {
        Menu {
            Picker(.RLocalizable.presentation, selection: Binding($setting).galleryListPresentation[scope]) {
                Label(.RLocalizable.row, systemSymbol: .listBullet)
                    .tag(GalleryListDisplayMode.row)
                Label(.RLocalizable.grid, systemSymbol: .squareGrid2x2)
                    .tag(GalleryListDisplayMode.grid)
            }
        } label: {
            Label(
                .RLocalizable.presentation,
                systemSymbol: setting.galleryListPresentation[scope] == .row ? .listBullet : .squareGrid2x2
            )
        }
        .accessibilityLabel(.RLocalizable.presentation)
        .accessibilityValue(setting.galleryListPresentation[scope] == .row ? .RLocalizable.row : .RLocalizable.grid)
        .accessibilityIdentifier("gallery-layout-\(scope.rawValue)")
    }
}
