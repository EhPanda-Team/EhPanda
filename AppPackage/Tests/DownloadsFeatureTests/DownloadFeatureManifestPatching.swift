import AppModels
import DownloadClient
import Foundation

// MARK: - Index patching seam
extension DownloadFeatureTestCase {
    /// Patches one gallery's record to an all-hashed, complete manifest through the index seam a
    /// page flush writes through. The caller settles it afterwards, which is the queue-store
    /// removal that actually makes it leave the schedulable set.
    func completeManifest(
        of gallery: SessionGallery,
        in fixture: SessionFixture
    ) async {
        await patchManifest(
            of: gallery,
            completedPageCount: gallery.pageCount,
            in: fixture
        )
    }

    /// The same index seam at an arbitrary count: the mid-run state a download reaches once some of
    /// its own page writes have landed and its record still reads incomplete.
    func patchManifest(
        of gallery: SessionGallery,
        completedPageCount: Int,
        in fixture: SessionFixture
    ) async {
        await fixture.manager.updateDownloadIndex(
            folderURL: fixture.storage.folderURL(
                relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
            ),
            manifest: manifest(
                for: SessionGallery(
                    gid: gallery.gid,
                    title: gallery.title,
                    pageCount: gallery.pageCount,
                    completedPageCount: completedPageCount
                )
            )
        )
    }
}
