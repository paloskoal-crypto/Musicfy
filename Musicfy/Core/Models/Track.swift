import Foundation
import SwiftData

@Model
final class Track {
    @Attribute(.unique) var videoID: String
    var title: String
    var artist: String
    var thumbnailURL: String
    var duration: Int // seconds
    var addedAt: Date
    var isDownloaded: Bool
    var localFileName: String? // filename in Documents/Downloads/

    init(videoID: String, title: String, artist: String, thumbnailURL: String, duration: Int) {
        self.videoID = videoID
        self.title = title
        self.artist = artist
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.addedAt = Date()
        self.isDownloaded = false
        self.localFileName = nil
    }

    var localFileURL: URL? {
        guard let name = localFileName else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Downloads").appendingPathComponent(name)
    }

    var formattedDuration: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%d:%02d", m, s)
    }
}
