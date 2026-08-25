import Foundation

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case accountDisabled
    case twoFactorRequired
    case invalidAuthCode
    case passwordExpired
    case networkError(String)
    case unexpectedResponse(Int)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:   return "البريد الإلكتروني أو كلمة المرور غير صحيحة"
        case .accountDisabled:      return "الحساب موقوف"
        case .twoFactorRequired:    return "التحقق بخطوتين مطلوب"
        case .invalidAuthCode:      return "رمز التحقق غير صحيح"
        case .passwordExpired:      return "انتهت صلاحية كلمة المرور، يرجى إعادة تسجيل الدخول"
        case .networkError(let m):  return "خطأ في الشبكة: \(m)"
        case .unexpectedResponse(let code): return "استجابة غير متوقعة من Apple (HTTP \(code))"
        case .unknown(let m):       return "خطأ غير معروف: \(m)"
        }
    }
}

// MARK: - Auth Response (Plist)
struct AuthResponse: Codable {
    let failureType: String?
    let customerMessage: String?
    let dsPersonId: String?
    let passwordToken: String?
    let accountInfo: AuthAccountInfo?
    let creditDisplay: String?

    enum CodingKeys: String, CodingKey {
        case failureType
        case customerMessage
        case dsPersonId
        case passwordToken
        case accountInfo
        case creditDisplay
    }
}

struct AuthAccountInfo: Codable {
    let appleId: String?
    let address: AuthAddress?
}

struct AuthAddress: Codable {
    let firstName: String?
    let lastName: String?
}

// MARK: - AuthService
/// Handles Apple ID authentication using the iTunes Store API
/// KEY FIX: Uses dynamic endpoint from BagService + correct headers
actor AuthService {

    static let shared = AuthService()

    // Apple failure type codes (from ipatool source)
    private let failureInvalidCredentials  = "-5000"
    private let failureBadLogin            = "MZFinance.BadLogin.Configurator_message"
    private let failureAccountDisabled     = "Your account is disabled."
    private let failurePasswordExpired     = "2034"
    private let failureSignInRequired      = "2042"
    private let failureTwoFactor           = "MZFinance.2FANeeded"

    func login(email: String,
               password: String,
               authCode: String = "",
               storefront: String = "143441-1,29") async throws -> Account {

        let guid = AppleHeaders.deviceGUID()

        // Step 1: Get fresh auth endpoint from Apple's bag
        let authEndpoint = await BagService.shared.getAuthEndpoint(guid: guid)

        // Step 2: Try up to 4 times (ipatool pattern - some pods need retry)
        var lastError: Error = AuthError.unknown("No attempts made")

        for attempt in 1...4 {
            do {
                let account = try await performLogin(
                    email: email,
                    password: password,
                    authCode: authCode,
                    guid: guid,
                    storefront: storefront,
                    endpoint: authEndpoint,
                    attempt: attempt
                )
                return account
            } catch AuthError.twoFactorRequired {
                throw AuthError.twoFactorRequired
            } catch {
                lastError = error
                // Only retry on network errors, not on credential errors
                if case AuthError.invalidCredentials = error { throw error }
                if case AuthError.accountDisabled    = error { throw error }
                if attempt < 4 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                }
            }
        }
        throw lastError
    }

    private func performLogin(email: String,
                              password: String,
                              authCode: String,
                              guid: String,
                              storefront: String,
                              endpoint: String,
                              attempt: Int) async throws -> Account {

        guard var urlComponents = URLComponents(string: endpoint) else {
            throw AuthError.networkError("Invalid endpoint URL")
        }
        urlComponents.queryItems = [URLQueryItem(name: "guid", value: guid)]

        guard let url = urlComponents.url else {
            throw AuthError.networkError("Failed to build URL")
        }

        // Build request body
        var bodyParts = [
            "appleId=\(email.urlEncoded)",
            "password=\(password.urlEncoded)",
            "attempt=\(attempt)",
            "createSession=true",
            "rmp=0",
            "why=signIn"
        ]
        if !authCode.isEmpty {
            bodyParts.append("secondaryPassword=\(authCode.urlEncoded)")
        }
        let body = bodyParts.joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 20

        AppleHeaders.applyAuth(to: &request, guid: guid, storefront: storefront)

        // Configure session - disable redirect following for auth endpoint
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        // Handle redirect (pod routing)
        if (301...302).contains(httpResponse.statusCode),
           let location = httpResponse.value(forHTTPHeaderField: "Location"),
           let redirectURL = URL(string: location),
           redirectURL.host?.contains("apple.com") == true {
            return try await performLogin(
                email: email, password: password, authCode: authCode,
                guid: guid, storefront: storefront,
                endpoint: redirectURL.absoluteString, attempt: 1
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw AuthError.unexpectedResponse(httpResponse.statusCode)
        }

        return try parseAuthResponse(data: data, email: email, storefront: storefront)
    }

    private func parseAuthResponse(data: Data, email: String, storefront: String) throws -> Account {
        // Try to decode plist response
        guard let authResp = try? PropertyListDecoder().decode(AuthResponse.self, from: data) else {
            // Try parsing as XML plist manually
            if let xmlString = String(data: data, encoding: .utf8) {
                return try parseXMLResponse(xmlString, email: email, storefront: storefront)
            }
            throw AuthError.unknown("Cannot parse Apple response")
        }

        // Check for failures
        if let failure = authResp.failureType {
            let msg = authResp.customerMessage ?? ""
            switch failure {
            case failureInvalidCredentials, "-5000":
                throw AuthError.invalidCredentials
            case failureBadLogin:
                throw AuthError.invalidCredentials
            case failureTwoFactor:
                throw AuthError.twoFactorRequired
            case failurePasswordExpired, "2034":
                throw AuthError.passwordExpired
            default:
                if msg.contains("disabled") {
                    throw AuthError.accountDisabled
                }
                if msg == failureAccountDisabled {
                    throw AuthError.accountDisabled
                }
                throw AuthError.unknown(msg.isEmpty ? failure : msg)
            }
        }

        guard let dsPersonId = authResp.dsPersonId,
              let token = authResp.passwordToken else {
            throw AuthError.unknown("Missing auth tokens in response")
        }

        let firstName = authResp.accountInfo?.address?.firstName ?? ""
        let lastName  = authResp.accountInfo?.address?.lastName  ?? ""
        let resolvedEmail = authResp.accountInfo?.appleId ?? email

        return Account(
            email: resolvedEmail,
            firstName: firstName,
            lastName: lastName,
            dsPersonId: dsPersonId,
            passwordToken: token,
            storefront: storefront,
            createdAt: Date()
        )
    }

    /// Fallback: parse XML plist manually
    private func parseXMLResponse(_ xml: String, email: String, storefront: String) throws -> Account {
        func value(for key: String, in xml: String) -> String? {
            let pattern = "<key>\(NSRegularExpression.escapedPattern(for: key))</key>\\s*<(?:string|integer)>([^<]+)</(?:string|integer)>"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                  let range = Range(match.range(at: 1), in: xml) else { return nil }
            return String(xml[range])
        }

        if let failure = value(for: "failureType", in: xml) {
            let msg = value(for: "customerMessage", in: xml) ?? ""
            if failure == "-5000" || failure == failureInvalidCredentials || msg.contains("password") {
                throw AuthError.invalidCredentials
            }
            if msg.contains("disabled") { throw AuthError.accountDisabled }
            throw AuthError.unknown(msg.isEmpty ? failure : msg)
        }

        guard let dsPersonId = value(for: "dsPersonId", in: xml),
              let token = value(for: "passwordToken", in: xml) else {
            throw AuthError.invalidCredentials
        }

        return Account(
            email: email,
            firstName: value(for: "firstName", in: xml) ?? "",
            lastName: value(for: "lastName", in: xml) ?? "",
            dsPersonId: dsPersonId,
            passwordToken: token,
            storefront: storefront,
            createdAt: Date()
        )
    }
}

// MARK: - No Redirect Delegate
private class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Let the caller handle redirects manually
        completionHandler(nil)
    }
}

// MARK: - String Extension
private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B") ?? self
    }
}
