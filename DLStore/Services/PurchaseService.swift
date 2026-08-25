import Foundation

enum PurchaseError: LocalizedError {
    case paidApp
    case subscriptionRequired
    case temporarilyUnavailable
    case alreadyOwned
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .paidApp:               return "شراء التطبيقات المدفوعة غير مدعوم"
        case .subscriptionRequired:  return "يتطلب اشتراكاً"
        case .temporarilyUnavailable:return "التطبيق غير متاح مؤقتاً"
        case .alreadyOwned:          return "التطبيق موجود بالفعل في حسابك"
        case .failed(let m):         return "فشل الشراء: \(m)"
        }
    }
}

struct PurchaseResponse: Codable {
    let failureType: String?
    let customerMessage: String?
    let jingleDocType: String?
    let status: Int?
    let songList: [PurchasedItem]?
}

struct PurchasedItem: Codable {
    let md5: String?
    let URL: String?
    let sinfs: [SinfItem]?
    let metadata: PurchaseMetadata?
}

struct SinfItem: Codable {
    let id: Int?
    let sinf: String?
}

struct PurchaseMetadata: Codable {
    let bundleShortVersionString: String?
    let bundleDisplayName: String?
    let softwareVersionExternalIdentifier: Int?
    let releaseDate: String?
}

actor PurchaseService {
    static let shared = PurchaseService()

    private let pricingParamAppStore    = "STDQ"
    private let pricingParamArcade      = "GAME"

    func purchase(app: StoreApp, account: Account) async throws {
        guard app.isFree else { throw PurchaseError.paidApp }

        let guid = AppleHeaders.deviceGUID()
        let buyEndpoint = await BagService.shared.getBuyEndpoint(guid: guid)

        do {
            try await performPurchase(app: app, account: account,
                                      guid: guid, endpoint: buyEndpoint,
                                      pricingParam: pricingParamAppStore)
        } catch PurchaseError.temporarilyUnavailable {
            // Fallback to Arcade pricing (ipatool pattern)
            try await performPurchase(app: app, account: account,
                                      guid: guid, endpoint: buyEndpoint,
                                      pricingParam: pricingParamArcade)
        }
    }

    private func performPurchase(app: StoreApp,
                                 account: Account,
                                 guid: String,
                                 endpoint: String,
                                 pricingParam: String) async throws {

        guard var urlComps = URLComponents(string: endpoint) else {
            throw PurchaseError.failed("Bad endpoint URL")
        }
        urlComps.queryItems = [URLQueryItem(name: "guid", value: guid)]
        guard let url = urlComps.url else {
            throw PurchaseError.failed("Cannot build purchase URL")
        }

        let bodyParts = [
            "appExtVrsId=\(app.id)",
            "hasAskedToFulfillPreorder=true",
            "buyWithoutAuthorization=true",
            "hasDoneAgeCheck=true",
            "guid=\(guid)",
            "price=0",
            "pricingParameters=\(pricingParam)",
            "productType=C",
            "salableAdamId=\(app.id)"
        ]
        let body = bodyParts.joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 20
        AppleHeaders.applyAuth(
            to: &request,
            guid: guid,
            storefront: account.storefront,
            dsPersonId: account.dsPersonId,
            token: account.passwordToken
        )
        request.setValue(account.dsPersonId, forHTTPHeaderField: "X-Dsid")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PurchaseError.failed("HTTP \(code)")
        }

        if let pResp = try? PropertyListDecoder().decode(PurchaseResponse.self, from: data) {
            try handlePurchaseFailure(pResp)
        }
    }

    private func handlePurchaseFailure(_ resp: PurchaseResponse) throws {
        guard let failure = resp.failureType else { return } // success
        let msg = resp.customerMessage ?? ""

        switch failure {
        case "5002": throw PurchaseError.alreadyOwned
        case "2059": throw PurchaseError.temporarilyUnavailable
        case "ap_subscription_required": throw PurchaseError.subscriptionRequired
        default:     throw PurchaseError.failed(msg.isEmpty ? failure : msg)
        }
    }
}
