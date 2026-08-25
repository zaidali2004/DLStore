import SwiftUI

struct SettingsView: View {
    @State private var showResetConfirm = false
    @State private var guid = AppleHeaders.deviceGUID()

    var body: some View {
        NavigationView {
            List {
                // GUID Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("معرف الجهاز (GUID)")
                                .font(.subheadline)
                            Text(guid)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = guid
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.accentColor)
                        }
                    }

                    Button {
                        regenerateGUID()
                    } label: {
                        Label("توليد GUID جديد", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("إعدادات الجهاز")
                }

                // App Info
                Section {
                    HStack {
                        Text("الإصدار")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("المطور")
                        Spacer()
                        Text("DLStore")
                            .foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "https://github.com/majd/ipatool")!) {
                        Label("المصدر الإلهامي", systemImage: "link")
                    }
                } header: {
                    Text("عن التطبيق")
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("إعادة تعيين التطبيق", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("منطقة الخطر")
                }
            }
            .navigationTitle("الإعدادات")
            .confirmationDialog("إعادة التعيين", isPresented: $showResetConfirm) {
                Button("إعادة التعيين", role: .destructive) {
                    resetApp()
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("سيتم حذف جميع الحسابات والتنزيلات والإعدادات")
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    func regenerateGUID() {
        KeychainService.delete(key: "dlstore.device.guid")
        guid = AppleHeaders.deviceGUID()
    }

    func resetApp() {
        // Clear all keychain data
        ["dlstore.accounts", "dlstore.accounts.active", "dlstore.device.guid"].forEach {
            KeychainService.delete(key: $0)
        }
        // Clear downloads folder
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads")
        try? FileManager.default.removeItem(at: dir)
    }
}
