import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Track.addedAt, order: .reverse) private var tracks: [Track]
    @EnvironmentObject private var audioEngine: AudioEngine
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var showDeleteConfirm: Track? = nil

    var downloadedTracks: [Track] {
        tracks.filter { $0.isDownloaded }
    }

    var body: some View {
        NavigationStack {
            Group {
                if downloadedTracks.isEmpty {
                    LibraryEmptyState()
                } else {
                    List {
                        ForEach(downloadedTracks) { track in
                            LibraryTrackRow(track: track) {
                                Task {
                                    await audioEngine.play(
                                        track: track,
                                        in: downloadedTracks
                                    )
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    showDeleteConfirm = track
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(.gray.opacity(0.25))
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.black)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black)
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("Delete Download", isPresented: Binding(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let track = showDeleteConfirm {
                    downloadManager.deleteDownload(track: track)
                }
                showDeleteConfirm = nil
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirm = nil
            }
        } message: {
            Text("This will remove the file from your device.")
        }
    }
}

// MARK: - Library Track Row

struct LibraryTrackRow: View {
    let track: Track
    let onPlay: () -> Void
    @EnvironmentObject private var audioEngine: AudioEngine

    var isPlaying: Bool {
        audioEngine.currentTrack?.videoID == track.videoID && audioEngine.isPlaying
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    AsyncImage(url: URL(string: track.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(16/9, contentMode: .fill)
                        default:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    if isPlaying {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.black.opacity(0.5))
                            .frame(width: 56, height: 56)
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                        if track.duration > 0 {
                            Text("·")
                                .foregroundStyle(.gray.opacity(0.5))
                            Text(track.formattedDuration)
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green.opacity(0.8))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct LibraryEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 52))
                .foregroundStyle(.gray.opacity(0.4))
            Text("No downloads yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text("Tap ··· on any song and choose Download")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
