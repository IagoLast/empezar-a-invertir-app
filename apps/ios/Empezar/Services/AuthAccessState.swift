import Foundation
import Combine

/// Bounds the UI wait independently of network cancellation and ignores late responses.
@MainActor final class AuthAccessState: ObservableObject {
    enum Phase { case idle, loading, ready, failed }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var providers: AuthProviders?
    private let timeout: Duration
    private var activeID: UUID?
    private var request: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var completion: CheckedContinuation<Void, Never>?

    init(timeout: Duration = .seconds(8)) { self.timeout = timeout }

    func load(using fetch: @escaping () async throws -> AuthProviders) async {
        guard activeID == nil, !Task.isCancelled else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                activeID = id
                completion = continuation
                phase = .loading
                request = Task { [weak self] in
                    do {
                        let result = try await fetch()
                        self?.finish(id: id, result: result, phase: .ready)
                    } catch {
                        self?.finish(id: id, phase: .failed)
                    }
                }
                deadline = Task { [weak self, timeout] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.finish(id: id, phase: .failed)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id: id) }
        }
    }

    func cancel() {
        guard let id = activeID else { return }
        cancel(id: id)
    }

    private func cancel(id: UUID) {
        finish(id: id, phase: providers == nil ? .idle : .ready)
    }

    private func finish(id: UUID, result: AuthProviders? = nil, phase: Phase) {
        guard activeID == id else { return }
        activeID = nil
        if let result { providers = result }
        self.phase = phase
        request?.cancel(); request = nil
        deadline?.cancel(); deadline = nil
        let completed = completion
        completion = nil
        completed?.resume()
    }
}
