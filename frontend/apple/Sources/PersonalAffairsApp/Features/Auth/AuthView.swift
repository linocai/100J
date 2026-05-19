import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var model: AppModel
    @State private var accessCode = ""
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://100j.linotsai.top/api/v1"
    @State private var showingAdvanced = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Image(systemName: "key.icloud")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text("100J")
                    .font(.largeTitle.weight(.semibold))
                Text("连接你的个人云端工作台")
                    .foregroundStyle(.secondary)
                Text("使用服务器上的云端访问码接入，登录状态会保存在 Apple 钥匙串中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                AuthField(label: "云端访问码") {
                    SecureField("输入云端访问码", text: $accessCode)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }

                DisclosureGroup("高级连接设置", isExpanded: $showingAdvanced) {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Spacer()

                    Button {
                        submit()
                    } label: {
                        if model.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("连接云端")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(accessCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 || model.isLoading)
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
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 8, !model.isLoading else { return }
        Task {
            await model.connectCloudOwner(accessCode: code, baseURL: endpoint.isEmpty ? nil : endpoint)
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
