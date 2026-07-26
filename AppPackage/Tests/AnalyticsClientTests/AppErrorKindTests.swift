@testable import AnalyticsClient
import AppModels
import Testing

struct ErrorKindFixture: Sendable {
    let error: AppError
    let kind: AppErrorKind
}

struct ErrorCategoryFixture: Sendable {
    let kind: AppErrorKind
    let category: AnalyticsErrorCategory
}

@Suite
struct AppErrorKindTests {
    // Distinctive enough that a substring search for it cannot collide with a case name or any
    // other rendering the mirrored value legitimately carries.
    private static let sentinel = "zqxsentinelerror4718"

    // `AppError` has sixteen cases. Counting them here rather than trusting the mirror to be
    // complete is the point: if a seventeenth is added, `AppErrorKind.init(_:)` stops compiling and
    // this number stops matching, and both have to be answered deliberately.
    //
    // It has already earned its keep once: `.loginRejected` tripped both halves at the moment it was
    // added, which is exactly when someone had to decide whether its payload was safe to count.
    @Test
    func theMirrorHasOneCasePerAppErrorCase() {
        #expect(AppErrorKind.allCases.count == 16)
    }

    @Test
    func everySpellingIsTheCaseNameVerbatim() {
        #expect(AppErrorKind.allCases.map(\.rawValue) == [
            "copyrightClaim", "ipBanned", "expunged", "networkingFailed", "webImageFailed",
            "parseFailed", "quotaExceeded", "authenticationRequired", "cloudflareChallengeFailed",
            "loginCaptchaRequired", "loginRejected", "unsupportedDeepLink", "fileOperationFailed",
            "noUpdates", "notFound", "unknown"
        ])
    }

    // The four String-carrying cases and the one carrying a `BanInterval` are constructed with
    // sentinel payloads, so the mapping is exercised on exactly the values that could leak.
    // `.loginRejected` matters most of the four: its payload is remote text the app deliberately
    // shows the user, so it is the one a reader is most likely to assume is safe to forward.
    @Test(arguments: [
        ErrorKindFixture(error: .copyrightClaim(AppErrorKindTests.sentinel), kind: .copyrightClaim),
        ErrorKindFixture(error: .ipBanned(.unrecognized(content: AppErrorKindTests.sentinel)), kind: .ipBanned),
        ErrorKindFixture(error: .expunged(AppErrorKindTests.sentinel), kind: .expunged),
        ErrorKindFixture(error: .networkingFailed, kind: .networkingFailed),
        ErrorKindFixture(error: .webImageFailed, kind: .webImageFailed),
        ErrorKindFixture(error: .parseFailed, kind: .parseFailed),
        ErrorKindFixture(error: .quotaExceeded, kind: .quotaExceeded),
        ErrorKindFixture(error: .authenticationRequired, kind: .authenticationRequired),
        ErrorKindFixture(error: .cloudflareChallengeFailed, kind: .cloudflareChallengeFailed),
        ErrorKindFixture(error: .loginCaptchaRequired, kind: .loginCaptchaRequired),
        ErrorKindFixture(error: .loginRejected(AppErrorKindTests.sentinel), kind: .loginRejected),
        ErrorKindFixture(error: .unsupportedDeepLink, kind: .unsupportedDeepLink),
        ErrorKindFixture(error: .fileOperationFailed(AppErrorKindTests.sentinel), kind: .fileOperationFailed),
        ErrorKindFixture(error: .noUpdates, kind: .noUpdates),
        ErrorKindFixture(error: .notFound, kind: .notFound),
        ErrorKindFixture(error: .unknown, kind: .unknown)
    ])
    func everyAppErrorMapsToItsOwnKind(fixture: ErrorKindFixture) {
        #expect(AppErrorKind(fixture.error) == fixture.kind)
    }

    // Each of the four payload-carrying cases separately, so a leak through one of them cannot be
    // masked by the others passing.
    @Test(arguments: [
        AppError.copyrightClaim(AppErrorKindTests.sentinel),
        AppError.expunged(AppErrorKindTests.sentinel),
        AppError.fileOperationFailed(AppErrorKindTests.sentinel),
        AppError.ipBanned(.unrecognized(content: AppErrorKindTests.sentinel))
    ])
    func noAssociatedValueSurvivesTheMirror(error: AppError) {
        let kind = AppErrorKind(error)
        var renderings = [String(describing: kind), kind.rawValue, kind.category.rawValue]
        renderings.append(contentsOf: Mirror(reflecting: kind).leafRenderings)

        // The sentinel really is present on the way in; without this the assertions below could
        // pass against an error that never carried it.
        #expect(String(describing: error).contains(Self.sentinel))

        for rendering in renderings {
            #expect(rendering.contains(Self.sentinel) == false, "the sentinel survived in \(rendering)")
        }
    }

    // The category is a local mirror of the SDK's error-category vocabulary, so the taxonomy stays
    // free of any SDK import and plan 14-06 translates it at the one call site that has one.
    @Test
    func theCategoryVocabularyIsTheThreeSpellingsTheSdkUses() {
        #expect(AnalyticsErrorCategory.allCases.map(\.rawValue) == [
            "thrown-exception", "user-input", "app-state"
        ])
    }

    @Test(arguments: [
        ErrorCategoryFixture(kind: .copyrightClaim, category: .appState),
        ErrorCategoryFixture(kind: .ipBanned, category: .appState),
        ErrorCategoryFixture(kind: .expunged, category: .appState),
        ErrorCategoryFixture(kind: .networkingFailed, category: .thrownException),
        ErrorCategoryFixture(kind: .webImageFailed, category: .thrownException),
        ErrorCategoryFixture(kind: .parseFailed, category: .thrownException),
        ErrorCategoryFixture(kind: .quotaExceeded, category: .appState),
        ErrorCategoryFixture(kind: .authenticationRequired, category: .appState),
        ErrorCategoryFixture(kind: .cloudflareChallengeFailed, category: .thrownException),
        ErrorCategoryFixture(kind: .loginCaptchaRequired, category: .userInput),
        ErrorCategoryFixture(kind: .loginRejected, category: .userInput),
        ErrorCategoryFixture(kind: .unsupportedDeepLink, category: .userInput),
        ErrorCategoryFixture(kind: .fileOperationFailed, category: .thrownException),
        ErrorCategoryFixture(kind: .noUpdates, category: .appState),
        ErrorCategoryFixture(kind: .notFound, category: .userInput),
        ErrorCategoryFixture(kind: .unknown, category: .thrownException)
    ])
    func everyKindCarriesItsPinnedCategory(fixture: ErrorCategoryFixture) {
        #expect(fixture.kind.category == fixture.category)
    }

    // The table above pins each kind individually; this proves the table is complete, so a new
    // kind cannot be given a category that no test ever reads.
    @Test
    func everyKindHasACategory() {
        let categories = AppErrorKind.allCases.map(\.category)

        #expect(categories.count == AppErrorKind.allCases.count)
        #expect(Set(categories).count == AnalyticsErrorCategory.allCases.count)
    }
}
