import Foundation
import Combine
import SwiftData
import YouTubeKit

@MainActor
final class DownloadManager: ObservableObject {

    static let shared = DownloadManager()

    @Published var activeDownloads: [String: DownloadState] = [:] // key = videoID

    struct DownloadState {
        var progress: Double
        var status: Status

        enum Status {
            case queued, downloading, done, failed(Error)
        }
    }

    private let session: URLSession
    private var delegates: [String: DownloadDelegate] = [:]
    private var modelContext: ModelContext?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        createDownloadsDirectory()
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private func createDownloadsDirectory() {
        let dir = downloadsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    var downloadsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads")
    }

    // MARK: - Download (TrackInfo — tidak butuh SwiftData context saat mulai)

    func download(trackInfo: TrackInfo) async {
        let videoID = trackInfo.videoID
        guard activeDownloads[videoID] == nil else { return }

        activeDownloads[videoID] = DownloadState(progress: 0, status: .queued)

        do {
            let yt = YouTube(videoID: videoID)
            let streams = try await yt.streams
            guard let stream = streams
                .filterAudioOnly()
                .filter({ $0.fileExtension == .m4a })
                .highestAudioBitrateStream() ??
                streams.filterAudioOnly().highestAudioBitrateStream() else {
                activeDownloads[videoID] = DownloadState(progress: 0, status: .failed(DownloadError.noStream))
                return
            }

            activeDownloads[videoID] = DownloadState(progress: 0, status: .downloading)

            let fileName = "\(videoID).m4a"
            let destURL = downloadsDirectory.appendingPathComponent(fileName)

            let delegate = DownloadDelegate { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.activeDownloads[videoID]?.progress = progress
                }
            } completion: { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.activeDownloads[videoID] = DownloadState(progress: 1.0, status: .done)
                        self.markTrackAsDownloaded(trackInfo: trackInfo, fileName: fileName)
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        self.activeDownloads.removeValue(forKey: videoID)
                    case .failure(let error):
                        self.activeDownloads[videoID] = DownloadState(progress: 0, status: .failed(error))
                    }
                    self.delegates.removeValue(forKey: videoID)
                }
            }

            delegates[videoID] = delegate

            let (downloadURL, _) = try await session.download(from: stream.url, delegate: delegate)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: downloadURL, to: destURL)
            delegate.complete(result: .success(()))

        } catch {
            activeDownloads[videoID] = DownloadState(progress: 0, status: .failed(error))
        }
    }

    func cancelDownload(videoID: String) {
        delegates[videoID]?.cancel()
        delegates.removeValue(forKey: videoID)
        activeDownloads.removeValue(forKey: videoID)
    }

    func deleteDownload(track: Track) {
        guard let fileName = track.localFileName else { return }
        let url = downloadsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)

        track.isDownloaded = false
        track.localFileName = nil
        try? modelContext?.save()
    }

    func isDownloaded(videoID: String) -> Bool {
        let fileName = "\(videoID).m4a"
        let url = downloadsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path)
    }

    func isDownloading(_ videoID: String) -> Bool {
        if case .downloading = activeDownloads[videoID]?.status { return true }
        return false
    }

    func progress(for videoID: String) -> Double {
        activeDownloads[videoID]?.progress ?? 0
    }

    private func markTrackAsDownloaded(trackInfo: TrackInfo, fileName: String) {
        guard let context = modelContext else { return }
        let videoID = trackInfo.videoID // Capture to local constant
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate { $0.videoID == videoID }
        )
        
        if let track = try? context.fetch(descriptor).first {
            track.isDownloaded = true
            track.localFileName = fileName
        } else {
            // Track belum ada di DB, buat baru
            let newTrack = Track(
                videoID: trackInfo.videoID,
                title: trackInfo.title,
                artist: trackInfo.artist,
                thumbnailURL: trackInfo.thumbnailURL,
                duration: trackInfo.duration
            )
            newTrack.isDownloaded = true
            newTrack.localFileName = fileName
            context.insert(newTrack)
        }
        try? context.save()
    }
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {

    private let onProgress: (Double) -> Void
    private let onComplete: (Result<Void, Error>) -> Void
    private var task: URLSessionDownloadTask?
    private var completed = false

    init(progress: @escaping (Double) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        self.onProgress = progress
        self.onComplete = completion
    }

    func complete(result: Result<Void, Error>) {
        guard !completed else { return }
        completed = true
        onComplete(result)
    }

    func cancel() {
        task?.cancel()
        complete(result: .failure(DownloadError.cancelled))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {}

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            complete(result: .failure(error))
        }
    }
}

enum DownloadError: LocalizedError {
    case noStream, cancelled

    var errorDescription: String? {
        switch self {
        case .noStream: return "No audio stream available"
        case .cancelled: return "Download cancelled"
        }
    }
}
