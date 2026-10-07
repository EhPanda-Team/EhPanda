#if DEBUG
import AppModels
import ComposableArchitecture
import Foundation
import LibraryClient
import SwiftUI
import UIKit

/// What a capture launch shows and whether it has finished showing it, as UI tests read it.
///
/// UI tests run outside the app, so the diagnostics travel through the channel they already read:
/// the accessibility tree. ``CaptureDiagnosticsAnchor`` adds one invisible element, identified
/// ``accessibilityIdentifier``, whose value is this record as JSON. It exists only in capture
/// launches and renders nothing, so no capture shows a label of its own.
struct CaptureDiagnostics: Equatable, Encodable {
    enum Readiness: String, Encodable {
        /// The screen is still loading its content or images.
        case loading
        /// The screen shows all of its content and every image it requested.
        case ready
        /// The screen can never finish: a load failed or the replay refused a request.
        case failed
    }

    static let accessibilityIdentifier = "capture_diagnostics"

    /// The screen the app shows, such as `home`, or `nil` for a screen no capture identifies yet.
    let screenID: String?
    let selectionID: String
    let fixtureVersion: String
    /// The galleries the screen shows, in display order.
    let galleryIDs: [String]
    /// The reader page the screen shows; `nil` outside the reader, which no capture shows yet.
    let page: Int?
    let readiness: Readiness
    /// Images the replay delivered that the image cache does not hold yet.
    let pendingImages: Int
    /// Requests the replay refused, as `METHOD URL` in arrival order.
    let unknownRequests: [String]

    func encodedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let json = String(bytes: try encoder.encode(self), encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "not UTF-8"))
        }
        return json
    }
}

extension CaptureDiagnostics {
    /// The diagnostics of `state` in a launch of `scene`.
    ///
    /// Home is ready once all of its lists hold galleries, nothing is loading, the current card's
    /// cover is cached and no delivered image waits for the cache. The current card is always on
    /// screen, so its cover proves the first render requested every visible image; without it, the
    /// moment between the lists arriving and their covers being requested would read as ready.
    init(
        scene: CaptureScene,
        state: AppReducer.State,
        answeredURLs: Set<String>,
        unknownRequests: [String],
        isCached: (String) -> Bool
    ) {
        let home = state.homeState
        let showsHome = state.tabBarState.tabBarItemType == .home
            && home.path.isEmpty
            && state.presentationState.detail == nil
            && state.presentationState.destination == nil
        let toplists = ToplistsType.allCases.map({ home.toplistsGalleries[$0.categoryIndex] ?? [] })
        let lists = [home.popularGalleries, home.frontpageGalleries] + toplists
        let loadingStates = [home.popularLoadingState, home.frontpageLoadingState]
            + ToplistsType.allCases.compactMap({ home.toplistsLoadingState[$0.categoryIndex] })
        let pendingImages = answeredURLs.count(where: { url in
            scene.replay[url]?.mimeType.hasPrefix("image/") == true && !isCached(url)
        })
        let currentCover = home.popularGalleries.first(where: { $0.gid == home.currentCardID })?.coverURL

        let readiness: Readiness
        if !unknownRequests.isEmpty || loadingStates.contains(where: Self.isFailure) {
            readiness = .failed
        } else if showsHome,
                  lists.allSatisfy({ !$0.isEmpty }),
                  !loadingStates.contains(.loading),
                  let currentCover, isCached(currentCover.absoluteString),
                  pendingImages == 0 {
            readiness = .ready
        } else {
            readiness = .loading
        }
        self.init(
            screenID: showsHome ? "home" : nil,
            selectionID: scene.selectionID,
            fixtureVersion: scene.fixtureVersion,
            galleryIDs: showsHome ? lists.flatMap({ $0.map(\.gid) }) : [],
            page: nil,
            readiness: readiness,
            pendingImages: pendingImages,
            unknownRequests: unknownRequests
        )
    }

    private static func isFailure(_ state: LoadingState) -> Bool {
        guard case .failed = state else {
            return false
        }
        return true
    }
}

/// The invisible element that carries ``CaptureDiagnostics`` to UI tests.
struct CaptureDiagnosticsAnchor: UIViewRepresentable {
    let store: StoreOf<AppReducer>
    let capture: InstalledCapture

    func makeUIView(context: Self.Context) -> CaptureDiagnosticsElement {
        CaptureDiagnosticsElement(store: store, capture: capture)
    }

    func updateUIView(_ uiView: CaptureDiagnosticsElement, context: Self.Context) {}
}

/// Computes its accessibility value each time a test reads it, from the store, the replay and
/// the image cache, so the value is never stale and the app needs no observation or timer for it.
final class CaptureDiagnosticsElement: UIView {
    private let store: StoreOf<AppReducer>
    private let capture: InstalledCapture
    @Dependency(\.libraryClient) private var libraryClient

    init(store: StoreOf<AppReducer>, capture: InstalledCapture) {
        self.store = store
        self.capture = capture
        super.init(frame: .zero)
        isAccessibilityElement = true
        isUserInteractionEnabled = false
        accessibilityIdentifier = CaptureDiagnostics.accessibilityIdentifier
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var accessibilityValue: String? {
        get {
            let diagnostics = CaptureDiagnostics(
                scene: capture.scene,
                state: store.state,
                answeredURLs: capture.replay.answeredURLs,
                unknownRequests: capture.replay.unknownRequestDescriptions,
                isCached: libraryClient.isCached
            )
            do {
                return try diagnostics.encodedJSON()
            } catch {
                // A test that cannot decode the value fails and reports this text.
                return "Capture diagnostics cannot be encoded: \(error)"
            }
        }
        // The value is derived on every read; there is nothing to store.
        set {}
    }
}
#endif
