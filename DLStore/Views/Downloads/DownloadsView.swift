import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject var downloadManager: DownloadManager

    var body: some View {
        NavigationView {
            Group {
                if downloadManager.items.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle("التنزيلات")
            .toolbar {
                if !downloadManager.items.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("مسح المكتملة") {
                            downloadManager.clearCompleted()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.35))
            Text("لا توجد تنزيلات")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("ابحث عن تطبيق وابدأ التنزيل")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    var taskList: some View {
        List {
            ForEach(downloadManager.items) { task in
                DownloadRow(task: task)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            downloadManager.remove(task)
                        } label: {
                            Label("حذف", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct DownloadRow: View {
    @ObservedObject var task: DownloadTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: task.app.artworkURL) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { Color.gray.opacity(0.2) }
                .frame(width: 44, height: 44)
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.app.name).font(.headline).lineLimit(1)
                    Text(task.status.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }

                Spacer()

                statusIcon
            }

            if task.status == .downloading {
                ProgressView(value: task.progress)
                    .tint(.accentColor)
                Text("\(Int(task.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let error = task.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let url = task.localURL, task.status == .completed {
                ShareLink(item: url, subject: Text(task.app.name)) {
                    Label("مشاركة IPA", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }

    var statusColor: Color {
        switch task.status {
        case .waiting:     return .secondary
        case .purchasing:  return .orange
        case .downloading: return .accentColor
        case .completed:   return .green
        case .failed:      return .red
        }
    }

    @ViewBuilder
    var statusIcon: some View {
        switch task.status {
        case .waiting:
            Image(systemName: "clock").foregroundColor(.secondary)
        case .purchasing:
            ProgressView().controlSize(.small)
        case .downloading:
            ProgressView().controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        }
    }
}
