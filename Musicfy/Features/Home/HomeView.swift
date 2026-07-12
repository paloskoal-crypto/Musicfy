import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var audioEngine: AudioEngine

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    SectionHeader(title: "Trending Music")

                    if vm.isLoading {
                        HStack {
                            Spacer()
                            ProgressView().tint(.white)
                            Spacer()
                        }
                        .frame(height: 200)
                    } else if let error = vm.error {
                        ErrorView(message: error) {
                            Task { await vm.load() }
                        }
                    } else {
                        if let featured = vm.trending.first {
                            FeaturedCard(result: featured) {
                                Task {
                                    await audioEngine.play(
                                        trackInfo: featured.toTrackInfo(),
                                        in: vm.trending.map { $0.toTrackInfo() }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(vm.trending.dropFirst()) { result in
                                    TrackCard(result: result) {
                                        Task {
                                            await audioEngine.play(
                                                trackInfo: result.toTrackInfo(),
                                                in: vm.trending.map { $0.toTrackInfo() }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    SectionHeader(title: "Browse Categories")
                    CategoryGrid()
                        .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background(Color.black)
            .navigationTitle("Musicfy")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await vm.load()
            }
        }
        .task {
            await vm.load()
        }
    }
}

// MARK: - Featured Card

struct FeaturedCard: View {
    let result: SearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: result.thumbnailURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(16/9, contentMode: .fill)
                    case .failure, .empty:
                        Rectangle().fill(Color.gray.opacity(0.3))
                    @unknown default:
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(result.channelName)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                        if !result.viewCount.isEmpty {
                            Text("·").foregroundStyle(.white.opacity(0.5))
                            Text("\(result.viewCount) views")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Track Card

struct TrackCard: View {
    let result: SearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: result.thumbnailURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(16/9, contentMode: .fill)
                    default:
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 160, height: 90)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(width: 160, alignment: .leading)
                    Text(result.channelName)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Grid

struct CategoryGrid: View {
    private let categories: [(name: String, icon: String, color: Color)] = [
        ("Pop", "music.note", .pink),
        ("Hip-Hop", "headphones", .purple),
        ("Rock", "guitars.fill", .red),
        ("Electronic", "bolt.fill", .blue),
        ("Jazz", "music.quarternote.3", .orange),
        ("Classical", "pianokeys", .teal),
        ("R&B", "waveform", .indigo),
        ("Lo-Fi", "moon.stars.fill", .mint),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(categories, id: \.name) { cat in
                NavigationLink {
                    CategoryResultsView(category: cat.name)
                } label: {
                    HStack {
                        Image(systemName: cat.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(cat.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(cat.color.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.gray)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
