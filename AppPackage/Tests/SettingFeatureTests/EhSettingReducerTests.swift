import AnalyticsClient
import AppModels
import ComposableArchitecture
import EhSettingClient
@testable import SettingFeature
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct EhSettingReducerTests {
    typealias Option = EhSettingReducer.Option

    // MARK: Fixtures

    static func site(profileName: String = "EhPanda") -> EhSetting {
        .empty(ehProfiles: [EhProfile(value: 1, name: profileName, isSelected: true)])
    }

    // The state a loaded page holds. Evaluated inside `TestStore.init`'s prepared dependencies (the parameter
    // is an autoclosure), so the state's `@SharedReader` holder resolves against this case's own storage.
    static func loadedState(_ ehSetting: EhSetting = site()) -> EhSettingReducer.State {
        var state = EhSettingReducer.State()
        state.setEhSetting(ehSetting, resettingProfileName: true)
        return state
    }

    @MainActor
    private static func makeStore(
        _ stubbed: StubbedSite = StubbedSite()
    ) -> TestStoreOf<EhSettingReducer> {
        TestStore(initialState: loadedState(), reducer: EhSettingReducer.init) {
            $0.analyticsClient = .noop
            $0.ehSettingClient = stubbed.client
        }
    }

    // MARK: First load

    @MainActor
    @Test
    func theFirstLoadAppliesTheSiteSettings() async {
        let store = TestStore(initialState: EhSettingReducer.State(), reducer: EhSettingReducer.init) {
            $0.analyticsClient = .noop
            $0.ehSettingClient.fetchSettings = { (_: GalleryHost) async throws(AppError) -> EhSetting in
                Self.site()
            }
        }

        await store.send(.fetchEhSetting) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchEhSettingDone) {
            $0.loadingState = .idle
            $0.ehSetting = Self.site()
            $0.ehProfile = EhProfile(value: 1, name: "EhPanda", isSelected: true)
            $0.editingProfileName = "EhPanda"
        }
        await store.finish()
    }

    @MainActor
    @Test
    func aFailedFirstLoadShowsTheFailure() async {
        let store = TestStore(initialState: EhSettingReducer.State(), reducer: EhSettingReducer.init) {
            $0.analyticsClient = .noop
            $0.ehSettingClient = .failing(.networkingFailed)
        }

        await store.send(.fetchEhSetting) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchEhSettingDone) {
            $0.loadingState = .failed(.networkingFailed)
        }
        await store.finish()
    }

    @MainActor
    @Test
    func aSiteAnswerOnALoadedPageStartsNoSave() async {
        // `submitChanges` stays unimplemented, so a save started by the answer would fail the case.
        let store = Self.makeStore()
        var other = Self.site()
        other.galleryName = .japanese
        other.showFilteredRemovalCount = false
        other.excludedLanguages = other.excludedLanguages.map({ !$0 })

        await store.send(.fetchEhSettingDone(.success(other))) {
            $0.ehSetting = other
        }
        await store.finish()
    }

    // MARK: Option.changes

    @Test
    func equalSettingsHaveNoChangedOptions() {
        #expect(Option.changes(from: Self.site(), to: Self.site()).isEmpty)
    }

    @Test
    func changedFieldsListInFormOrder() {
        let old = Self.site()
        var new = old
        // Written out of form order on purpose: the result follows the form, not the edit.
        new.useMultiplePageViewer = true
        new.ratingsColor = "rrggb"
        new.galleryName = .japanese

        #expect(Option.changes(from: old, to: new) == [.galleryName, .ratingsColor, .useMultiplePageViewer])
    }

    @Test
    func changedIndicesAreListedPerIndex() {
        let old = Self.site()
        var new = old
        new.excludedLanguages[49] = true
        new.favoriteCategories[9] = "Nine"
        new.favoriteCategories[0] = "Zero"
        new.disabledCategories[3] = true

        #expect(
            Option.changes(from: old, to: new)
                == [.disabledCategory(3), .favoriteCategory(0), .favoriteCategory(9), .excludedLanguage(49)]
        )
    }

    @Test
    func anIndexOnlyOneSideHasCounts() {
        let old = Self.site()
        var new = old
        new.disabledCategories.append(false)

        #expect(Option.changes(from: old, to: new) == [.disabledCategory(10)])
    }

    @Test
    func profilesAloneChangeNoOption() {
        let old = Self.site()
        let new = EhSetting.empty(ehProfiles: [
            EhProfile(value: 1, name: "EhPanda", isSelected: true),
            EhProfile(value: 2, name: "Second", isSelected: false)
        ])

        #expect(Option.changes(from: old, to: new).isEmpty)
    }

    // MARK: Saving one option

    @MainActor
    @Test
    func aBindingChangeSavesOnlyThatOptionAndAppliesTheAnswer() async {
        let stubbed = StubbedSite(submits: 1)
        let store = Self.makeStore(stubbed)
        var edited = Self.site()
        edited.galleryName = .japanese

        await store.send(.binding(.set(\.ehSetting, edited))) {
            $0.ehSetting = edited
            $0.updatingOptions = [.galleryName]
            $0.latestRevision = 1
        }
        #expect(store.state.loadingState == .idle)

        // The site's answer also differs in another option. Applying it starts no second save.
        var answer = edited
        answer.ratingsColor = "rrggb"
        stubbed.submits.answer(0, with: .success(answer))
        await store.receive(\.updateDone) {
            $0.updatingOptions = []
            $0.ehSetting = answer
        }

        #expect(stubbed.postedForms.value == [edited])
        await store.finish()
    }

    @MainActor
    @Test
    func aSecondChangeToAnUpdatingOptionStartsNoSecondSave() async {
        let stubbed = StubbedSite(submits: 1)
        let store = Self.makeStore(stubbed)
        var first = Self.site()
        first.galleryName = .japanese
        var second = first
        second.galleryName = .default

        await store.send(.binding(.set(\.ehSetting, first))) {
            $0.ehSetting = first
            $0.updatingOptions = [.galleryName]
            $0.latestRevision = 1
        }
        await store.send(.binding(.set(\.ehSetting, second))) {
            $0.ehSetting = second
        }

        stubbed.submits.answer(0, with: .success(second))
        await store.receive(\.updateDone) {
            $0.updatingOptions = []
        }
        #expect(stubbed.postedForms.value == [first])
        await store.finish()
    }

    @MainActor
    @Test
    func onlyTheLatestAnswerIsApplied() async {
        let stubbed = StubbedSite(submits: 2)
        let store = Self.makeStore(stubbed)
        var first = Self.site()
        first.galleryName = .japanese
        var second = first
        second.showFilteredRemovalCount = false

        await store.send(.binding(.set(\.ehSetting, first))) {
            $0.ehSetting = first
            $0.updatingOptions = [.galleryName]
            $0.latestRevision = 1
        }
        await stubbed.submits.waitForRequests(1)
        await store.send(.binding(.set(\.ehSetting, second))) {
            $0.ehSetting = second
            $0.updatingOptions = [.galleryName, .showFilteredRemovalCount]
            $0.latestRevision = 2
        }
        #expect(stubbed.postedForms.value == [first, second])

        // The older answer only re-enables its option; the form stays as the user set it.
        stubbed.submits.answer(0, with: .success(first))
        await store.receive(\.updateDone) {
            $0.updatingOptions = [.showFilteredRemovalCount]
        }

        var latest = second
        latest.ratingsColor = "rrggb"
        stubbed.submits.answer(1, with: .success(latest))
        await store.receive(\.updateDone) {
            $0.updatingOptions = []
            $0.ehSetting = latest
        }
        await store.finish()
    }

    @MainActor
    @Test
    func anOlderFailureStartsNoRefetch() async {
        // `fetchSettings` stays unimplemented, so a refetch would fail the case.
        let stubbed = StubbedSite(submits: 2)
        let store = Self.makeStore(stubbed)
        var first = Self.site()
        first.galleryName = .japanese
        var second = first
        second.showFilteredRemovalCount = false

        await store.send(.binding(.set(\.ehSetting, first))) {
            $0.ehSetting = first
            $0.updatingOptions = [.galleryName]
            $0.latestRevision = 1
        }
        await stubbed.submits.waitForRequests(1)
        await store.send(.binding(.set(\.ehSetting, second))) {
            $0.ehSetting = second
            $0.updatingOptions = [.galleryName, .showFilteredRemovalCount]
            $0.latestRevision = 2
        }

        stubbed.submits.answer(0, with: .failure(.networkingFailed))
        await store.receive(\.updateDone) {
            $0.updatingOptions = [.showFilteredRemovalCount]
        }

        stubbed.submits.answer(1, with: .success(second))
        await store.receive(\.updateDone) {
            $0.updatingOptions = []
        }
        await store.finish()
    }

    // MARK: A failed latest save

    @MainActor
    @Test
    func aFailedLatestSaveQuietlyRefetchesAndAppliesTheRefetch() async {
        let stubbed = StubbedSite(submits: 1, fetches: 1)
        let store = Self.makeStore(stubbed)
        var edited = Self.site()
        edited.galleryName = .japanese

        await store.send(.binding(.set(\.ehSetting, edited))) {
            $0.ehSetting = edited
            $0.updatingOptions = [.galleryName]
            $0.latestRevision = 1
        }

        // The option stays disabled while the refetch is out, and the page shows no loading state.
        stubbed.submits.answer(0, with: .failure(.networkingFailed))
        await store.receive(\.updateDone)
        #expect(store.state.updatingOptions == [.galleryName])
        #expect(store.state.loadingState == .idle)

        // The save did not take: the site still holds the old value.
        stubbed.fetches.answer(0, with: .success(Self.site()))
        await store.receive(\.refetchDone) {
            $0.updatingOptions = []
            $0.ehSetting = Self.site()
        }
        #expect(store.state.loadingState == .idle)
        await store.finish()
    }

    @MainActor
    @Test
    func aFailedRefetchOnlyReenablesTheOption() async {
        let stubbed = StubbedSite(submits: 1, fetches: 1)
        let store = Self.makeStore(stubbed)
        var edited = Self.site()
        edited.galleryName = .japanese

        await store.send(.binding(.set(\.ehSetting, edited))) {
            $0.ehSetting = edited
            $0.updatingOptions = [.galleryName]
            $0.latestRevision = 1
        }
        stubbed.submits.answer(0, with: .failure(.networkingFailed))
        await store.receive(\.updateDone)

        stubbed.fetches.answer(0, with: .failure(.networkingFailed))
        await store.receive(\.refetchDone) {
            $0.updatingOptions = []
        }
        #expect(store.state.ehSetting == edited)
        #expect(store.state.loadingState == .idle)
        await store.finish()
    }

    // MARK: The profile name

    @MainActor
    @Test
    func anOptionSavesAnswerLeavesTheTypedProfileNameAlone() async {
        let stubbed = StubbedSite(submits: 1)
        let store = Self.makeStore(stubbed)
        var edited = Self.site()
        edited.galleryName = .japanese

        await store.send(.binding(.set(\.editingProfileName, "Typed"))) {
            $0.editingProfileName = "Typed"
        }
        await store.send(.binding(.set(\.ehSetting, edited))) {
            $0.ehSetting = edited
            $0.updatingOptions = [.galleryName]
            $0.latestRevision = 1
        }

        var answer = Self.site(profileName: "Other")
        answer.galleryName = .japanese
        stubbed.submits.answer(0, with: .success(answer))
        await store.receive(\.updateDone) {
            $0.updatingOptions = []
            $0.ehSetting = answer
            $0.ehProfile = EhProfile(value: 1, name: "Other", isSelected: true)
        }
        #expect(store.state.editingProfileName == "Typed")
        await store.finish()
    }

    // MARK: Profile actions

    @MainActor
    @Test
    func aProfileActionUpdatesTheProfileOptionAndResetsTheProfileName() async {
        let stubbed = StubbedSite(profiles: 1)
        let store = Self.makeStore(stubbed)

        await store.send(.performAction(action: .rename, name: "Renamed", set: 1)) {
            $0.updatingOptions = [.profile]
            $0.latestRevision = 1
        }
        // A second action while the first is out changes nothing.
        await store.send(.performAction(action: .delete, name: nil, set: 1))

        stubbed.profiles.answer(0, with: .success(Self.site(profileName: "Renamed")))
        await store.receive(\.updateDone) {
            $0.updatingOptions = []
            $0.ehSetting = Self.site(profileName: "Renamed")
            $0.ehProfile = EhProfile(value: 1, name: "Renamed", isSelected: true)
            $0.editingProfileName = "Renamed"
        }
        #expect(stubbed.profileCalls.value == [ProfileCall(action: .rename, name: "Renamed", set: 1)])
        await store.finish()
    }
}

// MARK: Stubbed site

/// One profile action as the site received it.
private struct ProfileCall: Equatable, Sendable {
    let action: EhProfileAction?
    let name: String?
    let set: Int
}

/// The answers a test holds back, one stream per expected request.
///
/// A request takes the next stream in the order the requests start, and waits on its first element. The test
/// decides when and how each request answers, so two requests can be in flight at once and answer in either
/// order. A request nobody expected, or one whose stream ends empty, records an issue and fails.
private struct HeldAnswers: Sendable {
    let count: Int
    private let queue: LockIsolated<[AsyncStream<Result<EhSetting, AppError>>]>
    private let continuations: [AsyncStream<Result<EhSetting, AppError>>.Continuation]
    private let started = LockIsolated(0)

    init(count: Int) {
        self.count = count
        let made = (0..<count).map({ _ in AsyncStream<Result<EhSetting, AppError>>.makeStream() })
        queue = LockIsolated(made.map(\.stream))
        continuations = made.map(\.continuation)
    }

    func next() async throws(AppError) -> EhSetting {
        started.withValue({ $0 += 1 })
        let stream = queue.withValue({ $0.isEmpty ? nil : $0.removeFirst() })
        guard let stream else {
            reportIssue("A request started with no held answer left.")
            throw .unknown
        }
        for await result in stream {
            return try result.get()
        }
        reportIssue("A held answer ended without a result.")
        throw .unknown
    }

    func answer(_ index: Int, with result: Result<EhSetting, AppError>) {
        guard let continuation = continuations.dropFirst(index).first else {
            reportIssue("There is no held answer at index \(index).")
            return
        }
        continuation.yield(result)
        continuation.finish()
    }

    /// Returns once `count` requests have started, so the next change starts after them in a known order.
    func waitForRequests(_ count: Int) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while started.value < count, clock.now < deadline {
            await Task.yield()
        }
        #expect(started.value >= count)
    }
}

/// An `EhSettingClient` that answers only the requests a case expects and records what it was asked.
///
/// A closure the case does not expect stays the unimplemented one, so an unexpected request is reported.
private struct StubbedSite: Sendable {
    let submits: HeldAnswers
    let profiles: HeldAnswers
    let fetches: HeldAnswers
    let postedForms = LockIsolated<[EhSetting]>([])
    let profileCalls = LockIsolated<[ProfileCall]>([])

    init(submits: Int = 0, profiles: Int = 0, fetches: Int = 0) {
        self.submits = HeldAnswers(count: submits)
        self.profiles = HeldAnswers(count: profiles)
        self.fetches = HeldAnswers(count: fetches)
    }

    var client: EhSettingClient {
        var client = EhSettingClient.unimplemented
        let submits = submits
        let profiles = profiles
        let fetches = fetches
        let postedForms = postedForms
        let profileCalls = profileCalls
        if submits.count > 0 {
            client.submitChanges = { (_: GalleryHost, ehSetting: EhSetting) async throws(AppError) -> EhSetting in
                postedForms.withValue({ $0.append(ehSetting) })
                return try await submits.next()
            }
        }
        if profiles.count > 0 {
            client.performProfileAction = { (_, action, name, set) async throws(AppError) -> EhSetting in
                profileCalls.withValue({ $0.append(ProfileCall(action: action, name: name, set: set)) })
                return try await profiles.next()
            }
        }
        if fetches.count > 0 {
            client.fetchSettings = { (_: GalleryHost) async throws(AppError) -> EhSetting in
                try await fetches.next()
            }
        }
        return client
    }
}
