import AppModels
import Combine
import Foundation
import AppTools

extension Request {
    /// Shared plumbing for the `gdata` API (`api.php` `method=gdata`): builds the POST body from a list
    /// of `[gid, token]` pairs, retries transient failures, hands the raw payload to `decode`, and maps
    /// errors uniformly. Both the batch `GalleriesMetadataRequest` and the single-gallery
    /// `GalleryVersionMetadataRequest` are thin wrappers over this, so a future gdata contract change
    /// (params, retry policy, error mapping) lands in exactly one place.
    ///
    /// The endpoint accepts at most 25 pairs per call; callers that may exceed that must chunk before
    /// calling and cap their own in-flight fan-out.
    func gdataPublisher<T>(
        gidlist: [[Any]],
        urlSession: URLSession,
        decode: @escaping (Data) throws -> T
    ) -> AnyPublisher<T, AppError> {
        let params: [String: Any] = [
            "method": "gdata",
            "gidlist": gidlist,
            "namespace": 1
        ]
        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        return urlSession.dataTaskPublisher(for: request)
            .genericRetry()
            .map(\.data)
            .tryMap { data in try parseResponse(data: data, decode) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    /// Async companion to the single-place `gdata` contract above. Callers remain responsible for
    /// chunking more than 25 pairs and limiting their own in-flight requests.
    func gdataResponse<T>(
        gidlist: [[Any]],
        urlSession: URLSession,
        decode: (Data) throws -> T
    ) async throws(AppError) -> T {
        let params: [String: Any] = [
            "method": "gdata",
            "gidlist": gidlist,
            "namespace": 1
        ]
        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            return try parseResponse(data: data, decode)
        } catch {
            throw mapAppError(error: error)
        }
    }
}
