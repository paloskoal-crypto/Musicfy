import SwiftUI
import SwiftData

@main
struct MusicfyApp: App {

    @StateObject private var audioEngine = AudioEngine.shared
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioEngine)
                .environmentObject(downloadManager)
                .modelContainer(for: [Track.self, Playlist.self]) { result in
                    switch result {
                    case .success(let container):
                        DownloadManager.shared.setModelContext(container.mainContext)
                    case .failure(let error):
                        print("[App] SwiftData container error: \(error)")
                    }
                }
                .preferredColorScheme(.dark)
        }
    }
}
