import Foundation
import Security

// MARK: - Account Model
struct Account: Codable, Identifiable, Equatable {
    var id: String { email }
    let email: String
    let firstName: String
    let lastName: String
    let dsPersonId: String
    let passwordToken: String
    let storefront: String
    let createdAt: Date

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? email : full
    }
}

// MARK: - Account Store (ObservableObject)
class AccountStore: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var activeAccount: Account?

    private let keychainKey = "dlstore.accounts"

    init() {
        load()
    }

    func add(_ account: Account) {
        // Remove if already exists
        accounts.removeAll { $0.email == account.email }
        accounts.insert(account, at: 0)
        if activeAccount == nil {
            activeAccount = account
        }
        save()
    }

    func remove(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        if activeAccount?.id == account.id {
            activeAccount = accounts.first
        }
        save()
    }

    func setActive(_ account: Account) {
        activeAccount = account
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        KeychainService.save(key: keychainKey, data: data)
        if let active = activeAccount,
           let activeData = try? JSONEncoder().encode(active) {
            KeychainService.save(key: "\(keychainKey).active", data: activeData)
        }
    }

    private func load() {
        if let data = KeychainService.load(key: keychainKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        }
        if let data = KeychainService.load(key: "\(keychainKey).active"),
           let decoded = try? JSONDecoder().decode(Account.self, from: data) {
            activeAccount = decoded
        } else {
            activeAccount = accounts.first
        }
    }
}
