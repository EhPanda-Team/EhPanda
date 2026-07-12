import AppModels
import Foundation
import Testing

// Wave 0 self-tests for the request parity harness. Every URLSession below installs
// CountingStubProtocol, so these tests are deterministic and never open a network socket.
@Suite
struct HarnessSelfTests {
    @Test
    func sessionsWithTheSameURLRemainIsolated() async throws {
        let url = try #require(URL(string: "https://fixtures.example/shared"))
        let firstFixture = Data("first".utf8)
        let secondFixture = Data("second".utf8)
        let (firstSession, firstHandle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: firstFixture)]])
        )
        let (secondSession, secondHandle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: secondFixture)]])
        )
        defer {
            firstSession.invalidateAndCancel()
            secondSession.invalidateAndCancel()
            firstHandle.tearDown()
            secondHandle.tearDown()
        }

        async let firstResponse = firstSession.data(from: url)
        async let secondResponse = secondSession.data(from: url)
        let ((firstData, _), (secondData, _)) = try await (firstResponse, secondResponse)

        #expect(firstData == firstFixture)
        #expect(secondData == secondFixture)
        #expect(firstHandle.attempts(for: url) == 1)
        #expect(secondHandle.attempts(for: url) == 1)
    }

    @Test
    func attemptsAreCountedAndFixturesRoundTrip() async throws {
        let failureURL = try #require(URL(string: "https://fixtures.example/failure"))
        let fixtureURL = try #require(URL(string: "https://fixtures.example/success"))
        let fixture = Data("fixture".utf8)
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                failureURL: [.transportFailure(.timedOut)],
                fixtureURL: [.http(status: 200, data: fixture)]
            ])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        do {
            _ = try await session.data(from: failureURL)
            Issue.record("Expected the scripted transport failure.")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        } catch {
            Issue.record("Expected URLError.timedOut, received \(error).")
        }
        let (data, _) = try await session.data(from: fixtureURL)

        #expect(handle.attempts(for: failureURL) == 1)
        #expect(handle.attempts(for: fixtureURL) == 1)
        #expect(data == fixture)
    }

    @Test
    func streamedPOSTBodyIsCapturedWithoutRoutingHeader() async throws {
        let url = try #require(URL(string: "https://fixtures.example/form"))
        let body = Data("field=value".utf8)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 204, data: Data())]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)

        _ = try await session.data(for: request)

        let received = try #require(handle.receivedRequests.first)
        #expect(received.httpMethod == "POST")
        #expect(received.httpBody == body)
        #expect(received.httpBodyStream == nil)
        #expect(received.value(forHTTPHeaderField: CountingStubProtocol.tokenHeader) == nil)
    }

    @Test
    func captureMapsTypedSuccessAndFailure() async {
        let failure: Result<Int, AppError> = await capture { () async throws(AppError) -> Int in
            throw AppError.noUpdates
        }
        let success: Result<Int, AppError> = await capture {
            42
        }

        #expect(failure == .failure(.noUpdates))
        #expect(success == .success(42))
    }
}
