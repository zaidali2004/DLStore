import SwiftUI

struct SearchView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var query = ""
    @State private var results: [StoreApp] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var history: [String] = []
    @State private var selectedApp: StoreApp?

    var body: some View {
        NavigationView {
            Group {
                if results.isEmpty && !isLoading && query.isEmpty {
                    historyView
                } else if isLoading {
                    ProgressView("جاري البحث...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty {
                    noResults
                } else {
                    resultsList
                }
            }
            .navigationTitle("البحث")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "اسم التطبيق أو Bundle ID")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .sheet(item: $selectedApp) { app in
                AppDetailView(app: app)
                    .environmentObject(accountStore)
                    .environmentObject(downloadManager)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Search History
    var historyView: some View {
        VStack {
            if history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("ابحث عن أي تطبيق")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("السجل") {
                        ForEach(history, id: \.self) { term in
                            Button {
                                query = term
                                Task { await search() }
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text(term)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                        .onDelete { history.remove(atOffsets: $0) }
                    }
                }
            }
        }
    }

    // MARK: - No Results
    var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.4))
            Text("لا توجد نتائج لـ \"\(query)\"")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results List
    var resultsList: some View {
        List(results) { app in
            AppRow(app: app)
                .contentShape(Rectangle())
                .onTapGesture { selectedApp = app }
        }
        .listStyle(.plain)
    }

    // MARK: - Search Logic
    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Add to history
        if !history.contains(query) {
            history.insert(query, at: 0)
            if history.count > 20 { history = Array(history.prefix(20)) }
        }

        do {
            results = try await SearchService.shared.search(
                term: query,
                storefront: accountStore.activeAccount?.storefront ?? "143441"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - App Row
struct AppRow: View {
    let app: StoreApp

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: app.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 56, height: 56)
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(app.developerName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack {
                    Text(app.genre)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(app.isFree ? "مجاني" : String(format: "%.2f", app.price))
                        .font(.caption.bold())
                        .foregroundColor(app.isFree ? .green : .primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
