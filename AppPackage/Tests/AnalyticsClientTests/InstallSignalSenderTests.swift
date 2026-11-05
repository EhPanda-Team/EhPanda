@testable import AnalyticsClient
import AppModels
import ComposableArchitecture
import CryptoKit
import Foundation
import InstallSourceClient
import Sharing
import Testing

// D-06b and D-06c as tests: the one install signal is one request in the SDK's wire format, with seven
// fields and a payload of exactly one key, sent once per install. JSON is checked by key set, decoded
// through `JSONSerialization`, so a field added to the request fails here rather than shipping.
//
// Each case gets its own in-memory defaults for `@Shared(.installSignal)`, so the cases run in
// parallel; a "relaunch" is a new sender over the same defaults.
@Suite
struct InstallSignalSenderTests {
    private static let appID = "TEST-APP-ID"
    private static let salt = "test-salt"
    private static let bodyKeys: Set<String> = [
        "appID", "clientUser", "isTestMode", "payload", "receivedAt", "sessionID", "type"
    ]

    // MARK: The request

    @Test(arguments: [
        InstallSource.appStore, .marketplace("com.example.store"), .unknown
    ])
    func theFirstSendIsOneRequestInTheSDKWireFormat(source: InstallSource) async throws {
        let harness = Harness(responses: [.status(200)], source: source)

        await harness.ensureSent()

        let request = try #require(harness.transport.requests.value.first)
        #expect(harness.transport.requests.value.count == 1)
        #expect(request.url?.absoluteString == "https://nom.telemetrydeck.com/v2/")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.allHTTPHeaderFields?.keys.sorted() == ["Content-Type"])

        let object = try Self.onlyObject(in: request)
        #expect(Set(object.keys) == Self.bodyKeys)
        #expect(object["type"] as? String == "App.installed")
        #expect(object["appID"] as? String == Self.appID)
        #expect(object["isTestMode"] as? String == "true")

        let payload = try #require(object["payload"] as? [String: Any])
        #expect(Set(payload.keys) == ["App.installSource"])
        #expect(payload["App.installSource"] as? String == source.wireValue)

        // The SDK's hash: lowercase SHA-256 hex of the identifier followed by the salt. The first
        // generated UUID is the user identifier, the second the session.
        let clientUser = try #require(object["clientUser"] as? String)
        #expect(clientUser == Self.sha256Hex(Harness.uuid(0).uuidString + Self.salt))
        #expect(clientUser.wholeMatch(of: #/[0-9a-f]{64}/#) != nil)
        #expect(object["sessionID"] as? String == Harness.uuid(1).uuidString)

        let receivedDate = try #require(object["receivedAt"] as? String)
        #expect(receivedDate == "2026-01-02T03:04:05+0000")
        #expect(receivedDate.wholeMatch(of: #/\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\+0000/#) != nil)

        #expect(harness.state == InstallSignalState(settled: true, clientUser: nil))
    }

    // MARK: Once per install

    @Test
    func aSecondSendOnTheSameSenderMakesNoRequest() async {
        let harness = Harness(responses: [.status(200), .status(200)])

        await harness.ensureSent()
        await harness.ensureSent()

        #expect(harness.transport.requests.value.count == 1)
    }

    @Test
    func aRelaunchOverTheSameStorageMakesNoRequest() async {
        let harness = Harness(responses: [.status(200), .status(200)])
        await harness.ensureSent()

        let relaunched = harness.relaunched()
        await relaunched.ensureSent()

        #expect(harness.transport.requests.value.count == 1)
        #expect(relaunched.transport.requests.value.isEmpty)
    }

    @Test
    func twoConcurrentSendsMakeOneRequest() async {
        let harness = Harness(responses: [.status(200), .status(200)], yieldsInTransport: true)

        let sender = harness.sender
        await withDependencies {
            $0.defaultAppStorage = harness.defaults
        } operation: {
            async let first: Void = sender.ensureSent()
            async let second: Void = sender.ensureSent()
            _ = await (first, second)
        }

        #expect(harness.transport.requests.value.count == 1)
        #expect(harness.state.settled)
    }

    // MARK: Retries

    @Test
    func aServerErrorIsRetriedOnceAfterTenSecondsWithTheSameUser() async throws {
        let harness = Harness(responses: [.status(500), .status(200)])

        await harness.ensureSent()

        let requests = harness.transport.requests.value
        #expect(requests.count == 2)
        #expect(harness.sleeps.value == [.seconds(10)])
        let users = try requests.map({ try Self.onlyObject(in: $0)["clientUser"] as? String })
        #expect(users.first == users.last)
        #expect(harness.state == InstallSignalState(settled: true, clientUser: nil))
    }

    @Test
    func transportErrorsBackOffThenWaitForTheNextApplyWithTheSameUser() async throws {
        let harness = Harness(responses: [.failure, .failure, .failure, .failure, .status(200)])

        await harness.ensureSent()

        #expect(harness.transport.requests.value.count == 4)
        #expect(harness.sleeps.value == [.seconds(10), .seconds(20), .seconds(40)])
        #expect(!harness.state.settled)
        let kept = try #require(harness.state.clientUser)

        // The next apply (here, a relaunch) sends once more, as the same user, and settles.
        let relaunched = harness.relaunched()
        await relaunched.ensureSent()

        let request = try #require(relaunched.transport.requests.value.first)
        #expect(relaunched.transport.requests.value.count == 1)
        #expect(try Self.onlyObject(in: request)["clientUser"] as? String == kept)
        #expect(relaunched.state == InstallSignalState(settled: true, clientUser: nil))
    }

    // The SDK's drop list: the server rejected the signal and a retry cannot help.
    @Test(arguments: [400, 401, 403, 404, 413, 422, 501, 505])
    func aRejectedSignalSettlesWithoutARetry(status: Int) async {
        let harness = Harness(responses: [.status(status), .status(200)])

        await harness.ensureSent()

        #expect(harness.transport.requests.value.count == 1)
        #expect(harness.sleeps.value.isEmpty)
        #expect(harness.state == InstallSignalState(settled: true, clientUser: nil))
    }

    @Test(arguments: [200, 201, 202, 204, 299])
    func everySuccessStatusSettles(status: Int) async {
        let harness = Harness(responses: [.status(status)])

        await harness.ensureSent()

        #expect(harness.transport.requests.value.count == 1)
        #expect(harness.state.settled)
    }

    @Test(arguments: [429, 500, 502, 503, 300, 408])
    func otherStatusesAreRetried(status: Int) async {
        let harness = Harness(responses: [.status(status), .status(200)])

        await harness.ensureSent()

        #expect(harness.transport.requests.value.count == 2)
        #expect(harness.state.settled)
    }

    // MARK: No credentials

    @Test
    func aNilAppIDNeverCallsTheTransport() async {
        let harness = Harness(responses: [.status(200)], appID: nil)

        await harness.ensureSent()
        await harness.ensureSent()

        #expect(harness.transport.requests.value.isEmpty)
        #expect(harness.state == InstallSignalState())
    }

    // MARK: Persisted state

    @Test
    func theStateDefaultsToNotSettled() {
        #expect(InstallSignalState() == InstallSignalState(settled: false, clientUser: nil))
    }

    @Test(arguments: [
        StoredState(json: "{}", expected: InstallSignalState()),
        StoredState(json: #"{"settled":true}"#, expected: InstallSignalState(settled: true)),
        StoredState(
            json: #"{"settled":"yes","clientUser":"abc"}"#,
            expected: InstallSignalState(clientUser: "abc")
        ),
        StoredState(json: #"{"settled":true,"clientUser":7}"#, expected: InstallSignalState(settled: true)),
        StoredState(
            json: #"{"settled":false,"clientUser":"abc","extra":1}"#,
            expected: InstallSignalState(clientUser: "abc")
        )
    ])
    func theStateDecodesTolerantly(stored: StoredState) throws {
        let decoded = try JSONDecoder().decode(InstallSignalState.self, from: Data(stored.json.utf8))

        #expect(decoded == stored.expected)
    }

    @Test
    func theStateRoundTrips() throws {
        let state = InstallSignalState(settled: false, clientUser: "abc")
        let decoded = try JSONDecoder().decode(InstallSignalState.self, from: JSONEncoder().encode(state))

        #expect(decoded == state)
    }
}

// MARK: Helpers
extension InstallSignalSenderTests {
    private static func onlyObject(in request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        let array = try #require(try JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        #expect(array.count == 1)
        return try #require(array.first)
    }

    private static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map({ String(format: "%02x", $0) })
            .joined()
    }
}

struct StoredState: Sendable {
    let json: String
    let expected: InstallSignalState
}

/// A canned transport answer.
enum CannedResponse: Sendable {
    case status(Int)
    case failure
}

/// Records every request and answers from a script; past the script's end it answers 200.
final class RecordingTransport: Sendable {
    let requests = LockIsolated<[URLRequest]>([])
    private let responses: LockIsolated<[CannedResponse]>
    private let yields: Bool

    init(responses: [CannedResponse], yields: Bool = false) {
        self.responses = LockIsolated(responses)
        self.yields = yields
    }

    func send(_ request: URLRequest) async throws -> (data: Data, response: URLResponse) {
        requests.withValue({ $0.append(request) })
        if yields {
            for _ in 0..<10 {
                await Task.yield()
            }
        }
        let next = responses.withValue { responses -> CannedResponse in
            responses.isEmpty ? .status(200) : responses.removeFirst()
        }
        switch next {
        case .status(let code):
            let url = request.url ?? URL(fileURLWithPath: "/")
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)
            return (data: Data(), response: response ?? URLResponse())

        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }
}

/// One sender over its own in-memory defaults, with a fixed clock, numbered UUIDs and a sleep that
/// records its duration and returns at once.
struct Harness {
    let defaults: UserDefaults
    let transport: RecordingTransport
    let sleeps = LockIsolated<[Duration]>([])
    let sender: InstallSignalSender

    static func uuid(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID()
    }

    init(
        responses: [CannedResponse],
        source: InstallSource = .unknown,
        appID: String? = "TEST-APP-ID",
        yieldsInTransport: Bool = false,
        defaults: UserDefaults = .inMemory
    ) {
        self.defaults = defaults
        let transport = RecordingTransport(responses: responses, yields: yieldsInTransport)
        self.transport = transport
        let counter = LockIsolated(0)
        let sleeps = self.sleeps
        sender = InstallSignalSender(
            appID: appID,
            salt: "test-salt",
            transport: { try await transport.send($0) },
            now: { Date(timeIntervalSince1970: 1_767_323_045) },
            uuid: {
                counter.withValue { value in
                    defer { value += 1 }
                    return Self.uuid(value)
                }
            },
            sleep: { duration in sleeps.withValue({ $0.append(duration) }) },
            installSource: { source }
        )
    }

    /// A new sender over the same storage, as after a relaunch.
    func relaunched(responses: [CannedResponse] = []) -> Self {
        Self(responses: responses, defaults: defaults)
    }

    func ensureSent() async {
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            await sender.ensureSent()
        }
    }

    var state: InstallSignalState {
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.installSignal) var state
            return state
        }
    }
}
