import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var trending: [SearchResult] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            trending = try await SearchService.shared.fetchTrending()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
