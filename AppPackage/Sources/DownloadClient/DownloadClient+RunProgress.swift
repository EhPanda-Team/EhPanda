import AppModels
import Foundation

// MARK: - Run Progress Measurement
extension DownloadCoordinator {
    /// The ONE read of a gallery's run-scoped progress measurement.
    ///
    /// Two consumers exist and both come through here: the credited-pages definition's basis-first
    /// regime (`sessionCreditedPages`, which the continued-processing card's numerator sums) and the
    /// published `DownloadedGallery.runProgress` the badge and the inspector read (D-SSOT-10). They
    /// cannot drift, because there is no second expression for either of them to drift from — which
    /// is exactly the failure G-15-2F was: the run's measurement reached the system card while the
    /// in-app sheet went on deriving from a record that reads N-of-N for the whole repair.
    ///
    /// `DownloadSourceInventoryTests` counts this as the seventh whole-name site of the measurement,
    /// and its census doc carries the roles. The lifetime rules — when an entry is recorded, when it
    /// shrinks and when it is retired — live on `runProgressBases`' own declaration and are not
    /// restated here.
    func liveRunProgressBasis(gid: String) -> RunProgressBasis? {
        runProgressBases[gid]
    }

    /// The published form of that measurement, or nil when no run stands for this gallery.
    func publishedRunProgress(gid: String) -> DownloadRunProgress? {
        liveRunProgressBasis(gid: gid)
            .map({ DownloadRunProgress(creditedPageIndices: $0.creditedPageIndices) })
    }
}
