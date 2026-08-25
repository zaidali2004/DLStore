import SwiftUI

struct LoginView: View {
    @EnvironmentObject var accountStore: AccountStore
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var authCode = ""
    @State private var storefront = "143441"

    @State private var phase: Phase = .credentials
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Phase { case credentials, twoFactor }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                        .padding(.top, 20)

                    Text("تسجيل الدخول")
                        .font(.largeTitle.bold())

                    // Error Banner
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    if phase == .credentials {
                        credentialsForm
                    } else {
                        twoFactorForm
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Credentials Form
    var credentialsForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple ID").font(.caption).foregroundColor(.secondary)
                TextField("example@icloud.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("كلمة المرور").font(.caption).foregroundColor(.secondary)
                SecureField("••••••••", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("المنطقة").font(.caption).foregroundColor(.secondary)
                Picker("المنطقة", selection: $storefront) {
                    Text("السعودية").tag("143463")
                    Text("الإمارات").tag("143481")
                    Text("الولايات المتحدة").tag("143441")
                    Text("المملكة المتحدة").tag("143444")
                    Text("مصر").tag("143418")
                    Text("الكويت").tag("143493")
                    Text("قطر").tag("143498")
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            Button {
                Task { await login() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("تسجيل الدخول")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canLogin ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!canLogin || isLoading)
        }
        .padding(.horizontal)
    }

    // MARK: - 2FA Form
    var twoFactorForm: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("التحقق بخطوتين")
                .font(.title2.bold())

            Text("أدخل رمز التحقق المرسل إلى أجهزتك الأخرى")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            TextField("000000", text: $authCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title.monospaced())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

            Button {
                Task { await login() }
            } label: {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    else { Text("تأكيد").fontWeight(.semibold) }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(authCode.count >= 6 ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(authCode.count < 6 || isLoading)
            .padding(.horizontal)

            Button("استخدام حساب آخر") {
                phase = .credentials
                authCode = ""
                errorMessage = nil
            }
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Logic
    var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func login() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let account = try await AuthService.shared.login(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                authCode: authCode,
                storefront: storefront
            )
            await MainActor.run {
                accountStore.add(account)
                dismiss()
            }
        } catch AuthError.twoFactorRequired {
            await MainActor.run {
                phase = .twoFactor
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
