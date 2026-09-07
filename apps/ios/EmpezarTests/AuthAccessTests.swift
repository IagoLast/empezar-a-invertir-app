import XCTest
@testable import Empezar

@MainActor final class AuthAccessTests: XCTestCase {
    private let apple = AuthProviders(external: ["apple": true, "google": false])

    func testSuccessfulLoadEnablesOnlyConfiguredProviders() async {
        let state = AuthAccessState()
        await state.load { self.apple }
        XCTAssertEqual(state.phase, .ready)
        XCTAssertEqual(state.providers?.appleEnabled, true)
        XCTAssertEqual(state.providers?.googleEnabled, false)
    }

    func testFailureStopsLoadingAndRetryRecovers() async {
        let state = AuthAccessState()
        await state.load { throw URLError(.notConnectedToInternet) }
        XCTAssertEqual(state.phase, .failed)
        XCTAssertNil(state.providers)
        await state.load { self.apple }
        XCTAssertEqual(state.phase, .ready)
        XCTAssertEqual(state.providers?.appleEnabled, true)
    }

    func testDeadlineReturnsEvenWhenTransportIgnoresCancellation() async {
        let state = AuthAccessState(timeout: .milliseconds(30))
        var response: CheckedContinuation<AuthProviders, Never>?
        await state.load { await withCheckedContinuation { response = $0 } }
        XCTAssertEqual(state.phase, .failed)
        XCTAssertNil(state.providers)
        // A successful retry must not be overwritten by a late response from the old request.
        await state.load { self.apple }
        response?.resume(returning: AuthProviders(external: ["apple": false]))
        await Task.yield()
        XCTAssertEqual(state.phase, .ready)
        XCTAssertEqual(state.providers?.appleEnabled, true)
    }

    func testClosingDuringLoadAllowsImmediateReopening() async {
        let state = AuthAccessState()
        let started = expectation(description: "Request started")
        var response: CheckedContinuation<AuthProviders, Never>?
        let loading = Task {
            await state.load {
                await withCheckedContinuation { response = $0; started.fulfill() }
            }
        }
        await fulfillment(of: [started], timeout: 1)
        state.cancel()
        await loading.value
        XCTAssertEqual(state.phase, .idle)
        await state.load { self.apple }
        response?.resume(returning: AuthProviders(external: [:]))
        await Task.yield()
        XCTAssertEqual(state.providers?.appleEnabled, true)
    }

    func testRefreshFailurePreservesPreviouslyAvailableMethods() async {
        let state = AuthAccessState()
        await state.load { self.apple }
        await state.load { throw URLError(.timedOut) }
        XCTAssertEqual(state.phase, .failed)
        XCTAssertEqual(state.providers?.appleEnabled, true)
    }

    func testUnavailableProvidersAreNotNetworkErrors() async {
        let state = AuthAccessState()
        await state.load { AuthProviders(external: [:]) }
        XCTAssertEqual(state.phase, .ready)
        XCTAssertEqual(state.providers?.appleEnabled, false)
        XCTAssertEqual(state.providers?.googleEnabled, false)
    }
}
