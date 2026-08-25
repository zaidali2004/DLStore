import Foundation

struct StoreApp: Codable, Identifiable, Equatable {
    let id: Int
    let bundleId: String
    let name: String
    let developerName: String
    let version: String
    let price: Double
    let currency: String
    let artworkUrl: String
    let description: String
    let genre: String
    let releaseDate: String
    let minimumOsVersion: String
    let fileSizeBytes: String

    var isFree: Bool { price == 0 }
    var artworkURL: URL? { URL(string: artworkUrl.replacingOccurrences(of: "100x100", with: "512x512")) }
    var fileSizeMB: String {
        guard let bytes = Double(fileSizeBytes) else { return "Unknown" }
        return String(format: "%.1f MB", bytes / 1_000_000)
    }

    // Coding keys to map iTunes Search API response
    enum CodingKeys: String, CodingKey {
        case id = "trackId"
        case bundleId
        case name = "trackName"
        case developerName = "artistName"
        case version
        case price = "price"
        case currency = "currency"
        case artworkUrl = "artworkUrl100"
        case description = "description"
        case genre = "primaryGenreName"
        case releaseDate
        case minimumOsVersion
        case fileSizeBytes
    }
}

struct AppVersion: Codable, Identifiable {
    let id: Int  // externalVersionId
    let version: String
    let releaseDate: String
}

struct DownloadItem: Identifiable, ObservableObject {
    let id = UUID()
    let app: StoreApp
    let account: Account
    var versionId: Int?

    @Published var progress: Double = 0
    @Published var status: DownloadStatus = .waiting
    @Published var localURL: URL?
    @Published var errorMessage: String?

    enum DownloadStatus: String {
        case waiting = "waiting"
        case downloading = "downloading"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
    }
}
