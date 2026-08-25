import SwiftUI

struct ContentView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Label("البحث", systemImage: "magnifyingglass")
                }
                .tag(0)

            AccountsView()
                .tabItem {
                    Label("الحسابات", systemImage: "person.circle")
                }
                .tag(1)

            DownloadsView()
                .tabItem {
                    Label("التنزيلات", systemImage: "arrow.down.circle")
                }
                .badge(downloadManager.items.filter {
                    $0.status == .downloading || $0.status == .purchasing
                }.count)
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("الإعدادات", systemImage: "gearshape")
                }
                .tag(3)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
