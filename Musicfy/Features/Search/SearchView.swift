import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject private var audioEngine: AudioEngine

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField("Songs, artists, albums...", text: $vm.query)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            Task { await vm.search(query: vm.query) }
                        }
                    if !vm.query.isEmpty {
                        Button {
                            vm.query = ""
                            vm.results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                Divider().background(Color.gray.opacity(0.3))

                if vm.query.isEmpty && vm.results.isEmpty {
                    SearchEmptyState()
                } else {
                    SearchResultsList(
                        results: vm.results,
                        isLoading: vm.isLoading,
                        error: vm.error,
                        onLoadMore: {
                            Task { await vm.loadMore() }
                        }
                    ) { result in
                        Task {
                            await audioEngine.play(
                                trackInfo: result.toTrackInfo(),
                                in: vm.results.map { $0.toTrackInfo() }
                            )
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onChange(of: vm.query) { _, newValue in
            vm.scheduleSearch(query: newValue)
        }
    }
}

// MARK: - Results List (reusable)

struct SearchResultsList: View {
    let results: [SearchResult]
    let isLoading: Bool
    let error: String?
    var onLoadMore: (() -> Void)? = nil
    let onPlay: (SearchResult) -> Void

    @EnvironmentObject private var audioEngine: AudioEngine
    @EnvironmentObject private var downloadManager: DownloadManager

    var body: some View {
        Group {
            if isLoading && results.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if let error, results.isEmpty {
                ErrorView(message: error) {}
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { result in
                            TrackRow(result: result, onPlay: onPlay)
                                .onAppear {
                                    if result.id == results.last?.id {
                                        onLoadMore?()
                                    }
                                }
                            Divider()
                                .background(Color.gray.opacity(0.2))
                                .padding(.leading, 72)
                        }
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView().tint(.white).padding()
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let result: SearchResult
    let onPlay: (SearchResult) -> Void

    @EnvironmentObject private var audioEngine: AudioEngine
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var showOptions = false

    var isCurrentlyPlaying: Bool {
        audioEngine.currentTrackInfo?.videoID == result.id && audioEngine.isPlaying
    }

    var body: some View {
        Button {
            onPlay(result)
        } label: {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    AsyncImage(url: URL(string: result.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(16/9, contentMode: .fill)
                        default:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    if isCurrentlyPlaying {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.black.opacity(0.5))
                            .frame(width: 56, height: 56)
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: isCurrentlyPlaying)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Text(result.channelName)
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                        if result.duration > 0 {
                            Text("·").foregroundStyle(.gray.opacity(0.5))
                            Text(formatDuration(result.duration))
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        if !result.viewCount.isEmpty {
                            Text("·").foregroundStyle(.gray.opacity(0.5))
                            Text(result.viewCount)
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                    }
                }

                Spacer()

                // Download status / more button
                if let state = downloadManager.activeDownloads[result.id] {
                    if case .downloading = state.status {
                        CircularProgressView(progress: state.progress)
                            .frame(width: 28, height: 28)
                    } else if case .done = state.status {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Button {
                        showOptions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog(result.title, isPresented: $showOptions, titleVisibility: .visible) {
            Button("Play") { onPlay(result) }
            Button("Download") {
                let info = result.toTrackInfo()
                Task { await downloadManager.download(trackInfo: info) }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Circular Progress

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
        }
    }
}

// MARK: - Search Empty State

struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.gray.opacity(0.5))
            Text("Search for songs, artists or albums")
                .font(.system(size: 15))
                .foregroundStyle(.gray)
            Spacer()
        }
    }
}
