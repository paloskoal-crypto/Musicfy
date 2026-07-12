import SwiftUI

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool
    @EnvironmentObject private var audioEngine: AudioEngine

    var body: some View {
        if let trackInfo = audioEngine.currentTrackInfo {
            miniContent(trackInfo: trackInfo)
        }
    }

    @ViewBuilder
    private func miniContent(trackInfo: TrackInfo) -> some View {
        Button {
            showFullPlayer = true
        } label: {
            VStack(spacing: 0) {
                // Thin progress bar
                GeometryReader { geo in
                    let progress = audioEngine.duration > 0
                        ? min(1.0, audioEngine.currentTime / audioEngine.duration)
                        : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.15))
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: trackInfo.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(trackInfo.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(trackInfo.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    if audioEngine.isBuffering {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            audioEngine.togglePlayPause()
                        } label: {
                            Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task { await audioEngine.playNext() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.plain)
    }
}
