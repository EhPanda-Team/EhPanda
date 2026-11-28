import UIKit

/// What fitting the window's form sheets to their content came to (``SheetFitter/fit(in:)``).
enum SheetFit: Equatable {
    /// Every form sheet already held its content, or had grown as far as the window lets it: nothing was changed.
    case unchanged
    /// A form sheet's height was changed; every one now holds its content, or has grown as far as the window lets it.
    case fitted
    /// A presentation was still running after ``HostedWindowCapture/maximumSamples`` samples.
    case presenting
    /// The task was cancelled while a sample was waited for.
    case cancelled
}

extension HostedWindowCapture {
    /// The most times one fitting sets the sheets' heights and waits a sample. The fitted content can grow once the
    /// sheet is taller (a List read 912 pt in a 660 pt sheet and 935 pt once fitted, 19-26), and SwiftUI can put a
    /// sheet's own preferred height back while its presentation ends, so a fitting takes more than one pass.
    static let maximumFitPasses = 6

    /// The reason of an attempt or a hosting whose sheet presentation never finished, or whose wait for one was
    /// cancelled.
    static let presentingReason = "settle-timeout:presentation"
}

/// Fits a hosting's form sheets to their content (owner decision 2026-11-27 in 19-26, 「貼合內容」); one fitter per
/// hosting, which keeps each sheet's native size from the first time it sees the sheet.
///
/// On the iPad a form sheet keeps its own size (580 x 660 pt) whatever the window's height, so content taller than
/// the sheet was never in the picture at any committed height. Once no presentation is running, each sheet whose
/// content does not fit has its `preferredContentSize` height set so that its frame takes its content's height, and
/// one that was raised past its content is lowered again, never under its native height: a sheet that holds its
/// content is left as it is. UIKit keeps the sheet within the window, less its margins (32 pt above and below on the
/// iPad), so content taller than that still overflows, and the check and the measuring mode see it as they see any
/// page: the window's height stays the committed one, never adjusted. A sheet's content height is its frame plus the
/// largest overflow of a scroll view in it that scrolls the page, as the page's need reads it
/// (``HostedHierarchy/pageNeed(in:)``); that sum is the same whatever frame the window lets the sheet have. Only a
/// form sheet that floats in its container is fitted: a sheet that fills the window's height, as every sheet on the
/// iPhone does, grows with the window already.
///
/// The preferred height is the content height less the sheet's native offset: its native frame height less its
/// native preferred height, which SwiftUI gives every sheet it presents (580 x 640 pt in a 660 pt frame on the iPad).
/// It is never derived from the sheet's current preferred height and frame: while the window holds the frame under
/// the content, adding the overflow to the last preferred height raised it again on every pass (to 23,111 pt for
/// 1,841 pt of content, 19-26), and once SwiftUI had put its own preferred height back it set a negative one. A
/// sheet without a preferred height when first seen has no offset to read and is left as it is; the check sees any
/// content it cuts.
///
/// The capture and the measuring mode fit before the operating step, so that on the tall path, where the native
/// settle has let the sheet finish appearing, a dialog the step opens over a sheet anchors on the fitted sheet;
/// again after the step, in case its update put the sheet's own size back; and once more after the settle, for a
/// sheet that appeared only then (on the screen-sized path nothing settles before the step, and SwiftUI presents a
/// sheet a few run-loop turns after hosting). A fitting that changed anything there is followed by a second settle.
/// The hosting is disposed after every attempt, which drops the changed sizes, and the fitter, with it.
@MainActor
final class SheetFitter {
    /// A sheet's size when the fitter first saw it: its frame height and how far its frame is above its preferred
    /// height.
    private struct Native {
        let height: CGFloat
        let offset: CGFloat
    }

    /// The native size of every sheet seen, by the sheet's identity; a hosting's sheets outlive its fitter.
    private var natives: [ObjectIdentifier: Native] = [:]

    /// Fits every floating form sheet in `window` to its content, a pass at a time, at most
    /// ``HostedWindowCapture/maximumFitPasses`` passes.
    func fit(in window: UIWindow) async -> SheetFit {
        var result = SheetFit.unchanged
        for _ in 0..<HostedWindowCapture.maximumFitPasses {
            guard await HostedWindowCapture.presentationsFinished(in: window) else {
                return Task.isCancelled ? .cancelled : .presenting
            }
            var changed = false
            for sheet in HostedWindowCapture.formSheets(in: window) {
                changed = fit(sheet, in: window) || changed
            }
            guard changed else { return result }
            result = .fitted
            window.layoutIfNeeded()
            guard await HostedWindowCapture.nextSample() else { return .cancelled }
        }
        return result
    }

    /// Sets `sheet`'s preferred height so its frame takes its content's height, never under its native height;
    /// `false` when its preferred height is that already, or the sheet has no scroll view to read or no native offset.
    ///
    /// Both heights are compared in whole device pixels, as UIKit lays the frame out from the preferred height, and the
    /// preferred height set is that pixel exactly. A difference under a pixel in points can still land the frame a
    /// pixel off: SwiftUI set the downloads inspector's preferred height to 742.008 pt for 742.5 pt of content, its
    /// frame took 762 pt for 762.5 pt, and that pixel was `cannot-cover` at every height (19-26).
    private func fit(_ sheet: UIViewController, in window: UIWindow) -> Bool {
        let scale = window.screen.scale
        let frame = sheet.view.frame.height
        let preferred = sheet.preferredContentSize
        let id = ObjectIdentifier(sheet)
        if natives[id] == nil, preferred.height > 0 {
            natives[id] = Native(height: frame, offset: frame - preferred.height)
        }
        guard let native = natives[id],
              let overflow = HostedWindowCapture.overflow(of: sheet.view, in: window)
        else { return false }
        let pixels = ((max(native.height, frame + overflow) - native.offset) * scale).rounded()
        guard pixels != (preferred.height * scale).rounded() else { return false }
        let width = preferred.width > 0 ? preferred.width : sheet.view.frame.width
        sheet.preferredContentSize = CGSize(width: width, height: pixels / scale)
        return true
    }
}

extension HostedWindowCapture {
    /// The largest vertical overflow, signed, of a scroll view in `view` that scrolls the page
    /// (``HostedHierarchy/scrollsThePage(_:in:)``), or `nil` without one.
    fileprivate static func overflow(of view: UIView, in window: UIWindow) -> CGFloat? {
        ([view] + HostedHierarchy.descendants(of: view))
            .compactMap({ $0 as? UIScrollView })
            .filter({ HostedHierarchy.scrollsThePage($0, in: window) })
            .map({ scrollView in
                let insets = scrollView.adjustedContentInset
                return scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
            })
            .max()
    }

    /// The presented form sheets that float in their container, outermost first: their style is `.formSheet` and their
    /// bottom edge lies a device pixel or more above the container's. A form sheet UIKit shows as a sheet that fills
    /// the window's height, as on the iPhone, still reads `.formSheet` but sits on the container's bottom edge and
    /// grows with the window; it ignores a preferred height and is left out. A presented controller's children share
    /// its presentation controller and are left out too.
    fileprivate static func formSheets(in window: UIWindow) -> [UIViewController] {
        let pixel = 1 / window.screen.scale
        return controllers(from: window.rootViewController).filter({ controller in
            guard controller.presentingViewController?.presentedViewController === controller,
                  let presentation = controller.presentationController, presentation.presentationStyle == .formSheet,
                  let container = presentation.containerView, let presented = presentation.presentedView
            else { return false }
            return presented.convert(presented.bounds, to: container).maxY <= container.bounds.maxY - pixel
        })
    }

    /// Waits, a sample at a time and at most ``maximumSamples`` samples, until no controller in the window is being
    /// presented or dismissed; `false` when that never happened or the task was cancelled.
    fileprivate static func presentationsFinished(in window: UIWindow) async -> Bool {
        for _ in 0..<maximumSamples {
            let running = controllers(from: window.rootViewController).contains(where: {
                $0.isBeingPresented || $0.isBeingDismissed || $0.transitionCoordinator != nil
            })
            guard running else { return true }
            guard await nextSample() else { return false }
        }
        return false
    }
}
