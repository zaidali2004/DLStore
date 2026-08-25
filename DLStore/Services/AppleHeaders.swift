import Foundation
import UIKit

/// Apple-specific HTTP headers required for iTunes Store API
/// Based on Configurator 2.20 on macOS 26.5.1
enum AppleHeaders {

    static let userAgent = "Configurator/2.20 (Macintosh; OS X 26.5.1; 25F80) AppleWebKit/1624.2.5.11.4"
    static let widgetKey = "e0b80c3bf78523bfe532fc78cc52ef2f"

    static func apply(to request: inout URLRequest, guid: String, storefront: String = "143441-1,29") {
        request.setValue(userAgent,     forHTTPHeaderField: "User-Agent")
        request.setValue(storefront,    forHTTPHeaderField: "X-Apple-Store-Front")
        request.setValue("0",           forHTTPHeaderField: "X-Apple-Tz")
        request.setValue(widgetKey,     forHTTPHeaderField: "X-Apple-Widget-Key")
        request.setValue("en_US",       forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    }

    static func applyAuth(to request: inout URLRequest,
                          guid: String,
                          storefront: String = "143441-1,29",
                          dsPersonId: String? = nil,
                          token: String? = nil) {
        apply(to: &request, guid: guid, storefront: storefront)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/x-apple-plist",         forHTTPHeaderField: "Accept")
        if let dsPersonId = dsPersonId {
            request.setValue(dsPersonId, forHTTPHeaderField: "X-Dsid")
            request.setValue(dsPersonId, forHTTPHeaderField: "iCloud-Dsid")
        }
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "X-Token")
        }
    }

    /// Generate GUID from device UUID (replaces DLiPA's MAC address approach)
    static func deviceGUID() -> String {
        let key = "dlstore.device.guid"
        if let data = KeychainService.load(key: key),
           let stored = String(data: data, encoding: .utf8) {
            return stored
        }
        // Generate stable GUID from identifierForVendor
        let raw = UIDevice.current.identifierForVendor?.uuidString
                  ?? UUID().uuidString
        let guid = raw.replacingOccurrences(of: "-", with: "").uppercased()
        KeychainService.save(key: key, data: Data(guid.utf8))
        return guid
    }
}
