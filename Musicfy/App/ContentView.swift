import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var audioEngine: AudioEngine
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var selectedTab: Tab = .home
    @State private var showFullPlayer = false

    enum Tab: String, CaseIterable {
        case home = "Home"
        case search = "Search"
        case library = "Library"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .library: return "arrow.down.circle.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)
                    .toolbar(.hidden, for: .tabBar)

                SearchView()
                    .tag(Tab.search)
                    .toolbar(.hidden, for: .tabBar)

                LibraryView()
                    .tag(Tab.library)
                    .toolbar(.hidden, for: .tabBar)
            }

            VStack(spacing: 0) {
                // Mini Player
                if audioEngine.currentTrackInfo != nil {
                    MiniPlayerView(showFullPlayer: $showFullPlayer)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .animation(.spring(response: 0.3), value: audioEngine.currentTrackInfo?.videoID)
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView()
                .environmentObject(audioEngine)
                .environmentObject(downloadManager)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.gray)
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }
}
