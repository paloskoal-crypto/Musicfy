import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    @Published var error: String?

    private var nextPageToken: String?
    private var debounceTask: Task<Void, Never>?
    private var lastQuery = ""

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        lastQuery = query
        nextPageToken = nil
        isLoading = true
        error = nil
        do {
            let (res, token) = try await SearchService.shared.search(query: query)
            // guard against stale responses if query changed
            guard lastQuery == query else { return }
            results = res
            nextPageToken = token
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, let token = nextPageToken, !lastQuery.isEmpty else { return }
        isLoading = true
        do {
            let (res, token) = try await SearchService.shared.search(query: lastQuery, pageToken: token)
            results += res
            nextPageToken = token
        } catch {
            // silently fail on pagination
        }
        isLoading = false
    }

    // Debounced search while typing
    func scheduleSearch(query: String) {
        debounceTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            guard !Task.isCancelled else { return }
            await search(query: query)
        }
    }
}
