import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import Sharing
import SwiftUI
import Testing
import UIKit

/// An archive's file size is spoken like every other size the site gives as text.
///
/// The archive card showed the size in the reader's number format but left its unit to VoiceOver as it is written,
/// "MiB", read letter by letter. The torrent cell and Gallery Info speak the formatted count and the unit's word
/// (``SiteFileSize/spoken(locale:)``), and the card's size now does too.
@MainActor
struct ArchiveFileSizeTests {
    @Test
    func anArchiveSizeIsSpokenWithItsFormattedCountAndTheUnitsWord() throws {
        let unitWord = String(localized: .accessibilitySizeMebibyte(quantity: 26.2))
        try AccessibilityElements.read(of: Self.archives(), size: CGSize(width: 390, height: 844)) { elements in
            let labels = elements.compactMap({ $0.accessibilityLabel })
            #expect(
                labels.contains(where: { $0.contains("26,2") && $0.contains(unitWord) }),
                "No element reads the size as 26,2 and \(unitWord); the labels are \(labels)."
            )
        }
    }

    /// The Archive page with one archive of 26.2 MiB, in a `de_DE` environment.
    private static func archives() -> some View {
        var state = ArchivesReducer.State()
        state.hathArchives = [GalleryArchive.HathArchive(resolution: .x1280, fileSize: "26.2 MiB", gpPrice: "380")]
        let store = withDependencies {
            $0.context = .preview
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            Store(initialState: state, reducer: ArchivesReducer.init)
        }
        return ArchivesView(store: store, gid: "1", galleryURL: .mock, archiveURL: .mock)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "de_DE"))
    }
}
