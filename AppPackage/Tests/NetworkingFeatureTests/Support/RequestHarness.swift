import AppModels

/// Captures a concrete request's typed-throws response as a `Result` for parity assertions.
///
/// The operation is deliberately supplied as a closure. A generic helper constrained to `Request`
/// would dispatch a protocol-extension implementation statically, so after a concrete request gains
/// its async response method the test could silently keep exercising the legacy Combine facade.
/// Forming the call on the concrete request inside this closure guarantees the intended path runs.
func capture<T: Sendable>(
    _ operation: () async throws(AppError) -> T
) async -> Result<T, AppError> {
    do throws(AppError) {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}
