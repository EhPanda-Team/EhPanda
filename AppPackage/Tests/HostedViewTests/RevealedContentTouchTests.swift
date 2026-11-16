import AppComponents
import Observation
import SwiftUI
import Testing
import UIKit

/// Content shown with `revealed(_:)` takes touches from the moment it is revealed.
///
/// A screen used to fade its content in through the content's own opacity. For a scroll view that opacity is the
/// UIKit view's `alpha`, which SwiftUI animates away from the main thread: until the animation ends, the value UIKit
/// reads is the one the animation began with. Fading in, that is 0, and UIKit's hit test passes over a view whose
/// alpha is under 0.01. On Home the galleries looked opaque half a second after they landed and took no touch for
/// 1.1 to 2.2 seconds: a tap on a section's **Show All** went to the view behind the content and did nothing
/// (`GalleryCardUITests`, 2026-11-16, 7 of 8 first taps in a probe).
@MainActor
struct RevealedContentTouchTests {
    @Test
    func contentIsHitOnceRevealedAndNotBefore() throws {
        let reveal = Reveal()
        let hits = try Self.scrollViewHits(in: Covered(reveal: reveal), revealing: reveal)
        #expect(!hits.hidden)
        #expect(hits.revealed)
    }

    /// The premise of the test above: content that fades in through its own opacity is not hit while it fades.
    ///
    /// The fade here lasts an hour, so that it is still running when the test looks, however slowly the host turns
    /// its run loop. A screen's own fade (`.default`, a spring) ends about a second after it begins, and a test that
    /// looked inside that second would fail on a host that turned too slowly.
    @Test
    func contentThatFadesInIsNotHitWhileItFades() throws {
        let reveal = Reveal()
        let hits = try Self.scrollViewHits(in: Faded(reveal: reveal), revealing: reveal)
        #expect(!hits.hidden)
        #expect(!hits.revealed)
    }

    /// Whether a touch in the middle of the window goes to the content's scroll view, while the content is hidden
    /// and a tenth of a second after it is revealed, when SwiftUI has applied the change.
    private static func scrollViewHits(
        in view: some View, revealing reveal: Reveal
    ) throws -> Hits {
        let size = CGSize(width: 390, height: 600)
        return try HostedView.withRoot(of: view, size: size) { root in
            let window = try #require(root.window)
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            let hidden = isInScrollView(window.hitTest(middle, with: nil))
            reveal.isRevealed = true
            RunLoop.main.run(until: .now.addingTimeInterval(0.1))
            return Hits(hidden: hidden, revealed: isInScrollView(window.hitTest(middle, with: nil)))
        }
    }

    private static func isInScrollView(_ view: UIView?) -> Bool {
        var current = view
        while let each = current {
            if each is UIScrollView {
                return true
            }
            current = each.superview
        }
        return false
    }

    private struct Hits {
        let hidden: Bool
        let revealed: Bool
    }
}

@MainActor
@Observable
private final class Reveal {
    var isRevealed = false
}

private struct Content: View {
    var body: some View {
        ScrollView {
            Color.clear.frame(height: 2000)
        }
    }
}

private struct Covered: View {
    let reveal: Reveal

    var body: some View {
        Content().revealed(reveal.isRevealed)
    }
}

private struct Faded: View {
    let reveal: Reveal

    var body: some View {
        Content().animation(.linear(duration: 3600)) {
            $0.visible(reveal.isRevealed)
        }
    }
}
