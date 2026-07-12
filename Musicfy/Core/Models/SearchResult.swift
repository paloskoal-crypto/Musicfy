import Foundation

struct SearchResult: Identifiable, Hashable {
    let id: String       // videoID
    let title: String
    let channelName: String
    let thumbnailURL: String
    let duration: Int    // seconds, 0 jika belum diparse
    let viewCount: String
    let publishedAt: String

    /// Membuat Track SwiftData model — hanya panggil dari dalam ModelContext
    /// (misal saat play atau download, bukan di UI layer langsung)
    func toTrackInfo() -> TrackInfo {
        TrackInfo(
            videoID: id,
            title: title,
            artist: channelName,
            thumbnailURL: thumbnailURL,
            duration: duration
        )
    }
}

/// Plain struct — safe dipakai di mana saja, termasuk luar SwiftData context
struct TrackInfo {
    let videoID: String
    let title: String
    let artist: String
    let thumbnailURL: String
    let duration: Int

    var formattedDuration: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%d:%02d", m, s)
    }
}
