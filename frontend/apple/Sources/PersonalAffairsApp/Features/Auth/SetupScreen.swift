import PersonalAffairsCore
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// v1.1.2 Setup 屏 —— 一次性输入访问码，之后再也不见。
/// 输入成功后：
///   1. 服务器颁发 device-bound refresh token（365 天）
///   2. 写 Apple Keychain（whenUnlockedThisDeviceOnly）
///   3. 之后每次启动 AppModel.bootstrapIfPossible() 静默 resume
struct SetupScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var accessCode = ""
    @State private var showingAdvanced = false
    @FocusState private var codeFocused: Bool

    var body: some View {
        ZStack {
            MeshGradientBackdrop()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    Spacer(minLength: 60)

                    hero
                    setupCard

                    Button {
                        showingAdvanced = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "server.rack")
                            Text("自部署 / 自定义服务器地址")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppTheme.Spacing.xxl)
                .frame(maxWidth: 540, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .sheet(isPresented: $showingAdvanced) {
            AdvancedServerSheet(isPresented: $showingAdvanced)
                .environmentObject(model)
        }
        .onAppear { codeFocused = true }
    }

    private var hero: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            BrandMark(size: 84)
                .padding(.bottom, AppTheme.Spacing.sm)
            Text("欢迎使用 100J")
                .font(.system(size: 36, weight: .bold))
                .tracking(-0.5)
            Text("设置只需一次。\n之后这台设备会自动登录，再也不需要输入。")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var setupCard: some View {
        GlassCard(cornerRadius: 20, padding: AppTheme.Spacing.xxl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("一次性访问码")
                        .font(.headline.weight(.semibold))
                    Text("由你的服务器管理员设置（OWNER_CLOUD_ACCESS_CODE）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SecureField("8 位以上访问码", text: $accessCode)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .focused($codeFocused)
                    #if os(iOS)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    #endif
                    .onSubmit(submit)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("绑定到 \(deviceName)，写入 Apple 钥匙串")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    submit()
                } label: {
                    HStack {
                        Spacer()
                        if model.isLoading {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(.white)
                        } else {
                            Text("绑定这台设备并进入")
                                .font(.headline.weight(.semibold))
                        }
                        Spacer()
                    }
                    .frame(height: 22)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
        }
    }

    private var deviceName: String {
        DeviceSessionStore.defaultDeviceName
    }

    private var canSubmit: Bool {
        accessCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 && !model.isLoading
    }

    private func submit() {
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 8 else { return }
        Task {
            await model.connectCloudOwner(accessCode: code, baseURL: nil)
        }
    }
}

/// 高级 sheet：自部署 base URL。访问码输入仍在主屏。
private struct AdvancedServerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? AppModel.defaultCloudBaseURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("API Base URL", text: $baseURL)
                        .font(.callout.monospaced())
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                } header: {
                    Text("自部署服务器")
                } footer: {
                    Text("默认 \(AppModel.defaultCloudBaseURL) — 只在你跑了自己的 100J 服务器时改。")
                        .font(.footnote)
                }

                #if DEBUG
                Section {
                    Button("开发：进入本机 Owner 模式") {
                        model.updateBaseURL("http://127.0.0.1:8000/api/v1")
                        model.updateAuthMode(.localOwner)
                        isPresented = false
                    }
                } footer: {
                    Text("仅 DEBUG 构建可见。")
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle("服务器设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !endpoint.isEmpty {
                            _ = model.updateBaseURL(endpoint)
                        }
                        isPresented = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 360)
        #else
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        #endif
    }
}
