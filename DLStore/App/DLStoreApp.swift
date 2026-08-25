import SwiftUI

@main
struct DLStoreApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var downloadManager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountStore)
                .environmentObject(downloadManager)
        }
    }
}
