import SwiftUI

/// v1.1 登录页 — Sign in with Apple 是唯一主入口。
/// 底部小字「在自部署服务器上？」打开独立 sheet，输入访问码 + base URL。
struct LoginScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSelfHosted = false

    var body: some View {
        ZStack {
            MeshGradientBackdrop()

            VStack(spacing: AppTheme.Spacing.xxxl) {
                Spacer()

                VStack(spacing: AppTheme.Spacing.lg) {
                    BrandMark(size: 80)
                        .padding(.bottom, AppTheme.Spacing.sm)
                    Text("欢迎使用 100J")
                        .font(.system(size: 38, weight: .bold))
                        .tracking(-0.5)
                    Text("把弹性待办、固定日程和灵感分开管理。\n所有数据加密保存在你的私有云端。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 420)
                }

                VStack(spacing: AppTheme.Spacing.md) {
                    AppleSignInButton { result in
                        Task { await model.handleAppleSignIn(result) }
                    }
                    .frame(width: 320)

                    Text("首次登录会自动创建 Personal 与 Company 空间")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(.init("继续即表示你接受 [服务条款](https://100j.linotsai.top/terms) 与 [隐私政策](https://100j.linotsai.top/privacy)。"))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .tint(.indigo)
                    .frame(maxWidth: 340)

                Spacer()

                Button {
                    showingSelfHosted = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                        Text("自部署 / 调试 → 使用访问码登录")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .padding(AppTheme.Spacing.xxxl)
        }
        .sheet(isPresented: $showingSelfHosted) {
            SelfHostedLoginSheet(isPresented: $showingSelfHosted)
                .environmentObject(model)
        }
    }
}

/// 独立 Sheet — 输入访问码 + base URL，关闭即回登录页。
struct SelfHostedLoginSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool
    @State private var accessCode = ""
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://100j.linotsai.top/api/v1"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("8 位以上访问码", text: $accessCode)
                        #if os(iOS)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("API Base URL", text: $baseURL)
                        .font(.callout.monospaced())
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                } header: {
                    Text("自部署接入")
                } footer: {
                    Text("仅在自部署 100J 服务器、或本地调试时使用。普通用户请用 Apple ID 登录。")
                        .font(.footnote)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if model.isLoading {
                                ProgressView()
                            } else {
                                Text("连接")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets())
                }

                #if DEBUG
                Section {
                    Button("开发：进入本机 Owner") {
                        model.updateBaseURL("http://127.0.0.1:8000/api/v1")
                        model.updateAuthMode(.localOwner)
                        isPresented = false
                    }
                    .foregroundStyle(.tint)
                } footer: {
                    Text("仅 DEBUG 构建可见。")
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle("自部署登录")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 460)
        #else
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private var canSubmit: Bool {
        accessCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 && !model.isLoading
    }

    private func submit() {
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await model.connectCloudOwner(accessCode: code, baseURL: endpoint.isEmpty ? nil : endpoint)
            if model.isAuthenticated {
                isPresented = false
            }
        }
    }
}
