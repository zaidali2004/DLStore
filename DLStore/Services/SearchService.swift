import Foundation

struct SearchResult: Codable {
    let resultCount: Int
    let results: [StoreApp]
}

actor SearchService {
    static let shared = SearchService()

    func search(term: String,
                storefront: String = "143441",
                limit: Int = 20) async throws -> [StoreApp] {

        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term",    value: term),
            URLQueryItem(name: "country", value: storefrontToCountry(storefront)),
            URLQueryItem(name: "entity",  value: "software"),
            URLQueryItem(name: "limit",   value: "\(limit)"),
            URLQueryItem(name: "lang",    value: "en_us")
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let guid = AppleHeaders.deviceGUID()
        AppleHeaders.apply(to: &request, guid: guid, storefront: "\(storefront)-1,29")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(SearchResult.self, from: data)
        return decoded.results
    }

    func lookup(bundleId: String, storefront: String = "143441") async throws -> StoreApp? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleId),
            URLQueryItem(name: "country",  value: storefrontToCountry(storefront)),
            URLQueryItem(name: "entity",   value: "software")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let guid = AppleHeaders.deviceGUID()
        AppleHeaders.apply(to: &request, guid: guid)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(SearchResult.self, from: data)
        return decoded.results.first
    }

    func lookupById(_ appId: Int, storefront: String = "143441") async throws -> StoreApp? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id",      value: "\(appId)"),
            URLQueryItem(name: "country", value: storefrontToCountry(storefront)),
            URLQueryItem(name: "entity",  value: "software")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        let guid = AppleHeaders.deviceGUID()
        AppleHeaders.apply(to: &request, guid: guid)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(SearchResult.self, from: data)
        return decoded.results.first
    }

    private func storefrontToCountry(_ storefront: String) -> String {
        let code = storefront.components(separatedBy: "-").first ?? storefront
        let map: [String: String] = [
            "143441": "us", "143444": "gb", "143443": "de",
            "143442": "fr", "143446": "jp", "143463": "sa",
            "143481": "ae", "143445": "ca", "143460": "au",
            "143448": "it", "143449": "es"
        ]
        return map[code] ?? "us"
    }
}
