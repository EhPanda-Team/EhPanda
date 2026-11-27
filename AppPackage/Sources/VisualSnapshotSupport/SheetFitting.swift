import UIKit

/// What fitting the window's form sheets to their content came to (``HostedWindowCapture/fitSheets(in:)``).
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

    /// Fits every form sheet in the window to its content (owner decision 2026-11-27 in 19-26, 「貼合內容」).
    ///
    /// On the iPad a form sheet keeps its own size (580 x 660 pt) whatever the window's height, so content taller than
    /// the sheet was never in the picture at any committed height. Once no presentation is running, each sheet whose
    /// content does not fit has its `preferredContentSize` height raised by its overflow, and one that was raised past
    /// its content is lowered again, never under the size it had when the fitting began: a sheet that holds its
    /// content is left as it is. UIKit keeps the sheet within the window, less its margins (32 pt above and below on
    /// the iPad), so content taller than that still overflows, and the check and the measuring mode see it as they see
    /// any page: the window's height stays the committed one, never adjusted. A sheet's overflow is the largest
    /// overflow of a scroll view in it the user could see and scroll, as the page's need reads it
    /// (``HostedHierarchy/pageNeed(in:)``). Only a form sheet that floats in its container is fitted: a sheet that
    /// fills the window's height, as every sheet on the iPhone does, grows with the window already.
    ///
    /// The capture and the measuring mode fit before the operating step, so that on the tall path, where the native
    /// settle has let the sheet finish appearing, a dialog the step opens over a sheet anchors on the fitted sheet;
    /// again after the step, in case its update put the sheet's own size back; and once more after the settle, for a
    /// sheet that appeared only then (on the screen-sized path nothing settles before the step, and SwiftUI presents a
    /// sheet a few run-loop turns after hosting). A fitting that changed anything there is followed by a second
    /// settle. The hosting is disposed after every attempt, which drops the changed sizes with it.
    static func fitSheets(in window: UIWindow) async -> SheetFit {
        var native: [ObjectIdentifier: CGFloat] = [:]
        var result = SheetFit.unchanged
        for _ in 0..<maximumFitPasses {
            guard await presentationsFinished(in: window) else {
                return Task.isCancelled ? .cancelled : .presenting
            }
            var changed = false
            for sheet in formSheets(in: window) {
                let frame = sheet.view.frame.height
                let floor = native[ObjectIdentifier(sheet)] ?? frame
                native[ObjectIdentifier(sheet)] = floor
                changed = fit(sheet, floor: floor, in: window) || changed
            }
            guard changed else { return result }
            result = .fitted
            window.layoutIfNeeded()
            guard await nextSample() else { return .cancelled }
        }
        return result
    }

    /// Sets `sheet`'s preferred height so its frame takes its content's height, never under `floor`; `false` when the
    /// sheet already has that height, or has no scroll view to read.
    private static func fit(_ sheet: UIViewController, floor: CGFloat, in window: UIWindow) -> Bool {
        let pixel = 1 / window.screen.scale
        guard let overflow = overflow(of: sheet.view, in: window) else { return false }
        let frame = sheet.view.frame.height
        let target = max(floor, frame + overflow)
        guard abs(target - frame) >= pixel else { return false }
        let preferred = sheet.preferredContentSize
        let base = preferred.height > 0 ? preferred.height : frame
        let width = preferred.width > 0 ? preferred.width : sheet.view.frame.width
        let height = base + target - frame
        guard abs(height - preferred.height) >= pixel else { return false }
        sheet.preferredContentSize = CGSize(width: width, height: height)
        return true
    }

    /// The largest vertical overflow, signed, of a scroll view in `view` the user could see and scroll, or `nil`
    /// without one.
    private static func overflow(of view: UIView, in window: UIWindow) -> CGFloat? {
        ([view] + HostedHierarchy.descendants(of: view))
            .compactMap({ $0 as? UIScrollView })
            .filter({ HostedHierarchy.isVisibleAndScrolling($0, in: window) })
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
    private static func formSheets(in window: UIWindow) -> [UIViewController] {
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
    private static func presentationsFinished(in window: UIWindow) async -> Bool {
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
