import AppModels
import GalleryClient

extension GalleryClient {
    /// The first fetch of each Home destination that loads when presented (Front Page, Toplists, Popular) fails with
    /// `.networkingFailed`. Every other fetch stays unimplemented, so a test that reaches one is told.
    static var homeDestinationFetchesFailing: Self {
        var client = Self.unimplemented
        let failing = Self.failing(.networkingFailed)
        client.fetchFrontPageGalleries = failing.fetchFrontPageGalleries
        client.fetchToplistsGalleries = failing.fetchToplistsGalleries
        client.fetchPopularGalleries = failing.fetchPopularGalleries
        return client
    }
}
