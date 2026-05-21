import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var model: AppModel
    @State private var emailField = ""
    @State private var otpField = ""
    @State private var otpRequested = false
    @State private var accessCode = ""
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://100j.linotsai.top/api/v1"
    @State private var showingAdvanced = false
    @FocusState private var emailFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            VStack(spacing: 12) {
                AuthAppMark()
                Text("欢迎使用 100J")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("把弹性待办、固定日程和灵感分开管理。所有数据保存在你的私有云端。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            VStack(spacing: 14) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    Task { await model.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(width: 320, height: 46)
                .disabled(model.isLoading)

                Text("或")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                emailOTPBlock
            }
            .controlSize(.large)

            Text("继续即表示你接受服务条款与隐私政策。")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 18)

            DisclosureGroup("自部署 / 调试", isExpanded: $showingAdvanced) {
                AdvancedAuthBox(
                    accessCode: $accessCode,
                    baseURL: $baseURL,
                    submit: submitAccessCode
                )
                .padding(.top, 10)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 360)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .onSubmit {
            if otpRequested {
                verifyOTP()
            } else if emailField.contains("@") {
                requestOTP()
            }
        }
    }

    @ViewBuilder
    private var emailOTPBlock: some View {
        if otpRequested {
            VStack(spacing: 10) {
                TextField("6 位验证码", text: $otpField)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif

                Button {
                    verifyOTP()
                } label: {
                    HStack {
                        if model.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("登录")
                    }
                    .frame(width: 320)
                }
                .buttonStyle(.borderedProminent)
                .disabled(otpField.trimmingCharacters(in: .whitespacesAndNewlines).count != 6 || model.isLoading)

                Button("换个邮箱") {
                    otpRequested = false
                    otpField = ""
                    emailFocused = true
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        } else {
            VStack(spacing: 10) {
                TextField("邮箱", text: $emailField)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .focused($emailFocused)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif

                Button {
                    requestOTP()
                } label: {
                    HStack {
                        if model.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("发送一次性验证码")
                    }
                    .frame(width: 320)
                }
                .buttonStyle(.bordered)
                .disabled(!emailField.contains("@") || model.isLoading)
            }
        }
    }

    private func requestOTP() {
        Task {
            await model.requestEmailOTP(email: emailField)
            if model.errorMessage == nil {
                otpRequested = true
            }
        }
    }

    private func verifyOTP() {
        Task {
            await model.verifyEmailOTP(email: emailField, code: otpField)
        }
    }

    private func submitAccessCode() {
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 8, !model.isLoading else { return }
        Task {
            await model.connectCloudOwner(accessCode: code, baseURL: endpoint.isEmpty ? nil : endpoint)
        }
    }
}

private struct AuthAppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.indigo)
            Text("J")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 58, height: 58)
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        .accessibilityHidden(true)
    }
}

private struct AdvancedAuthBox: View {
    @EnvironmentObject private var model: AppModel
    @Binding var accessCode: String
    @Binding var baseURL: String
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AuthField(label: "云端访问码") {
                SecureField("输入云端访问码", text: $accessCode)
                    .textFieldStyle(.roundedBorder)
            }

            AuthField(label: "API Base URL") {
                TextField("https://100j.linotsai.top/api/v1", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    #endif
            }

            HStack {
                #if DEBUG
                Button("开发：进入本机 Owner") {
                    model.updateBaseURL("http://127.0.0.1:8000/api/v1")
                    model.updateAuthMode(.localOwner)
                }
                #if os(macOS)
                .buttonStyle(.link)
                #else
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                #endif
                #endif

                Spacer()

                Button("连接访问码", action: submit)
                    .buttonStyle(.bordered)
                    .disabled(accessCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 || model.isLoading)
            }
        }
    }
}

private struct AuthField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}
