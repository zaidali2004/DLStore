import SwiftUI

struct AppDetailView: View {
    let app: StoreApp
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.dismiss) var dismiss
    @State private var isDownloading = false
    @State private var errorMessage: String?

    var isAlreadyDownloading: Bool {
        downloadManager.items.contains {
            $0.app.id == app.id && ($0.status == .downloading || $0.status == .purchasing)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(alignment: .top, spacing: 16) {
                        AsyncImage(url: app.artworkURL) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.2) }
                        .frame(width: 80, height: 80)
                        .cornerRadius(18)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(app.name).font(.title2.bold())
                            Text(app.developerName).foregroundColor(.secondary)
                            Text(app.genre).font(.caption).foregroundColor(.secondary)
                            Text(app.isFree ? "مجاني" : "\(app.price)")
                                .font(.caption.bold())
                                .foregroundColor(app.isFree ? .green : .primary)
                        }
                        Spacer()
                    }
                    .padding()

                    // Error
                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                            Text(err).font(.subheadline).foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Download button
                    Button {
                        Task { await startDownload() }
                    } label: {
                        HStack {
                            if isDownloading || isAlreadyDownloading {
                                ProgressView().tint(.white)
                                Text("جاري التنزيل...")
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("تنزيل IPA")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            accountStore.activeAccount == nil ? Color.gray :
                            (isDownloading || isAlreadyDownloading) ? Color.orange : Color.accentColor
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isDownloading || isAlreadyDownloading || accountStore.activeAccount == nil)
                    .padding(.horizontal)

                    if accountStore.activeAccount == nil {
                        Text("⚠️ يجب تسجيل الدخول أولاً")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal)
                    }

                    // Info
                    Divider().padding(.horizontal)
                    infoSection

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("الوصف").font(.headline)
                        Text(app.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    var infoSection: some View {
        HStack {
            InfoCell(title: "الإصدار", value: app.version)
            Divider()
            InfoCell(title: "الحجم", value: app.fileSizeMB)
            Divider()
            InfoCell(title: "iOS الأدنى", value: app.minimumOsVersion)
        }
        .frame(height: 60)
        .padding(.horizontal)
    }

    func startDownload() async {
        guard let account = accountStore.activeAccount else { return }
        isDownloading = true
        errorMessage = nil
        defer { isDownloading = false }

        downloadManager.download(app: app, account: account)
        dismiss()
    }
}

struct InfoCell: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
