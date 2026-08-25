import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var accountStore: AccountStore
    @State private var showLogin = false
    @State private var accountToDelete: Account?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            Group {
                if accountStore.accounts.isEmpty {
                    emptyState
                } else {
                    accountsList
                }
            }
            .navigationTitle("الحسابات")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showLogin = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .confirmationDialog("حذف الحساب", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("حذف الحساب", role: .destructive) {
                    if let acc = accountToDelete {
                        accountStore.remove(acc)
                    }
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("هل أنت متأكد من حذف هذا الحساب؟")
            }
        }
    }

    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.4))
            Text("لا توجد حسابات")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("أضف Apple ID لبدء التنزيل")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                showLogin = true
            } label: {
                Label("إضافة حساب", systemImage: "plus")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Accounts List
    var accountsList: some View {
        List {
            ForEach(accountStore.accounts) { account in
                AccountRow(account: account, isActive: account.id == accountStore.activeAccount?.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        accountStore.setActive(account)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            accountToDelete = account
                            showDeleteConfirm = true
                        } label: {
                            Label("حذف", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

struct AccountRow: View {
    let account: Account
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 46, height: 46)
                Text(account.displayName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(isActive ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(account.displayName)
                    .font(.headline)
                Text(account.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}
