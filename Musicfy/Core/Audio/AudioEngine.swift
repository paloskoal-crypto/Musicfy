import AVFoundation
import Combine
import MediaPlayer
import UIKit
import YouTubeKit

// MARK: - TimeObserver helper (NSObject untuk CADisplayLink)
private final class DisplayLinkTarget: NSObject {
    var onTick: (() -> Void)?

    @objc func tick() {
        onTick?()
    }
}

@MainActor
final class AudioEngine: ObservableObject {

    static let shared = AudioEngine()

    // MARK: - Published State
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isBuffering = false
    @Published var currentTrackInfo: TrackInfo?
    @Published var currentPreset: EQPreset = .flat
    @Published var eqBands: [EQBand] = EQPreset.flat.bands
    @Published var volume: Float = 1.0
    @Published var queue: [TrackInfo] = []
    @Published var currentIndex: Int = 0

    // MARK: - Private
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 10)
    private let timePitch = AVAudioUnitTimePitch()

    private var audioFile: AVAudioFile?
    private var displayLink: CADisplayLink?
    private let displayLinkTarget = DisplayLinkTarget()
    private var streamTask: Task<Void, Never>?

    private init() {
        setupEngine()
        setupRemoteCommandCenter()
        setupAudioSession()

        displayLinkTarget.onTick = { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateTime()
            }
        }
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("[AudioEngine] Session setup error: \(error)")
        }
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(eq)
        engine.attach(timePitch)

        engine.connect(playerNode, to: eq, format: nil)
        engine.connect(eq, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)

        applyPreset(.flat)

        do {
            try engine.start()
        } catch {
            print("[AudioEngine] Engine start error: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { await self?.playNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { await self?.playPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }

    // MARK: - Playback (TrackInfo — tidak perlu SwiftData context)

    func play(trackInfo: TrackInfo, in queue: [TrackInfo] = []) async {
        streamTask?.cancel()
        currentTrackInfo = trackInfo
        isBuffering = true
        isPlaying = false

        if !queue.isEmpty {
            self.queue = queue
            self.currentIndex = queue.firstIndex(where: { $0.videoID == trackInfo.videoID }) ?? 0
        }

        streamTask = Task {
            do {
                let url = try await resolveAudioURL(for: trackInfo)
                guard !Task.isCancelled else { return }
                await loadAndPlay(url: url, trackInfo: trackInfo)
            } catch {
                print("[AudioEngine] Failed to resolve URL: \(error)")
                await MainActor.run { isBuffering = false }
            }
        }
    }

    /// Overload untuk SwiftData Track object
    func play(track: Track, in queue: [Track] = []) async {
        let info = TrackInfo(
            videoID: track.videoID,
            title: track.title,
            artist: track.artist,
            thumbnailURL: track.thumbnailURL,
            duration: track.duration
        )
        let queueInfos = queue.map {
            TrackInfo(videoID: $0.videoID, title: $0.title, artist: $0.artist,
                      thumbnailURL: $0.thumbnailURL, duration: $0.duration)
        }
        await play(trackInfo: info, in: queueInfos)
    }

    private func resolveAudioURL(for trackInfo: TrackInfo) async throws -> URL {
        print("[AudioEngine] 🎵 Resolving audio for: \(trackInfo.title) (\(trackInfo.videoID))")
        
        // Cek file lokal dulu
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = docs.appendingPathComponent("Downloads/\(trackInfo.videoID).m4a")
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("[AudioEngine] ✅ Found local file: \(localURL.path)")
            return localURL
        }

        // Streaming via YouTubeKit
        print("[AudioEngine] 📡 Fetching YouTube streams...")
        let yt = YouTube(videoID: trackInfo.videoID)
        let streams = try await yt.streams
        
        print("[AudioEngine] 🔍 Available streams: \(streams.count)")
        let audioStreams = streams.filterAudioOnly()
        print("[AudioEngine] 🎧 Audio-only streams: \(audioStreams.count)")
        
        guard let stream = audioStreams
            .filter({ $0.fileExtension == .m4a })
            .highestAudioBitrateStream() ??
            audioStreams.highestAudioBitrateStream() else {
            print("[AudioEngine] ❌ No audio stream available")
            throw AudioEngineError.noStreamAvailable
        }
        
        print("[AudioEngine] ✅ Selected stream: \(stream.url.absoluteString)")
        return stream.url
    }

    private func loadAndPlay(url: URL, trackInfo: TrackInfo) async {
        print("[AudioEngine] 🔊 Loading audio from: \(url.absoluteString.prefix(100))...")
        playerNode.stop()

        do {
            let file = try AVAudioFile(forReading: url)
            print("[AudioEngine] ✅ Audio file loaded. Duration: \(Double(file.length) / file.fileFormat.sampleRate)s")
            
            self.audioFile = file
            self.duration = Double(file.length) / file.fileFormat.sampleRate
            self.currentTime = 0

            if !engine.isRunning {
                try engine.start()
            }

            playerNode.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackFinished()
                }
            }

            playerNode.play()
            isPlaying = true
            isBuffering = false

            startTimeTracking()
            updateNowPlayingInfo(trackInfo: trackInfo)
            
            print("[AudioEngine] ▶️ Playback started!")

        } catch {
            print("[AudioEngine] ❌ Load error: \(error.localizedDescription)")
            print("[AudioEngine] ❌ Full error: \(error)")
            isBuffering = false
        }
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimeTracking()
        updateNowPlayingInfoPlaybackState()
    }

    func resume() {
        playerNode.play()
        isPlaying = true
        startTimeTracking()
        updateNowPlayingInfoPlaybackState()
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func seek(to time: Double) {
        guard let file = audioFile else { return }
        let sampleRate = file.fileFormat.sampleRate
        let sampleTime = AVAudioFramePosition(time * sampleRate)
        let remaining = file.length - sampleTime
        guard remaining > 0 else { return }
        let frameCount = AVAudioFrameCount(remaining)

        playerNode.stop()
        playerNode.scheduleSegment(file, startingFrame: sampleTime, frameCount: frameCount, at: nil) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handlePlaybackFinished()
            }
        }
        currentTime = time
        if isPlaying { playerNode.play() }
    }

    func playNext() async {
        guard !queue.isEmpty else { return }
        let nextIndex = currentIndex + 1
        guard nextIndex < queue.count else { return }
        currentIndex = nextIndex
        await play(trackInfo: queue[nextIndex], in: queue)
    }

    func playPrevious() async {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty, currentIndex > 0 else { return }
        let prevIndex = currentIndex - 1
        currentIndex = prevIndex
        await play(trackInfo: queue[prevIndex], in: queue)
    }

    private func handlePlaybackFinished() {
        Task { await playNext() }
    }

    // MARK: - EQ

    func applyPreset(_ preset: EQPreset) {
        currentPreset = preset
        eqBands = preset.bands
        applyBands(preset.bands)
    }

    func applyBands(_ bands: [EQBand]) {
        eqBands = bands
        for (i, band) in bands.enumerated() {
            guard i < eq.bands.count else { break }
            eq.bands[i].frequency = band.frequency
            eq.bands[i].bandwidth = band.bandwidth
            eq.bands[i].gain = band.gain
            eq.bands[i].filterType = band.filterType
            eq.bands[i].bypass = false
        }
    }

    func updateBandGain(at index: Int, gain: Float) {
        guard index < eqBands.count else { return }
        eqBands[index] = EQBand(
            frequency: eqBands[index].frequency,
            bandwidth: eqBands[index].bandwidth,
            gain: gain,
            filterType: eqBands[index].filterType
        )
        eq.bands[index].gain = gain
    }

    // MARK: - Volume

    func setVolume(_ value: Float) {
        volume = value
        engine.mainMixerNode.outputVolume = value
    }

    // MARK: - Time Tracking

    private func startTimeTracking() {
        stopTimeTracking()
        let link = CADisplayLink(target: displayLinkTarget, selector: #selector(DisplayLinkTarget.tick))
        link.preferredFramesPerSecond = 10
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTimeTracking() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let file = audioFile else { return }

        let sampleRate = file.fileFormat.sampleRate
        let currentSample = Double(playerTime.sampleTime)
        currentTime = min(max(0, currentSample / sampleRate), duration)
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo(trackInfo: TrackInfo) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: trackInfo.title,
            MPMediaItemPropertyArtist: trackInfo.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load thumbnail async tanpa block main thread
        if let thumbURL = URL(string: trackInfo.thumbnailURL) {
            Task.detached {
                guard let data = try? Data(contentsOf: thumbURL),
                      let image = UIImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                await MainActor.run {
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
    }

    private func updateNowPlayingInfoPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

enum AudioEngineError: Error {
    case noStreamAvailable
}
