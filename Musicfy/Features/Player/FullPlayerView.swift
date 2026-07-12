import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject private var audioEngine: AudioEngine
    @EnvironmentObject private var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var showEQ = false
    @State private var isDraggingSlider = false
    @State private var dragTime: Double = 0

    var displayTime: Double {
        isDraggingSlider ? dragTime : audioEngine.currentTime
    }

    var body: some View {
        ZStack {
            // Blurred background
            if let trackInfo = audioEngine.currentTrackInfo {
                AsyncImage(url: URL(string: trackInfo.thumbnailURL)) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .ignoresSafeArea()
                            .blur(radius: 60)
                            .opacity(0.4)
                    }
                }
            }
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Now Playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { showEQ = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)

                if let trackInfo = audioEngine.currentTrackInfo {
                    // Artwork
                    AsyncImage(url: URL(string: trackInfo.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(16/9, contentMode: .fit)
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fit)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                    .scaleEffect(audioEngine.isPlaying ? 1.0 : 0.92)
                    .animation(.spring(response: 0.4), value: audioEngine.isPlaying)

                    // Title + Download button
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trackInfo.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(trackInfo.artist)
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        DownloadButton(videoID: trackInfo.videoID, trackInfo: trackInfo)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    // Seek bar
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { displayTime },
                                set: { val in
                                    isDraggingSlider = true
                                    dragTime = val
                                }
                            ),
                            in: 0...max(audioEngine.duration, 1)
                        ) { editing in
                            if !editing {
                                audioEngine.seek(to: dragTime)
                                isDraggingSlider = false
                            }
                        }
                        .tint(.white)

                        HStack {
                            Text(formatTime(displayTime))
                            Spacer()
                            Text(formatTime(audioEngine.duration))
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    // Controls
                    HStack(spacing: 44) {
                        Button {
                            Task { await audioEngine.playPrevious() }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }

                        Button { audioEngine.togglePlayPause() } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 68, height: 68)
                                if audioEngine.isBuffering {
                                    ProgressView().tint(.black).scaleEffect(1.2)
                                } else {
                                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.black)
                                }
                            }
                        }

                        Button {
                            Task { await audioEngine.playNext() }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 28)

                    // Volume
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.gray).font(.system(size: 14))
                        Slider(value: Binding(
                            get: { Double(audioEngine.volume) },
                            set: { audioEngine.setVolume(Float($0)) }
                        ), in: 0...1)
                        .tint(.white)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.gray).font(.system(size: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                    // EQ quick chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EQPreset.all) { preset in
                                Button { audioEngine.applyPreset(preset) } label: {
                                    Text(preset.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(audioEngine.currentPreset == preset ? .black : .white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(audioEngine.currentPreset == preset ? Color.white : Color.white.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showEQ) {
            EqualizerView().environmentObject(audioEngine)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let t = Int(max(0, seconds))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: - Download Button

struct DownloadButton: View {
    let videoID: String
    let trackInfo: TrackInfo
    @EnvironmentObject private var downloadManager: DownloadManager

    var body: some View {
        Group {
            if downloadManager.isDownloaded(videoID: videoID) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.green)
            } else if let state = downloadManager.activeDownloads[videoID] {
                if case .downloading = state.status {
                    ZStack {
                        CircularProgressView(progress: state.progress)
                            .frame(width: 28, height: 28)
                        Button {
                            downloadManager.cancelDownload(videoID: videoID)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            } else {
                Button {
                    Task { await downloadManager.download(trackInfo: trackInfo) }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
