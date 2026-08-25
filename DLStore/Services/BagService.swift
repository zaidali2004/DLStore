import Foundation

/// Fetches Apple's dynamic URL bag to get current API endpoints
/// Apple changes these endpoints - fetching dynamically avoids hardcoded broken URLs
actor BagService {

    static let shared = BagService()

    private var cachedBag: AppleBag?
    private var lastFetch: Date?
    private let cacheDuration: TimeInterval = 3600 // 1 hour

    // Default fallback endpoints (from ipatool reference)
    private let fallbackAuthEndpoint = "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate"
    private let fallbackBuyEndpoint  = "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/buyProduct"

    struct AppleBag {
        let authEndpoint: String
        let buyEndpoint: String
        let buyProductBatchEndpoint: String?
    }

    func getAuthEndpoint(guid: String) async -> String {
        if let bag = await fetchBag(guid: guid) {
            return bag.authEndpoint
        }
        return fallbackAuthEndpoint
    }

    func getBuyEndpoint(guid: String) async -> String {
        if let bag = await fetchBag(guid: guid) {
            return bag.buyEndpoint
        }
        return fallbackBuyEndpoint
    }

    private func fetchBag(guid: String) async -> AppleBag? {
        // Return cache if fresh
        if let cached = cachedBag,
           let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            return cached
        }

        guard let url = URL(string: "https://init.itunes.apple.com/bag.xml?ix=6") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        AppleHeaders.apply(to: &request, guid: guid)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let xmlString = String(data: data, encoding: .utf8) ?? ""
            let bag = parseBag(xml: xmlString)
            cachedBag = bag
            lastFetch = Date()
            return bag
        } catch {
            return nil
        }
    }

    private func parseBag(xml: String) -> AppleBag? {
        // Extract authentication-url
        func extract(key: String, from xml: String) -> String? {
            let pattern = "<key>\(NSRegularExpression.escapedPattern(for: key))</key>\\s*<string>([^<]+)</string>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                  let range = Range(match.range(at: 1), in: xml) else {
                return nil
            }
            return String(xml[range])
        }

        let authEndpoint = extract(key: "authentication-url", from: xml)
                        ?? extract(key: "MZFinance.defaultBasePath", from: xml)
                        ?? "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate"

        let buyEndpoint  = extract(key: "MZBuy.defaultBasePath", from: xml)
                        ?? "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/buyProduct"

        let buyBatchEndpoint = extract(key: "MZBuy.buyProductBatch", from: xml)

        return AppleBag(
            authEndpoint: authEndpoint,
            buyEndpoint: buyEndpoint,
            buyProductBatchEndpoint: buyBatchEndpoint
        )
    }
}
