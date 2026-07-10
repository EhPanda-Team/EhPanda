import Foundation

/// Isolates the single deprecated CFNetwork call the app deliberately depends on:
/// `CFReadStreamCreateForHTTPRequest`. It is the only proven way to preserve domain fronting —
/// an arbitrary `Host` on a hand-built `CFHTTPMessage` while the socket connects to a resolved IP
/// (no censored SNI). No warning-free replacement (URLSession, Network.framework) preserves the
/// host-control + arbitrary-Host + original-domain-trust triad; see DEP-06
/// (`01-DEP06-EVIDENCE.md`) and decisions D-12 / D-14.
///
/// This module exists solely to contain that one deprecated call. Its target is compiled with
/// `-suppress-warnings` in `Package.swift`, so the unavoidable SDK deprecation notice is silenced
/// at this single, documented boundary rather than across the codebase. It replaces the former
/// external `EhPanda-Team/DeprecatedAPI` package (inlined in plan 01-09).
public enum LegacyCFReadStream {
    /// Wraps the deprecated `CFReadStreamCreateForHTTPRequest`. The returned `Unmanaged` carries a
    /// +1 retain; the caller balances it (`.autorelease().takeUnretainedValue()`), preserving the
    /// original shim's ownership contract.
    public static func create(
        _ alloc: CFAllocator?, _ request: CFHTTPMessage
    ) -> Unmanaged<CFReadStream> {
        CFReadStreamCreateForHTTPRequest(alloc, request)
    }
}
