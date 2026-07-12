import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: String
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify) var tracks: [Track]

    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.tracks = []
    }
}
