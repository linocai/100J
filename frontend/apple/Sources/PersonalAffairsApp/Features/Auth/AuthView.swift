import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text("100J")
                    .font(.largeTitle.weight(.semibold))
                Text("登录你的个人事务工作台")
                    .foregroundStyle(.secondary)
                Text("登录状态会安全保存在 Apple 钥匙串中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                AuthField(label: "邮箱") {
                    TextField("name@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                }
                AuthField(label: "密码") {
                    SecureField("密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                if isRegistering {
                    AuthField(label: "显示名称") {
                        TextField("可选", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                AuthField(label: "API Base URL") {
                    TextField("http://127.0.0.1:8000/api/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                HStack {
                    Button(isRegistering ? "已有账号？" : "创建账号") {
                        isRegistering.toggle()
                    }
                    #if os(macOS)
                    .buttonStyle(.link)
                    #else
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    #endif

                    Spacer()

                    Button {
                        submit()
                    } label: {
                        if model.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(isRegistering ? "注册" : "登录")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || model.isLoading)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 400)
            #if os(macOS)
            .controlSize(.large)
            #else
            .padding(.horizontal)
            #endif

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        }
        .onSubmit(submit)
        #if os(macOS)
        .padding(40)
        #else
        .padding(.vertical, 28)
        #endif
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty, !model.isLoading else { return }
        Task {
            model.updateBaseURL(baseURL)
            if isRegistering {
                await model.register(email: email, password: password, displayName: displayName.trimmedOrNil)
            } else {
                await model.login(email: email, password: password)
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
