import Foundation
import Combine

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var items: [DownloadTask] = []

    private var urlSession: URLSession!
    private var activeTasks: [Int: DownloadTask] = [:]  // taskId -> DownloadTask

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.dlstore.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public

    func download(app: StoreApp, account: Account, versionId: Int? = nil) {
        guard !items.contains(where: { $0.app.id == app.id && $0.status == .downloading }) else {
            return
        }
        let task = DownloadTask(app: app, account: account, versionId: versionId)
        DispatchQueue.main.async { self.items.insert(task, at: 0) }
        Task { await startDownload(task) }
    }

    func remove(_ task: DownloadTask) {
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == task.id }
        }
    }

    func clearCompleted() {
        DispatchQueue.main.async {
            self.items.removeAll { $0.status == .completed || $0.status == .failed }
        }
    }

    // MARK: - Download Flow

    private func startDownload(_ task: DownloadTask) async {
        updateTask(task, status: .purchasing)

        do {
            // Step 1: Purchase (acquire license)
            do {
                try await PurchaseService.shared.purchase(app: task.app, account: task.account)
            } catch PurchaseError.alreadyOwned {
                // Already owned is fine, continue to download
            }

            // Step 2: Get download URL
            updateTask(task, status: .downloading)
            let ipaURL = try await fetchDownloadURL(task: task)

            // Step 3: Download the IPA
            try await downloadIPA(task: task, from: ipaURL)

            updateTask(task, status: .completed)

        } catch {
            updateTask(task, status: .failed, error: error.localizedDescription)
        }
    }

    private func fetchDownloadURL(task: DownloadTask) async throws -> URL {
        let guid = AppleHeaders.deviceGUID()
        let buyEndpoint = await BagService.shared.getBuyEndpoint(guid: guid)

        guard var urlComps = URLComponents(string: buyEndpoint) else {
            throw URLError(.badURL)
        }
        urlComps.queryItems = [URLQueryItem(name: "guid", value: guid)]
        guard let url = urlComps.url else { throw URLError(.badURL) }

        var bodyParts = [
            "appExtVrsId=\(task.versionId ?? task.app.id)",
            "guid=\(guid)",
            "price=0",
            "pricingParameters=STDQ",
            "productType=C",
            "salableAdamId=\(task.app.id)",
            "externalVersionId=\(task.versionId ?? task.app.id)"
        ]
        let body = bodyParts.joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 20
        AppleHeaders.applyAuth(
            to: &request,
            guid: guid,
            storefront: task.account.storefront,
            dsPersonId: task.account.dsPersonId,
            token: task.account.passwordToken
        )

        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse download URL from plist response
        if let xmlStr = String(data: data, encoding: .utf8) {
            let pattern = "<key>URL</key>\\s*<string>([^<]+)</string>"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: xmlStr, range: NSRange(xmlStr.startIndex..., in: xmlStr)),
               let range = Range(match.range(at: 1), in: xmlStr),
               let url = URL(string: String(xmlStr[range])) {
                return url
            }
        }
        throw NSError(domain: "DLStore", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "لم يتم العثور على رابط التنزيل"])
    }

    private func downloadIPA(task: DownloadTask, from url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url)
            request.timeoutInterval = 0 // No timeout for downloads
            let guid = AppleHeaders.deviceGUID()
            AppleHeaders.apply(to: &request, guid: guid, storefront: task.account.storefront)

            let dlTask = urlSession.downloadTask(with: request)
            activeTasks[dlTask.taskIdentifier] = task
            task.continuation = continuation
            dlTask.resume()
        }
    }

    // MARK: - Helpers

    private func updateTask(_ task: DownloadTask,
                            status: DownloadTask.Status,
                            progress: Double? = nil,
                            localURL: URL? = nil,
                            error: String? = nil) {
        DispatchQueue.main.async {
            task.status = status
            if let p = progress { task.progress = p }
            if let u = localURL { task.localURL = u }
            if let e = error    { task.errorMessage = e }
        }
    }
}

// MARK: - URLSession Download Delegate
extension DownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let task = activeTasks[downloadTask.taskIdentifier] else { return }
        activeTasks.removeValue(forKey: downloadTask.taskIdentifier)

        // Move to Documents/Downloads
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let filename = "\(task.app.name)_\(task.app.version).ipa"
            .replacingOccurrences(of: "/", with: "-")
        let destination = dir.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            updateTask(task, status: .completed, localURL: destination)
            task.continuation?.resume(returning: ())
        } catch {
            updateTask(task, status: .failed, error: error.localizedDescription)
            task.continuation?.resume(throwing: error)
        }
        task.continuation = nil
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let task = activeTasks[downloadTask.taskIdentifier],
              totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        updateTask(task, status: .downloading, progress: progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let dlTask = activeTasks[task.taskIdentifier] else { return }
        activeTasks.removeValue(forKey: task.taskIdentifier)
        updateTask(dlTask, status: .failed, error: error.localizedDescription)
        dlTask.continuation?.resume(throwing: error)
        dlTask.continuation = nil
    }
}

// MARK: - DownloadTask
class DownloadTask: ObservableObject, Identifiable {
    let id = UUID()
    let app: StoreApp
    let account: Account
    let versionId: Int?
    let createdAt = Date()

    @Published var status: Status = .waiting
    @Published var progress: Double = 0
    @Published var localURL: URL?
    @Published var errorMessage: String?

    var continuation: CheckedContinuation<Void, Error>?

    enum Status: String {
        case waiting     = "انتظار"
        case purchasing  = "جاري الحصول على الترخيص"
        case downloading = "جاري التنزيل"
        case completed   = "اكتمل"
        case failed      = "فشل"
    }

    init(app: StoreApp, account: Account, versionId: Int? = nil) {
        self.app = app
        self.account = account
        self.versionId = versionId
    }
}
