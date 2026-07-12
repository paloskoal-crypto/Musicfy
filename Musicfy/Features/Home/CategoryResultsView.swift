import SwiftUI

struct CategoryResultsView: View {
    let category: String
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject private var audioEngine: AudioEngine

    var body: some View {
        SearchResultsList(
            results: vm.results,
            isLoading: vm.isLoading,
            error: vm.error
        ) { result in
            Task {
                await audioEngine.play(
                    trackInfo: result.toTrackInfo(),
                    in: vm.results.map { $0.toTrackInfo() }
                )
            }
        }
        .background(Color.black)
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await vm.search(query: category + " music")
        }
    }
}
