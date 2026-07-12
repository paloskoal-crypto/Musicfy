import Foundation

final class SearchService {

    static let shared = SearchService()

    private let apiKey = "AIzaSyAD-ptPEv_HDwTXfWn17EKAHi2DYT7abfQ"
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let session = URLSession.shared

    private init() {}

    // MARK: - Search Videos

    func search(query: String, pageToken: String? = nil) async throws -> (results: [SearchResult], nextPageToken: String?) {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: "10"), // music
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "key", value: apiKey),
            pageToken.map { URLQueryItem(name: "pageToken", value: $0) }
        ].compactMap { $0 }

        let data = try await fetch(url: components.url!)
        
        let response: SearchListResponse
        do {
            response = try JSONDecoder().decode(SearchListResponse.self, from: data)
        } catch {
            print("[SearchService] ❌ Search JSON decode error: \(error)")
            if let jsonStr = String(data: data, encoding: .utf8) {
                print("[SearchService] Response: \(jsonStr.prefix(500))")
            }
            throw error
        }

        let videoIDs = response.items.compactMap { $0.id.videoId }
        let details = try await fetchVideoDetails(videoIDs: videoIDs)

        let results = response.items.compactMap { item -> SearchResult? in
            guard let videoID = item.id.videoId else { return nil }
            // Skip live streams - YouTubeKit tidak support
            let liveStatus = item.snippet.liveBroadcastContent ?? "none"
            if liveStatus == "live" || liveStatus == "upcoming" {
                print("[SearchService] ⏭️ Skipping \(liveStatus) video: \(item.snippet.title)")
                return nil
            }
            let detail = details[videoID]
            return SearchResult(
                id: videoID,
                title: item.snippet.title,
                channelName: item.snippet.channelTitle,
                thumbnailURL: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.default.url,
                duration: detail?.durationSeconds ?? 0,
                viewCount: detail?.viewCountFormatted ?? "",
                publishedAt: item.snippet.publishedAt.toRelativeString()
            )
        }

        return (results, response.nextPageToken)
    }

    // MARK: - Trending / Home Feed

    func fetchTrending(categoryID: String = "10", regionCode: String = "US") async throws -> [SearchResult] {
        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "chart", value: "mostPopular"),
            URLQueryItem(name: "videoCategoryId", value: categoryID),
            URLQueryItem(name: "regionCode", value: regionCode),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let data = try await fetch(url: components.url!)
        
        let response: VideoListResponse
        do {
            response = try JSONDecoder().decode(VideoListResponse.self, from: data)
        } catch {
            print("[SearchService] ❌ Trending JSON decode error: \(error)")
            if let jsonStr = String(data: data, encoding: .utf8) {
                print("[SearchService] Response: \(jsonStr.prefix(500))")
            }
            throw error
        }
        
        return response.items.compactMap { item -> SearchResult? in
            // Skip live streams
            let liveStatus = item.snippet.liveBroadcastContent ?? "none"
            if liveStatus == "live" || liveStatus == "upcoming" {
                print("[SearchService] ⏭️ Skipping \(liveStatus) video: \(item.snippet.title)")
                return nil
            }
            return SearchResult(
                id: item.id,
                title: item.snippet.title,
                channelName: item.snippet.channelTitle,
                thumbnailURL: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.default.url,
                duration: item.contentDetails?.durationSeconds ?? 0,
                viewCount: item.statistics?.viewCountFormatted ?? "",
                publishedAt: item.snippet.publishedAt.toRelativeString()
            )
        }
    }

    // MARK: - Related Videos

    func fetchRelated(videoID: String) async throws -> [SearchResult] {
        // YouTube v3 relatedToVideoId is deprecated, fallback ke search dengan judul
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "relatedToVideoId", value: videoID),
            URLQueryItem(name: "maxResults", value: "15"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let data = try await fetch(url: components.url!)
        let response = try JSONDecoder().decode(SearchListResponse.self, from: data)

        let videoIDs = response.items.compactMap { $0.id.videoId }
        let details = try await fetchVideoDetails(videoIDs: videoIDs)

        return response.items.compactMap { item -> SearchResult? in
            guard let videoID = item.id.videoId else { return nil }
            let detail = details[videoID]
            return SearchResult(
                id: videoID,
                title: item.snippet.title,
                channelName: item.snippet.channelTitle,
                thumbnailURL: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.default.url,
                duration: detail?.durationSeconds ?? 0,
                viewCount: detail?.viewCountFormatted ?? "",
                publishedAt: item.snippet.publishedAt.toRelativeString()
            )
        }
    }

    // MARK: - Video Details (duration, views)

    func fetchVideoDetails(videoIDs: [String]) async throws -> [String: VideoDetail] {
        guard !videoIDs.isEmpty else { return [:] }
        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails,statistics"),
            URLQueryItem(name: "id", value: videoIDs.joined(separator: ",")),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let data = try await fetch(url: components.url!)
        let response = try JSONDecoder().decode(VideoListResponse.self, from: data)

        var dict: [String: VideoDetail] = [:]
        for item in response.items {
            dict[item.id] = VideoDetail(
                durationSeconds: item.contentDetails?.durationSeconds ?? 0,
                viewCountFormatted: item.statistics?.viewCountFormatted ?? ""
            )
        }
        return dict
    }

    // MARK: - Single Video Detail (untuk track yang baru diplay by ID)

    func fetchSingleVideo(videoID: String) async throws -> SearchResult? {
        let details = try await fetchVideoDetails(videoIDs: [videoID])

        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "id", value: videoID),
            URLQueryItem(name: "key", value: apiKey)
        ]
        let data = try await fetch(url: components.url!)
        let response = try JSONDecoder().decode(VideoListResponse.self, from: data)

        guard let item = response.items.first else { return nil }
        let detail = details[videoID]
        return SearchResult(
            id: item.id,
            title: item.snippet.title,
            channelName: item.snippet.channelTitle,
            thumbnailURL: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.default.url,
            duration: detail?.durationSeconds ?? 0,
            viewCount: detail?.viewCountFormatted ?? "",
            publishedAt: item.snippet.publishedAt.toRelativeString()
        )
    }

    // MARK: - Network

    private func fetch(url: URL) async throws -> Data {
        print("[SearchService] Fetching: \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            print("[SearchService] ❌ Invalid HTTP response")
            throw SearchServiceError.unknown
        }
        
        print("[SearchService] Status: \(http.statusCode)")
        
        guard http.statusCode == 200 else {
            // Log response body untuk debugging
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[SearchService] ❌ Error response: \(responseStr)")
            }
            throw SearchServiceError.httpError(http.statusCode)
        }
        
        // Log successful response untuk debugging
        if let responseStr = String(data: data, encoding: .utf8) {
            print("[SearchService] ✅ Response preview: \(responseStr.prefix(200))...")
        }
        
        return data
    }
}

// MARK: - Helper Models

struct VideoDetail {
    let durationSeconds: Int
    let viewCountFormatted: String
}

enum SearchServiceError: LocalizedError {
    case httpError(Int)
    case unknown

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP Error \(code)"
        case .unknown: return "Unknown error"
        }
    }
}

// MARK: - Response Decodables

private struct SearchListResponse: Decodable {
    let items: [SearchItem]
    let nextPageToken: String?

    struct SearchItem: Decodable {
        let id: VideoID
        let snippet: Snippet
    }

    struct VideoID: Decodable {
        let videoId: String?
    }
}

private struct VideoListResponse: Decodable {
    let items: [VideoItem]

    struct VideoItem: Decodable {
        let id: String
        let snippet: Snippet
        let contentDetails: ContentDetails?
        let statistics: Statistics?
    }

    struct ContentDetails: Decodable {
        let duration: String // ISO 8601 e.g. PT4M13S

        var durationSeconds: Int {
            parseDuration(duration)
        }
    }

    struct Statistics: Decodable {
        let viewCount: String?

        var viewCountFormatted: String {
            guard let countStr = viewCount, let count = Int(countStr) else { return "" }
            switch count {
            case 0..<1_000: return "\(count)"
            case 1_000..<1_000_000: return String(format: "%.1fK", Double(count) / 1_000)
            case 1_000_000..<1_000_000_000: return String(format: "%.1fM", Double(count) / 1_000_000)
            default: return String(format: "%.1fB", Double(count) / 1_000_000_000)
            }
        }
    }
}

private struct Snippet: Decodable {
    let title: String
    let channelTitle: String
    let publishedAt: String
    let thumbnails: Thumbnails
    let liveBroadcastContent: String?  // "live", "upcoming", or "none"

    struct Thumbnails: Decodable {
        let `default`: Thumbnail
        let medium: Thumbnail?
        let high: Thumbnail?

        struct Thumbnail: Decodable {
            let url: String
        }
    }
}

// MARK: - Duration Parsing

private func parseDuration(_ iso: String) -> Int {
    // PT1H4M13S, PT4M13S, PT43S
    var total = 0
    let clean = iso.replacingOccurrences(of: "PT", with: "")
    let hourParts = clean.components(separatedBy: "H")
    var remaining = clean
    if hourParts.count == 2 {
        total += (Int(hourParts[0]) ?? 0) * 3600
        remaining = hourParts[1]
    }
    let minParts = remaining.components(separatedBy: "M")
    if minParts.count == 2 {
        total += (Int(minParts[0]) ?? 0) * 60
        remaining = minParts[1]
    }
    let secPart = remaining.replacingOccurrences(of: "S", with: "")
    total += Int(secPart) ?? 0
    return total
}

// MARK: - Date Formatting

private extension String {
    func toRelativeString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: self)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: self)
        }
        guard let date else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
